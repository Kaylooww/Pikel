extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_netcode.gd
## Client prediction with reconciliation, and snapshot interpolation (RP-032).
## Latency, loss and jitter are simulated here in plain code; no sockets.
const DT: float = 1.0 / 60.0
var errors: Array[String] = []
var checks: int = 0
var tuning := GameplayTuning.new()

func _initialize() -> void:
    _test_prediction()
    _test_interpolation()
    if errors.is_empty():
        print("PASS: %d netcode checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

## A client and a pretend server. The server applies each input `latency` ticks after it was
## sent and reports back `latency` ticks later still. `lost` are sequence numbers that never arrive.
func _simulate(ticks: int, latency: int, lost: Array, teleport_at: int = -1) -> Dictionary:
    var start := Vector3(0.0, 0.0, 5.0)
    var server_position: Vector3 = start
    var acked: int = 0
    var client := ClientPrediction.new(1, tuning)
    client.reconcile(start, 0) # first snapshot
    var in_flight: Array = [] # [arrival_tick, input]
    var reports: Array = [] # [arrival_tick, position, ack]
    var worst_jump: float = 0.0
    var worst_correction: float = 0.0
    var previous_render: Vector3 = client.render_position()
    for tick in range(1, ticks + 1):
        # Client: zig-zag across the court, sprinting half the time.
        var move := Vector2(1.0 if (tick / 40) % 2 == 0 else -1.0, -0.4 if tick % 90 < 45 else 0.4)
        var input: PlayerInput = PlayerInput.make(move, tick % 60 < 30, PlayerInput.Swing.NONE, Vector3.ZERO, tick)
        client.apply_local(input)
        if not lost.has(tick):
            in_flight.append([tick + latency, input])
        # Server: apply what has arrived, in order.
        while not in_flight.is_empty() and in_flight[0][0] <= tick:
            var arrived: PlayerInput = in_flight.pop_front()[1]
            server_position = PlayerMotion.step(server_position, arrived.move, arrived.sprint, 1, tuning, DT)
            acked = arrived.seq
        if tick == teleport_at:
            server_position = Vector3(1.5, 0.0, 7.0) # e.g. placed on the serve spot
        reports.append([tick + latency, server_position, acked])
        # Client: snapshots that have arrived.
        while not reports.is_empty() and reports[0][0] <= tick:
            var report: Array = reports.pop_front()
            client.reconcile(report[1], report[2])
            worst_correction = maxf(worst_correction, client.last_correction)
        client.decay(DT)
        worst_jump = maxf(worst_jump, previous_render.distance_to(client.render_position()))
        previous_render = client.render_position()
    # Let everything in flight land, with the player standing still.
    for tick in range(ticks + 1, ticks + 1 + 2 * latency + 60):
        while not in_flight.is_empty() and in_flight[0][0] <= tick:
            var arrived: PlayerInput = in_flight.pop_front()[1]
            server_position = PlayerMotion.step(server_position, arrived.move, arrived.sprint, 1, tuning, DT)
            acked = arrived.seq
        reports.append([tick + latency, server_position, acked])
        while not reports.is_empty() and reports[0][0] <= tick:
            var report: Array = reports.pop_front()
            client.reconcile(report[1], report[2])
        client.decay(DT)
    return {"client": client, "server": server_position, "worst_jump": worst_jump, "worst_correction": worst_correction}

func _test_prediction() -> void:
    var step: float = tuning.sprint_speed * DT

    # No loss: the prediction is never wrong, at 0, 3 and 12 ticks of one-way latency (0, 100, 400 ms round trip).
    for latency: int in [0, 3, 12]:
        var clean: Dictionary = _simulate(600, latency, [])
        var c: ClientPrediction = clean["client"]
        _assert(c.corrections == 0 and clean["worst_correction"] < 0.001, "with %d ticks of latency and no loss the server never corrects the prediction" % latency)
        _assert(c.position.distance_to(clean["server"]) < 0.001 and c.pending_count() == 0, "client and server end in the same place (latency %d)" % latency)
        _assert(clean["worst_jump"] <= step + 0.001, "the drawn player never moves more than one step per tick (latency %d)" % latency)

    # Lost inputs: the client has moved where the server has not. It is corrected and converges.
    var lossy: Dictionary = _simulate(600, 6, [100, 101, 102, 250, 400, 401])
    var l: ClientPrediction = lossy["client"]
    _assert(l.corrections > 0 and lossy["worst_correction"] > 0.01, "lost inputs cause corrections")
    _assert(lossy["worst_correction"] < 4.0 * step, "each correction is about the size of the lost movement, not more")
    _assert(l.position.distance_to(lossy["server"]) < 0.001, "after loss the client still ends where the server is")
    _assert(lossy["worst_jump"] <= 2.0 * step, "small corrections are blended: no visible jump")
    _assert(l.render_position().distance_to(l.position) < 0.001, "the blend offset decays to nothing")

    # A teleport by the server (new rally) is too big to hide and is shown at once.
    var jumped: Dictionary = _simulate(300, 6, [], 200)
    var j: ClientPrediction = jumped["client"]
    _assert(jumped["worst_correction"] > ClientPrediction.SNAP_DISTANCE, "a serve-spot teleport is a large correction")
    _assert(j.position.distance_to(jumped["server"]) < 0.001, "the client follows the teleport")

    # Details.
    var fresh := ClientPrediction.new(-1, tuning)
    fresh.apply_local(PlayerInput.make(Vector2(1, 0), false, PlayerInput.Swing.NONE, Vector3.ZERO, 1))
    _assert(not fresh.has_state and fresh.pending_count() == 0 and fresh.position == Vector3.ZERO, "nothing is predicted before the first snapshot")
    fresh.reconcile(Vector3(0, 0, -5), 0)
    _assert(fresh.has_state and fresh.position == Vector3(0, 0, -5) and fresh.corrections == 0, "the first snapshot sets the position without counting as a correction")
    for seq in range(1, 400):
        fresh.apply_local(PlayerInput.make(Vector2.ZERO, false, PlayerInput.Swing.NONE, Vector3.ZERO, seq))
    _assert(fresh.pending_count() == ClientPrediction.MAX_PENDING, "the unacknowledged input list is capped")
    fresh.reconcile(Vector3(0, 0, -5), 399)
    _assert(fresh.pending_count() == 0, "an acknowledgement clears everything up to it")

func _test_interpolation() -> void:
    var interp := SnapshotInterpolator.new()
    _assert(interp.sample().is_empty() and interp.newest_tick() == -1, "nothing to draw before the first snapshot")
    _assert(interp.push(_snap(10, 0.0)) and interp.push(_snap(12, 2.0)) and interp.push(_snap(14, 4.0)), "newer snapshots are accepted")
    _assert(not interp.push(_snap(12, 99.0)) and not interp.push(_snap(14, 99.0)) and interp.newest_tick() == 14, "a repeated or out-of-order snapshot is ignored")
    _assert(is_equal_approx(interp.sample_at(11.0)["home"].x, 1.0) and is_equal_approx(interp.sample_at(13.5)["ball"].x, 3.5), "positions are blended between the two surrounding snapshots")
    _assert(is_equal_approx(interp.sample_at(12.0)["away"].x, -2.0), "exactly on a snapshot gives that snapshot")
    _assert(is_equal_approx(interp.sample_at(3.0)["home"].x, 0.0) and is_equal_approx(interp.sample_at(99.0)["home"].x, 4.0), "outside the buffer it holds the nearest snapshot and never guesses ahead")
    _assert(is_equal_approx(interp.render_tick, 10.0 - SnapshotInterpolator.DELAY_TICKS), "the render clock starts a fixed delay behind")

    # Steady stream: one snapshot every 2 ticks. The render clock stays DELAY_TICKS behind and motion is smooth.
    interp = SnapshotInterpolator.new()
    var worst_step: float = 0.0
    var last_x: float = 0.0
    for tick in range(0, 240):
        if tick % 2 == 0:
            interp.push(_snap(tick, tick * 0.1))
        interp.advance()
        var x: float = interp.sample()["home"].x
        if tick > 30:
            worst_step = maxf(worst_step, absf(x - last_x))
        last_x = x
    _assert(absf(interp.render_tick - (interp.newest_tick() - SnapshotInterpolator.DELAY_TICKS)) < 1.5, "the render clock tracks the newest snapshot minus the delay")
    _assert(worst_step < 0.15 and worst_step > 0.05, "a steadily moving opponent is drawn moving steadily (0.1 per tick)")

    # Lossy, bursty stream: every third snapshot lost, the rest arriving in pairs. Still no big jumps.
    interp = SnapshotInterpolator.new()
    worst_step = 0.0
    var held: Array = []
    for tick in range(0, 240):
        if tick % 2 == 0 and (tick / 2) % 3 != 0:
            held.append(_snap(tick, tick * 0.1))
        if held.size() >= 2:
            for snapshot: NetSnapshot in held:
                interp.push(snapshot)
            held.clear()
        interp.advance()
        var x: float = interp.sample().get("home", Vector3.ZERO).x
        if tick > 30:
            worst_step = maxf(worst_step, absf(x - last_x))
        last_x = x
    _assert(worst_step < 0.3, "with a third of snapshots lost and the rest bunched, motion stays within three ticks' worth per tick")

    # A long silence, then the stream resumes far ahead: the clock jumps instead of crawling.
    interp.push(_snap(1000, 100.0))
    interp.advance()
    _assert(absf(interp.render_tick - (1000 - SnapshotInterpolator.DELAY_TICKS)) < 1.5, "after a long gap the render clock resynchronises at once")
    interp.clear()
    _assert(interp.sample().is_empty(), "clear empties the buffer")

func _snap(tick: int, x: float) -> NetSnapshot:
    var snapshot := NetSnapshot.new()
    snapshot.tick = tick
    snapshot.home_position = Vector3(x, 0, 5)
    snapshot.away_position = Vector3(-x, 0, -5)
    snapshot.ball_position = Vector3(x, 1, 0)
    return snapshot

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
