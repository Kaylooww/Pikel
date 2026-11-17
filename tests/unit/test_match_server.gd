extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_match_server.gd
## The match server's rules about who may do what, driven directly with no sockets:
## seats, ownership, input validation, the speed limit, events and match ids (RP-030, RP-031, RP-033),
## kept seats, seat tickets and the serve clock (RP-034).
const E := NetProtocol.EventType
const DRIVE := PlayerInput.Swing.DRIVE
const ALICE: int = 1001 # peer ids
const BOB: int = 1002
const CAROL: int = 1003
const DAVE: int = 1004
var errors: Array[String] = []
var checks: int = 0
var tuning := GameplayTuning.new()

func _initialize() -> void:
    var server: MatchServer = _server()

    # Joining.
    server.on_peer_connected(ALICE)
    server.on_hello(ALICE, NetProtocol.VERSION)
    _assert(server.seats == {ALICE: 1} and server.sim == null, "the first player takes the home seat and waits")
    server.on_input(ALICE, NetProtocol.encode_input(0, PlayerInput.make(Vector2(1, 0), false, PlayerInput.Swing.NONE, Vector3.ZERO, 1)))
    _assert(server.rejected_inputs == 1, "input before a match exists is rejected")
    server.on_hello(BOB, NetProtocol.VERSION + 1)
    _assert(not server.seats.has(BOB) and server.sim == null, "a client with another protocol version is not seated")
    server.on_hello(BOB, NetProtocol.VERSION)
    _assert(server.seats == {ALICE: 1, BOB: -1} and server.sim != null and server.match_id >= 1000, "the second player takes the away seat and the match starts with an id")
    server.on_hello(CAROL, NetProtocol.VERSION)
    _assert(not server.seats.has(CAROL), "a third player is turned away")
    server.on_hello(ALICE, NetProtocol.VERSION)
    _assert(server.seats[ALICE] == 1, "saying hello twice changes nothing")
    _assert(_event_types(server) == [E.RALLY_STARTED], "the first rally is announced")
    var id: int = server.match_id
    var sim: MatchSimulation = server.sim

    # Ownership: the side comes from who sent the input.
    var rejected: int = server.rejected_inputs
    var home_start: Vector3 = sim.positions[1]
    var away_start: Vector3 = sim.positions[-1]
    server.on_input(BOB, NetProtocol.encode_input(id, PlayerInput.make(Vector2(1, 0), true, PlayerInput.Swing.NONE, Vector3.ZERO, 1)))
    server.tick()
    _assert(sim.positions[1] == home_start and sim.positions[-1] != away_start, "Bob's input moves Bob's player, never Alice's")
    server.on_input(CAROL, NetProtocol.encode_input(id, PlayerInput.make(Vector2(1, 0), true, PlayerInput.Swing.NONE, Vector3.ZERO, 1)))
    server.tick()
    _assert(server.rejected_inputs == rejected + 1 and sim.positions[1] == home_start, "input from someone without a seat is rejected")

    # Validation.
    rejected = server.rejected_inputs
    server.on_input(ALICE, "garbage")
    server.on_input(ALICE, [id, 1, Vector2(NAN, 0), false, 0, Vector2.ZERO])
    server.on_input(ALICE, NetProtocol.encode_input(id + 1, PlayerInput.make(Vector2(1, 0), false, PlayerInput.Swing.NONE, Vector3.ZERO, 1)))
    _assert(server.rejected_inputs == rejected + 3, "malformed input and input for another match are rejected")
    server.on_input(ALICE, NetProtocol.encode_input(id, PlayerInput.make(Vector2(-1, 0), false, PlayerInput.Swing.NONE, Vector3.ZERO, 5)))
    server.on_input(ALICE, NetProtocol.encode_input(id, PlayerInput.make(Vector2(-1, 0), false, PlayerInput.Swing.NONE, Vector3.ZERO, 5)))
    server.on_input(ALICE, NetProtocol.encode_input(id, PlayerInput.make(Vector2(-1, 0), false, PlayerInput.Swing.NONE, Vector3.ZERO, 4)))
    _assert(server.rejected_inputs == rejected + 5, "a repeated or older sequence number is rejected")
    server.on_input(ALICE, NetProtocol.encode_input(id, PlayerInput.make(Vector2(-1, 0), false, PlayerInput.Swing.NONE, Vector3.ZERO, 5 + NetProtocol.MAX_SEQ_JUMP + 1)))
    _assert(server.rejected_inputs == rejected + 6, "a sequence number absurdly far ahead is rejected")
    server.tick()
    _assert(is_equal_approx(home_start.x - sim.positions[1].x, tuning.move_speed * MatchSimulation.DT), "exactly one of those inputs was applied")

    # Honest client: one input per tick. The server acknowledges each and agrees with the client's prediction exactly.
    var prediction := ClientPrediction.new(1, tuning)
    prediction.reconcile(sim.positions[1], 5)
    var seq: int = 5
    var agreed: bool = true
    for i in range(120):
        seq += 1
        var input: PlayerInput = PlayerInput.make(Vector2(-0.7 if i < 60 else 0.9, -0.3), i % 2 == 0, PlayerInput.Swing.NONE, Vector3.ZERO, seq)
        prediction.apply_local(input)
        server.on_input(ALICE, NetProtocol.encode_input(id, input))
        server.tick()
        var snapshot: NetSnapshot = NetProtocol.decode_snapshot(NetProtocol.encode_snapshot(sim, id, server._acked[1]))
        prediction.reconcile(snapshot.home_position, snapshot.ack_seq)
        agreed = agreed and snapshot.ack_seq == seq
    _assert(agreed and prediction.corrections == 0 and prediction.position == sim.positions[1], "an honest client's prediction matches the server on every tick")

    # Speed hack: ten inputs per tick for a second. The server applies about one per tick.
    var from: Vector3 = sim.positions[-1]
    var bob_seq: int = 1
    for i in range(60):
        for burst in range(10):
            bob_seq += 1
            server.on_input(BOB, NetProtocol.encode_input(id, PlayerInput.make(Vector2(-1, 0), true, PlayerInput.Swing.NONE, Vector3.ZERO, bob_seq)))
        server.tick()
    var allowed: float = (60.0 + MatchServer.MAX_BURST + MatchServer.MAX_QUEUE) * tuning.sprint_speed * MatchSimulation.DT
    _assert(from.distance_to(sim.positions[-1]) <= minf(allowed, 2.0 * tuning.max_side_distance), "sending ten times too many inputs does not make a player faster")
    _assert(server.dropped_inputs > 400, "the flood is dropped, not saved up")

    # After a quiet spell a short burst is allowed (jitter catch-up), but no more than MAX_BURST at once.
    for i in range(30):
        server.tick()
    from = sim.positions[-1]
    for burst in range(8):
        bob_seq += 1
        server.on_input(BOB, NetProtocol.encode_input(id, PlayerInput.make(Vector2(1, 0), false, PlayerInput.Swing.NONE, Vector3.ZERO, bob_seq)))
    server.tick()
    _assert(is_equal_approx(from.distance_to(sim.positions[-1]), MatchServer.MAX_BURST * tuning.move_speed * MatchSimulation.DT), "a late burst is caught up by at most four inputs in one tick")

    # Authoritative hits: a swing is only a request.
    var fresh: MatchServer = _server()
    fresh.on_hello(ALICE, NetProtocol.VERSION)
    fresh.on_hello(BOB, NetProtocol.VERSION)
    id = fresh.match_id
    sim = fresh.sim
    fresh.on_input(BOB, NetProtocol.encode_input(id, PlayerInput.make(Vector2.ZERO, false, DRIVE, Vector3(1.5, 0, 4.6), 1)))
    fresh.tick()
    _assert(not sim.ball.moving and sim.referee.rally.phase == RallyState.Phase.WAITING_FOR_SERVE, "the receiver cannot hit the server's ball by asking to")
    fresh.on_input(ALICE, NetProtocol.encode_input(id, PlayerInput.make(Vector2.ZERO, false, DRIVE, Vector3(-1.5, 0, -4.6), 1)))
    fresh.tick()
    _assert(sim.ball.moving and sim.referee.rally.phase == RallyState.Phase.SERVE_IN_FLIGHT, "the server's swing is judged by the server and connects")
    var swing: Array = fresh.events_sent[-1]
    _assert(swing[2] == E.SWING and swing.slice(3) == [1, int(MatchSimulation.SwingResult.HIT), false, "CLEAN"], "the hit is announced with who, the result and the contact quality")
    for i in range(20):
        fresh.on_input(BOB, NetProtocol.encode_input(id, PlayerInput.make(Vector2.ZERO, false, DRIVE, Vector3(1.5, 0, 4.6), 2 + i)))
        fresh.tick()
    var refusals: int = 0
    for sent: Array in fresh.events_sent:
        if sent[2] == E.SWING and sent[3] == -1:
            refusals += 1
    _assert(refusals >= 1 and refusals <= 2, "twenty refused swings in twenty ticks produce one or two messages, not twenty")
    for i in range(600):
        fresh.tick()
        if sim.referee.rally.rally_id == 2:
            break
    var types: Array = _event_types(fresh)
    _assert(types.has(E.RALLY_ENDED) and types.count(E.RALLY_STARTED) == 2, "the rally result and the next rally are announced")
    var ended: Array = []
    var ids: Array = []
    for sent: Array in fresh.events_sent:
        ids.append(sent[0])
        if sent[2] == E.RALLY_ENDED:
            ended = sent.slice(3)
    _assert(ended == [1, int(RallyState.Fault.DOUBLE_BOUNCE), -1, 1, true, 1, 0], "the fault, who committed it, the winner and the new score come from the server")
    var increasing: bool = true
    for i in range(1, ids.size()):
        increasing = increasing and ids[i] > ids[i - 1]
    _assert(increasing, "event ids only ever increase")

    # A player dropping mid-match: the seat is kept and the match stands still.
    var bob_ticket: String = fresh._tokens[-1]
    var frozen_tick: int = sim.tick
    fresh.on_peer_disconnected(BOB)
    _assert(fresh.sim == sim and fresh.seats == {ALICE: 1} and fresh.events_sent[-1].slice(2) == [int(E.OPPONENT_AWAY), MatchServer.RECONNECT_SECONDS], "a player dropping mid-match keeps the match, and the other is told how long it will wait")
    for i in range(100):
        fresh.tick()
    _assert(sim.tick == frozen_tick, "the match stands still while a seat is being kept")
    fresh.on_hello(CAROL, NetProtocol.VERSION)
    fresh.on_hello(CAROL, NetProtocol.VERSION, "not-the-ticket")
    _assert(not fresh.seats.has(CAROL), "nobody else can take a kept seat, with no ticket or with a wrong one")
    fresh.on_hello(DAVE, NetProtocol.VERSION, bob_ticket)
    _assert(fresh.seats == {ALICE: 1, DAVE: -1} and fresh.match_id == id and fresh.events_sent[-1][2] == E.OPPONENT_BACK, "the dropped player's new connection gets the seat back with its ticket, in the same match")
    fresh.tick()
    _assert(sim.tick == frozen_tick + 1, "play goes on once they are back")
    # A client can notice a dead link before the server does: the ticket also replaces a connection the server still believes in.
    fresh.on_hello(BOB, NetProtocol.VERSION, bob_ticket)
    _assert(fresh.seats == {ALICE: 1, BOB: -1} and fresh.sim == sim and fresh._held.is_empty(), "a ticket replaces that player's stale connection without pausing")
    fresh.on_peer_disconnected(DAVE)
    _assert(fresh.seats == {ALICE: 1, BOB: -1} and fresh._held.is_empty(), "the stale connection closing afterwards changes nothing")

    # Nobody comes back: the match is aborted, and the next pair gets a new match id.
    fresh.on_peer_disconnected(BOB)
    for i in range(MatchServer.RECONNECT_TICKS + 1):
        fresh.tick()
    _assert(fresh.sim == null and fresh.seats == {ALICE: 1} and fresh.events_sent[-1][2] == E.MATCH_ABORTED, "when the time is up the match is aborted and the other player is told")
    fresh.on_hello(DAVE, NetProtocol.VERSION, bob_ticket)
    _assert(fresh.sim != null and fresh.seats[DAVE] == -1 and fresh.match_id == id + 1 and fresh._tokens[-1] != bob_ticket, "an expired ticket is just a new player: new match, new id, new ticket")
    rejected = fresh.rejected_inputs
    fresh.on_input(ALICE, NetProtocol.encode_input(id, PlayerInput.make(Vector2(1, 0), false, PlayerInput.Swing.NONE, Vector3.ZERO, 50)))
    _assert(fresh.rejected_inputs == rejected + 1, "input still addressed to the old match is rejected")

    # Bot fill, a whole match, and the automatic rematch.
    var solo: MatchServer = _server()
    solo.fill_with_bot = true
    solo.points_to_win = 2
    solo.win_by = 1
    solo.on_hello(ALICE, NetProtocol.VERSION)
    _assert(solo.sim != null and solo.bot_side == -1 and solo.seats == {ALICE: 1}, "with bot fill one player is enough to start")
    solo.on_hello(BOB, NetProtocol.VERSION)
    _assert(not solo.seats.has(BOB), "the bot's seat is taken")
    var finished: Array[MatchScore] = []
    solo.match_finished.connect(func(score: MatchScore) -> void: finished.append(score))
    var human_bot := PracticeBot.new(1, tuning, 3)
    var solo_seq: int = 0
    var first_id: int = solo.match_id
    while finished.is_empty() and solo.sim.tick < 60 * 60 * 20:
        solo_seq += 1
        var decided: PlayerInput = human_bot.decide(MatchView.from_simulation(solo.sim, 1))
        decided.seq = solo_seq
        solo.on_input(ALICE, NetProtocol.encode_input(first_id, decided))
        solo.tick()
    _assert(finished.size() == 1 and solo.sim.is_over(), "a full match against the server's bot is played through the network input path")
    _assert(solo.events_sent[-1][2] == E.MATCH_ENDED and solo.events_sent[-1].slice(3) == [finished[0].winner_side, finished[0].score_of(1), finished[0].score_of(-1)], "the match result is announced")
    for i in range(MatchServer.REMATCH_DELAY_TICKS + 2):
        solo.tick()
    _assert(solo.sim != null and not solo.sim.is_over() and solo.match_id == first_id + 1 and solo.sim.tick < 5, "ten seconds later a rematch starts with a new match id")

    # Private match code (RP-035).
    var private: MatchServer = _server()
    private.match_code = "K7QX2M"
    private.on_hello(ALICE, NetProtocol.VERSION, "", "WRONG1")
    private.on_hello(BOB, NetProtocol.VERSION)
    _assert(private.seats.is_empty(), "without the match code, or with a wrong one, nobody is seated")
    private.on_hello(ALICE, NetProtocol.VERSION, "", "K7QX2M")
    _assert(private.seats == {ALICE: 1}, "the right code gets a seat")
    var reticket: String = private._tokens[1]
    private.on_hello(CAROL, NetProtocol.VERSION, reticket, "WRONG1")
    _assert(private.seats == {ALICE: 1}, "even a valid seat ticket needs the match code")
    private.free()

    # Serve clock: an idle server cannot stall the match.
    var idle: MatchServer = _server()
    idle.on_hello(ALICE, NetProtocol.VERSION)
    idle.on_hello(BOB, NetProtocol.VERSION)
    for i in range(MatchServer.SERVE_CLOCK_TICKS):
        idle.tick()
    _assert(idle.events_sent[-1][2] == E.RALLY_ENDED and idle.events_sent[-1].slice(4, 7) == [int(RallyState.Fault.SERVE_CLOCK), 1, -1], "a server who does not serve in 15 seconds loses the rally")

    for node: MatchServer in [server, fresh, solo, idle]:
        node.free()
    if errors.is_empty():
        print("PASS: %d match server checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

func _server() -> MatchServer:
    var server := MatchServer.new()
    server.tuning = tuning
    return server

func _event_types(server: MatchServer) -> Array:
    var types: Array = []
    for sent: Array in server.events_sent:
        types.append(sent[2])
    return types

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
