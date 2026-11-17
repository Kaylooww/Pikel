extends SceneTree
## Run with: godot --headless --path . --script res://tests/integration/test_lan_match.gd
## A real match server and two real clients talking over UDP on localhost, in one process
## (each has its own multiplayer API). Two bots play a short match through the full network
## path; then a few unwelcome guests are sent away (RP-030 to RP-033), and a dropped player
## reconnects into the same match (RP-034).
## Needs UDP port 47811 free. Localhost has almost no latency or loss; see test_netcode.gd
## for those. Headless: says nothing about how the match looks.
const PORT: int = 47811
const SPEED: int = 8 ## the fixed simulation tick is run this many times faster than real time
const E := NetProtocol.EventType
var errors: Array[String] = []
var checks: int = 0
var tuning := GameplayTuning.new()
var events: Dictionary = {} ## client name -> Array of [type, payload]
var failures: Dictionary = {} ## client name -> reason
var notices: Dictionary = {} ## client name -> Array of connection notices

func _initialize() -> void:
    _run()

func _run() -> void:
    await process_frame
    Engine.physics_ticks_per_second = MatchSimulation.TICK_RATE * SPEED
    Engine.max_physics_steps_per_frame = 4 # keep network polling frequent relative to ticks

    var server_branch: Node = _branch("S")
    var server := MatchServer.new()
    server.tuning = tuning
    server.port = PORT
    server.points_to_win = 2
    server.win_by = 1
    server.link = server_branch.get_node("NetLink")
    server_branch.add_child(server)
    var listening: Error = server.listen()
    _assert(listening == OK, "server listens on UDP port %d (is something else using it?)" % PORT)
    if listening != OK:
        _finish()
        return

    var alice: MatchClient = _client("A")
    var bob: MatchClient = _client("B")
    await _until(func() -> bool: return alice.status == MatchClient.Status.PLAYING and bob.status == MatchClient.Status.PLAYING, 5.0)
    _assert(alice.status == MatchClient.Status.PLAYING and bob.status == MatchClient.Status.PLAYING, "both clients are welcomed into a match")
    _assert(alice.side == 1 and bob.side == -1, "first to join is home, second is away")
    _assert(alice.match_id == server.match_id and bob.match_id == server.match_id and server.match_id >= 1000, "everyone agrees on the match id")
    await _until(func() -> bool: return alice.latest != null and bob.latest != null, 5.0)
    _assert(alice.latest != null and bob.latest != null, "both clients receive snapshots")

    # Two bots play the match through the network.
    var bots: Dictionary = {alice: PracticeBot.new(1, tuning, 7), bob: PracticeBot.new(-1, tuning, 8)}
    var ticks_went_backwards: bool = false
    var last_tick: Dictionary = {alice: 0, bob: 0}
    var worst_view_gap: float = 0.0
    var limit: int = 60 * 60 * 15 # fifteen minutes of game time
    var played: int = 0
    while not (_got(alice, E.MATCH_ENDED) and _got(bob, E.MATCH_ENDED)) and played < limit and failures.is_empty():
        await physics_frame
        played += 1
        for client: MatchClient in [alice, bob]:
            client.tick()
            if client.can_play():
                client.send(bots[client].decide(client.view()))
            ticks_went_backwards = ticks_went_backwards or client.latest.tick < last_tick[client]
            last_tick[client] = client.latest.tick
        if server.sim != null and server.sim.rally_live() and server.sim.referee.rally.phase != RallyState.Phase.WAITING_FOR_SERVE:
            # While a rally is being played (not while players are being placed for a serve):
            # how far is what Bob sees of Alice from where the server has her right now?
            worst_view_gap = maxf(worst_view_gap, bob.shown_position(1).distance_to(server.sim.positions[1]))
    var score: MatchScore = server.sim.score() if server.sim != null else null
    _assert(failures.is_empty() and score != null and score.is_over(), "the match is played to the end over the network")
    if score == null or not score.is_over():
        _finish()
        return
    print("lan match: %d server ticks, final %d-%d, %d rallies; snapshots A=%d B=%d; prediction corrections A=%d/%d B=%d/%d; rejected inputs %d" % [
        server.sim.tick, score.score_of(1), score.score_of(-1), score.last_rally_id, alice.snapshots_received, bob.snapshots_received,
        alice.prediction.corrections, alice.prediction.reconciles, bob.prediction.corrections, bob.prediction.reconciles, server.rejected_inputs])

    # Everyone ended up with the same match.
    await _until(func() -> bool: return alice.latest.winner_side != 0 and bob.latest.winner_side != 0, 3.0)
    for client: MatchClient in [alice, bob]:
        var who: String = client.get_parent().name
        var final: Array = _last(client, E.MATCH_ENDED)
        _assert(final == [score.winner_side, score.score_of(1), score.score_of(-1)], "%s is told the server's result and final score" % who)
        _assert(client.latest.home_points == score.score_of(1) and client.latest.away_points == score.score_of(-1) and client.latest.winner_side == score.winner_side, "%s's last snapshot shows the same score" % who)
        _assert(_count(client, E.RALLY_ENDED) == score.last_rally_id and _count(client, E.RALLY_STARTED) == score.last_rally_id, "%s was told about every rally, once" % who)
        _assert(client.snapshots_received > 100, "%s received a steady stream of snapshots" % who)
        _assert(client.shown_position(client.side).distance_to(server.sim.positions[client.side]) < 0.05, "%s draws their own player where the server has them" % who)
        var own_hits: int = 0
        for entry: Array in events[who]:
            if entry[0] == E.SWING and entry[1][0] == client.side and entry[1][1] == MatchSimulation.SwingResult.HIT:
                own_hits += 1
        _assert(own_hits >= 1, "%s's hits were confirmed by the server" % who)
        # Corrections are expected once per rally (placed on the serve spot); honest movement should not add many.
        _assert(client.prediction.corrections <= score.last_rally_id * 3 + client.prediction.reconciles / 50, "%s's movement prediction was almost never corrected" % who)
    _assert(not ticks_went_backwards, "snapshot ticks never go backwards on a client")
    _assert(server.rejected_inputs == 0, "the server rejected nothing from two honest clients")
    # The opponent is drawn in the past on purpose. At this test's 8x speed that is up to about 20 ticks.
    print("lan match: opponent drawn at most %.2f m behind the server during rallies" % worst_view_gap)
    _assert(worst_view_gap < tuning.sprint_speed * 20.0 / MatchSimulation.TICK_RATE, "the opponent is never drawn further behind than 20 ticks of sprinting")
    var same_rallies: bool = true
    var a_ended: Array = _all(alice, E.RALLY_ENDED)
    var b_ended: Array = _all(bob, E.RALLY_ENDED)
    for i in range(mini(a_ended.size(), b_ended.size())):
        same_rallies = same_rallies and a_ended[i] == b_ended[i]
    _assert(same_rallies and a_ended.size() == b_ended.size(), "both clients received identical rally results in the same order")

    # A third player is turned away.
    var carol: MatchClient = _client("C")
    await _until(func() -> bool: return failures.has("C"), 5.0)
    _assert(failures.has("C") and str(failures.get("C")).contains("two players") and carol.side == 0 and server.seats.size() == 2, "a third client is told the server is full and gets no seat")

    # Junk from a seated client is counted and ignored; the server keeps running.
    var rejected: int = server.rejected_inputs
    var alice_link: NetLink = alice.get_parent().get_node("NetLink")
    alice_link.submit_input.rpc_id(1, ["not", "an", "input"])
    alice_link.submit_input.rpc_id(1, [alice.match_id + 5, 999999, Vector2(1, 0), true, 1, Vector2.ZERO])
    alice_link.hello.rpc_id(1, 12345, "")
    await _until(func() -> bool: return server.rejected_inputs >= rejected + 2, 3.0)
    _assert(server.rejected_inputs >= rejected + 2 and server.seats.size() == 2, "malformed and mis-addressed input over the wire is rejected, and a second hello changes nothing")

    # The rematch starts. Then Bob's connection dies in the middle of it. A dead link cannot be
    # produced on localhost, so the test closes Bob's socket under him (the server sees him go)
    # and tells his client what ENet would have told it after a few silent seconds.
    var rematch: int = server.match_id + (1 if server.sim.is_over() else 0)
    await _pump([alice, bob], func() -> bool: return alice.match_id == rematch and bob.match_id == rematch and alice.latest != null and bob.latest != null, 6.0)
    _assert(server.sim != null and not server.sim.is_over() and alice.match_id == rematch and bob.match_id == rematch, "the same two players are put into a rematch")
    var old_peer: int = server.seats.find_key(-1)
    bob.multiplayer.multiplayer_peer.close()
    bob._on_lost("test: the link died")
    # Hold Bob's retries until the server has noticed, so the kept-seat path is the one tested.
    await _until(func() -> bool: return not server._held.is_empty(), 8.0)
    _assert(server._held.has(-1) and server.sim != null, "the server notices the dead link and keeps the seat")
    await _pump([alice, bob], func() -> bool: return _got(alice, E.OPPONENT_BACK) and bob.status == MatchClient.Status.PLAYING and bob.latest != null, 8.0)
    _assert(bob.status == MatchClient.Status.PLAYING and bob.side == -1 and bob.match_id == rematch and server.match_id == rematch and server.seats.size() == 2 and server.seats.find_key(-1) != old_peer,
        "a dropped client reconnects on a new connection and gets its seat back in the same match")
    _assert(_got(alice, E.OPPONENT_AWAY) and _got(alice, E.OPPONENT_BACK) and not alice.paused and not failures.has("A") and not failures.has("B"), "the other player is told the opponent dropped and came back")
    _assert(notices["B"].size() == 2 and str(notices["B"][1]).begins_with("Reconnected"), "the dropped client reports losing the connection and getting it back")
    var bob_tick: int = bob.latest.tick
    await _pump([alice, bob], func() -> bool: return bob.latest.tick > bob_tick + 30, 3.0)
    _assert(bob.latest.tick > bob_tick + 30, "snapshots flow again after the reconnect")

    # A player who leaves for good: the other waits out the reconnect time, then goes back to waiting.
    bob.leave()
    await _until(func() -> bool: return _got(alice, E.MATCH_ABORTED), 8.0)
    _assert(_count(alice, E.OPPONENT_AWAY) == 2 and _got(alice, E.MATCH_ABORTED) and alice.status == MatchClient.Status.WAITING_FOR_MATCH and server.seats.size() == 1 and server.sim == null,
        "when a player leaves for good, the other is told, the seat is given up after the wait, and they go back to waiting")

    alice.leave()
    _finish()

func _finish() -> void:
    for child: Node in root.get_children():
        if child.name in ["S", "A", "B", "C"]:
            if child.multiplayer.multiplayer_peer != null:
                child.multiplayer.multiplayer_peer.close()
            child.queue_free()
    if errors.is_empty():
        print("PASS: %d lan match checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

## A subtree with its own multiplayer API, so a server and clients can share one process.
func _branch(branch_name: String) -> Node:
    var branch := Node.new()
    branch.name = branch_name
    root.add_child(branch)
    set_multiplayer(MultiplayerAPI.create_default_interface(), branch.get_path())
    var link := NetLink.new()
    link.name = "NetLink"
    branch.add_child(link)
    return branch

func _client(branch_name: String) -> MatchClient:
    var branch: Node = _branch(branch_name)
    var client := MatchClient.new()
    client.tuning = tuning
    client.link = branch.get_node("NetLink")
    branch.add_child(client)
    events[branch_name] = []
    client.event.connect(func(type: NetProtocol.EventType, payload: Array) -> void: events[branch_name].append([type, payload]))
    client.failed.connect(func(reason: String) -> void: failures[branch_name] = reason)
    notices[branch_name] = []
    client.notice.connect(func(text: String) -> void: notices[branch_name].append(text))
    var error: Error = client.join("127.0.0.1", PORT)
    if error != OK:
        failures[branch_name] = "join error %d" % error
    return client

func _all(client: MatchClient, type: NetProtocol.EventType) -> Array:
    var found: Array = []
    for entry: Array in events[client.get_parent().name]:
        if entry[0] == type:
            found.append(entry[1])
    return found

func _got(client: MatchClient, type: NetProtocol.EventType) -> bool:
    return not _all(client, type).is_empty()

func _count(client: MatchClient, type: NetProtocol.EventType) -> int:
    return _all(client, type).size()

func _last(client: MatchClient, type: NetProtocol.EventType) -> Array:
    var found: Array = _all(client, type)
    return found[-1] if not found.is_empty() else []

## Like _until, but keeps the clients ticking (a client makes its reconnect attempts in tick()).
func _pump(clients: Array, done: Callable, seconds: float) -> void:
    var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
    while not done.call() and Time.get_ticks_msec() < deadline:
        await physics_frame
        for client: MatchClient in clients:
            client.tick()

## Waits up to `seconds` of real time for `done`.
func _until(done: Callable, seconds: float) -> void:
    var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
    while not done.call() and Time.get_ticks_msec() < deadline:
        await process_frame

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
