extends RefCounted
class_name PlayerMotion
## Pure player movement for one fixed step. The player node, the match simulation and
## client prediction all call this, so they cannot disagree about where a player ends up.

## `move` is in world space: x sideways, y along +z (toward the home baseline). Its length
## is capped at 1, so no input can make a player faster than the tuning allows.
## `side` is +1 for the home half, -1 for the away half; players never cross the net.
static func step(position: Vector3, move: Vector2, sprint: bool, side: int, tuning: GameplayTuning, delta: float) -> Vector3:
    var direction: Vector2 = move.limit_length(1.0)
    var speed: float = tuning.sprint_speed if sprint else tuning.move_speed
    var next := Vector3(position.x + direction.x * speed * delta, 0.0, position.z + direction.y * speed * delta)
    next.x = clampf(next.x, -tuning.max_side_distance, tuning.max_side_distance)
    if side == 1:
        next.z = clampf(next.z, tuning.min_net_distance, tuning.max_back_distance)
    else:
        next.z = clampf(next.z, -tuning.max_back_distance, -tuning.min_net_distance)
    return next
