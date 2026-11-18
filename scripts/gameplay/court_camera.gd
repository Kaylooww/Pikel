extends Camera3D
class_name CourtCamera
## Follows one player using the active CameraRig. Owns all camera motion so game scripts
## only set `target` and, if they want, switch rigs.

## The first rig is the default; C cycles through the rest.
@export var rigs: Array[CameraRig] = [
    preload("res://config/camera_chase.tres"),
    preload("res://config/camera_match.tres"),
    preload("res://config/camera_training.tres"),
]
var rig_index: int = 0
var side: int = 1 ## +1 films from behind the home baseline, -1 from behind the away baseline
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
    # Rigs are written for the home half. For the away half, mirror the court through the net post line.
    var mirror := Vector3(side, 1.0, side)
    var seen_from_home: Vector3 = target.position * mirror
    position = position.lerp(rig.desired_position(seen_from_home) * mirror, weight)
    fov = lerpf(fov, rig.fov, weight)
    basis = Basis.looking_at(rig.look_target(seen_from_home) * mirror - position, Vector3.UP)
