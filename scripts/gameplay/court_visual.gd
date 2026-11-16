extends Node3D
## Procedural visual-only prototype court; collision math lives in CourtDimensions.
func _ready() -> void:
    _box("Surround", Vector3(0, -0.10, 0), Vector3(16, 0.16, 23), Color("72c4b8"))
    _box("Surface", Vector3(0, 0.004, 0), Vector3(CourtDimensions.WIDTH, 0.018, CourtDimensions.LENGTH), Color("265d88"))
    var w: float = CourtDimensions.HALF_WIDTH
    var l: float = CourtDimensions.HALF_LENGTH
    var k: float = CourtDimensions.KITCHEN_DEPTH
    _box("KitchenHome", Vector3(0, 0.017, k / 2.0), Vector3(CourtDimensions.WIDTH, 0.014, k), Color("36b4a8"))
    _box("KitchenAway", Vector3(0, 0.017, -k / 2.0), Vector3(CourtDimensions.WIDTH, 0.014, k), Color("36b4a8"))
    var t: float = CourtDimensions.LINE_WIDTH
    for x in [-w, w]:
        _box("Sideline", Vector3(x, 0.042, 0), Vector3(t, 0.008, CourtDimensions.LENGTH), Color.WHITE)
    for z in [-l, l, -k, k]:
        _box("TransverseLine", Vector3(0, 0.042, z), Vector3(CourtDimensions.WIDTH, 0.008, t), Color.WHITE)
    for z in [-(l+k)/2.0, (l+k)/2.0]:
        _box("Centerline", Vector3(0, 0.042, z), Vector3(t, 0.008, l-k), Color.WHITE)
    _box("NetTop", Vector3(0, 0.885, 0), Vector3(CourtDimensions.WIDTH+0.30, 0.055, 0.055), Color("f3f6f7"))
    for x in [-w-0.17, w+0.17]:
        _box("NetPost", Vector3(x, 0.46, 0), Vector3(0.10, 0.92, 0.10), Color("1b3545"))
    for xidx in range(25):
        var xx: float = -w + (CourtDimensions.WIDTH * float(xidx)/24.0)
        _box("NetStringV", Vector3(xx, 0.47, 0), Vector3(0.012, 0.81, 0.012), Color("18394a"))
    for yidx in range(11):
        _box("NetStringH", Vector3(0, 0.09 + float(yidx)*0.077, 0), Vector3(CourtDimensions.WIDTH, 0.009, 0.012), Color("18394a"))

func _box(label: String, center: Vector3, size: Vector3, color: Color) -> void:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.0
    material.roughness = 0.9
    mesh.material = material
    node.mesh = mesh
    node.name = label
    node.position = center
    add_child(node)
