extends Resource
class_name CameraRig
## One camera behaviour as data: where the camera sits relative to the followed player and
## where it looks. Defaults are the raised training view; other views are .tres files in
## config/ that override them. Written for the home half (player at +z looking toward -z).

@export var height: float = 9.2
@export var base_z: float = 12.0 ## camera z when the player stands on the net line
@export var follow_x: float = 0.35 ## fraction of the player's sideways position the camera copies
@export var follow_z: float = 0.0 ## fraction of the player's depth the camera copies (0 = fixed)
@export var look_follow_x: float = 0.16 ## fraction of the player's sideways position the aim point copies
@export var look_z: float = -0.15 ## court z the camera looks at
@export var fov: float = 58.0
@export var smoothing_rate: float = 3.7 ## per second; higher catches up faster

func desired_position(player_position: Vector3) -> Vector3:
    return Vector3(player_position.x * follow_x, height, base_z + player_position.z * follow_z)

func look_target(player_position: Vector3) -> Vector3:
    return Vector3(player_position.x * look_follow_x, 0.0, look_z)

## Fraction of the remaining distance to cover this frame. Exponential, so the motion is the
## same at any frame rate (a fixed per-frame lerp is not).
static func smooth_weight(rate: float, delta: float) -> float:
    return 1.0 - exp(-rate * delta)
