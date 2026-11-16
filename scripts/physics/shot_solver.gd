extends RefCounted
class_name ShotSolver
## Pure shot solver: turns "hit from here to there" into a launch velocity, or refuses.
## No scene access. The ball integrates the same no-drag parabola, so a solved shot lands
## where the solver says it will.

enum Reason { NONE, BAD_TARGET, NET, TOO_FAST }

class Solution extends RefCounted:
    var ok: bool = false
    var reason: Reason = Reason.NONE
    var velocity: Vector3 = Vector3.ZERO
    var flight_time: float = 0.0

const SIM_STEP: float = 1.0 / 60.0
const ARC_GROWTH: float = 1.05 # each retry flies 5% longer, which means a higher arc

## Solve a shot from `origin` (ball center) that lands on `target` (floor point).
## Starts from the flight time the shot type prefers and raises the arc until the ball
## clears the net. Refuses when no allowed arc clears, or the target is not a legal aim.
static func solve(origin: Vector3, target: Vector3, soft: bool, tuning: GameplayTuning) -> Solution:
    var result := Solution.new()
    var crosses_net: bool = CourtDimensions.side_from_z(origin.z) != CourtDimensions.side_from_z(target.z)
    if not crosses_net or not CourtDimensions.inside_court(target):
        result.reason = Reason.BAD_TARGET
        return result
    var radius: float = CourtDimensions.BALL_VISUAL_RADIUS
    var flat := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
    var speed: float = tuning.dink_speed if soft else tuning.drive_speed
    var flight_time: float = clampf(flat.length() / speed, tuning.min_flight_time, tuning.max_flight_time)
    result.reason = Reason.NET
    while flight_time <= tuning.max_flight_time:
        # No-drag ballistic arc whose center is at ball radius above the target at flight_time.
        var rise: float = (radius - origin.y + 0.5 * tuning.gravity * flight_time * flight_time) / flight_time
        var velocity := Vector3(flat.x / flight_time, rise, flat.z / flight_time)
        if clears_net(origin, velocity, flight_time, tuning.gravity, radius):
            if velocity.length() > tuning.max_launch_speed:
                result.reason = Reason.TOO_FAST
                return result
            result.ok = true
            result.reason = Reason.NONE
            result.velocity = velocity
            result.flight_time = flight_time
            return result
        flight_time *= ARC_GROWTH
    return result

## Walks the flight in fixed steps through the same swept net test the ball uses.
static func clears_net(origin: Vector3, velocity: Vector3, flight_time: float, gravity: float, radius: float) -> bool:
    var previous: Vector3 = origin
    var t: float = 0.0
    while t < flight_time:
        t = minf(t + SIM_STEP, flight_time)
        var next: Vector3 = position_at(origin, velocity, gravity, t)
        if NetCollision.hits_net(previous, next, radius):
            return false
        previous = next
    return true

static func position_at(origin: Vector3, velocity: Vector3, gravity: float, t: float) -> Vector3:
    return origin + velocity * t + Vector3.DOWN * (0.5 * gravity * t * t)
