# 03 — Controls, aiming and camera

## Input mapping
| Input | Prototype | Production intent |
|---|---|---|
| WASD | Move | Remappable analog movement |
| Shift | Sprint | Sprint with exhaustion/recovery |
| Mouse movement | Ground-plane cursor target on far half | Aim with shot-depth/assist indicator |
| Left mouse | Drive | Normal/charged shot + contact timing |
| Right mouse | Soft/dink | Dink/drop depending on situation |
| R | Respawn practice ball | Training reset; not a live-match shortcut |
| Esc | Menu | Pause/settings/exit lobby |
| Space | Not implemented | Lunge/dive |
| Q/E | Not implemented | Spin modifiers |
| Mouse wheel | Not implemented | Camera distance |
| Controller | Not implemented | Post-beta accessibility / Steam Input |

## How cursor aiming should work
1. Convert `get_viewport().get_mouse_position()` through `Camera3D.project_ray_origin/normal`.
2. Intersect the ray with the y≈0 court plane or a dedicated raycastable aim surface.
3. Convert to a **world-space intended landing point**; clamp display target to reasonable opposite-court area in training.
4. The player must still move into paddle reach and contact at legal timing.
5. Use target, shot selection, contact height and power to solve a viable trajectory; if impossible, show a rejected/low-confidence target **before** or at contact.
6. Distinguish exact cursor target from actual predicted landing when skill error is applied.

## Production camera
- Third-person raised chase camera, both halves readable.
- Dynamic follow with configurable smoothing (time-based rather than per-frame lerp).
- Include camera occlusion and net visibility testing.
- Preserve screen-space cursor accuracy as camera moves; freeze target or record an input timestamp during shot release.
- Optional overhead camera for training but competitive aim behavior must be consistent/fair.

## Swing UX
- Timing windows derived from authoritative proximity/swing phases and ball velocity, not just animation time.
- Contact indicators: too early, clean, late, unreachable, illegal volley, net/fault.
- Predicted shadow/landing marker accessible to color-blind users.
- Avoid both a perfect trajectory guide and strong unpredictable errors (inconsistent player feedback).

## Input safety and online fairness
A client may REQUEST a shot at tick T, but the authoritative simulation validates position, reach, timing, ball state, and legal shot. Rate limit repeated mouse presses. Never accept a client-provided 'I hit the ball' boolean as proof.
