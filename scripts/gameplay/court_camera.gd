extends Camera3D
class_name CourtCamera
## Follows one player using the active CameraRig. Owns all camera motion so game scripts
## only set `target` and, if they want, switch rigs.

@export var rigs: Array[CameraRig] = [
    preload("res://config/camera_training.tres"),
    preload("res://config/camera_match.tres"),
]
var rig_index: int = 0
var target: Node3D

func active_rig() -> CameraRig:
    return rigs[rig_index]

func next_rig() -> void:
    rig_index = (rig_index + 1) % rigs.size()

## Jump straight to where the active rig wants the camera (scene start, hard cuts).
func snap() -> void:
    if target != null:
        _place(1.0)

func _process(delta: float) -> void:
    if target != null:
        _place(CameraRig.smooth_weight(active_rig().smoothing_rate, delta))

func _place(weight: float) -> void:
    var rig: CameraRig = active_rig()
    position = position.lerp(rig.desired_position(target.position), weight)
    fov = lerpf(fov, rig.fov, weight)
    basis = Basis.looking_at(rig.look_target(target.position) - position, Vector3.UP)
