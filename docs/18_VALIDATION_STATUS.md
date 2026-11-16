# 18 — Validation status of this delivered starter

**Prepared:** 2026-11-16.

## Checks actually performed

- [x] Verified the `project.godot` file is present.
- [x] Verified all `res://...` resource references in text source files resolve to files inside the package.
- [x] Verified local Markdown links and embedded reference image links resolve to packaged files.
- [x] Verified the original concept art was split into four separate PNGs and a combined full sheet.
- [x] Generated four technical reference diagrams as SVG and PNG.
- [x] Inspected selected diagrams for legibility.
- [x] Created a reusable `tools/static_validate.py` checker.

## Checks NOT performed here

- [ ] Godot 4.7.2 executable import/compile — no Godot executable was available in the packaging environment.
- [ ] `tests/unit/test_rules.gd` running inside Godot — requires the Godot binary.
- [ ] F5 gameplay and camera/input sanity — requires the Godot editor GUI.
- [ ] Windows export test — requires a Windows environment and export templates.
- [ ] Live Claude Code ↔ Godot MCP connection — requires the user's installed applications and approvals.
- [ ] Multiplayer runtime — not implemented in this starter.

## Headless results recorded 2026-11-17 (Windows 11, Godot 4.7.2.stable.official.ed1daf0bf)

- [x] `godot --headless --path . --editor --quit` — exit 0, no errors or warnings printed.
- [x] `tests/unit/test_rules.gd` — `PASS: 7 rules smoke checks`, exit 0.
- [x] `tests/unit/test_net_collision.gd` — `PASS: 11 net collision checks`, exit 0.
- [x] `godot --headless --path . --quit-after 120 res://scenes/game/training.tscn` — exit 0, no script errors. This only proves the scene loads and ticks; nobody played it.

## RP-004 results recorded 2026-11-17 (same machine and Godot build)

- [x] Headless import — exit 0, no errors or warnings printed.
- [x] `test_rules.gd` — `PASS: 7 rules smoke checks` (two serve assertions corrected: they had the diagonal mirrored).
- [x] `test_net_collision.gd` — `PASS: 11 net collision checks`.
- [x] `test_court_dimensions.gd` — `PASS: 29 court dimension checks`.
- [x] Training scene, 120 headless frames — exit 0, no script errors.
- [ ] Moved court lines and widened net have not been looked at on screen.

Still not performed: F5 gameplay with a human, Windows export, MCP editor connection.

Do not describe this project as a fully validated production game.
