# Pseudocode: Phase 1 - Add `--format text` to cdp-bridge.js tree mode

## Files to Create/Modify
- `skills/_shared/scripts/cdp-bridge.js` (modify)

## Design: formatTreeAsText

### Approaches Considered
1. **Single function** -- `formatTreeAsText(value)` detects find-result vs plain tree internally, returns string. Caller passes value, gets text.
2. **Two functions** -- separate `formatFindResultAsText` and `formatNodeAsText`. Caller must detect which shape and dispatch.
3. **Streaming formatter** -- writes directly to stdout line-by-line instead of building a string.

### Choice: A (Single function)
Rationale: Simplest caller interface (one call site, no shape detection leaked to caller). Building a string is fine because Phase 2 needs `Buffer.byteLength(output)` on the full result anyway. The function hides: tree shape detection, indentation, unnamed-node skipping, prop formatting.

### Depth Check
- Interface: 1 function, 1 parameter
- Hidden details: shape detection, recursion, indent logic, unnamed-node skipping, prop key extraction
- Common case complexity: simple -- caller calls formatTreeAsText(value), gets string

## Pseudocode

### 1. Add `format` default to args object (line 397, inside args literal)

Add `format: "json"` to the args object, after the `depth: null` property.

### 2. Add `--format` case to arg parser switch (after --depth case, before default)

```
case "--format":
    read next argument as format value
    if value is not "json" and not "text"
        write error to stderr: "Error: --format must be 'json' or 'text'"
        exit 1
    set args.format to value
```

### 3. Add `formatTreeAsText(value)` function (after modeTree closing brace, before modeNetwork comment)

```
function formatTreeAsText(value)
    collect output lines into an array

    define inner function formatNode(node, indentLevel)
        -- Skip unnamed nodes (React internals like View, Fragment)
        -- but still recurse their children at the SAME indent level
        if node.name is not null
            build line: repeat "  " indentLevel times, then node.name
            if node.props is not null
                extract keys of node.props
                append " {" + keys joined by comma + "}" to line
            push line to output lines
            -- children of named nodes get indentLevel + 1
            for each child in node.children
                formatNode(child, indentLevel + 1)
        else
            -- unnamed node: recurse children at SAME indent (skip this node visually)
            for each child in node.children
                formatNode(child, indentLevel)

    -- Detect shape: find-result has { find, matches }, plain tree has { name, ... }
    if value has "find" property and value has "matches" property
        for each match in value.matches (with index)
            if index > 0, push empty string to output lines (blank separator)
            formatNode(match, 0)
    else
        -- Plain tree node
        formatNode(value, 0)

    return output lines joined by newline, with trailing newline
```

### 4. Replace stdout write in modeTree (line 355)

Replace the single `process.stdout.write(JSON.stringify(value, null, 2) + "\n")` with:

```
if args.format is "text"
    set output to formatTreeAsText(value)
else
    set output to JSON.stringify(value, null, 2) + "\n"
process.stdout.write(output)
```

### 5. Update `printUsage()` (after the --depth line, before the closing parenthesis)

Add a line documenting:
```
  --format json|text  Output format for tree mode (default: json)
```

## Design Notes
- Unnamed nodes (name is null) are skipped visually but their children are promoted to the same indent level. This means React internals like View and Fragment disappear from output but their contents remain visible.
- Props are shown as key names only (no values) because the text format is for quick orientation, not detailed inspection. If a caller needs prop values, they use JSON format.
- The `--find` result shape `{ find, matches }` is handled by iterating matches with blank-line separators, matching how a human would scan multiple results.
- The trailing newline on the return value keeps consistency with the JSON path which also ends with "\n".

## PRE-GATE Status
- [x] Discovery complete
- [x] Pseudocode complete
- [x] Design reviewed (deep modules lens applied -- single-function interface hides all formatting complexity)
- [x] Ready for implementation
