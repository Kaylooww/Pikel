extends Node3D
## Playable training vertical slice, NOT a complete game or legal rules engine.
@export var tuning: GameplayTuning = preload("res://config/gameplay_tuning.tres")
@onready var court: Node3D = $Court
@onready var player: PickleballPlayer = $HomePlayer
@onready var bot: PickleballPlayer = $PracticeOpponent
@onready var ball: PickleballBall = $Ball
@onready var camera: CourtCamera = $Camera3D
const AIM_OK := Color(0.33, 0.84, 0.80, 0.70)
const AIM_BLOCKED := Color(1.0, 0.51, 0.42, 0.70)
const AIM_IDLE := Color(0.75, 0.78, 0.80, 0.40)
var marker: MeshInstance3D
var marker_material: StandardMaterial3D
var landing_marker: MeshInstance3D
var drive_preview: TrajectoryPreview
var dink_preview: TrajectoryPreview
var aim_label: Label
var shot_label: Label
var shot_target: Vector3 = Vector3.ZERO ## where the player's last shot was aimed
var awaiting_landing: bool = false ## the player's shot is in the air and has not landed yet
var referee := RallyController.new()
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
    camera.target = player
    camera.snap()
    ball.bounced.connect(_on_ball_bounced)
    ball.net_hit.connect(_on_ball_net_hit)
    referee.rally_ended.connect(_on_rally_ended)
    _reset_ball()
    marker = MeshInstance3D.new()
    var marker_mesh := CylinderMesh.new()
    marker_mesh.top_radius = 0.30
    marker_mesh.bottom_radius = 0.30
    marker_mesh.height = 0.015
    marker_material = StandardMaterial3D.new()
    marker_material.albedo_color = Color(0.98, 0.85, 0.35, 0.55)
    marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker_mesh.material = marker_material
    marker.mesh = marker_mesh
    marker.position = Vector3(0, 0.10, -4.5)
    add_child(marker)
    landing_marker = MeshInstance3D.new()
    var landing_mesh := CylinderMesh.new()
    landing_mesh.top_radius = 0.12
    landing_mesh.bottom_radius = 0.12
    landing_mesh.height = 0.02
    var landing_material := StandardMaterial3D.new()
    landing_material.albedo_color = Color("ff816c")
    landing_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    landing_mesh.material = landing_material
    landing_marker.mesh = landing_mesh
    landing_marker.visible = false
    add_child(landing_marker)
    drive_preview = TrajectoryPreview.new()
    drive_preview.set_color(Color("ffe06b"))
    add_child(drive_preview)
    dink_preview = TrajectoryPreview.new()
    dink_preview.set_color(Color("55d5cb"))
    add_child(dink_preview)
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
    _update_aim_preview()
    if ball.moving and not resetting:
        var want: Vector3 = Vector3(clampf(ball.position.x, -2.9, 2.9), 0, -4.8)
        bot.ai_direction = (want - bot.position).normalized() if ball.position.z < 1.0 else (Vector3(0, 0, -5.1) - bot.position).normalized()
        if bot_should_return and ball.position.z < -0.2 and ball.position.distance_to(bot.position + Vector3.UP * tuning.bot_contact_height) < tuning.bot_reach:
            bot_should_return = false
            if ball.launch(Vector3(clampf(player.position.x, -2.4, 2.4), 0.0, 4.55), false).ok:
                referee.hit(-1, ball.position)
                bot_hits += 1
                _update_score()
                _set_status("Opponent returned the ball. Wait for a bounce, then hit it!")
    else:
        bot.ai_direction = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(GameInput.RESET_BALL):
        _reset_ball()
        _set_status("New practice ball ready.")
    elif event.is_action_pressed(GameInput.CAMERA_NEXT):
        camera.next_rig()
        _set_status("Camera view changed.")
    elif event.is_action_pressed(GameInput.MENU_BACK):
        get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
    elif not resetting:
        if event.is_action_pressed(GameInput.SHOT_DRIVE):
            _attempt_hit(false)
        elif event.is_action_pressed(GameInput.SHOT_DINK):
            _attempt_hit(true)

## Shows what a click would do right now: the arc of each shot type that the solver accepts,
## and a marker colour plus text for accepted / refused / out of reach.
func _update_aim_preview() -> void:
    if resetting or not _ball_in_reach():
        drive_preview.show_points(PackedVector3Array())
        dink_preview.show_points(PackedVector3Array())
        marker_material.albedo_color = AIM_IDLE
        aim_label.text = "AIM  —  ball not in reach"
        return
    if _must_bounce_first():
        drive_preview.show_points(PackedVector3Array())
        dink_preview.show_points(PackedVector3Array())
        marker_material.albedo_color = AIM_BLOCKED
        aim_label.text = "WAIT  —  let the return bounce first (two-bounce rule)"
        return
    # The arcs use the real target, so a mistimed or stretched swing visibly drifts off the marker.
    var contact: SwingContact.Contact = _contact()
    var real_target: Vector3 = contact.apply(target_position)
    var drive_ok: bool = _preview_shot(drive_preview, real_target, false)
    var dink_ok: bool = _preview_shot(dink_preview, real_target, true)
    marker_material.albedo_color = AIM_OK if (drive_ok or dink_ok) else AIM_BLOCKED
    if drive_ok and dink_ok:
        aim_label.text = "AIM OK  —  contact: %s  —  yellow dots: drive   aqua dots: dink" % contact.label()
    elif drive_ok or dink_ok:
        aim_label.text = "AIM OK  —  contact: %s  —  only the %s clears the net from here" % [contact.label(), "drive" if drive_ok else "dink"]
    else:
        aim_label.text = "AIM BLOCKED  —  contact: %s  —  no shot lands in from here" % contact.label()

func _preview_shot(view: TrajectoryPreview, real_target: Vector3, soft: bool) -> bool:
    var shot: ShotSolver.Solution = ShotSolver.solve(ball.position, real_target, soft, tuning)
    view.show_points(ShotSolver.sample_arc(ball.position, shot, tuning.gravity))
    return shot.ok

## Reach and timing of a swing made right now.
func _contact() -> SwingContact.Contact:
    return SwingContact.evaluate(player.position, ball.position, ball.ball_velocity, 1, tuning)

## True while the opponent's return is in the air and the rules require it to bounce.
func _must_bounce_first() -> bool:
    return referee.rally.phase == RallyState.Phase.RETURN_IN_FLIGHT and referee.rally.last_hitter == -1

func _ball_in_reach() -> bool:
    return ball.position.z > 0.0 and _contact().in_reach

func _attempt_hit(soft: bool) -> void:
    if not RulesEngine.is_cross_court_target(target_position, 1):
        _set_status("Aim at the opponent's side.")
        return
    if ball.position.z <= 0.0:
        _set_status("Ball is still on the other half.")
        return
    if referee.rally.last_hitter == 1:
        return # your own shot is still in play; a second click must not count as a second hit
    var contact: SwingContact.Contact = _contact()
    if not contact.in_reach:
        _set_status("Too far from ball — move closer.")
        return
    var shot: ShotSolver.Solution = ball.launch(contact.apply(target_position), soft)
    if not shot.ok:
        _set_status("%s (contact: %s)" % [_refusal_text(shot.reason), contact.label()])
        return
    awaiting_landing = true
    shot_target = target_position
    landing_marker.visible = false
    player_hits += 1
    _update_score()
    _set_status("%s  —  %s" % ["DINK" if soft else "DRIVE", contact.label()])
    referee.hit(1, ball.position) # may end the rally at once, e.g. volleying the return

func _refusal_text(reason: ShotSolver.Reason) -> String:
    match reason:
        ShotSolver.Reason.NET: return "Can't clear the net from here — get under the ball or aim shorter."
        ShotSolver.Reason.TOO_FAST: return "Too far for that shot."
        _: return "That swing would send the ball out."

func _on_ball_bounced(contact: Vector3) -> void:
    if awaiting_landing:
        awaiting_landing = false
        landing_marker.position = Vector3(contact.x, 0.11, contact.z)
        landing_marker.visible = true
        var miss_cm: float = Vector2(contact.x - shot_target.x, contact.z - shot_target.z).length() * 100.0
        # Own label: the status line is overwritten as soon as the opponent swings.
        shot_label.text = "LAST SHOT  —  landed %d cm from your target (coral dot)" % roundi(miss_cm)
    referee.bounce(contact)
    if referee.rally.is_over():
        return
    if referee.rally.last_hitter == 1:
        bot_should_return = true
        _set_status("Opponent preparing a return …")
    else:
        _set_status("Bounce on your side — return it!")

func _on_ball_net_hit(contact: Vector3) -> void:
    awaiting_landing = false
    referee.net(contact)

## The rules ended the rally: show why, then set up the next practice ball.
func _on_rally_ended(rally: RallyState) -> void:
    ball.stop()
    bot_should_return = false
    _set_status(_fault_text(rally))
    if resetting:
        return
    resetting = true
    await get_tree().create_timer(tuning.fault_reset_delay).timeout
    if is_inside_tree():
        _reset_ball()

func _fault_text(rally: RallyState) -> String:
    var what: String
    match rally.fault:
        RallyState.Fault.NET: what = "NET"
        RallyState.Fault.OUT: what = "OUT"
        RallyState.Fault.OWN_SIDE: what = "DID NOT CROSS THE NET"
        RallyState.Fault.DOUBLE_BOUNCE: what = "DOUBLE BOUNCE"
        RallyState.Fault.VOLLEY_BEFORE_BOUNCE: what = "TWO-BOUNCE RULE — the ball had to bounce first"
        _: what = "DOUBLE HIT"
    return "%s  —  %s" % [what, "you win the rally" if rally.winner_side == 1 else "opponent wins the rally"]

## New practice ball in the player's hand. The player's first hit is the serve.
func _reset_ball() -> void:
    var spawn: Vector3 = player.position + Vector3(0.35, 1.00, -0.85)
    spawn.z = maxf(spawn.z, tuning.min_net_distance) # never spawn on the opponent's half
    ball.reset_ball(spawn)
    referee.start(1)
    awaiting_landing = false
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
    aim_label = Label.new()
    stack.add_child(aim_label)
    shot_label = Label.new()
    shot_label.text = "LAST SHOT  —  none yet"
    stack.add_child(shot_label)
    var help := Label.new()
    help.text = "%s/%s/%s/%s move | %s sprint | Mouse aim | %s drive | %s dink | %s reset | %s camera | %s menu" % [
        GameInput.label(GameInput.MOVE_FORWARD), GameInput.label(GameInput.MOVE_LEFT), GameInput.label(GameInput.MOVE_BACK),
        GameInput.label(GameInput.MOVE_RIGHT), GameInput.label(GameInput.SPRINT), GameInput.label(GameInput.SHOT_DRIVE),
        GameInput.label(GameInput.SHOT_DINK), GameInput.label(GameInput.RESET_BALL), GameInput.label(GameInput.CAMERA_NEXT),
        GameInput.label(GameInput.MENU_BACK)]
    stack.add_child(help)
    _update_score()

func _update_score() -> void:
    score_label.text = "PRACTICE • Your hits: %d   Opponent returns: %d   |   NOT OFFICIAL SCORING" % [player_hits, bot_hits]

func _set_status(message: String) -> void:
    if is_instance_valid(status_label):
        status_label.text = message
