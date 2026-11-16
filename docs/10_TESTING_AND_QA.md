# 10 — Quality assurance plan and acceptance gates

## Test pyramid
1. **Pure unit:** court bounds, kitchen predicates, scoring and serve sequence, shot solver, event sequencing.
2. **Integration:** paddle collision → shot → flight → bounce → ruling, scene transition, asset import.
3. **Headless smoke:** import/parse and simple automated scenarios via Godot binary.
4. **Local hands-on:** motion, camera, aiming, feedback, rule feel.
5. **Multiplayer:** separate clients, server snapshots, 50–200ms latency, jitter, 1–5% packet loss.
6. **Beta regression:** 100 rallies or planned automated equivalent per scenario, 4-player matches, reconnect and UI navigation.

## Starter smoke commands
```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/unit/test_rules.gd
```
Or `./tools/validate_project.ps1` on Windows when Godot is on PATH. These cannot establish gameplay feel or correctness of the complete sport rules.

## First acceptance tests
| ID | Scenario | Pass criteria |
|---|---|---|
| VS-001 | F5 menu load | No parse errors; clickable practice entry |
| VS-002 | WASD/Shift move | Smooth motion, bounds enforced |
| VS-003 | Cursor target | Marker visibly remains on far court |
| VS-004 | Shoot near ball | Ball launches toward target |
| VS-005 | Shoot far from ball | Rejected with feedback |
| VS-006 | Drive hits net | Rally resets, never tunnels through low net |
| VS-007 | Ball out | Deterministic reset and feedback |
| VS-008 | Second bounce | Single fault event and reset |
| VS-009 | Opponent response | A scripted legal-ish return can be practiced |
| VS-010 | Esc/R | Return to menu / reset practice ball |

## Rules tests to implement BEFORE full match system
- Kitchen line inclusive, valid kitchen groundstrokes, forbidden volley including momentum.
- Serve diagonal and non-volley zone; initial doubles serve status; correct rotation and side-out.
- Boundary line in; ball beyond outer line out.
- Two-bounce rule with delayed return and early illegal volley.
- Ball/net/player event order across simultaneous contact timestamps.
- Match ends only under configured target score/winning margin.

## Network tests
- Input authority: malicious client sends impossible coordinates/shot speed and gets rejected.
- Two clients stay in the same ball/rally/score state over 100 simulated rallies.
- Dropout, reconnect, duplicate packet, packet reordering, server process exit.
- Jitter/loss against configurable packet send/snapshot rates; track percentage of corrections.
- Four clients, simultaneous swings, correct team ownership and rotation.

## Required bug template
**Summary, Godot version, OS, reproduction steps, expected behavior, actual behavior, scene/script path, screenshot/log, severity, regression test, fix commit.**

## Performance acceptance (initial targets, verify on real hardware)
- 60 FPS on defined minimum-spec PC in a 4-player environment.
- Stable fixed timestep and no severe hitches during serve/contact events.
- No repeatable missed collisions or duplicate scores.
- Measured bandwidth and 99th percentile latency recorded for multiplayer beta.

## Integrity requirement
An AI agent must distinguish **code inspection**, **syntax import**, **unit test**, **live gameplay**, and **production deployment**. Never report "tested" without saying which one happened.
