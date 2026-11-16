# Claude Code instructions — RallyPop Pickleball

Read `AGENTS.md` first. Then read `README.md`, `docs/02_TECHNICAL_ARCHITECTURE.md`, `docs/11_ROADMAP_AND_BACKLOG.md`, and the spec relevant to the user task.

- Godot **4.7.2** (GDScript) is pinned for this starting branch.
- Root contains an importable `project.godot`; don't recreate the project or change engine without approval.
- A vertical-slice **practice prototype** is present; no complete scoring, legal serve state machine, real multiplayer or ranked system exists yet.
- Reference PNGs in `references/concept_art/` are art direction only, not licensed third-party screenshots or production models.
- Physics/gameplay correctness takes priority over visual polish. Incrementally replace approximations with tested systems.
- Ensure new scenes/scripts follow naming and module boundaries.
- Keep short implementation reports, updated tests, and explicit limitations.
- Commits follow `<commit type>: <short description>`; see `docs/19_GITHUB_RULES.md`.
- The initial kickoff prompt is `prompts/MASTER_STARTING_PROMPT.md`.
- Never pretend you ran Godot, connected an MCP editor, built a game, or observed screenshots if you did not.
