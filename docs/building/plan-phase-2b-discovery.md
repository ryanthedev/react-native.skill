# Discovery: Phase 2b - New Skills

## Files Found

### Existing (conventions reference)
- `skills/rn-docs/SKILL.md` -- SKILL.md format: frontmatter (name, description, allowed-tools), on-load version display, workflow sections, routing/search tables, context efficiency table
- `skills/rn-diagnose/SKILL.md` -- Reference doc pattern: `${CLAUDE_SKILL_DIR}/references/error-patterns.md`, routing table by error category, subagent dispatch blocks, response format spec
- `skills/ios-sim/SKILL.md` -- Script-routing pattern: routing table by intent, direct commands table, named workflows with subagent dispatch blocks, tips section, context efficiency table
- `skills/rn-diagnose/references/error-patterns.md` -- Reference doc format: heading per pattern, Match/Cause/Fix structure
- `skills/ios-sim/references/troubleshooting.md` -- Reference doc format: prerequisites, install instructions

### Phase 2a scripts (prerequisites -- all exist)
- `skills/_shared/scripts/metro.sh` -- Commands: status, targets, bundle-check, symbolicate. Port resolution: --port flag > RCT_METRO_PORT > 8081
- `skills/_shared/scripts/logs.sh` -- Commands: ios, android. Options: --timeout, --json, --native
- `skills/_shared/scripts/cdp-bridge.js` -- Modes: console, eval, tree, network. Options: --port, --timeout, --find

### Phase 2b targets (to be created)
- `skills/rn-debug/SKILL.md` -- Does NOT exist
- `skills/rn-debug/references/metro-endpoints.md` -- Does NOT exist
- `skills/rn-coding/SKILL.md` -- Does NOT exist
- `skills/rn-coding/references/workflow-checklist.md` -- Does NOT exist

## Current State

Phase 2a is complete. All three shared scripts exist with the interfaces specified in the plan. No Phase 2b files exist yet -- all four files need to be created from scratch.

## Conventions Observed Across Existing Skills

1. **Frontmatter format:** YAML between `---` fences with `name`, `description` (including trigger words), `allowed-tools`
2. **On-load block:** Every skill reads `../../.claude-plugin/plugin.json` and displays `{skill-name} v{version}`
3. **Script paths:** Use `${CLAUDE_SKILL_DIR}/` prefix for same-skill scripts; `${CLAUDE_SKILL_DIR}/../` for cross-skill scripts; `${CLAUDE_SKILL_DIR}/../../` for repo-root-relative paths
4. **Shared scripts path:** `${CLAUDE_SKILL_DIR}/../_shared/scripts/` (from any skill directory)
5. **Context efficiency warning:** Bold inline block for large-output skills: `IMPORTANT: Never load X in main context. Always dispatch a subagent.`
6. **Subagent dispatch format:** Fenced code block with `Dispatch Agent:` header, specifying subagent_type, model (haiku for cheap tasks, omitted for complex), description, and prompt
7. **Routing table:** `| Intent | Script/Workflow | Notes |` format
8. **Reference docs:** Stored in `references/` subdirectory, read via `${CLAUDE_SKILL_DIR}/references/`
9. **Context efficiency table:** Present in all skills with Bash or Agent tools

## Gaps

1. **No gap in script interfaces** -- The plan's routing table commands match the actual script interfaces exactly
2. **Minor convention detail:** The plan says rn-coding uses "Read/Grep/Glob" tools only, but the plan also says it should "suggest verification" using other skills. This is fine -- suggesting is just text output, not tool invocation.
3. **Shared script path convention:** No existing skill references `_shared/scripts/` yet. rn-debug will be the first. Path will be `${CLAUDE_SKILL_DIR}/../_shared/scripts/`.

## Prerequisites

- [x] Phase 2a scripts exist and are executable
- [x] Existing skill conventions documented (frontmatter, routing, subagent patterns)
- [x] Plan specifies triggers, routing tables, fallback logic for both new skills
- [x] Reference doc patterns established (error-patterns.md, troubleshooting.md)
- [x] docs/building/ directory exists for output

## Recommendation

**BUILD** -- All four files need to be created. No blockers. Conventions are clear from existing skills.
