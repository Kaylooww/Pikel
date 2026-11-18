extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_aim_advice.gd
## The aiming hint logic shared by local and online play, and the cursor clamp.
const A := AimAdvice.State
const P := RallyState.Phase
var errors: Array[String] = []
var checks: int = 0
var tuning := GameplayTuning.new()

func _initialize() -> void:
    var diagonal := Vector3(-1.5, 0.0, -4.6)

    # Serving from a legal spot at the diagonal court.
    var view: MatchView = _serve_view()
    var advice: AimAdvice = AimAdvice.evaluate(view, diagonal, tuning)
    _assert(advice.state == A.OK and advice.text.begins_with("AIM OK") and advice.hold.ok and advice.tap.ok, "a legal serve is OK with both arcs")
    _assert(advice.real_target.is_equal_approx(diagonal) and advice.contact.is_clean(), "a still ball in hand is a clean contact on target")
    advice = AimAdvice.evaluate(view, Vector3(1.5, 0.0, -4.6), tuning)
    _assert(advice.state == A.BLOCKED and advice.text.contains("diagonal") and advice.hold.ok, "wrong service court is flagged but the arc is still shown")
    view.my_position = Vector3(1.5, 0.0, 5.0)
    view.ball_position = view.my_position + Vector3(0.35, 1.0, -0.85)
    advice = AimAdvice.evaluate(view, diagonal, tuning)
    _assert(advice.state == A.BLOCKED and advice.text.contains("baseline") and advice.text.contains("right half"), "serving from inside the court is flagged")
    view = _serve_view()
    view.serve_from_right = false
    view.my_position = Vector3(1.5, 0.0, 7.0)
    _assert(AimAdvice.evaluate(view, Vector3(1.5, 0.0, -4.6), tuning).text.contains("left half"), "the hint names the left half for a left-court serve")

    # Times when there is nothing to swing at.
    view = _serve_view()
    view.live = false
    _assert(_idle(view, "set up"), "between rallies")
    view = _serve_view()
    view.server_side = -1
    _assert(_idle(view, "Opponent is serving"), "opponent's serve")
    view = _rally_view()
    view.last_hitter = 1
    _assert(_idle(view, "Your shot"), "own shot in play")
    view = _rally_view()
    view.ball_position = Vector3(0.0, 1.0, -3.0)
    _assert(_idle(view, "other half"), "ball on the other half")
    view = _rally_view()
    view.ball_position = Vector3(3.0, 1.0, 1.0)
    _assert(_idle(view, "not in reach"), "ball out of reach")

    # Rule warnings.
    view = _rally_view()
    view.phase = P.RETURN_IN_FLIGHT
    view.bounces_since_hit = 0
    advice = AimAdvice.evaluate(view, diagonal, tuning)
    _assert(advice.state == A.BLOCKED and advice.text.begins_with("WAIT") and advice.hold == null, "the return must bounce: no arcs offered")
    view.phase = P.SERVE_IN_FLIGHT
    _assert(AimAdvice.evaluate(view, diagonal, tuning).text.begins_with("WAIT"), "the serve must bounce too")
    view = _rally_view()
    view.bounces_since_hit = 0
    view.my_position = Vector3(0.0, 0.0, 1.5)
    view.ball_position = Vector3(0.3, 1.0, 1.3)
    _assert(AimAdvice.evaluate(view, diagonal, tuning).text.begins_with("KITCHEN"), "volley from inside the kitchen is warned")
    view.bounces_since_hit = 1
    _assert(AimAdvice.evaluate(view, diagonal, tuning).state == A.OK, "a bounced ball in the kitchen may be hit")
    view = _rally_view()
    view.my_position = Vector3(0.0, 0.0, 0.5)
    view.ball_position = Vector3(0.0, 0.12, 0.3)
    advice = AimAdvice.evaluate(view, Vector3(0.0, 0.0, -6.5), tuning)
    _assert(advice.state == A.BLOCKED and advice.text.begins_with("AIM BLOCKED") and not advice.hold.ok, "no arc clears the net from low at the net")

    # The same advice works for the away side.
    view = _serve_view()
    view.side = -1
    view.server_side = -1
    view.my_position = Vector3(-1.5, 0.0, -7.0)
    view.opponent_position = Vector3(1.5, 0.0, 6.0)
    view.ball_position = view.my_position + Vector3(-0.35, 1.0, 0.85)
    advice = AimAdvice.evaluate(view, Vector3(1.5, 0.0, 4.6), tuning)
    _assert(advice.state == A.OK and advice.real_target.z > 0.0, "away player serving to the home half is OK")

    # Cursor clamp.
    _assert(CourtAim.clamp_to_opponent_court(Vector3(9.0, 3.0, 2.0), 1).is_equal_approx(Vector3(CourtDimensions.HALF_WIDTH - 0.16, 0.0, -0.20)), "home aim is pulled onto the away half, inside the lines")
    _assert(CourtAim.clamp_to_opponent_court(Vector3(-9.0, 0.0, -20.0), 1).is_equal_approx(Vector3(-CourtDimensions.HALF_WIDTH + 0.16, 0.0, -CourtDimensions.HALF_LENGTH + 0.14)), "home aim cannot go past the far baseline")
    _assert(CourtAim.clamp_to_opponent_court(Vector3(0.0, 0.0, -3.0), -1).z > 0.0, "away aim is pulled onto the home half")

    # HUD wording.
    _assert(RallyText.score_line(3, 2, 1, false, 1) == "YOU 3  –  2 OPPONENT   |   You serve, left court", "score line for home")
    _assert(RallyText.score_line(3, 2, 1, true, -1) == "YOU 2  –  3 OPPONENT   |   Opponent serves, right court", "score line for away")
    var rally := RallyState.new(1, 1, false)
    rally.apply(RallyEvent.hit(1, 1, 0, 1, Vector3.ZERO, Vector3(0.0, 0.0, 5.0)))
    _assert(RallyText.fault(rally, 1).contains("FOOT FAULT") and RallyText.fault(rally, 1).contains("left half") and RallyText.fault(rally, 1).contains("opponent wins"), "fault text for the player at fault")
    _assert(RallyText.fault(rally, -1).contains("you win"), "the same fault read from the other side")

    if errors.is_empty():
        print("PASS: %d aim advice checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

func _serve_view() -> MatchView:
    var view := MatchView.new()
    view.side = 1
    view.live = true
    view.phase = P.WAITING_FOR_SERVE
    view.server_side = 1
    view.serve_from_right = true
    view.my_position = Vector3(1.5, 0.0, 7.0)
    view.opponent_position = Vector3(-1.5, 0.0, -6.0)
    view.ball_position = view.my_position + Vector3(0.35, 1.0, -0.85)
    return view

## Open rally: the opponent's ball has bounced once and sits still next to the home player.
func _rally_view() -> MatchView:
    var view: MatchView = _serve_view()
    view.phase = P.OPEN_RALLY
    view.last_hitter = -1
    view.bounces_since_hit = 1
    view.my_position = Vector3(0.0, 0.0, 5.0)
    view.ball_position = Vector3(0.3, 1.0, 4.6)
    return view

func _idle(view: MatchView, expected_text: String) -> bool:
    var advice: AimAdvice = AimAdvice.evaluate(view, Vector3(-1.5, 0.0, -4.6), tuning)
    return advice.state == A.IDLE and advice.text.contains(expected_text) and advice.hold == null

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
