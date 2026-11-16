extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_rules.gd
var errors: Array[String] = []

func _initialize() -> void:
    _assert(CourtDimensions.inside_court(Vector3(0, 0, 0)), "court center in bounds")
    _assert(not CourtDimensions.inside_court(Vector3(10, 0, 0)), "far outside out")
    _assert(CourtDimensions.inside_kitchen(Vector3(0, 0, 0.6)), "inside kitchen")
    _assert(not CourtDimensions.inside_kitchen(Vector3(0, 0, 3.0)), "outside kitchen")
    _assert(not RulesEngine.service_landing_is_valid(Vector3(1.0, 0.0, -1.0), true, true), "serve in kitchen invalid")
    _assert(RulesEngine.service_landing_is_valid(Vector3(1.0, 0.0, -4.0), true, true), "valid opposite cross-court serve")
    _assert(not RulesEngine.service_landing_is_valid(Vector3(-1.0, 0.0, -4.0), true, true), "wrong service box invalid")
    if errors.is_empty():
        print("PASS: 7 rules smoke checks")
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

func _assert(condition: bool, desc: String) -> void:
    if not condition:
        errors.append(desc)
