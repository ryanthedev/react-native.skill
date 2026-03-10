---
name: rn-docs
description: Search React Native official documentation. Use when answering questions about React Native APIs, components, hooks, layout, navigation, native modules, or platform-specific behavior. Triggers on "React Native", "RN docs", "how does View work", "FlatList props", "native module", "new architecture".
allowed-tools: Read, Grep, Glob
---

# Skill: rn-docs

**On load:** Read `../../.claude-plugin/plugin.json` from this skill's base directory. Display `rn-docs v{version}` before proceeding.

Search the official React Native documentation to answer questions accurately.

---

## Docs Location

All documentation lives at:
```
${CLAUDE_SKILL_DIR}/../../refs/react-native-docs/docs/
```

## Workflow

1. Read `${CLAUDE_SKILL_DIR}/references/manifest.md` to find relevant files by title
2. Grep the docs directory for specific terms if the manifest isn't enough
3. Read the matched files to extract the answer
4. Cite the filename when referencing documentation

## Search Strategy

| Need | Tool | Example |
|------|------|---------|
| Find which file covers a topic | Read references/manifest.md, scan titles | "Which file covers FlatList?" |
| Find specific API/prop/method | Grep docs directory | `Grep "onEndReached"` |
| Find all files mentioning a concept | Grep with glob `*.md` | `Grep "useAnimatedStyle" --glob "*.md"` |
| Read a known doc | Read the file directly | `Read docs/flatlist.md` |

## File Structure

- Docs are Docusaurus markdown with YAML frontmatter (`id`, `title`, `description`)
- Most files are self-contained API reference pages (~200 lines)
- Subdirectories: `the-new-architecture/`, `releases/`, `legacy/`
- Files starting with `_` are partials (imported by other docs)

## Tips

- Component docs include props tables — grep for prop names directly
- API docs (e.g., `animated.md`, `layoutanimation.md`) cover usage patterns and method signatures
- The `the-new-architecture/` subdirectory covers Turbo Modules, Fabric, and the new renderer
- Files with `❌` in the title are deprecated APIs
