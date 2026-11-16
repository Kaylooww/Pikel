# 12 — AI-driven coding workflow

## Working model
Claude Code can work in the repository like a developer: read code, edit source, invoke commands where permitted, and report results. The optional Godot MCP bridge may let it inspect live editor state. Neither eliminates the need for a human deciding design, quality and shipping.

## Role assignments (can be the same AI in separate sessions)
| Agent persona | Owns | Must NOT overwrite |
|---|---|---|
| Architect | Schemas, boundaries, ADRs | Whole project without review |
| Physics | Ball integration/trajectory/collisions | UI menu code |
| Gameplay | Movement/shot intent/contact | Networking protocols |
| Rules | Service, score, rally state | Ball rendering |
| Networking | Server/client/snapshots | Cosmetic art sources |
| UX | HUD/menus/settings | Rules of adjudication |
| Animation | Rig integration/state trees | Controller physics |
| QA | Fixtures, regression, measurements | Game rules to make tests pass |

## Required process
1. Select a prioritized issue in `docs/11_ROADMAP_AND_BACKLOG.md`.
2. Read specs and dependencies, inspect current files and test fixtures.
3. Propose file-level changes and success criteria.
4. Implement a small branch with the smallest safe change.
5. Run headless Godot import + relevant tests, then real game where available.
6. Provide a clear change log, test output, limitations and demo instructions.
7. Review/merge only after a human validates any design-impacting behavior.

## Suggested Git naming
Branch and commit naming is defined in `docs/19_GITHUB_RULES.md`, for example `feat/swept-net-collision`, `fix/snapshot-jitter`, `docs/rig-handoff-v2`. Commit messages should describe observable work, not "finished game".

## Model limitations and guardrails
- Refuse the urge to generate entire multiplayer code in a single prompt.
- AI can invent incorrect Godot API calls; run the real pinned editor/CLI.
- AI can produce visually plausible physics that violates real rules; scenario-test events.
- AI can unknowingly bypass server authority; architecture review critical.
- AI cannot reliably judge whether an opponent feels fair from text alone; human playtests required.
- Do not install random plugins/MCP servers without reviewing permissions and avoiding secrets.

## Session handoff format
```markdown
## Task
## Files read
## Files changed
## Tests actually run + results
## Manual validation status
## Known limitations
## Next smallest task
```

## Prompt order
1. `prompts/MASTER_STARTING_PROMPT.md`.
2. `.claude/commands/first-sprint.md`.
3. Small ticket-specific instructions for physics/rules/networking/model imports.
4. Ask for a reproducible test report after each change.
