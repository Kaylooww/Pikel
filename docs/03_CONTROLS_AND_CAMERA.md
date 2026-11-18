# 03 — Controls, aiming and camera

## Input mapping
| Input | Prototype | Production intent |
|---|---|---|
| WASD | Move | Remappable analog movement |
| Shift | Sprint | Sprint with exhaustion/recovery |
| Mouse movement | Ground-plane cursor target on far half | Aim with shot-depth/assist indicator |
| Left mouse | Tap: dink (a volley dink on a ball in the air). Hold: drive, charged by hold time | — |
| Right mouse | Tap: block (soaks up pace, lands short). Hold: lob, height and depth charged by hold time | — |
| R | Respawn practice ball | Training reset; not a live-match shortcut |
| Esc | Menu | Pause/settings/exit lobby |
| Space | Not implemented | Lunge/dive |
| Q / E | Backhand / forehand, pressed with each swing | Handedness setting |
| C | Cycle camera views: behind the player (default), match chase, raised training | Settings option, not a live-match key |
| Mouse wheel | Not implemented | Camera distance |
| Controller | Not implemented | Post-beta accessibility / Steam Input |

## Input actions (implemented)
Controls are twelve named actions in `project.godot` (Project Settings > Input Map): `move_left`, `move_right`, `move_forward`, `move_back`, `sprint`, `shot_dink_drive`, `shot_block_lob`, `stroke_backhand`, `stroke_forehand`, `reset_ball`, `camera_next`, `menu_back`. Keys are bound by physical position, so WASD stays in the same place on non-QWERTY layouts. Gameplay scripts read these through `scripts/gameplay/game_input.gd` (`GameInput`) and never check raw keys.

`GameInput.rebind(action, event)` replaces a binding, `GameInput.reset_to_defaults()` restores the project defaults, and `GameInput.label(action)` gives the key name the HUD hint line shows. There is no settings screen yet and rebinds are not saved between runs. Controller bindings can be added to the same actions later without touching gameplay code.

## How cursor aiming should work
1. Convert `get_viewport().get_mouse_position()` through `Camera3D.project_ray_origin/normal`.
2. Intersect the ray with the y≈0 court plane or a dedicated raycastable aim surface.
3. Convert to a **world-space intended landing point**; clamp display target to reasonable opposite-court area in training.
4. The player must still move into paddle reach and contact at legal timing.
5. Use target, shot selection, contact height and power to solve a viable trajectory; if impossible, show a rejected/low-confidence target **before** or at contact.
6. Distinguish exact cursor target from actual predicted landing when skill error is applied.

## Production camera
**Implemented:** `CourtCamera` owns all camera motion and reads a `CameraRig` resource (height, depth, how much it follows the player, look point, field of view, smoothing rate). Smoothing is exponential in time, so it behaves the same at any frame rate. Three rigs ship. The default (`config/camera_chase.tres`) is a low third-person view modelled on the Just Volleyball reference: 5 m up and 6 m behind the player, following them fully, looking 4 m past them (about 27° down), 60° field of view, so the player stands in the lower half and the whole far court is in view. **C** cycles to the older lower match chase view and the raised training view. Cursor aiming uses whichever camera is active; with the low camera a cursor above the horizon aims at the far baseline instead of being ignored. Framing was checked in rendered screenshots (Xvfb + software OpenGL), not on a real display. The remaining bullets below are still to do.

- Third-person raised chase camera, both halves readable.
- Dynamic follow with configurable smoothing (time-based rather than per-frame lerp).
- Include camera occlusion and net visibility testing.
- Preserve screen-space cursor accuracy as camera moves; freeze target or record an input timestamp during shot release.
- Optional overhead camera for training but competitive aim behavior must be consistent/fair.

## Tap, hold and side (implemented)
`scripts/gameplay/swing_buttons.gd` (`SwingButtons`) turns presses into swings and takes the time as an argument, so it is tested with exact timestamps. A press shorter than `tap_threshold` (0.15 s) is a tap; longer is a hold whose charge rises from 0 at the threshold to 1 at `full_charge_time` (0.9 s). The swing happens on release, or, for a held drive or lob, by itself when the ball reaches the ideal contact point (`auto_release`): press early to charge more, and the shot still meets the ball. The left button makes a dink or a drive, the right a block or a lob. While one button is held the other is ignored. The HUD shows a charge meter (`scripts/ui/charge_meter.gd`) while a drive or lob is held.

Q (backhand) or E (forehand) must be pressed with each swing: any time from `side_key_window` (0.25 s) before the mouse press until the release, the latest one counting. An old press does not carry over to the next swing. `SwingContact.needed_stroke` says which side the ball is on (a `body_deadzone` in front of the body takes either). The right side is a full shot; the wrong side keeps `wrong_side_power` of the pace and drifts by `wrong_side_error`; no side keeps `no_side_power` and drifts by `no_side_error`. The aim hint names the side to press.

## Volleys (implemented)
A swing at a ball that has not bounced since the opponent hit it is a volley. It must be pressed within a hard window of ideal contact (`volley_dink_window` 0.10 s, `volley_block_window` 0.20 s, `volley_drive_window` 0.14 s for drives and lobs) or the paddle misses (`MISTIMED`) and the player cannot swing again for `whiff_recovery` (0.4 s). A tapped dink on a ball in the air is a punched volley (`volley_dink_speed`) toward the aim, so two players at the kitchen line can trade volleys until one mistimes or the ball goes out of reach. The kitchen rule (no volley from inside it, momentum after a volley) and the two-bounce rule are unchanged.

## Swing UX
**Implemented:** `scripts/gameplay/swing_contact.gd` (`SwingContact.evaluate`) judges a swing from the player position, ball position and ball velocity. Within `clean_reach` of the contact point the swing is comfortable; out to `player_reach` it is stretched and the shot falls short. Timing is the time until the ball reaches a plane `contact_lead` in front of the body: inside `clean_timing_window` is clean, earlier pulls the shot to the hitter's left, later pushes it right, growing to `max_timing_error`. The error is deterministic, so the preview arc shows the real landing point drifting off the cursor marker before the click, and the HUD names the contact quality. All numbers are in the tuning resource. Not yet: a left-handed option and swing animation phases. Backhand, charge and volleys are described above.

- Timing windows derived from authoritative proximity/swing phases and ball velocity, not just animation time.
- Contact indicators: too early, clean, late, unreachable, illegal volley, net/fault.
- Predicted shadow/landing marker accessible to color-blind users.
- Avoid both a perfect trajectory guide and strong unpredictable errors (inconsistent player feedback).

## Input safety and online fairness
A client may REQUEST a shot at tick T, but the authoritative simulation validates position, reach, timing, ball state, and legal shot. Rate limit repeated mouse presses. Never accept a client-provided 'I hit the ball' boolean as proof.
