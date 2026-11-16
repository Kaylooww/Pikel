# 04 — Ball physics, collision and shot solver

## Baseline
The starter integrates gravity and a simple ballistic shot toward the cursor target at each physics tick. It's intentionally a **prototype**, not a calibrated aerodynamic or deterministic cross-machine physics engine. `scripts/physics/ball_controller.gd` is the current implementation.

## Implemented so far
- `scripts/physics/shot_solver.gd` (`ShotSolver.solve`) turns origin, target and shot type into a launch velocity. It starts from the flight time the shot type prefers, lengthens the flight in 5% steps (a higher arc) until the swept net test passes, and refuses with a reason (`BAD_TARGET`, `NET`, `TOO_FAST`) when no arc within `max_flight_time` and `max_launch_speed` works.
- `ball_controller.gd` integrates the exact constant-gravity step, so the flown path is the same parabola the solver used, and it backs the ball up to the moment of floor contact so in/out is judged on the true landing point. In tests the ball lands within 2 cm of the solved target.
- `ShotSolver.sample_arc` gives evenly timed points along a solved shot. `scripts/physics/trajectory_preview.gd` draws them as dots and decides nothing. The training scene previews what a click would do right now, for both shot types, and reports where the last shot landed against where it was aimed.
- Not yet: drag, spin, contact height chosen by the player, skill error, paddle contact windows (RP-015).

## Model
Use position `p`, velocity `v`, spin `omega`, fixed step `dt`. Candidate acceleration:

`a = g - k_drag * |v| * v + k_magnus * (omega × v)`

Start with `k_drag = 0`, `k_magnus = 0`, then tune using repeated trajectories and real-world footage. A pickleball has high drag; physically grounded coefficients must be estimated, not invented as guaranteed reality.

## Flight solver
For no drag, let horizontal distance be `d`, chosen flight time `T`, initial height `y0` and target contact height `yr`. Set:

`vxz = (target_xz - start_xz) / T`

`vy = (yr - y0 + 0.5 * g * T^2) / T`

Then verify net clearance, ball release velocity and target feasibility. Don't silently teleport the ball to the cursor target. For advanced physics use numerical shooting/iteration to handle drag, spin and legal flight corridors.

## Collision priorities
1. **Swept sphere / segment-plane** net checking to avoid tunneling; include net posts.
2. Sphere-floor contact with line-inclusive in/out adjudication.
3. Player paddle collision during a validated swing window; hit origin, normal and event tick.
4. Out-of-bounds vertical and horizontal flight capture, then rally events.
5. Kitchen rules depend on player feet/momentum at hit, not on the ball entering the kitchen.
6. Ensure one contact event cannot score twice.

## Bounce model
At minimum resolve vertical coefficient of restitution, surface friction and spin interaction. Keep separate **real physical ball radius** and **stylized display size** if competitive scale requires it. The starter deliberately uses a 0.105m **visual/gameplay radius** for readability, which is NOT regulation size; adjust before claiming realistic collisions.

## Shot parameters to tune
| Parameter | Suggested initial direction | Validation |
|---|---|---|
| Gravity | 9.81 m/s² | Time-of-flight repeatability |
| Drag | Disabled in scaffold | Match measured flight curves |
| Spin | Disabled in scaffold | Predictable curvature and bounce |
| Drive speed | Faster/flatter | Net and boundary safety |
| Dink | Slower/lower | Kitchen landing accuracy |
| Net collision | Replace approximate crossing check | No fast ball tunneling |
| Paddle reach | Based on body geometry, not magic range | Good timing and misses feel fair |
| Hit quality | Clean/early/late/out-of-balance | Understandable visual feedback |

## Reproducibility
Create test fixtures for shot origin, target, initial velocity, per-tick positions, bounce points, and final ruling. Exact bitwise cross-platform determinism can be difficult; favor **single server-owned simulation** and tolerance-based client visualization.

## Automated scenario matrix
- Clean drive clears net and lands in opponent court.
- Low drive catches net with high speed without passing through.
- Aim outside court results in rejected aim or out ruling.
- Ball at line edge is in; beyond outside edge is out.
- Dink lands close to non-volley-zone line.
- Second bounce ends rally exactly once.
- Repeated swing inputs cannot produce duplicated hit events.
- High jitter and snapshot correction don't invent extra net/floor contacts.

## Do not confuse the concepts
**Trajectory preview** can be approximate, **ball simulation** must be authoritative, **rules** adjudicate a legal event. Keep those concerns separate.
