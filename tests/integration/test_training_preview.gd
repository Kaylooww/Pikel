extends SceneTree
## Run with: godot --headless --path . --script res://tests/integration/test_training_preview.gd
## Boots the real training scene and checks the aim preview and landing feedback (RP-012).
## Headless: proves the logic runs, not that it looks right.
const TRAINING := preload("res://scenes/game/training.tscn")
var errors: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    _run()

func _run() -> void:
    var game: Node3D = TRAINING.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    # Fresh ball sits next to the player: both shot types should preview.
    _assert(game.hold_preview.multimesh.visible_instance_count > 0, "drive arc is shown when the ball is in reach")
    _assert(game.tap_preview.multimesh.visible_instance_count > 0, "dink arc is shown when the ball is in reach")
    _assert(game.aim_label.text.begins_with("AIM OK"), "aim label says OK")
    _assert(game.marker_material.albedo_color == game.AIM_OK, "marker uses the OK colour")
    var arc_end: Vector3 = game.hold_preview.shown_points[-1]
    _assert(Vector2(arc_end.x - game.target_position.x, arc_end.z - game.target_position.z).length() < 0.01, "arc ends on the aim marker")

    # Ball out of reach: no arc, idle marker.
    var spawn: Vector3 = game.ball.position
    game.ball.position = Vector3(0.0, 1.0, -3.0)
    await process_frame
    _assert(game.hold_preview.multimesh.visible_instance_count == 0, "no arc when the ball is out of reach")
    _assert(game.aim_label.text.contains("not in reach"), "aim label says not in reach")
    _assert(game.marker_material.albedo_color == game.AIM_IDLE, "marker uses the idle colour")

    # Ball low at the net: every shot is refused, and the preview says so before the click.
    game.player.position = Vector3(0.0, 0.0, 0.5)
    game.ball.position = Vector3(0.0, 0.12, 0.3)
    game.target_position = Vector3(0.0, 0.0, -6.5)
    game._update_aim_preview()
    _assert(game.aim_label.text.begins_with("AIM BLOCKED"), "aim label says blocked")
    _assert(game.marker_material.albedo_color == game.AIM_BLOCKED, "marker uses the blocked colour")
    _assert(game.hold_preview.multimesh.visible_instance_count == 0, "no arc for a refused shot")

    # Hit a real shot and wait for it to land: feedback reports the miss distance.
    game._reset_ball() # back on the serve spot with a fresh ball
    await process_frame
    var aimed: Vector3 = game.target_position
    game._attempt_hit(_drive(game))
    _assert(game.ball.moving and game.shot_target == aimed, "shot is launched at the aim point")
    for i in range(240):
        if game.landing_marker.visible:
            break
        await physics_frame
    _assert(game.landing_marker.visible, "landing marker appears at the bounce")
    _assert(Vector2(game.landing_marker.position.x - aimed.x, game.landing_marker.position.z - aimed.z).length() < 0.02, "ball landed on the previewed point")
    _assert(game.shot_label.text.contains("cm from your target"), "HUD reports the miss distance")

    # A late, stretched swing: the preview and the real shot both drift off the aim point (RP-015).
    game._reset_ball() # new rally, so this swing is a fresh serve
    game.landing_marker.visible = false
    game.ball.reset_ball(game.player.position + Vector3(1.2, 0.95, 0.8))
    game.ball.ball_velocity = Vector3(0.0, 0.0, 8.0) # flying past the player
    game.target_position = Vector3(-1.5, 0.0, -4.5)
    game._update_aim_preview()
    _assert(game.aim_label.text.contains("LATE"), "aim label shows late contact")
    var drift_end: Vector3 = game.hold_preview.shown_points[-1]
    _assert(drift_end.x > -1.5 + 0.3, "previewed arc drifts to the right of the marker")
    game._attempt_hit(_drive(game))
    _assert(game.status_label.text.contains("LATE"), "status names the contact quality")
    for i in range(240):
        if game.landing_marker.visible:
            break
        await physics_frame
    _assert(Vector2(game.landing_marker.position.x - drift_end.x, game.landing_marker.position.z - drift_end.z).length() < 0.02, "mishit lands where the preview showed")
    _assert(not game.shot_label.text.contains(" 0 cm"), "miss distance is no longer zero")

    game.queue_free()
    if errors.is_empty():
        print("PASS: %d training preview checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

## A drive with the right side picked for where the ball is, as the player would hit it.
func _drive(game: Node) -> SwingButtons.Request:
    var request := SwingButtons.Request.new()
    request.swing = PlayerInput.Swing.DRIVE
    request.power = 0.3
    var needed: SwingContact.Stroke = SwingContact.needed_stroke(game.player.position, game.ball.position, 1, game.tuning)
    request.stroke = needed if needed != SwingContact.Stroke.NONE else SwingContact.Stroke.FOREHAND
    return request

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
