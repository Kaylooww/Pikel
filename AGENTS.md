# AGENTS.md — repository-wide agent policy

## Intent
Build an original, responsive, mouse-targeted 3D pickleball game in Godot 4.7.2 using GDScript. This project is a starter **prototype**, not finished competitive multiplayer. Do not claim unimplemented features work.

## Read before editing
1. `README.md` and `START_HERE.md`.
2. `docs/02_TECHNICAL_ARCHITECTURE.md`.
3. The task-specific spec (physics, rules, networking, art, etc.).
4. `docs/11_ROADMAP_AND_BACKLOG.md`.
5. Current code and tests in the affected directory.

## Boundaries
- Gameplay logic must not depend on UI text nodes.
- `scripts/core/court_dimensions.gd` is canonical for units/axis/dimensions.
- Only the future authoritative server decides actual scores, faults, legal contact, and ball result in multiplayer.
- Keep 3D placeholder models separate from physics/controller logic.
- Do not implement networked authoritative physics by simply synchronizing Node3D transforms every frame.
- Do not embed API keys, tokens, or player PII in code, scenes, Markdown, or Git.
- Don't alter unrelated modules or install external dependencies without approval.
- Don't download or reproduce copyrighted screenshots/assets/models/code from the reference game.

## Definition of done
- Scope and assumptions explicitly recorded.
- Code parses/imports in pinned Godot version.
- Unit/scenario checks added or updated.
- Manual checks specified; do not claim they ran if not executed.
- Documentation and acceptance criteria updated.
- Implementation limitations disclosed.

## Recommended commands
```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/unit/test_rules.gd
```

## Workflow
One issue → one feature branch → minimal change → tests → review → merge. Present a proposed plan before large architectural edits. Ask for human review at gameplay-balance, art direction, security, billing or irreversible-change boundaries.
