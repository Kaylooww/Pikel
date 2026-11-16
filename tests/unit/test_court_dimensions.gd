extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_court_dimensions.gd
## Freezes the court units and the line-inclusive predicates (RP-004).
const FT: float = 0.3048
const IN: float = 0.0254
const C := preload("res://scripts/core/court_dimensions.gd")
var errors: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    # Units: regulation sizes in meters.
    _assert(is_equal_approx(C.WIDTH, 20.0 * FT), "width is 20 ft")
    _assert(is_equal_approx(C.LENGTH, 44.0 * FT), "length is 44 ft")
    _assert(is_equal_approx(C.KITCHEN_DEPTH, 7.0 * FT), "kitchen is 7 ft")
    _assert(is_equal_approx(C.NET_CENTER_HEIGHT, 34.0 * IN), "net center is 34 in")
    _assert(is_equal_approx(C.NET_SIDE_HEIGHT, 36.0 * IN), "net side is 36 in")
    _assert(is_equal_approx(C.NET_HALF_WIDTH, 11.0 * FT), "posts are 22 ft apart")
    _assert(is_equal_approx(C.LINE_WIDTH, 2.0 * IN), "lines are 2 in wide")
    # Boundary: outer edge of the line is in, anything beyond is out.
    _assert(C.inside_court(Vector3(C.HALF_WIDTH, 0, 0)), "on sideline edge is in")
    _assert(not C.inside_court(Vector3(C.HALF_WIDTH + 0.001, 0, 0)), "1 mm past sideline is out")
    _assert(C.inside_court(Vector3(0, 0, -C.HALF_LENGTH)), "on baseline edge is in")
    _assert(not C.inside_court(Vector3(0, 0, C.HALF_LENGTH + 0.001)), "1 mm past baseline is out")
    _assert(C.inside_court(Vector3(-C.HALF_WIDTH, 5.0, C.HALF_LENGTH)), "corner is in, height ignored")
    # Kitchen: its line is part of the zone, on both halves.
    _assert(C.inside_kitchen(Vector3(0, 0, C.KITCHEN_DEPTH)), "home kitchen line is kitchen")
    _assert(C.inside_kitchen(Vector3(0, 0, -C.KITCHEN_DEPTH)), "away kitchen line is kitchen")
    _assert(not C.inside_kitchen(Vector3(0, 0, C.KITCHEN_DEPTH + 0.001)), "1 mm behind kitchen line is not kitchen")
    _assert(not C.inside_kitchen(Vector3(C.HALF_WIDTH + 0.001, 0, 1.0)), "beside the court is not kitchen")
    # Sides.
    _assert(C.side_from_z(3.0) == 1 and C.side_from_z(-3.0) == -1, "home is +z, away is -z")
    # Serve: diagonal court only. The home right court is +x, so its target is -x on the away half.
    _assert(C.legal_serve_target(Vector3(-1.5, 0, -4.0), true, true), "home right serves to -x")
    _assert(not C.legal_serve_target(Vector3(1.5, 0, -4.0), true, true), "home right straight ahead is a fault")
    _assert(C.legal_serve_target(Vector3(1.5, 0, -4.0), true, false), "home left serves to +x")
    _assert(C.legal_serve_target(Vector3(1.5, 0, 4.0), false, true), "away right serves to +x")
    _assert(C.legal_serve_target(Vector3(-1.5, 0, 4.0), false, false), "away left serves to -x")
    _assert(not C.legal_serve_target(Vector3(-1.5, 0, 4.0), true, true), "serve onto own half is a fault")
    # Serve lines: kitchen line is a fault; centerline, sideline and baseline are in.
    _assert(not C.legal_serve_target(Vector3(-1.5, 0, -C.KITCHEN_DEPTH), true, true), "serve on kitchen line is a fault")
    _assert(C.legal_serve_target(Vector3(-1.5, 0, -C.KITCHEN_DEPTH - 0.001), true, true), "serve 1 mm past kitchen line is in")
    _assert(C.legal_serve_target(Vector3(0.02, 0, -4.0), true, true), "serve on centerline is in")
    _assert(not C.legal_serve_target(Vector3(0.03, 0, -4.0), true, true), "serve past centerline is a fault")
    _assert(C.legal_serve_target(Vector3(-C.HALF_WIDTH, 0, -C.HALF_LENGTH), true, true), "serve on far corner is in")
    _assert(not C.legal_serve_target(Vector3(-C.HALF_WIDTH - 0.001, 0, -4.0), true, true), "serve wide is a fault")
    if errors.is_empty():
        print("PASS: %d court dimension checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
