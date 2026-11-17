extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_net_protocol.gd
## The wire format: round trips, and refusing everything that is not exactly well formed.
const E := NetProtocol.EventType
var errors: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    # Input round trip.
    var input: PlayerInput = PlayerInput.make(Vector2(0.6, -0.8), true, PlayerInput.Swing.DINK, Vector3(-1.5, 0.0, -4.6), 42)
    var wire: Array = NetProtocol.encode_input(77, input)
    var back: PlayerInput = NetProtocol.decode_input(wire, 77)
    _assert(back != null and back.seq == 42 and back.move.is_equal_approx(Vector2(0.6, -0.8)) and back.sprint and back.swing == PlayerInput.Swing.DINK, "input survives the round trip")
    _assert(back.aim.is_equal_approx(Vector3(-1.5, 0.0, -4.6)), "aim point survives, flattened to the court")
    _assert(wire.size() == 6, "an input is six values: there is no room for a claimed position, hit or score")

    # Inputs that must be refused or cleaned.
    _assert(NetProtocol.decode_input(wire, 78) == null, "input for another match is refused")
    _assert(NetProtocol.decode_input(null, 77) == null and NetProtocol.decode_input("hi", 77) == null and NetProtocol.decode_input({}, 77) == null, "non-arrays are refused")
    _assert(NetProtocol.decode_input([77, 42, Vector2.ZERO, true, 1], 77) == null, "too few values is refused")
    _assert(NetProtocol.decode_input([77, 42, Vector2.ZERO, true, 1, Vector2.ZERO, "extra"], 77) == null, "too many values is refused")
    _assert(NetProtocol.decode_input([77, "42", Vector2.ZERO, true, 1, Vector2.ZERO], 77) == null, "wrong type is refused")
    _assert(NetProtocol.decode_input([77, 42, Vector3.ZERO, true, 1, Vector2.ZERO], 77) == null, "a Vector3 where a Vector2 belongs is refused")
    _assert(NetProtocol.decode_input([77, 42, Vector2.ZERO, 1, 1, Vector2.ZERO], 77) == null, "an int where a bool belongs is refused")
    _assert(NetProtocol.decode_input([77, 0, Vector2.ZERO, false, 0, Vector2.ZERO], 77) == null, "sequence numbers start at 1")
    _assert(NetProtocol.decode_input([77, 42, Vector2.ZERO, false, 3, Vector2.ZERO], 77) == null and NetProtocol.decode_input([77, 42, Vector2.ZERO, false, -1, Vector2.ZERO], 77) == null, "unknown swing types are refused")
    _assert(NetProtocol.decode_input([77, 42, Vector2(NAN, 0), false, 0, Vector2.ZERO], 77) == null, "NaN movement is refused")
    _assert(NetProtocol.decode_input([77, 42, Vector2.ZERO, false, 1, Vector2(INF, 0)], 77) == null, "infinite aim is refused")
    var fast: PlayerInput = NetProtocol.decode_input([77, 42, Vector2(500, -500), true, 0, Vector2.ZERO], 77)
    _assert(fast != null and is_equal_approx(fast.move.length(), 1.0), "an oversized move vector is cut to length 1")
    var far: PlayerInput = NetProtocol.decode_input([77, 42, Vector2.ZERO, false, 1, Vector2(9999, -9999)], 77)
    _assert(far != null and far.aim == Vector3(NetProtocol.AIM_LIMIT, 0.0, -NetProtocol.AIM_LIMIT), "a far-away aim point is clamped")

    # Snapshot round trip from a real simulation.
    var sim := MatchSimulation.new(GameplayTuning.new())
    sim.step({1: PlayerInput.make(Vector2(-1, 0), true, PlayerInput.Swing.DRIVE, Vector3(-1.5, 0.0, -4.6))})
    sim.step({})
    var snap: NetSnapshot = NetProtocol.decode_snapshot(NetProtocol.encode_snapshot(sim, 77, 9))
    _assert(snap != null and snap.match_id == 77 and snap.tick == 2 and snap.ack_seq == 9, "snapshot header survives")
    _assert(snap.home_position == sim.positions[1] and snap.away_position == sim.positions[-1] and snap.ball_position == sim.ball.position and snap.ball_velocity == sim.ball.velocity and snap.ball_moving, "positions and ball survive exactly")
    _assert(snap.phase == RallyState.Phase.SERVE_IN_FLIGHT and snap.last_hitter == 1 and snap.server_side == 1 and snap.serve_from_right and snap.live and snap.winner_side == 0 and snap.rally_id == 1, "rally state survives")
    _assert(snap.position_of(1) == snap.home_position and snap.position_of(-1) == snap.away_position, "position_of picks the side")
    var view: MatchView = snap.to_view(-1, Vector3(9, 0, -9))
    _assert(view.side == -1 and view.my_position == Vector3(9, 0, -9) and view.opponent_position == snap.home_position and view.last_hitter == 1, "a snapshot becomes the view of either side")

    # Snapshots that must be refused.
    var good: Array = NetProtocol.encode_snapshot(sim, 77, 9)
    var broken: Array = good.duplicate()
    broken.pop_back()
    _assert(NetProtocol.decode_snapshot(broken) == null, "a short snapshot is refused")
    broken = good.duplicate()
    broken[5] = Vector3(NAN, 0, 0)
    _assert(NetProtocol.decode_snapshot(broken) == null, "a snapshot with a NaN position is refused")
    broken = good.duplicate()
    broken[13] = 99
    _assert(NetProtocol.decode_snapshot(broken) == null, "a snapshot with an unknown rally phase is refused")
    broken = good.duplicate()
    broken[1] = 2.5
    _assert(NetProtocol.decode_snapshot(broken) == null and NetProtocol.decode_snapshot("x") == null, "wrong types are refused")

    # Welcome.
    var welcome: Dictionary = NetProtocol.decode_welcome(NetProtocol.encode_welcome(77, -1, 11, 2, "ticket"))
    _assert(welcome == {"match_id": 77, "side": -1, "tick_rate": 60, "points_to_win": 11, "win_by": 2, "token": "ticket"}, "welcome survives the round trip, seat ticket included")
    _assert(NetProtocol.decode_welcome([NetProtocol.VERSION + 1, 77, 1, 60, 11, 2, "t"]).is_empty(), "a welcome from another protocol version is refused")
    _assert(NetProtocol.decode_welcome([NetProtocol.VERSION, 77, 0, 60, 11, 2, "t"]).is_empty() and NetProtocol.decode_welcome([NetProtocol.VERSION, 77, 1, 60, 11, 2]).is_empty() and NetProtocol.decode_welcome([1, 2]).is_empty(), "a welcome with no real side, or the wrong size, is refused")

    # Private match codes (RP-035).
    var made: String = NetProtocol.new_match_code()
    _assert(made.length() == 6 and NetProtocol.clean_code(made) == made and made != NetProtocol.new_match_code(), "a new match code is six readable characters and different each time")
    _assert(NetProtocol.clean_code(" k7q-x2m ") == "K7QX2M", "a code typed in lower case with a dash and spaces is understood")
    _assert(NetProtocol.clean_code("K7QX2") == "" and NetProtocol.clean_code("K7QX2MM") == "" and NetProtocol.clean_code("K0QX1M") == "", "a code of the wrong length or with look-alike characters is refused")

    # Events.
    var ended: Dictionary = NetProtocol.decode_event(NetProtocol.encode_event(5, 77, E.RALLY_ENDED, [3, int(RallyState.Fault.NET), 1, -1, true, 2, 4]))
    _assert(ended["id"] == 5 and ended["match_id"] == 77 and ended["type"] == E.RALLY_ENDED and ended["payload"] == [3, int(RallyState.Fault.NET), 1, -1, true, 2, 4], "rally-ended event survives")
    _assert(NetProtocol.decode_event(NetProtocol.encode_event(6, 77, E.SWING, [1, 0, false, "CLEAN"]))["payload"][3] == "CLEAN", "swing event survives")
    _assert(not NetProtocol.decode_event(NetProtocol.encode_event(7, 77, E.MATCH_ENDED, [1, 11, 7])).is_empty() and not NetProtocol.decode_event(NetProtocol.encode_event(8, 77, E.RALLY_STARTED, [4, -1, false])).is_empty() and not NetProtocol.decode_event(NetProtocol.encode_event(9, 77, E.MATCH_ABORTED, ["left"])).is_empty(), "the other event types survive")
    _assert(NetProtocol.decode_event(NetProtocol.encode_event(10, 77, E.OPPONENT_AWAY, [20]))["payload"] == [20] and not NetProtocol.decode_event(NetProtocol.encode_event(11, 77, E.OPPONENT_BACK, [])).is_empty() and NetProtocol.decode_event([12, 77, int(E.OPPONENT_AWAY), "soon"]).is_empty(), "the opponent-away and opponent-back events survive, and a malformed one is refused")
    _assert(NetProtocol.decode_event([5, 77, int(E.RALLY_ENDED), 3, 1]).is_empty(), "an event with a short payload is refused")
    _assert(NetProtocol.decode_event([5, 77, int(E.SWING), 1, 0, false, 12]).is_empty(), "an event with a wrong payload type is refused")
    _assert(NetProtocol.decode_event([5, 77, 99]).is_empty() and NetProtocol.decode_event([5, 77]).is_empty() and NetProtocol.decode_event(null).is_empty(), "unknown or headerless events are refused")

    if errors.is_empty():
        print("PASS: %d net protocol checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
