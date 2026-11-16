extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_net_collision.gd
const R: float = CourtDimensions.BALL_VISUAL_RADIUS
var errors: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    _assert(is_equal_approx(CourtDimensions.net_height_at(0.0), CourtDimensions.NET_CENTER_HEIGHT), "net is 34 in at center")
    _assert(is_equal_approx(CourtDimensions.net_height_at(-CourtDimensions.HALF_WIDTH), CourtDimensions.NET_SIDE_HEIGHT), "net is 36 in at sideline")
    _assert(not _hit(Vector3(0, 1.5, 0.1), Vector3(0, 1.5, -0.1)), "high crossing clears")
    _assert(_hit(Vector3(0, 0.5, 0.1), Vector3(0, 0.5, -0.1)), "low crossing hits net body")
    _assert(_hit(Vector3(0, 0.5, 0.4), Vector3(0, 0.5, -0.4)), "fast low ball does not tunnel")
    _assert(not _hit(Vector3(0, 1.0, 0.1), Vector3(0, 1.0, -0.1)), "1.0 m clears the lower center")
    _assert(_hit(Vector3(3.0, 1.0, 0.1), Vector3(3.0, 1.0, -0.1)), "1.0 m clips the higher side")
    _assert(not _hit(Vector3(4.0, 0.5, 0.1), Vector3(4.0, 0.5, -0.1)), "around the post is clear")
    _assert(_hit(Vector3(0, 0.5, 0.3), Vector3(0, 0.5, 0.05)), "graze without crossing z=0 hits")
    _assert(not _hit(Vector3(0, 0.5, 3.0), Vector3(0, 0.5, 2.8)), "far from net is clear")
    # Center crosses z=0 at y=0.97, above net+radius (0.9686), so a plane-only check passes it.
    _assert(_hit(Vector3(0, 1.10, 0.05), Vector3(0, 0.84, -0.05)), "steep drop clips the tape")
    if errors.is_empty():
        print("PASS: %d net collision checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

func _hit(prev: Vector3, next: Vector3) -> bool:
    return NetCollision.hits_net(prev, next, R)

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
