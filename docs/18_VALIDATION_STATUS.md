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

## RP-005 results recorded 2026-11-17 (same machine and Godot build)

- [x] Headless import — exit 0, no errors or warnings printed.
- [x] `test_rules.gd` 7, `test_net_collision.gd` 11, `test_court_dimensions.gd` 29 — all pass.
- [x] `test_gameplay_tuning.gd` — `PASS: 15 gameplay tuning checks`.
- [x] Training scene, 120 headless frames — exit 0, no script errors.
- [ ] Editing the `.tres` in the Godot inspector has not been tried by a human.

## RP-011 results recorded 2026-11-17 (same machine and Godot build)

- [x] Headless import — exit 0, no errors or warnings printed.
- [x] `test_rules.gd` 7, `test_net_collision.gd` 11, `test_court_dimensions.gd` 29, `test_gameplay_tuning.gd` 15 — all pass.
- [x] `test_shot_solver.gd` — `PASS: 16 shot solver checks`.
- [x] Training scene, 120 headless frames — exit 0, no script errors.
- [ ] Refused-shot messages and the higher arcs have not been seen or felt by a human.

## RP-012 results recorded 2026-11-17 (same machine and Godot build)

- [x] Headless import — exit 0, no errors or warnings printed.
- [x] Unit tests: rules 7, net collision 11, court dimensions 29, gameplay tuning 15, shot solver 24 — all pass.
- [x] `tests/integration/test_training_preview.gd` — `PASS: 15 training preview checks` (real training scene, headless).
- [x] Training scene, 120 headless frames — exit 0, no script errors.
- [ ] The dots, marker colours and HUD lines have not been seen on screen. Headless runs have no renderer, so size, visibility and clutter are unknown.

## RP-013 results recorded 2026-11-17 (same machine and Godot build)

- [x] Headless import — exit 0, no errors or warnings printed.
- [x] Unit tests: rules 7, net collision 11, court dimensions 29, gameplay tuning 15, shot solver 24 — all pass.
- [x] `test_camera.gd` — `PASS: 18 camera checks`.
- [x] `tests/integration/test_training_preview.gd` — `PASS: 15 training preview checks`.
- [x] Training scene, 120 headless frames — exit 0, no script errors.
- [ ] Neither camera view has been seen on screen. The match view's numbers are a first guess.

## RP-014 results recorded 2026-11-17 (same machine and Godot build)

- [x] Headless import — exit 0, no errors or warnings printed.
- [x] Unit tests: rules 7, net collision 11, court dimensions 29, gameplay tuning 15, shot solver 24, camera 18 — all pass.
- [x] `test_input.gd` — `PASS: 26 input checks` (simulated events and action presses).
- [x] `tests/integration/test_training_preview.gd` — `PASS: 15 training preview checks`.
- [x] Training scene, 120 headless frames — exit 0, no script errors.
- [ ] No real keyboard or mouse has been used against the new action map.

## RP-015 results recorded 2026-11-17 (same machine and Godot build)

- [x] Headless import — exit 0, no errors or warnings printed.
- [x] Unit tests: rules 7, net collision 11, court dimensions 29, gameplay tuning 15, shot solver 24, camera 18, input 26 — all pass.
- [x] `test_swing_contact.gd` — `PASS: 22 swing contact checks`.
- [x] `tests/integration/test_training_preview.gd` — `PASS: 20 training preview checks`.
- [x] Training scene, 120 headless frames — exit 0, no script errors.
- [ ] Whether the timing windows and error sizes feel fair has not been judged by a player. The numbers are first guesses.

## RP-020 results recorded 2026-11-17 (same machine and Godot build)

- [x] Headless import — exit 0, no errors or warnings printed.
- [x] Unit tests: rules 7, net collision 11, court dimensions 29, gameplay tuning 15, shot solver 24, camera 18, input 26, swing contact 22 — all pass.
- [x] `test_rally_state.gd` — `PASS: 30 rally state checks`.
- [x] `tests/integration/test_training_preview.gd` — `PASS: 20 training preview checks`.
- [x] Training scene, 120 headless frames — exit 0, no script errors.
- [ ] `RallyState` is exercised only by unit tests; no live rally runs through it yet.

## RP-021 results recorded 2026-11-17 (same machine and Godot build)

- [x] Headless import — exit 0, no errors or warnings printed.
- [x] Unit tests: rules 7, net collision 11, court dimensions 29, gameplay tuning 15, shot solver 24, camera 18, input 26, swing contact 22, rally state 31 — all pass.
- [x] `test_rally_controller.gd` — `PASS: 12 rally controller checks`.
- [x] `tests/integration/test_training_preview.gd` — `PASS: 20 training preview checks`.
- [x] `tests/integration/test_training_rally.gd` — `PASS: 15 training rally checks` (three real rallies in the headless training scene).
- [x] Training scene, 120 headless frames — exit 0, no script errors.
- [ ] No human has played a rally under the new rules or read the new HUD messages on screen.

## RP-022 results recorded 2026-11-17 (same machine and Godot build)

- [x] Headless import — exit 0, no errors or warnings printed.
- [x] Unit tests: rules 7, net collision 11, court dimensions 39, gameplay tuning 15, shot solver 24, camera 18, input 26, swing contact 22, rally state 40, rally controller 13 — all pass.
- [x] `tests/integration/test_training_preview.gd` — `PASS: 20 training preview checks`.
- [x] `tests/integration/test_training_rally.gd` — `PASS: 23 training rally checks` (six rallies, including a foot fault and a wrong-court serve).
- [x] Training scene, 120 headless frames — exit 0, no script errors.
- [ ] Serve rules were written from the project's rules doc and general knowledge of the rulebook, not checked line by line against the 2026 USA Pickleball text.
- [ ] No human has served a ball in the game.

## RP-023 results recorded 2026-11-17 (same machine and Godot build)

- [x] Headless import — exit 0, no errors or warnings printed.
- [x] Unit tests: rules 7, net collision 11, court dimensions 39, gameplay tuning 15, shot solver 24, camera 18, input 26, swing contact 22, rally state 52, rally controller 14 — all pass.
- [x] `tests/integration/test_training_preview.gd` — `PASS: 20 training preview checks`.
- [x] `tests/integration/test_training_rally.gd` — `PASS: 30 training rally checks`, run three times in a row to check it is not timing-flaky.
- [x] Training scene, 120 headless frames — exit 0, no script errors.
- [ ] No human has volleyed at the kitchen line in the game; the 0.6 s momentum window is a guess.

## RP-024 results recorded 2026-11-17 (same machine and Godot build)

- [x] Headless import — exit 0, no errors or warnings printed.
- [x] Unit tests: rules 7, net collision 11, court dimensions 39, gameplay tuning 15, shot solver 24, camera 18, input 26, swing contact 22, rally state 52 — all pass.
- [x] `test_match_score.gd` — `PASS: 24 match score checks`.
- [x] `test_rally_controller.gd` — `PASS: 25 rally controller checks` (11 new for a scored match).
- [x] `tests/integration/test_training_preview.gd` 20 and `tests/integration/test_training_rally.gd` 30 — pass.
- [x] Training scene, 120 headless frames — exit 0, no script errors.
- [ ] Scoring is exercised only by unit tests; no playable match exists yet.

## RP-025 and RP-030 to RP-033 results recorded 2026-11-17 (same machine and Godot build)

- [x] Headless import — exit 0, no errors or warnings printed.
- [x] Unit tests, all pass: rules 7, net collision 11, court dimensions 39, gameplay tuning 15, shot solver 24, camera 20, input 26, swing contact 22, rally state 52, rally controller 25, match score 24, motion 14, match simulation 27, aim advice 23, net protocol 34, match server 32, netcode 32.
- [x] Integration tests, all pass: training preview 20, training rally 30, singles match 20, LAN match 27 (run three times in a row).
- [x] Two bot-vs-bot matches to 11 inside `test_match_simulation.gd`: 37 rallies ending 9-11 and 32 rallies ending 7-11; the same seeds replayed identically.
- [x] Scenes booted headless for 120 frames with exit 0: main menu, training, singles match, online match.
- [x] `tools/lan_smoke_test.sh`: server and two clients as separate processes, final `3-1`, all three agreed, 0 rejected inputs, about 70 seconds.
- [x] `tools/lan_smoke_test.ps1`: same, final `3-0`, all three agreed.
- [x] Server started with `--bot` through `tools/run_server.sh`, one bot client joined from another process: final `0-2`, both agreed.
- [x] Client pointed at a port with no server: reports "No server answered at that address" after 8 seconds and exits with code 1.
- [x] Each of the five network commits was checked out on its own, imported without errors, and passed its own tests.
- [ ] Everything above ran on one machine. No match has been played between two PCs, over Wi-Fi, or with real latency, jitter or loss.
- [ ] No human has played the singles match or an online match. Bot difficulty, the mirrored far-end camera, the HUD wording and how prediction and the delayed opponent feel are all unjudged.
- [x] `tools/run_server.ps1 -Bot` run for real: it stayed attached, a bot client in another process played a match against it, final `2-1`, both agreed.
- [x] `tools/validate_project.ps1` run end to end: all 21 test files, exit 0, 36 seconds. With a deliberately failing test added it exits 1 and names the test.

**Correction to earlier entries:** until this date `tools/validate_project.ps1` had never been run, and it could not have passed. The standard Windows `Godot.exe` is a window-mode program, so PowerShell neither waited for it nor received an exit code, and the script stopped at its first check with "Godot import/parse failed". Every result recorded above came from running the same Godot commands directly in bash, which does wait. The script now pipes Godot's output, which makes PowerShell wait and read the exit code, and it discovers tests instead of listing them. `tools/run_server.ps1` had the same flaw and the same fix.

Still not performed: F5 gameplay with a human, Windows export, MCP editor connection.

Do not describe this project as a fully validated production game.

## RP-034 results recorded 2026-11-17 (same machine and Godot build)

- [x] Headless import: exit 0, no errors.
- [x] `tools/validate_project.sh`: all 21 test files pass. Changed counts: rally state 54, match simulation 31, net protocol 35, match server 40, LAN match 33 (run three times in a row).
- [x] `tools/lan_smoke_test.sh`: protocol v2, final `2-3`, server and both clients agreed, 0 rejected inputs.
- [x] Main menu, training, singles match and online match scenes booted headless for 120 frames: exit 0.
- [x] Windowed client (run through the Godot MCP bridge, not by a person) joined a `--bot` server; the server process was then killed. The client printed `Connection lost. Trying to reconnect …`, retried for 20 s, then `Lost the connection to the server.` Only the log was read; nobody looked at the screen.
- [ ] A reconnect over a real dropped Wi-Fi link, and the HUD wording while paused, have not been seen by a human.

## RP-035 (private match codes slice) results recorded 2026-11-17 (same machine and Godot build)

- [x] `tools/validate_project.sh`: all 21 test files pass. Changed counts: net protocol 38, match server 43, LAN match 34 (a client with the wrong code is refused over real sockets).
- [x] `tools/lan_smoke_test.sh` (final `0-3`) and `tools/lan_smoke_test.ps1` (final `3-2`) with `--code=SNEAK7`: server and both clients agreed, 0 rejected inputs. The first attempt used `SMOKE7`, which contains an excluded "O"; the server silently made up another code and both clients were refused. The server now prints a warning for an invalid `--code`.
- [x] Main menu, training, singles match and online match scenes booted headless for 120 frames: exit 0.
- [x] Windowed client (run through the Godot MCP bridge) joined a server started with `--code=TEST42` without a code and printed `Wrong match code. Ask the host for the code their server printed.` Only the log was read.
- [ ] Nobody has typed a code into the main menu's new field or looked at the reworked join row on screen.
- [ ] Public server deployment is not built; it waits for approval.

## New hit controls and volley exchanges, recorded 2026-11-18 (Godot 4.7.2 Linux headless, not the Windows machine)

- [x] Headless import: exit 0, no errors.
- [x] All 23 test files pass, two of them new: `test_swing_buttons.gd` (31 tap/hold and Q/E checks) and `test_volley_exchange.gd` (25 volley timing, kitchen and two-bounce checks). Changed counts: shot solver 38, swing contact 35, motion 21, gameplay tuning 22, input 31, net protocol 43, singles match 24.
- [x] Four bot-vs-bot matches in the simulation: every shot type is used, about 700 volleys, matches end. Every rally still ends in a double bounce, as before this change, because a swing that would land out is refused rather than hit out.
- [ ] Nobody has held a mouse button, watched the charge meter or tried to time a volley. Every timing window and power range is a first guess.
- [x] `tools/lan_smoke_test.sh` with protocol version 4: final `3-0`, server and both clients agreed, 0 rejected inputs.
- [ ] Not run on macOS with a window; the game has only been played on Windows.
