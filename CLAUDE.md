# Claude Code instructions — RallyPop Pickleball

Read `AGENTS.md` first. Then read `README.md`, `docs/02_TECHNICAL_ARCHITECTURE.md`, `docs/11_ROADMAP_AND_BACKLOG.md`, and the spec relevant to the user task.

- Godot **4.7.2** (GDScript) is pinned for this starting branch.
- Root contains an importable `project.godot`; don't recreate the project or change engine without approval.
- Present: practice court, a rules-complete singles match against a bot, and a LAN 1v1 slice with a dedicated authoritative server. Not present: doubles, internet play, accounts, reconnect, ranked, real art. The README truth table is the source of truth.
- Reference PNGs in `references/concept_art/` are art direction only, not licensed third-party screenshots or production models.
- Physics/gameplay correctness takes priority over visual polish. Incrementally replace approximations with tested systems.
- Ensure new scenes/scripts follow naming and module boundaries.
- Keep short implementation reports, updated tests, and explicit limitations.
- **When the user says just "continue" (or "next"), read `prompts/NEXT.md` and follow it:** branch from `main`, build the next open backlog task, verify, commit, push the branch, then ask the user to merge. After the merge, delete the branch and wait for "continue".
- Commits follow `<commit type>: <short description>`; see `docs/19_GITHUB_RULES.md`.
- The initial kickoff prompt is `prompts/MASTER_STARTING_PROMPT.md`.
- Never pretend you ran Godot, connected an MCP editor, built a game, or observed screenshots if you did not.
