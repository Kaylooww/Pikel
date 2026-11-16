extends MultiMeshInstance3D
class_name TrajectoryPreview
## Draws a row of dots along a flight path. Visual only: it is handed points and never
## decides anything about the shot.
const MAX_DOTS: int = 32
var shown_points: PackedVector3Array ## what is currently drawn

func _init() -> void:
    var dot := SphereMesh.new()
    dot.radius = 0.04
    dot.height = 0.08
    dot.radial_segments = 8
    dot.rings = 4
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dot.material = material
    multimesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = dot
    multimesh.instance_count = MAX_DOTS
    multimesh.visible_instance_count = 0

func set_color(color: Color) -> void:
    (multimesh.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = color

## Shows one dot per point (world space; keep this node at the origin). Empty hides the arc.
func show_points(points: PackedVector3Array) -> void:
    var count: int = mini(points.size(), MAX_DOTS)
    for i in range(count):
        multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, points[i]))
    multimesh.visible_instance_count = count
    shown_points = points.slice(0, count)
