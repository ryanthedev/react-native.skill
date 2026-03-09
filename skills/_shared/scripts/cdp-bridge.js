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

    const wsUrl = targets[0].webSocketDebuggerUrl;
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
    const walkerExpression = `
(function() {
    var hook = globalThis.__REACT_DEVTOOLS_GLOBAL_HOOK__;
    if (!hook) return { __noHook: true };

    var roots = hook.getFiberRoots ? Array.from(hook.getFiberRoots(1)) : [];
    if (roots.length === 0) return { __noHook: true };

    var findName = ${findFilter};
    var matches = [];

    function getComponentName(fiber) {
        if (!fiber.type) return null;
        return fiber.type.displayName || fiber.type.name || null;
    }

    function walkFiber(fiber) {
        if (!fiber) return null;

        var name = getComponentName(fiber);
        var node = {
            name: name,
            props: null,
            state: null,
            children: []
        };

        try { node.props = fiber.memoizedProps; } catch(e) {}
        try {
            if (fiber.memoizedState && fiber.memoizedState.memoizedState !== undefined) {
                node.state = fiber.memoizedState;
            }
        } catch(e) {}

        var child = fiber.child;
        while (child) {
            var childNode = walkFiber(child);
            if (childNode) node.children.push(childNode);
            child = child.sibling;
        }

        if (findName && name === findName) {
            matches.push(node);
        }

        return node;
    }

    var tree = walkFiber(roots[0].current);

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

    process.stdout.write(JSON.stringify(value, null, 2) + "\n");
    client.close();
    process.exit(0);
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
        '  --find <name>       Filter tree to component name (tree mode)\n'
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
