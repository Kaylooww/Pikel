extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_rally_controller.gd
## The controller numbers events and reports the end of a rally exactly once (RP-021).
var errors: Array[String] = []
var checks: int = 0
var ended: Array[RallyState] = []

func _initialize() -> void:
    var c := RallyController.new()
    c.rally_ended.connect(func(rally: RallyState) -> void: ended.append(rally))
    c.start(1)
    var first: RallyState = c.rally
    _assert(first.rally_id == 1 and first.server_side == 1, "first rally has id 1")
    _assert(c.hit(1, Vector3(0, 1, 7), Vector3(1.5, 0, 7)) and c.bounce(Vector3(0, 0, -4)), "serve and bounce are accepted")
    _assert(first.log[0].id < first.log[1].id, "event ids increase")
    _assert(first.log[0].rally_id == 1 and first.log[1].type == RallyEvent.Type.BOUNCE, "events carry rally id and type")
    _assert(ended.is_empty(), "no end reported while the rally is live")
    _assert(c.bounce(Vector3(0, 0, -5)), "second bounce is accepted")
    _assert(ended.size() == 1 and ended[0] == first and first.fault == RallyState.Fault.DOUBLE_BOUNCE, "rally end is reported with the fault")
    _assert(not c.bounce(Vector3(0, 0, -6)) and not c.net(Vector3.ZERO) and ended.size() == 1, "later events do not report a second end")

    c.momentum_ticks = 50
    c.start(-1, true)
    _assert(c.rally.momentum_ticks == 50 and not c.kitchen_entry(1, Vector3(0, 0, 1)), "new rallies get the momentum window, and idle kitchen entries are ignored")
    _assert(first.log[0].player_position == Vector3(1.5, 0, 7), "hit events carry the hitter's feet position")
    _assert(c.rally != first and c.rally.rally_id == 2 and c.rally.server_side == -1, "next rally gets a new id and server")
    _assert(not c.hit(1, Vector3.ZERO, Vector3(1.5, 0, 7)), "wrong server cannot start it")
    _assert(c.hit(-1, Vector3(0, 1, -7), Vector3(-1.5, 0, -7)) and c.rally.log[0].id > first.log[-1].id, "event ids keep increasing across rallies")
    _assert(c.net(Vector3.ZERO) and ended.size() == 2 and ended[1].fault == RallyState.Fault.NET and ended[1].winner_side == 1, "net ends the second rally for the other side")

    # A scored match (RP-024): to 2 points, win by 1, home serves first.
    var won: Array[MatchScore] = []
    var m := RallyController.new()
    m.match_ended.connect(func(final: MatchScore) -> void: won.append(final))
    m.new_match(1, 2, 1)
    _assert(m.score.score_call() == "0-0" and m.rally.server_side == 1 and m.rally.serve_from_right, "match starts with home serving from the right")
    m.hit(1, Vector3.ZERO, Vector3(1.5, 0, 7))
    m.bounce(Vector3(-1.5, 0, -4))
    m.bounce(Vector3(-1.5, 0, -6)) # receiver lets it bounce twice
    _assert(m.rally.is_over() and m.score.score_call() == "1-0" and won.is_empty(), "server winning the rally scores, match goes on")
    var scored_rally: RallyState = m.rally
    _assert(not m.bounce(Vector3.ZERO) and m.score.score_call() == "1-0", "a late event cannot score the rally again")
    _assert(m.start_next() and m.rally != scored_rally and m.rally.server_side == 1 and not m.rally.serve_from_right, "next rally: same server, now from the left court")
    m.hit(1, Vector3.ZERO, Vector3(-1.5, 0, 7))
    m.net(Vector3.ZERO) # server faults
    _assert(m.score.score_call() == "0-1" and m.score.server_side == -1, "server losing the rally is a side-out")
    _assert(m.start_next() and m.rally.server_side == -1 and m.rally.serve_from_right, "next rally: away serves from their right court")
    _assert(not m.hit(1, Vector3.ZERO, Vector3(1.5, 0, 7)), "home can no longer serve")
    m.hit(-1, Vector3.ZERO, Vector3(-1.5, 0, -7))
    m.net(Vector3.ZERO) # side-out back to home at 1-0
    m.start_next()
    _assert(m.rally.server_side == 1 and not m.rally.serve_from_right and m.score.score_call() == "1-0", "serve returns to home, left court at 1")
    m.hit(1, Vector3.ZERO, Vector3(-1.5, 0, 7))
    m.bounce(Vector3(1.5, 0, -4))
    m.bounce(Vector3(1.5, 0, -6))
    _assert(m.score.is_over() and m.score.winner_side == 1 and m.score.score_call() == "2-0", "second point wins the match")
    _assert(won.size() == 1 and won[0] == m.score, "match end is reported once")
    var last: RallyState = m.rally
    _assert(not m.start_next() and m.rally == last, "no new rally starts after the match is won")

    if errors.is_empty():
        print("PASS: %d rally controller checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
