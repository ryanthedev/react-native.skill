#!/usr/bin/env node

// cdp-bridge.js -- Chrome DevTools Protocol bridge for React Native debugging
// Modes: console, eval, tree, network
// Requires Node 22+ (native WebSocket, native fetch)

"use strict";

// -- Node version check --

const nodeMajor = parseInt(process.version.slice(1), 10);
if (nodeMajor < 22) {
    process.stderr.write(
        `cdp-bridge.js requires Node 22+, found ${process.version}\n`
    );
    process.exit(1);
}

// -- Port resolution: --port flag > RCT_METRO_PORT env > 8081 --

function resolvePort(args) {
    if (args.port !== undefined) {
        return args.port;
    }
    if (process.env.RCT_METRO_PORT) {
        return parseInt(process.env.RCT_METRO_PORT, 10);
    }
    return 8081;
}

// -- WebSocket URL discovery via Metro /json/list endpoint --

async function discoverWebSocketUrl(port) {
    const url = `http://localhost:${port}/json/list`;
    const response = await fetch(url);
    const targets = await response.json();

    if (!Array.isArray(targets) || targets.length === 0) {
        throw new Error("No debuggable targets found from Metro");
    }

    // Select target by capability priority:
    // 1. reactNative.capabilities.nativePageReloads === true (Expo/new arch)
    // 2. Title includes "Bridgeless" (new architecture fallback)
    // 3. First target (vanilla RN single-target case)
    const target =
        targets.find((t) => t.reactNative?.capabilities?.nativePageReloads === true) ||
        targets.find((t) => t.title && t.title.includes("Bridgeless")) ||
        targets[0];

    const wsUrl = target.webSocketDebuggerUrl;
    if (!wsUrl) {
        throw new Error("Target missing webSocketDebuggerUrl");
    }
    return wsUrl;
}

// -- CDP client wrapper --
// Deep module: hides message ID tracking, request/response correlation,
// and JSON parse/stringify behind send(method, params) + on(event, cb).

function connectCDP(wsUrl) {
    return new Promise((resolve, reject) => {
        const ws = new WebSocket(wsUrl);

        let nextId = 1;
        // Pending requests keyed by message ID, each holding {resolve, reject}
        const pending = new Map();
        // Event listeners keyed by CDP method name
        const listeners = new Map();

        ws.addEventListener("open", () => {
            resolve({
                // Send a CDP command, returns a Promise with the result
                send(method, params = {}) {
                    return new Promise((res, rej) => {
                        const id = nextId++;
                        pending.set(id, { resolve: res, reject: rej });
                        ws.send(JSON.stringify({ id, method, params }));
                    });
                },

                // Register a listener for CDP events
                on(method, callback) {
                    if (!listeners.has(method)) {
                        listeners.set(method, []);
                    }
                    listeners.get(method).push(callback);
                },

                // Close the WebSocket connection
                close() {
                    ws.close();
                },
            });
        });

        ws.addEventListener("message", (event) => {
            let msg;
            try {
                msg = JSON.parse(event.data);
            } catch {
                return;
            }

            // Response to a send() call
            if (msg.id !== undefined && pending.has(msg.id)) {
                const handler = pending.get(msg.id);
                pending.delete(msg.id);
                if (msg.error) {
                    handler.reject(new Error(msg.error.message));
                } else {
                    handler.resolve(msg.result);
                }
                return;
            }

            // CDP event
            if (msg.method && listeners.has(msg.method)) {
                for (const cb of listeners.get(msg.method)) {
                    cb(msg.params);
                }
            }
        });

        ws.addEventListener("error", (err) => {
            // Reject all pending requests on error
            for (const handler of pending.values()) {
                handler.reject(err);
            }
            pending.clear();
            reject(err);
        });

        ws.addEventListener("close", () => {
            // Reject any remaining pending requests
            for (const handler of pending.values()) {
                handler.reject(new Error("WebSocket closed"));
            }
            pending.clear();
        });
    });
}

// -- Mode: console --
// Streams Runtime.consoleAPICalled events as NDJSON

async function modeConsole(client, args) {
    await client.send("Runtime.enable");

    client.on("Runtime.consoleAPICalled", (params) => {
        const line = JSON.stringify({
            type: params.type,
            args: params.args.map((arg) => arg.value ?? arg.description ?? arg.type),
            timestamp: params.timestamp,
        });
        process.stdout.write(line + "\n");
    });

    if (args.timeout) {
        setTimeout(() => {
            client.close();
        }, args.timeout * 1000);
    }

    // Keep process alive until connection closes
    await new Promise((resolve) => {
        const ws = client;
        // Listen for process signals to close gracefully
        process.on("SIGINT", () => { ws.close(); });
        process.on("SIGTERM", () => { ws.close(); });
        // Resolve when stdout is no longer needed (connection dropped)
        const check = setInterval(() => {
            // The process will exit when the event loop drains after ws.close()
        }, 60000);
        check.unref();
    });
}

// -- Mode: eval --
// Evaluates a JS expression and prints the result

async function modeEval(client, args) {
    if (!args.expression) {
        process.stderr.write("Error: eval mode requires an expression argument\n");
        process.exit(1);
    }

    const result = await client.send("Runtime.evaluate", {
        expression: args.expression,
        awaitPromise: true,
        returnByValue: true,
    });

    if (result.exceptionDetails) {
        const desc =
            result.exceptionDetails.exception?.description ||
            result.exceptionDetails.text ||
            "Evaluation threw an exception";
        process.stderr.write(`Error: ${desc}\n`);
        client.close();
        process.exit(1);
    }

    process.stdout.write(JSON.stringify(result.result.value) + "\n");
    client.close();
    process.exit(0);
}

// -- Mode: tree --
// Walks the React fiber tree via __REACT_DEVTOOLS_GLOBAL_HOOK__

async function modeTree(client, args) {
    // Self-contained JS expression that runs in the app's JS context.
    // Walks stable fiber properties: type.name, type.displayName,
    // memoizedProps, memoizedState, child, sibling.
    const findFilter = args.find ? JSON.stringify(args.find) : "null";
    const maxDepth = args.depth ? args.depth : "null";
    const walkerExpression = `
(function() {
    var maxDepth = ${maxDepth};
    var hook = globalThis.__REACT_DEVTOOLS_GLOBAL_HOOK__;
    if (!hook) return { __noHook: true };

    var roots = [];
    if (hook.renderers && hook.getFiberRoots) {
        hook.renderers.forEach(function(renderer, id) {
            var r = hook.getFiberRoots(id);
            if (r && r.size > 0) {
                r.forEach(function(root) { roots.push(root); });
            }
        });
    }
    if (roots.length === 0) return { __noRoots: true, rendererCount: hook.renderers ? hook.renderers.size : 0 };

    var findName = ${findFilter};
    var matches = [];

    function getComponentName(fiber) {
        if (!fiber.type) return null;
        return fiber.type.displayName || fiber.type.name || null;
    }

    function safeProps(props) {
        if (!props || typeof props !== 'object') return null;
        var out = {};
        var keys = Object.keys(props);
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i];
            if (k === 'children') continue;
            var v = props[k];
            var t = typeof v;
            if (t === 'string' || t === 'number' || t === 'boolean' || v === null) {
                out[k] = v;
            } else if (t === 'function') {
                out[k] = '[function]';
            } else if (Array.isArray(v)) {
                out[k] = '[array:' + v.length + ']';
            } else if (t === 'object') {
                if (v.$$typeof) { out[k] = '[element]'; }
                else { try { out[k] = JSON.parse(JSON.stringify(v)); } catch(e) { out[k] = '[object]'; } }
            }
        }
        return Object.keys(out).length > 0 ? out : null;
    }

    // When --find is used, search the full tree but limit matched subtree depth.
    // When --find is NOT used, --depth limits the entire traversal.
    function walkFiber(fiber, depth) {
        if (!fiber) return null;
        if (!findName && maxDepth !== null && depth > maxDepth) return null;

        var name = getComponentName(fiber);
        var node = {
            name: name,
            props: null,
            state: null,
            children: []
        };

        try { node.props = safeProps(fiber.memoizedProps); } catch(e) {}
        try {
            if (fiber.memoizedState && fiber.memoizedState.memoizedState !== undefined) {
                try { node.state = JSON.parse(JSON.stringify(fiber.memoizedState.memoizedState)); } catch(e) { node.state = '[complex]'; }
            }
        } catch(e) {}

        var child = fiber.child;
        while (child) {
            var childNode = walkFiber(child, depth + 1);
            if (childNode) node.children.push(childNode);
            child = child.sibling;
        }

        if (findName && name === findName) {
            // For matched nodes, trim subtree to --depth if specified
            if (maxDepth !== null) {
                function trimNode(n, d) {
                    if (d >= maxDepth) { n.children = []; return; }
                    n.children.forEach(function(c) { trimNode(c, d + 1); });
                }
                var copy = JSON.parse(JSON.stringify(node));
                trimNode(copy, 0);
                matches.push(copy);
            } else {
                matches.push(node);
            }
        }

        return node;
    }

    var tree = walkFiber(roots[0].current, 0);

    if (findName) {
        return { find: findName, matches: matches };
    }
    return tree;
})()
`;

    const result = await client.send("Runtime.evaluate", {
        expression: walkerExpression,
        returnByValue: true,
    });

    if (result.exceptionDetails) {
        const desc =
            result.exceptionDetails.exception?.description ||
            result.exceptionDetails.text ||
            "Tree walk threw an exception";
        process.stderr.write(`Error: ${desc}\n`);
        client.close();
        process.exit(1);
    }

    const value = result.result.value;

    if (value && value.__noHook) {
        process.stderr.write(
            "React DevTools hook not found -- ensure app is running in dev mode\n"
        );
        client.close();
        process.exit(1);
    }

    if (value && value.__noRoots) {
        process.stderr.write(
            `No fiber roots found (${value.rendererCount} renderer(s) registered) -- app may not have rendered yet\n`
        );
        client.close();
        process.exit(1);
    }

    const output = args.format === "text"
        ? formatTreeAsText(value)
        : JSON.stringify(value, null, 2) + "\n";
    process.stdout.write(output);
    client.close();
    process.exit(0);
}

// -- Text formatter for tree output --
// Converts a tree node (or find-result with matches) into a human-readable
// indented text representation. Unnamed nodes (React internals) are skipped
// but their children are promoted to the same indent level.

function formatTreeAsText(value) {
    const lines = [];

    function formatNode(node, indentLevel) {
        if (node.name !== null) {
            let line = "  ".repeat(indentLevel) + node.name;
            if (node.props !== null) {
                const keys = Object.keys(node.props);
                line += " {" + keys.join(", ") + "}";
            }
            lines.push(line);
            // Children of named nodes indent one level deeper
            if (node.children) {
                for (const child of node.children) {
                    formatNode(child, indentLevel + 1);
                }
            }
        } else {
            // Unnamed node: skip visually, recurse children at same indent
            if (node.children) {
                for (const child of node.children) {
                    formatNode(child, indentLevel);
                }
            }
        }
    }

    // Detect shape: find-result has { find, matches }, plain tree has { name, ... }
    if (value.find !== undefined && value.matches !== undefined) {
        for (let idx = 0; idx < value.matches.length; idx++) {
            if (idx > 0) {
                lines.push("");
            }
            formatNode(value.matches[idx], 0);
        }
    } else {
        formatNode(value, 0);
    }

    return lines.join("\n") + "\n";
}

// -- Mode: network --
// Streams Network.requestWillBeSent events as NDJSON

async function modeNetwork(client, args) {
    await client.send("Network.enable");

    client.on("Network.requestWillBeSent", (params) => {
        const line = JSON.stringify({
            url: params.request.url,
            method: params.request.method,
            headers: params.request.headers,
            timestamp: params.timestamp,
        });
        process.stdout.write(line + "\n");
    });

    if (args.timeout) {
        setTimeout(() => {
            client.close();
        }, args.timeout * 1000);
    }

    // Keep process alive until connection closes (same as console mode)
    await new Promise(() => {
        process.on("SIGINT", () => { client.close(); });
        process.on("SIGTERM", () => { client.close(); });
    });
}

// -- Argument parsing --

function parseArgs() {
    const argv = process.argv.slice(2);
    const args = {
        mode: null,
        port: undefined,
        timeout: null,
        expression: null,
        find: null,
        depth: null,
        format: "json",
    };

    let i = 0;
    while (i < argv.length) {
        switch (argv[i]) {
            case "--port":
                args.port = parseInt(argv[++i], 10);
                break;
            case "--timeout":
                args.timeout = parseInt(argv[++i], 10);
                break;
            case "--find":
                args.find = argv[++i];
                break;
            case "--depth":
                args.depth = parseInt(argv[++i], 10);
                break;
            case "--format": {
                const fmt = argv[++i];
                if (fmt !== "json" && fmt !== "text") {
                    process.stderr.write("Error: --format must be 'json' or 'text'\n");
                    process.exit(1);
                }
                args.format = fmt;
                break;
            }
            default:
                if (argv[i].startsWith("-")) {
                    process.stderr.write(`Error: Unknown option '${argv[i]}'\n`);
                    process.exit(1);
                }
                // Positional args: first is mode, second is expression (for eval)
                if (args.mode === null) {
                    args.mode = argv[i];
                } else if (args.mode === "eval" && args.expression === null) {
                    args.expression = argv[i];
                }
                break;
        }
        i++;
    }

    return args;
}

function printUsage() {
    process.stderr.write(
        "Usage: cdp-bridge.js <mode> [options]\n" +
        "\n" +
        "Modes:\n" +
        '  console             Stream console.log events (NDJSON)\n' +
        '  eval "expression"   Evaluate JS and print result\n' +
        "  tree                Walk React fiber component tree\n" +
        "  network             Stream network requests (NDJSON)\n" +
        "\n" +
        "Options:\n" +
        "  --port <PORT>       Metro port (default: $RCT_METRO_PORT or 8081)\n" +
        "  --timeout <SEC>     Stop after SEC seconds (console/network)\n" +
        '  --find <name>       Filter tree to component name (tree mode)\n' +
        '  --depth <N>         Limit tree traversal depth (tree mode)\n' +
        '  --format json|text  Output format for tree mode (default: json)\n'
    );
    process.exit(1);
}

// -- Main --

async function main() {
    const args = parseArgs();

    if (!args.mode) {
        printUsage();
    }

    const port = resolvePort(args);
    let wsUrl;

    try {
        wsUrl = await discoverWebSocketUrl(port);
    } catch (err) {
        process.stderr.write(`Cannot connect to Metro on port ${port}\n`);
        process.stderr.write("Ensure Metro is running: npx react-native start\n");
        process.exit(1);
    }

    let client;
    try {
        client = await connectCDP(wsUrl);
    } catch (err) {
        process.stderr.write(`WebSocket connection failed: ${err.message}\n`);
        process.exit(1);
    }

    switch (args.mode) {
        case "console":
            await modeConsole(client, args);
            break;
        case "eval":
            await modeEval(client, args);
            break;
        case "tree":
            await modeTree(client, args);
            break;
        case "network":
            await modeNetwork(client, args);
            break;
        default:
            process.stderr.write(`Error: Unknown mode '${args.mode}'\n`);
            printUsage();
    }
}

// Global unhandled rejection handler
process.on("unhandledRejection", (err) => {
    process.stderr.write(`Error: ${err.message || err}\n`);
    process.exit(1);
});

main().catch((err) => {
    process.stderr.write(`Error: ${err.message || err}\n`);
    process.exit(1);
});
