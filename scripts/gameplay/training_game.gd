extends Node3D
## Playable training vertical slice, NOT a complete game or legal rules engine.
@onready var court: Node3D = $Court
@onready var player: PickleballPlayer = $HomePlayer
@onready var bot: PickleballPlayer = $PracticeOpponent
@onready var ball: PickleballBall = $Ball
@onready var camera: Camera3D = $Camera3D
var marker: MeshInstance3D
var status_label: Label
var score_label: Label
var player_hits: int = 0
var bot_hits: int = 0
var bot_should_return: bool = false
var resetting: bool = false
var target_position: Vector3 = Vector3(0, 0, -4.5)

func _ready() -> void:
    player.position = Vector3(0.0, 0.0, 5.0)
    bot.position = Vector3(0.0, 0.0, -5.2)
    bot.home_side = false
    bot.controlled_by_ai = true
    var bot_material := StandardMaterial3D.new()
    bot_material.albedo_color = Color("4dd4bd")
    bot.get_node("Body").material_override = bot_material
    var ball_material := StandardMaterial3D.new()
    ball_material.albedo_color = Color("ffe86b")
    ball.get_node("Visual").material_override = ball_material
    _reset_ball()
    ball.bounced.connect(_on_ball_bounced)
    ball.fault.connect(_on_ball_fault)
    marker = MeshInstance3D.new()
    var marker_mesh := CylinderMesh.new()
    marker_mesh.top_radius = 0.30
    marker_mesh.bottom_radius = 0.30
    marker_mesh.height = 0.015
    var marker_material := StandardMaterial3D.new()
    marker_material.albedo_color = Color(0.98, 0.85, 0.35, 0.55)
    marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker_mesh.material = marker_material
    marker.mesh = marker_mesh
    marker.position = Vector3(0, 0.10, -4.5)
    add_child(marker)
    _make_environment()
    _make_hud()
    _set_status("Aim on the OPPOSITE court; click while the ball is within reach.")

func _process(_delta: float) -> void:
    var origin: Vector3 = camera.project_ray_origin(get_viewport().get_mouse_position())
    var direction: Vector3 = camera.project_ray_normal(get_viewport().get_mouse_position())
    if absf(direction.y) > 0.001:
        var distance: float = (0.03 - origin.y) / direction.y
        if distance > 0.0:
            var world: Vector3 = origin + direction * distance
            target_position = Vector3(clampf(world.x, -CourtDimensions.HALF_WIDTH + 0.16, CourtDimensions.HALF_WIDTH - 0.16), 0.0, clampf(world.z, -CourtDimensions.HALF_LENGTH + 0.14, -0.20))
            marker.position = Vector3(target_position.x, 0.10, target_position.z)
    camera.position = Vector3(lerpf(camera.position.x, player.position.x * 0.35, 0.06), 9.2, 12.0)
    camera.look_at(Vector3(player.position.x * 0.16, 0.0, -0.15), Vector3.UP)
    if ball.moving and not resetting:
        var want: Vector3 = Vector3(clampf(ball.position.x, -2.9, 2.9), 0, -4.8)
        bot.ai_direction = (want - bot.position).normalized() if ball.position.z < 1.0 else (Vector3(0, 0, -5.1) - bot.position).normalized()
        if bot_should_return and ball.position.z < -0.2 and ball.position.distance_to(bot.position + Vector3.UP * 1.0) < 2.25:
            bot_should_return = false
            bot_hits += 1
            ball.launch(Vector3(clampf(player.position.x, -2.4, 2.4), 0.0, 4.55), false, -1)
            _update_score()
            _set_status("Opponent returned the ball. Wait for a bounce, then hit it!")
    else:
        bot.ai_direction = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_R:
            _reset_ball()
            _set_status("New practice ball ready.")
        elif event.keycode == KEY_ESCAPE:
            get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
    if event is InputEventMouseButton and event.pressed and not resetting:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _attempt_hit(false)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _attempt_hit(true)

func _attempt_hit(soft: bool) -> void:
    if not RulesEngine.is_cross_court_target(target_position, 1):
        _set_status("Aim at the opponent's side.")
        return
    if ball.position.z <= 0.0:
        _set_status("Ball is still on the other half.")
        return
    if ball.position.distance_to(player.position + Vector3.UP * 0.95) > 2.05:
        _set_status("Too far from ball — move closer.")
        return
    player_hits += 1
    ball.launch(target_position, soft, 1)
    _update_score()
    _set_status("DINK" if soft else "DRIVE")

func _on_ball_bounced(side: int, count: int, _contact: Vector3) -> void:
    if side == -1 and count == 1 and ball.last_hitter == 1:
        bot_should_return = true
        _set_status("Opponent preparing a return …")
    elif side == 1 and count == 1:
        _set_status("Bounce on your side — return it!")

func _on_ball_fault(reason: String) -> void:
    _set_status(reason)
    if resetting:
        return
    resetting = true
    bot_should_return = false
    await get_tree().create_timer(1.1).timeout
    if is_inside_tree():
        _reset_ball()

func _reset_ball() -> void:
    ball.reset_ball(player.position + Vector3(0.35, 1.00, -0.85))
    bot_should_return = false
    resetting = false

func _make_environment() -> void:
    var env := WorldEnvironment.new()
    var world := Environment.new()
    world.background_mode = Environment.BG_COLOR
    world.background_color = Color("bde8f1")
    world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    world.ambient_light_color = Color("ffffff")
    world.ambient_light_energy = 0.8
    env.environment = world
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55.0, -24.0, 0.0)
    sun.light_energy = 1.15
    add_child(sun)

func _make_hud() -> void:
    var hud := CanvasLayer.new()
    add_child(hud)
    var panel := PanelContainer.new()
    panel.position = Vector2(16, 12)
    panel.custom_minimum_size = Vector2(600, 92)
    hud.add_child(panel)
    var stack := VBoxContainer.new()
    panel.add_child(stack)
    score_label = Label.new()
    score_label.add_theme_font_size_override("font_size", 19)
    stack.add_child(score_label)
    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 16)
    stack.add_child(status_label)
    var help := Label.new()
    help.text = "WASD move | SHIFT sprint | Mouse aim | LEFT drive | RIGHT dink | R reset | ESC menu"
    stack.add_child(help)
    _update_score()

func _update_score() -> void:
    score_label.text = "PRACTICE • Your hits: %d   Opponent returns: %d   |   NOT OFFICIAL SCORING" % [player_hits, bot_hits]

func _set_status(message: String) -> void:
    if is_instance_valid(status_label):
        status_label.text = message
