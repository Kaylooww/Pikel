extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_rally_state.gd
## Rally events and state transitions (RP-020).
const P := RallyState.Phase
const F := RallyState.Fault
const HOME: int = 1
const AWAY: int = -1
const HOME_COURT := Vector3(0.0, 0.0, 4.0)
const AWAY_COURT := Vector3(0.0, 0.0, -4.0)
var errors: Array[String] = []
var checks: int = 0
var next_id: int = 0

func _initialize() -> void:
    # A full legal exchange walks every phase in order. Home serves.
    var r := RallyState.new(7, HOME)
    _assert(r.phase == P.WAITING_FOR_SERVE and not r.is_over(), "rally starts waiting for the serve")
    _assert(_hit(r, HOME) and r.phase == P.SERVE_IN_FLIGHT, "server's hit starts the serve")
    _assert(_bounce(r, AWAY_COURT) and r.phase == P.WAITING_FOR_RETURN, "serve bounce waits for the return")
    _assert(_hit(r, AWAY) and r.phase == P.RETURN_IN_FLIGHT, "receiver's hit is the return")
    _assert(_bounce(r, HOME_COURT) and r.phase == P.OPEN_RALLY, "return bounce opens the rally")
    _assert(_hit(r, HOME) and r.phase == P.OPEN_RALLY, "third shot keeps the rally open")
    _assert(_hit(r, AWAY) and r.phase == P.OPEN_RALLY, "a volley is allowed once the rally is open")
    _assert(_bounce(r, HOME_COURT) and _hit(r, HOME) and r.phase == P.OPEN_RALLY, "groundstrokes continue the rally")
    _assert(r.fault == F.NONE and r.winner_side == 0 and r.log.size() == 8, "no fault yet and every event is logged")

    # Each way a rally can end, with who is at fault and who wins.
    r = _open_rally(HOME) # away hit last, ball bounced once on home side
    _bounce(r, HOME_COURT)
    _assert(_ended(r, F.DOUBLE_BOUNCE, HOME), "second bounce is a fault on the side that let it bounce")
    r = _open_rally(HOME)
    _bounce(r, Vector3(0.0, 0.0, 9.0))
    _assert(_ended(r, F.DOUBLE_BOUNCE, HOME), "second bounce beyond the baseline is still a double bounce, not out")
    r = _open_rally(HOME)
    _hit(r, HOME)
    _bounce(r, Vector3(5.0, 0.0, -4.0))
    _assert(_ended(r, F.OUT, HOME), "landing outside the court is a fault on the hitter")
    r = _open_rally(HOME)
    _hit(r, HOME)
    _bounce(r, HOME_COURT)
    _assert(_ended(r, F.OWN_SIDE, HOME), "landing on your own half is a fault on the hitter")
    r = _open_rally(HOME)
    _hit(r, HOME)
    r.apply(RallyEvent.net(_id(), r.rally_id, 0))
    _assert(_ended(r, F.NET, HOME), "ball stopped by the net is a fault on the hitter")
    r = _open_rally(HOME)
    _hit(r, HOME)
    _hit(r, HOME)
    _assert(_ended(r, F.DOUBLE_HIT, HOME), "hitting twice in a row is a fault")
    r = _open_rally(HOME)
    _hit(r, HOME)
    _bounce(r, Vector3(CourtDimensions.HALF_WIDTH, 0.0, -CourtDimensions.HALF_LENGTH))
    _assert(not r.is_over(), "a ball on the line is in and the rally goes on")

    # Two-bounce rule shape: the serve and the return must each bounce before being hit.
    r = RallyState.new(1, HOME)
    _hit(r, HOME)
    _hit(r, AWAY)
    _assert(_ended(r, F.VOLLEY_BEFORE_BOUNCE, AWAY), "volleying the serve is a fault on the receiver")
    r = RallyState.new(1, HOME)
    _hit(r, HOME)
    _bounce(r, AWAY_COURT)
    _hit(r, AWAY)
    _hit(r, HOME)
    _assert(_ended(r, F.VOLLEY_BEFORE_BOUNCE, HOME), "volleying the return is a fault on the server")
    r = RallyState.new(1, HOME)
    _hit(r, HOME)
    _bounce(r, AWAY_COURT)
    _bounce(r, AWAY_COURT)
    _assert(_ended(r, F.DOUBLE_BOUNCE, AWAY), "receiver letting the serve bounce twice loses the rally")

    # Serve faults.
    r = RallyState.new(1, HOME)
    _hit(r, HOME)
    r.apply(RallyEvent.net(_id(), 1, 0))
    _assert(_ended(r, F.NET, HOME), "serve into the net is a fault on the server")
    r = RallyState.new(1, HOME)
    _hit(r, HOME)
    _bounce(r, Vector3(0.0, 0.0, -9.0))
    _assert(_ended(r, F.OUT, HOME), "long serve is a fault on the server")

    # Mirrored: away serves.
    r = RallyState.new(2, AWAY)
    _assert(not _hit(r, HOME) and r.phase == P.WAITING_FOR_SERVE, "only the server can start the rally")
    _hit(r, AWAY)
    _bounce(r, HOME_COURT)
    _hit(r, HOME)
    _bounce(r, AWAY_COURT)
    _assert(r.phase == P.OPEN_RALLY and r.server_side == AWAY, "away-served rally reaches open play")

    # Events that must be ignored.
    r = RallyState.new(3, HOME)
    _assert(not _bounce(r, AWAY_COURT) and r.log.is_empty(), "a bounce before the serve is ignored")
    var serve: RallyEvent = RallyEvent.hit(_id(), 3, 10, HOME)
    _assert(r.apply(serve) and not r.apply(serve), "the same event applied twice counts once")
    _assert(r.phase == P.SERVE_IN_FLIGHT and r.log.size() == 1, "a duplicate does not cause a double-hit fault")
    _assert(not r.apply(RallyEvent.bounce(serve.id - 1, 3, 11, AWAY_COURT)), "an older event id is ignored")
    _assert(not r.apply(RallyEvent.bounce(_id(), 99, 11, AWAY_COURT)), "an event from another rally is ignored")
    r.apply(RallyEvent.net(_id(), 3, 12))
    var winner: int = r.winner_side
    _assert(not _bounce(r, Vector3(9.0, 0.0, 9.0)) and not _hit(r, AWAY), "nothing is accepted after the rally ends")
    _assert(r.fault == F.NET and r.winner_side == winner and r.log.size() == 2, "a finished rally cannot end twice")
    _assert(r.log[0].tick == 10 and r.log[1].type == RallyEvent.Type.NET, "the log keeps tick and type")

    if errors.is_empty():
        print("PASS: %d rally state checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

## A rally where `server` served, the return came back and bounced once on the server's half.
func _open_rally(server: int) -> RallyState:
    var r := RallyState.new(1, server)
    _hit(r, server)
    _bounce(r, AWAY_COURT if server == HOME else HOME_COURT)
    _hit(r, -server)
    _bounce(r, HOME_COURT if server == HOME else AWAY_COURT)
    return r

func _ended(r: RallyState, reason: RallyState.Fault, guilty: int) -> bool:
    return r.is_over() and r.fault == reason and r.fault_side == guilty and r.winner_side == -guilty

func _id() -> int:
    next_id += 1
    return next_id

func _hit(r: RallyState, side: int) -> bool:
    return r.apply(RallyEvent.hit(_id(), r.rally_id, 0, side))

func _bounce(r: RallyState, at: Vector3) -> bool:
    return r.apply(RallyEvent.bounce(_id(), r.rally_id, 0, at))

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
