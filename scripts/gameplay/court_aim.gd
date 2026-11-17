extends RefCounted
class_name CourtAim
## Turns the mouse cursor into an aim point on the opponent's court.

const SIDE_MARGIN: float = 0.16
const BASELINE_MARGIN: float = 0.14
const NET_MARGIN: float = 0.20

## Projects the cursor onto the court surface and clamps it into the half that `side`
## (+1 home, -1 away) hits toward. Returns `fallback` when the cursor is above the horizon.
static func target_from_mouse(camera: Camera3D, mouse: Vector2, side: int, fallback: Vector3) -> Vector3:
    var origin: Vector3 = camera.project_ray_origin(mouse)
    var direction: Vector3 = camera.project_ray_normal(mouse)
    if absf(direction.y) <= 0.001:
        return fallback
    var distance: float = (0.03 - origin.y) / direction.y
    if distance <= 0.0:
        return fallback
    return clamp_to_opponent_court(origin + direction * distance, side)

static func clamp_to_opponent_court(point: Vector3, side: int) -> Vector3:
    var x: float = clampf(point.x, -CourtDimensions.HALF_WIDTH + SIDE_MARGIN, CourtDimensions.HALF_WIDTH - SIDE_MARGIN)
    var depth: float = clampf(-side * point.z, NET_MARGIN, CourtDimensions.HALF_LENGTH - BASELINE_MARGIN)
    return Vector3(x, 0.0, -side * depth)
