extends RefCounted
class_name BallFlight
## Closed-form flight of a spinning ball with air drag. Pure maths, no state.
##
## Model: a = g_spin - k * v, where k is `air_drag` (linear drag) and g_spin is gravity plus
## the Magnus push of the ball's spin, taken as straight up or down:
##   g_spin = (0, -(gravity + spin_lift * spin), 0)       spin in rev/s, positive = topspin
## Topspin adds to gravity (drives dip), backspin takes some away (dinks and blocks float).
## Because the acceleration is linear in v, the flight has an exact solution:
##   v(t) = v0 * e^(-kt) + g_spin * E(t)                 E(t) = (1 - e^(-kt)) / k
##   p(t) = p0 + v0 * E(t) + g_spin * F(t)               F(t) = (t - E(t)) / k
## so the ball can be stepped exactly and the solver can invert it exactly: a solved shot
## lands where the solver says it will, at any tick rate.
## shortcut: real drag grows with speed squared and real Magnus force follows the velocity;
## both are folded into these two constants. Calibrate against footage before calling it real.

const SMALL_KT: float = 0.0001 ## below this k*t the series form is used (it is exact to float precision there)

## Constant acceleration from gravity and spin.
static func accel(spin: float, tuning: GameplayTuning) -> Vector3:
    return Vector3(0.0, -(tuning.gravity + tuning.spin_lift * spin), 0.0)

static func position_at(origin: Vector3, velocity: Vector3, spin: float, t: float, tuning: GameplayTuning) -> Vector3:
    var k: float = maxf(tuning.air_drag, 0.0)
    return origin + velocity * _e(k, t) + accel(spin, tuning) * _f(k, t)

static func velocity_at(velocity: Vector3, spin: float, t: float, tuning: GameplayTuning) -> Vector3:
    var k: float = maxf(tuning.air_drag, 0.0)
    return velocity * exp(-k * t) + accel(spin, tuning) * _e(k, t)

## The launch velocity that puts the ball center exactly on `arrival` after `t` seconds.
static func launch_velocity(origin: Vector3, arrival: Vector3, spin: float, t: float, tuning: GameplayTuning) -> Vector3:
    var k: float = maxf(tuning.air_drag, 0.0)
    return (arrival - origin - accel(spin, tuning) * _f(k, t)) / _e(k, t)

static func _e(k: float, t: float) -> float:
    var kt: float = k * t
    if kt < SMALL_KT:
        return t * (1.0 - kt * 0.5 + kt * kt / 6.0)
    return (1.0 - exp(-kt)) / k

static func _f(k: float, t: float) -> float:
    var kt: float = k * t
    if kt < SMALL_KT:
        return t * t * (0.5 - kt / 6.0 + kt * kt / 24.0)
    return (t - _e(k, t)) / k
