extends Node3D
class_name AimPreview
## The on-court aiming aids: the target ring, the dotted drive and dink arcs, and the dot
## showing where the last shot landed. Display only; it shows an AimAdvice it is given.

const OK_COLOR := Color(0.33, 0.84, 0.80, 0.70)
const BLOCKED_COLOR := Color(1.0, 0.51, 0.42, 0.70)
const IDLE_COLOR := Color(0.75, 0.78, 0.80, 0.40)

var marker_material := StandardMaterial3D.new()
var marker := MeshInstance3D.new()
var landing_marker := MeshInstance3D.new()
var drive_arc := TrajectoryPreview.new()
var dink_arc := TrajectoryPreview.new()

func _init() -> void:
    marker_material.albedo_color = IDLE_COLOR
    marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker.mesh = _disc(0.30, 0.015, marker_material)
    add_child(marker)
    var landing_material := StandardMaterial3D.new()
    landing_material.albedo_color = Color("ff816c")
    landing_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    landing_marker.mesh = _disc(0.12, 0.02, landing_material)
    landing_marker.visible = false
    add_child(landing_marker)
    drive_arc.set_color(Color("ffe06b"))
    add_child(drive_arc)
    dink_arc.set_color(Color("55d5cb"))
    add_child(dink_arc)

## Shows the ring at `aim` and whatever the advice says about a swing from `ball_position`.
func show_advice(advice: AimAdvice, aim: Vector3, ball_position: Vector3, tuning: GameplayTuning) -> void:
    marker.position = Vector3(aim.x, 0.10, aim.z)
    match advice.state:
        AimAdvice.State.OK: marker_material.albedo_color = OK_COLOR
        AimAdvice.State.BLOCKED: marker_material.albedo_color = BLOCKED_COLOR
        _: marker_material.albedo_color = IDLE_COLOR
    _show_arc(drive_arc, advice.drive, ball_position, tuning)
    _show_arc(dink_arc, advice.dink, ball_position, tuning)

func show_landing(at: Vector3) -> void:
    landing_marker.position = Vector3(at.x, 0.11, at.z)
    landing_marker.visible = true

func hide_landing() -> void:
    landing_marker.visible = false

func _show_arc(arc: TrajectoryPreview, shot: ShotSolver.Solution, ball_position: Vector3, tuning: GameplayTuning) -> void:
    arc.show_points(ShotSolver.sample_arc(ball_position, shot, tuning.gravity) if shot != null else PackedVector3Array())

func _disc(radius: float, height: float, material: Material) -> CylinderMesh:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.material = material
    return mesh
