extends SceneTree
## Run with: godot --headless --path . --script res://tests/integration/test_singles_match.gd
## The playable singles scene: input reaches the simulation, the court shows the simulation,
## and a whole match can be played to the end (RP-025).
## Headless: proves the flow, not how it looks or how the bot feels to play against.
const SCENE := preload("res://scenes/game/singles_match.tscn")
const DT: float = 1.0 / 60.0
const P := RallyState.Phase
var errors: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    _run()

func _run() -> void:
    var game: Node = SCENE.instantiate()
    game.points_to_win = 3
    game.win_by = 1
    root.add_child(game)
    await process_frame
    await process_frame
    var court: MatchCourt = game.court

    # The scene starts on a legal serve with everything shown where the simulation says.
    _assert(game.sim.referee.rally.phase == P.WAITING_FOR_SERVE and game.sim.referee.rally.server_side == 1, "match starts with the player to serve")
    _assert(court.home_player.position == game.sim.positions[1] and court.away_player.position == game.sim.positions[-1], "player models stand where the simulation says")
    _assert(court.ball_node.position == game.sim.ball.position, "ball model is where the simulation says")
    _assert(not court.home_player.is_physics_processing() and not court.ball_node.is_physics_processing(), "models do not move themselves in a match")
    _assert(court.score_label.text == "YOU 0  –  0 OPPONENT   |   You serve, right court", "score line shows 0-0 and who serves")
    _assert(court.camera.target == court.home_player and court.camera.side == 1, "camera follows the home player")

    # The player's own input: move, aim, click.
    Input.action_press(GameInput.MOVE_LEFT)
    var before: Vector3 = game.sim.positions[1]
    game._physics_process(DT)
    Input.action_release(GameInput.MOVE_LEFT)
    _assert(game.sim.positions[1].x < before.x and court.home_player.position == game.sim.positions[1], "pressing move-left moves the player through the simulation")
    court.target_position = Vector3(-1.5, 0.0, -4.6)
    game._physics_process(DT)
    _assert(court.aim_label.text.begins_with("AIM OK") and court.preview.drive_arc.shown_points.size() > 0, "aim hint and arc are shown for a legal serve")
    _assert(court.preview.marker_material.albedo_color == AimPreview.OK_COLOR, "aim ring shows OK")
    var click := InputEventAction.new()
    click.action = GameInput.SHOT_DRIVE
    click.pressed = true
    court._unhandled_input(click)
    game._physics_process(DT)
    _assert(game.sim.referee.rally.phase == P.SERVE_IN_FLIGHT and court.status_label.text.begins_with("DRIVE"), "clicking serves the ball and the status names the shot")
    game._physics_process(DT)
    _assert(game.sim.referee.rally.phase == P.SERVE_IN_FLIGHT and court.aim_label.text.contains("Your shot"), "one click is one swing")

    # The bot plays the rest of this rally against a player who stands still.
    var first: RallyState = game.sim.referee.rally
    _play(game, 3000, func() -> bool: return first.is_over())
    _assert(first.is_over() and (court.status_label.text.contains("wins the rally") or court.status_label.text.contains("win the rally")), "the rally ends with a result on the HUD")
    _assert(court.preview.landing_marker.visible, "the landing dot marked where the serve came down")

    # Let a bot play the home side too and finish the match.
    game.autoplay = true
    _play(game, 60 * 60 * 20, func() -> bool: return game.sim.is_over())
    var score: MatchScore = game.sim.score()
    print("singles scene match: %d ticks, final %d-%d" % [game.sim.tick, score.score_of(1), score.score_of(-1)])
    _assert(game.sim.is_over() and maxi(score.score_of(1), score.score_of(-1)) == 3, "a match to 3 is played to the end")
    _assert(court.status_label.text.begins_with("MATCH") and court.status_label.text.contains("%d – %d" % [score.score_of(1), score.score_of(-1)]), "the HUD announces the result and final score")
    _assert(court.score_label.text.begins_with("YOU %d  –  %d OPPONENT" % [score.score_of(1), score.score_of(-1)]), "the score line shows the final score")
    var frozen: Vector3 = game.sim.positions[-1]
    game._physics_process(DT)
    _assert(game.sim.positions[-1] == frozen, "nothing moves after the match")

    # Rematch.
    var old_sim: MatchSimulation = game.sim
    var again := InputEventAction.new()
    again.action = GameInput.RESET_BALL
    again.pressed = true
    court._unhandled_input(again)
    _assert(game.sim != old_sim and not game.sim.is_over() and game.sim.score().score_call() == "0-0" and game.matches_started == 2, "the rematch key starts a fresh match")
    court._unhandled_input(again)
    _assert(game.matches_started == 2, "the rematch key does nothing while a match is in progress")

    # A rendered frame runs without errors (preview, camera, HUD).
    game.autoplay = false
    await process_frame
    await physics_frame
    _assert(court.aim_label.text != "", "the aim hint is filled in on a normal frame")

    game.queue_free()
    if errors.is_empty():
        print("PASS: %d singles match checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

## Steps the game by hand, much faster than real time, until `done` or the tick limit.
func _play(game: Node, max_ticks: int, done: Callable) -> void:
    for i in range(max_ticks):
        if done.call():
            return
        game._physics_process(DT)

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
