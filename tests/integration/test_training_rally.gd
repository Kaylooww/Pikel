extends SceneTree
## Run with: godot --headless --path . --script res://tests/integration/test_training_rally.gd
## Plays real rallies in the training scene and checks the rules decide them (RP-021).
## Headless: proves the flow, not how it looks or feels.
const TRAINING := preload("res://scenes/game/training.tscn")
const P := RallyState.Phase
const F := RallyState.Fault
var errors: Array[String] = []
var checks: int = 0
var game: Node3D

func _initialize() -> void:
    _run()

func _run() -> void:
    game = TRAINING.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    # Rally 1: serve, opponent returns, player volleys the return -> two-bounce fault.
    _assert(game.referee.rally.phase == P.WAITING_FOR_SERVE, "practice starts waiting for the serve")
    game.target_position = Vector3(0.0, 0.0, -4.5)
    game._attempt_hit(false)
    _assert(game.referee.rally.phase == P.SERVE_IN_FLIGHT, "first hit is the serve")
    game._attempt_hit(false)
    _assert(game.referee.rally.phase == P.SERVE_IN_FLIGHT and game.player_hits == 1, "a second click on your own shot is ignored")
    # The opponent can swing in the same frame the serve bounces, so wait for the return itself.
    await _until(func() -> bool: return game.referee.rally.phase == P.RETURN_IN_FLIGHT)
    _assert(game.referee.rally.phase == P.RETURN_IN_FLIGHT and game.bot_hits == 1, "opponent returns the serve")
    _assert(game.referee.rally.log.size() == 3 and game.referee.rally.log[1].type == RallyEvent.Type.BOUNCE, "serve bounce is recorded before the return")
    await _until(func() -> bool: return game.ball.position.z > 1.0)
    game.player.position = Vector3(game.ball.position.x, 0.0, game.ball.position.z + 0.3)
    game._update_aim_preview()
    _assert(game.aim_label.text.begins_with("WAIT"), "aim label warns to let the return bounce")
    var first: RallyState = game.referee.rally
    game._attempt_hit(false)
    _assert(first.is_over() and first.fault == F.VOLLEY_BEFORE_BOUNCE and first.fault_side == 1, "volleying the return is a two-bounce fault on the player")
    _assert(game.status_label.text.contains("TWO-BOUNCE") and game.status_label.text.contains("opponent wins"), "status explains the fault")
    _assert(not game.ball.moving, "ball stops when the rally ends")

    # The next practice ball arrives by itself as a new rally.
    await _until(func() -> bool: return game.referee.rally != first)
    var second: RallyState = game.referee.rally
    _assert(second.rally_id == first.rally_id + 1 and second.phase == P.WAITING_FOR_SERVE and not game.resetting, "a new rally starts after the reset delay")

    # Rally 2: serve, return, let it bounce (open rally), then let it bounce again.
    game.player.position = Vector3(0.0, 0.0, 5.0)
    game._reset_ball()
    second = game.referee.rally
    await process_frame
    game.target_position = Vector3(0.0, 0.0, -4.5)
    game._attempt_hit(false)
    await _until(func() -> bool: return second.phase == P.RETURN_IN_FLIGHT)
    game.player.position = Vector3(-3.0, 0.0, 7.0) # step away so the return is not touched
    await _until(func() -> bool: return second.phase == P.OPEN_RALLY)
    _assert(second.phase == P.OPEN_RALLY and not second.is_over(), "return bouncing once opens the rally")
    await _until(func() -> bool: return second.is_over())
    _assert(second.fault == F.DOUBLE_BOUNCE and second.fault_side == 1 and second.winner_side == -1, "letting it bounce twice loses the rally")
    _assert(game.status_label.text.contains("DOUBLE BOUNCE"), "status names the double bounce")

    # Rally 3: an overhit serve lands beyond the baseline and is out, charged to the server.
    await _until(func() -> bool: return game.referee.rally != second)
    game.player.position = Vector3(0.0, 0.0, 5.0)
    game._reset_ball()
    var third: RallyState = game.referee.rally
    game.ball.launch(Vector3(-2.9, 0.0, -6.6), false)
    game.ball.ball_velocity.z *= 1.15 # overhit: lands beyond the baseline
    game.referee.hit(1, game.ball.position, game.player.position)
    await _until(func() -> bool: return third.is_over())
    _assert(third.fault == F.OUT and third.fault_side == 1, "a long serve is out on the server")
    _assert(third.log.size() == 2 and third.log[0].id < third.log[1].id, "the rally log holds the hit and the bounce in order")

    # Rally 4: serving from inside the court is a foot fault, and the preview warns first (RP-022).
    await _until(func() -> bool: return game.referee.rally != third)
    game._reset_ball()
    var fourth: RallyState = game.referee.rally
    _assert(game.player.position == game.SERVE_SPOT and CourtDimensions.legal_serve_position(game.player.position, true, true), "a new ball puts the player on a legal serve spot")
    game.player.position = Vector3(1.5, 0.0, 5.0)
    game.ball.reset_ball(game.player.position + Vector3(0.35, 1.0, -0.85))
    game.target_position = Vector3(-1.5, 0.0, -4.5)
    game._update_aim_preview()
    _assert(game.aim_label.text.begins_with("SERVE FAULT IF HIT") and game.aim_label.text.contains("baseline"), "preview warns about the serve position")
    game._attempt_hit(false)
    _assert(fourth.is_over() and fourth.fault == F.SERVE_POSITION and game.status_label.text.contains("FOOT FAULT"), "serving from inside the court is a foot fault")

    # Rally 5: a serve straight ahead lands in the wrong service court.
    await _until(func() -> bool: return game.referee.rally != fourth)
    game._reset_ball()
    var fifth: RallyState = game.referee.rally
    game.target_position = Vector3(1.5, 0.0, -4.5)
    game._update_aim_preview()
    _assert(game.aim_label.text.begins_with("SERVE FAULT IF HIT") and game.aim_label.text.contains("diagonal"), "preview warns about the service court")
    _assert(game.marker_material.albedo_color == game.AIM_BLOCKED, "marker shows the serve would be a fault")
    game._attempt_hit(false)
    _assert(fifth.phase == P.SERVE_IN_FLIGHT, "the serve is still hit")
    await _until(func() -> bool: return fifth.is_over())
    _assert(fifth.fault == F.SERVE_COURT and fifth.fault_side == 1 and game.status_label.text.contains("SERVICE FAULT"), "it is called a service fault when it lands")

    # Rally 6: a legal serve from the spot to the diagonal court shows no warning.
    await _until(func() -> bool: return game.referee.rally != fifth)
    game._reset_ball()
    game.target_position = Vector3(-1.5, 0.0, -4.5)
    game._update_aim_preview()
    _assert(game.aim_label.text.begins_with("AIM OK") and game.marker_material.albedo_color == game.AIM_OK, "a legal serve previews as OK")

    game.queue_free()
    if errors.is_empty():
        print("PASS: %d training rally checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

## Waits up to 10 seconds of physics frames for `done` to become true.
func _until(done: Callable) -> void:
    for i in range(600):
        if done.call():
            return
        await physics_frame

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
