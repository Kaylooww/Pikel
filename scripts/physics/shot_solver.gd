extends RefCounted
class_name ShotSolver
## Pure shot solver: turns "hit this kind of shot from here to there" into a launch velocity
## and spin, or refuses. No scene access. The ball flies with the same closed-form drag and
## spin model (BallFlight), so a solved shot lands where the solver says it will.

enum Reason { NONE, BAD_TARGET, NET, TOO_FAST }

class Solution extends RefCounted:
    var ok: bool = false
    var reason: Reason = Reason.NONE
    var velocity: Vector3 = Vector3.ZERO
    var spin: float = 0.0 ## rev/s, positive is topspin
    var flight_time: float = 0.0
    var target: Vector3 = Vector3.ZERO ## where it lands: the aim after the shot's own shaping (block short, lob deep)

const SIM_STEP: float = 1.0 / 60.0
const ARC_GROWTH: float = 1.05 # each retry flies 5% longer, which means a higher arc

## Solve a shot from `origin` (ball center) that lands on `target` (floor point).
## Starts from the flight time the recipe prefers and raises the arc until the ball clears
## the net. Refuses when no allowed arc clears, or the target is not a legal aim.
static func solve(origin: Vector3, target: Vector3, recipe: ShotRecipe, tuning: GameplayTuning) -> Solution:
    var result := Solution.new()
    var crosses_net: bool = CourtDimensions.side_from_z(origin.z) != CourtDimensions.side_from_z(target.z)
    if not crosses_net or not CourtDimensions.inside_court(target):
        result.reason = Reason.BAD_TARGET
        return result
    var landing: Vector3 = recipe.shape_target(target)
    var radius: float = CourtDimensions.BALL_VISUAL_RADIUS
    var arrival := Vector3(landing.x, radius, landing.z)
    var distance: float = Vector2(landing.x - origin.x, landing.z - origin.z).length()
    var preferred: float = recipe.flight_time if recipe.flight_time > 0.0 else distance / maxf(recipe.speed, 0.01)
    var flight_time: float = clampf(preferred, recipe.min_flight_time, recipe.max_flight_time)
    result.reason = Reason.NET
    result.target = landing
    while flight_time <= recipe.max_flight_time:
        var velocity: Vector3 = BallFlight.launch_velocity(origin, arrival, recipe.spin, flight_time, tuning)
        if clears_net(origin, velocity, recipe.spin, flight_time, tuning):
            if velocity.length() > tuning.max_launch_speed:
                result.reason = Reason.TOO_FAST
                return result
            result.ok = true
            result.reason = Reason.NONE
            result.velocity = velocity
            result.spin = recipe.spin
            result.flight_time = flight_time
            return result
        flight_time *= ARC_GROWTH
    return result

## Walks the flight in fixed steps through the same swept net test the ball uses.
static func clears_net(origin: Vector3, velocity: Vector3, spin: float, flight_time: float, tuning: GameplayTuning) -> bool:
    var radius: float = CourtDimensions.BALL_VISUAL_RADIUS
    var previous: Vector3 = origin
    var t: float = 0.0
    while t < flight_time:
        t = minf(t + SIM_STEP, flight_time)
        var next: Vector3 = BallFlight.position_at(origin, velocity, spin, t, tuning)
        if NetCollision.hits_net(previous, next, radius):
            return false
        previous = next
    return true

## Evenly timed points along a solved shot, from contact to landing, for previews.
static func sample_arc(origin: Vector3, shot: Solution, tuning: GameplayTuning, count: int = 16) -> PackedVector3Array:
    var points := PackedVector3Array()
    if shot == null or not shot.ok or count < 2:
        return points
    for i in range(count):
        points.append(BallFlight.position_at(origin, shot.velocity, shot.spin, shot.flight_time * float(i) / float(count - 1), tuning))
    return points
