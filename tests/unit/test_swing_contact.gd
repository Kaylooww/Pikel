extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_swing_contact.gd
## Reach, timing windows and the error they cause (RP-015).
const T := SwingContact.Timing
var errors: Array[String] = []
var checks: int = 0
var tuning := GameplayTuning.new()

func _initialize() -> void:
    var player := Vector3(0.0, 0.0, 5.0)
    var hand: Vector3 = player + Vector3.UP * tuning.player_contact_height
    var plane_z: float = player.z - tuning.contact_lead # ideal contact plane for a home player

    # Reach.
    var still: SwingContact.Contact = _eval(player, hand + Vector3(0.3, 0.0, -0.4), Vector3.ZERO)
    _assert(still.in_reach and still.is_clean() and still.offset == Vector3.ZERO, "close still ball is a clean hit with no error")
    _assert(still.label() == "CLEAN", "clean label")
    var far: SwingContact.Contact = _eval(player, hand + Vector3(1.6, 0.0, 0.0), Vector3.ZERO)
    _assert(far.in_reach and far.stretched and not far.is_clean(), "ball past the comfortable radius is stretched")
    _assert(far.offset.z > 0.0 and far.offset.z < tuning.max_reach_error and far.offset.x == 0.0, "stretched shot falls short, toward the net")
    var limit: SwingContact.Contact = _eval(player, hand + Vector3(tuning.player_reach, 0.0, 0.0), Vector3.ZERO)
    _assert(limit.in_reach and is_equal_approx(limit.offset.z, tuning.max_reach_error), "full stretch gives the maximum reach error")
    var gone: SwingContact.Contact = _eval(player, hand + Vector3(tuning.player_reach + 0.05, 0.0, 0.0), Vector3.ZERO)
    _assert(not gone.in_reach and gone.offset == Vector3.ZERO, "ball beyond reach cannot be hit")

    # Timing, ball flying toward a home player at 8 m/s.
    var incoming := Vector3(0.0, 0.0, 8.0)
    var on_time: SwingContact.Contact = _eval(player, Vector3(0.0, 0.95, plane_z - 0.4), incoming) # 0.05 s away
    _assert(on_time.timing == T.CLEAN and on_time.is_clean(), "swing inside the window is clean")
    var early: SwingContact.Contact = _eval(player, Vector3(0.0, 0.95, plane_z - 1.0), incoming) # 0.125 s before
    _assert(early.timing == T.EARLY and early.offset.x < 0.0, "early swing pulls the ball to the hitter's left")
    var late: SwingContact.Contact = _eval(player, Vector3(0.0, 0.95, plane_z + 1.0), incoming) # 0.125 s after
    _assert(late.timing == T.LATE and late.offset.x > 0.0, "late swing pushes the ball to the hitter's right")
    _assert(is_equal_approx(early.offset.x, -late.offset.x), "equally early and late swings miss by the same amount")
    var earlier: SwingContact.Contact = _eval(player, Vector3(0.0, 0.95, plane_z - 1.4), incoming) # 0.175 s before
    _assert(earlier.offset.x < early.offset.x, "worse timing means a bigger miss")
    var fast := Vector3(0.0, 0.0, 3.0)
    var worst: SwingContact.Contact = _eval(player, Vector3(0.0, 0.95, plane_z - 1.2), fast) # 0.4 s before
    _assert(is_equal_approx(worst.offset.x, -tuning.max_timing_error), "timing error is capped")
    _assert(early.label() == "EARLY + STRETCHED" and late.label() == "LATE", "timing labels")

    # A ball that is not approaching has no timing to judge.
    _assert(_eval(player, Vector3(0.0, 0.95, plane_z - 1.0), Vector3(0.0, 0.0, -8.0)).timing == T.CLEAN, "ball moving away is not judged on timing")

    # Both problems at once.
    var both: SwingContact.Contact = _eval(player, Vector3(1.3, 0.95, plane_z + 1.0), incoming)
    _assert(both.timing == T.LATE and both.stretched and both.label() == "LATE + STRETCHED", "late and stretched combine")

    # Mirrored for a player on the away half.
    var away := Vector3(0.0, 0.0, -5.0)
    var away_early: SwingContact.Contact = SwingContact.evaluate(away, Vector3(0.0, 0.95, -5.0 + tuning.contact_lead + 1.0), Vector3(0.0, 0.0, -8.0), -1, tuning)
    _assert(away_early.timing == T.EARLY and away_early.offset.x > 0.0, "away player's early swing is mirrored")
    var away_far: SwingContact.Contact = SwingContact.evaluate(away, away + Vector3(1.6, 0.95, 0.0), Vector3.ZERO, -1, tuning)
    _assert(away_far.offset.z < 0.0, "away player's stretched shot also falls toward the net")

    # Applying the error.
    _assert(still.apply(Vector3(1.0, 0.0, -4.0)) == Vector3(1.0, 0.0, -4.0), "clean contact leaves the aim alone")
    _assert(early.apply(Vector3(1.0, 0.0, -4.0)).x < 1.0, "early contact moves the real target")
    _assert(limit.apply(Vector3(0.0, 0.0, -0.5)).z <= -SwingContact.MIN_DEPTH, "a short mishit still crosses the net")
    _assert(away_far.apply(Vector3(0.0, 0.0, 0.5)).z >= SwingContact.MIN_DEPTH, "same for the away side")
    # A late swing aimed near the sideline goes out: an honest miss, and the solver refuses it.
    var wide: Vector3 = worst.apply(Vector3(-CourtDimensions.HALF_WIDTH + 0.2, 0.0, -4.0))
    _assert(not CourtDimensions.inside_court(wide), "a badly timed shot aimed at the line goes wide")

    if errors.is_empty():
        print("PASS: %d swing contact checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

func _eval(player: Vector3, ball: Vector3, velocity: Vector3) -> SwingContact.Contact:
    return SwingContact.evaluate(player, ball, velocity, 1, tuning)

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
