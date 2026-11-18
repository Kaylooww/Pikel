extends Node3D
## Playable training vertical slice, NOT a complete game or legal rules engine.
@export var tuning: GameplayTuning = preload("res://config/gameplay_tuning.tres")
@onready var court: Node3D = $Court
@onready var player: PickleballPlayer = $HomePlayer
@onready var bot: PickleballPlayer = $PracticeOpponent
@onready var ball: PickleballBall = $Ball
@onready var camera: CourtCamera = $Camera3D
## Where the practice server stands: right court, a step behind the baseline.
const SERVE_SPOT := Vector3(1.5, 0.0, CourtDimensions.HALF_LENGTH + 0.3)
const AIM_OK := Color(0.33, 0.84, 0.80, 0.70)
const AIM_BLOCKED := Color(1.0, 0.51, 0.42, 0.70)
const AIM_IDLE := Color(0.75, 0.78, 0.80, 0.40)
var marker: MeshInstance3D
var marker_material: StandardMaterial3D
var landing_marker: MeshInstance3D
var hold_preview: TrajectoryPreview ## drive or lob at the current charge
var tap_preview: TrajectoryPreview ## dink or block
var buttons: SwingButtons
var charge_meter := ChargeMeter.new()
var clock: Callable = func() -> float: return Time.get_ticks_usec() / 1000000.0 ## seconds; tests replace it
var aim_label: Label
var shot_label: Label
var shot_target: Vector3 = Vector3.ZERO ## where the player's last shot was aimed
var awaiting_landing: bool = false ## the player's shot is in the air and has not landed yet
var referee := RallyController.new()
var in_kitchen: Dictionary = {} ## player node -> was standing in the kitchen last tick
var status_label: Label
var score_label: Label
var player_hits: int = 0
var bot_hits: int = 0
var bot_should_return: bool = false
var resetting: bool = false
var target_position: Vector3 = Vector3(0, 0, -4.5)

func _ready() -> void:
    bot.position = Vector3(-1.5, 0.0, -5.2)
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
    buttons = SwingButtons.new(tuning)
    ball.bounced.connect(_on_ball_bounced)
    ball.net_hit.connect(_on_ball_net_hit)
    referee.rally_ended.connect(_on_rally_ended)
    referee.momentum_ticks = roundi(tuning.momentum_window * Engine.physics_ticks_per_second)
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
    hold_preview = TrajectoryPreview.new()
    hold_preview.set_color(Color("ffe06b"))
    add_child(hold_preview)
    tap_preview = TrajectoryPreview.new()
    tap_preview.set_color(Color("55d5cb"))
    add_child(tap_preview)
    CourtScenery.add_environment(self)
    _make_hud()
    _set_status("Aim on the OPPOSITE court; click while the ball is within reach.")

## Tells the rules whenever a player steps into the kitchen.
func _physics_process(_delta: float) -> void:
    for who: PickleballPlayer in [player, bot]:
        var inside: bool = CourtDimensions.inside_kitchen(who.position)
        if inside and not in_kitchen.get(who, false):
            referee.kitchen_entry(1 if who == player else -1, who.position)
        in_kitchen[who] = inside
    # A held drive or lob swings by itself when the ball reaches the ideal contact point.
    if not resetting and referee.rally.last_hitter != 1 and ball.position.z > 0.0 and not _must_bounce_first() and not _kitchen_volley():
        var auto: SwingButtons.Request = buttons.auto_release(clock.call(), _contact(SwingContact.Stroke.FOREHAND))
        if auto != null:
            _attempt_hit(auto)

func _process(_delta: float) -> void:
    target_position = CourtAim.target_from_mouse(camera, get_viewport().get_mouse_position(), 1, target_position)
    marker.position = Vector3(target_position.x, 0.10, target_position.z)
    var now: float = clock.call()
    charge_meter.show_charge(buttons.pending_swing(now), buttons.charge(now), buttons.pending_stroke(now))
    _update_aim_preview()
    if ball.moving and not resetting:
        var want: Vector3 = Vector3(clampf(ball.position.x, -2.9, 2.9), 0, -4.8)
        bot.ai_direction = (want - bot.position).normalized() if ball.position.z < 1.0 else (Vector3(0, 0, -5.1) - bot.position).normalized()
        if bot_should_return and ball.position.z < -0.2 and ball.position.distance_to(bot.position + Vector3.UP * tuning.bot_contact_height) < tuning.bot_reach:
            bot_should_return = false
            if ball.launch(Vector3(clampf(player.position.x, -2.4, 2.4), 0.0, 4.55), ShotRecipe.make(ShotRecipe.Kind.DRIVE, 0.3, false, tuning)).ok:
                referee.hit(-1, ball.position, bot.position)
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
    else:
        SwingInput.handle(buttons, event, clock.call(), func(request: SwingButtons.Request) -> void:
            if not resetting:
                _attempt_hit(request))

## Shows what a click would do right now: the arc of each shot type that the solver accepts,
## and a marker colour plus text for accepted / refused / out of reach.
func _update_aim_preview() -> void:
    if resetting or not _ball_in_reach():
        hold_preview.show_points(PackedVector3Array())
        tap_preview.show_points(PackedVector3Array())
        marker_material.albedo_color = AIM_IDLE
        aim_label.text = "AIM  —  ball not in reach"
        return
    if _must_bounce_first() or _kitchen_volley():
        hold_preview.show_points(PackedVector3Array())
        tap_preview.show_points(PackedVector3Array())
        marker_material.albedo_color = AIM_BLOCKED
        aim_label.text = "WAIT  —  let the return bounce first (two-bounce rule)" if _must_bounce_first() else "KITCHEN  —  no volleys here: let it bounce or step back"
        return
    # The arcs use the real target, so a mistimed or stretched swing visibly drifts off the marker.
    var needed: SwingContact.Stroke = SwingContact.needed_stroke(player.position, ball.position, 1, tuning)
    var contact: SwingContact.Contact = _contact(needed if needed != SwingContact.Stroke.NONE else SwingContact.Stroke.FOREHAND)
    var real_target: Vector3 = contact.apply(target_position)
    var now: float = clock.call()
    var alt: bool = buttons.held_button() == SwingButtons.Pad.ALT
    var volley: bool = _volley()
    var tap_kind: ShotRecipe.Kind = ShotRecipe.Kind.BLOCK if alt else ShotRecipe.Kind.DINK
    var hold_kind: ShotRecipe.Kind = ShotRecipe.Kind.LOB if alt else ShotRecipe.Kind.DRIVE
    var hold_ok: bool = _preview_shot(hold_preview, real_target, ShotRecipe.make(hold_kind, buttons.charge(now), volley, tuning))
    var tap_ok: bool = _preview_shot(tap_preview, real_target, ShotRecipe.make(tap_kind, 0.0, volley, tuning))
    var serve_problem: String = _serve_problem(real_target)
    var label: String = "%s  —  contact: %s" % [AimAdvice._side_hint(needed).trim_suffix("  —"), contact.label()]
    marker_material.albedo_color = AIM_OK if (hold_ok or tap_ok) and serve_problem == "" else AIM_BLOCKED
    if (hold_ok or tap_ok) and serve_problem != "":
        aim_label.text = "SERVE FAULT IF HIT  —  %s" % serve_problem
    elif hold_ok and tap_ok:
        aim_label.text = "AIM OK  —  %s  —  yellow dots: %s   aqua dots: %s" % [label, ShotRecipe.kind_name(hold_kind).to_lower(), ShotRecipe.kind_name(tap_kind).to_lower()]
    elif hold_ok or tap_ok:
        aim_label.text = "AIM OK  —  %s  —  only the %s clears the net from here" % [label, ShotRecipe.kind_name(hold_kind if hold_ok else tap_kind).to_lower()]
    else:
        aim_label.text = "AIM BLOCKED  —  %s  —  no shot lands in from here" % label

func _preview_shot(view: TrajectoryPreview, real_target: Vector3, recipe: ShotRecipe) -> bool:
    var shot: ShotSolver.Solution = ShotSolver.solve(ball.position, real_target, recipe, tuning)
    view.show_points(ShotSolver.sample_arc(ball.position, shot, tuning))
    return shot.ok

## Reach, timing and side of a swing made right now.
func _contact(stroke: SwingContact.Stroke, volley_window: float = 0.0) -> SwingContact.Contact:
    return SwingContact.evaluate(player.position, ball.position, ball.ball_velocity, 1, tuning, stroke, volley_window)

## True while the ball in play has not bounced since the opponent hit it.
func _volley() -> bool:
    return MatchSimulation.is_volley(referee.rally)

## Why a serve hit right now would be a fault, or "" if it is legal or this is not a serve.
func _serve_problem(real_target: Vector3) -> String:
    var rally: RallyState = referee.rally
    if rally.phase != RallyState.Phase.WAITING_FOR_SERVE:
        return ""
    if not CourtDimensions.legal_serve_position(player.position, true, rally.serve_from_right):
        return "stand behind the baseline, on the right half"
    if not CourtDimensions.legal_serve_target(real_target, true, rally.serve_from_right):
        return "aim at the diagonal service court, past the kitchen line"
    return ""

## True while the opponent's return is in the air and the rules require it to bounce.
func _must_bounce_first() -> bool:
    return referee.rally.phase == RallyState.Phase.RETURN_IN_FLIGHT and referee.rally.last_hitter == -1

## True when hitting now would be a volley made from inside the kitchen.
func _kitchen_volley() -> bool:
    var rally: RallyState = referee.rally
    return rally.phase == RallyState.Phase.OPEN_RALLY and rally.last_hitter == -1 and rally.bounces_since_hit == 0 and CourtDimensions.inside_kitchen(player.position)

func _ball_in_reach() -> bool:
    return ball.position.z > 0.0 and _contact(SwingContact.Stroke.FOREHAND).in_reach

func _attempt_hit(request: SwingButtons.Request) -> void:
    if not RulesEngine.is_cross_court_target(target_position, 1):
        _set_status("Aim at the opponent's side.")
        return
    if ball.position.z <= 0.0:
        _set_status("Ball is still on the other half.")
        return
    if referee.rally.last_hitter == 1:
        return # your own shot is still in play; a second click must not count as a second hit
    var kind: ShotRecipe.Kind = int(request.swing) as ShotRecipe.Kind
    var volley: bool = _volley()
    var contact: SwingContact.Contact = _contact(request.stroke, MatchSimulation.volley_window(kind, tuning) if volley else 0.0)
    if not contact.in_reach:
        _set_status("Too far from ball — move closer.")
        return
    if contact.whiffed:
        _set_status(RallyText.swing(MatchSimulation.SwingResult.MISTIMED, kind, contact.label()))
        return
    var recipe: ShotRecipe = ShotRecipe.make(kind, request.power, volley, tuning).weakened(contact.power)
    var shot: ShotSolver.Solution = ball.launch(contact.apply(target_position), recipe)
    if not shot.ok:
        _set_status("%s (contact: %s)" % [_refusal_text(shot.reason), contact.label()])
        return
    awaiting_landing = true
    shot_target = target_position
    landing_marker.visible = false
    player_hits += 1
    _update_score()
    _set_status(RallyText.swing(MatchSimulation.SwingResult.HIT, kind, contact.label()))
    referee.hit(1, ball.position, player.position) # may end the rally at once, e.g. a foot fault or volleying the return

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
    _set_status(RallyText.fault(rally, 1))
    if resetting:
        return
    resetting = true
    await get_tree().create_timer(tuning.fault_reset_delay).timeout
    if is_inside_tree():
        _reset_ball()

## New practice ball: the player is put on the serve spot with the ball in hand.
## Their first hit is the serve. shortcut: always the right court until scoring picks the side (RP-024).
func _reset_ball() -> void:
    player.position = SERVE_SPOT
    ball.reset_ball(player.position + Vector3(0.35, 1.00, -0.85))
    referee.start(1, true)
    awaiting_landing = false
    bot_should_return = false
    resetting = false

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
    help.text = RallyText.controls_hint("%s reset" % GameInput.label(GameInput.RESET_BALL))
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help.custom_minimum_size = Vector2(600, 0)
    stack.add_child(help)
    hud.add_child(charge_meter)
    _update_score()

func _update_score() -> void:
    score_label.text = "PRACTICE • Your hits: %d   Opponent returns: %d   |   NOT OFFICIAL SCORING" % [player_hits, bot_hits]

func _set_status(message: String) -> void:
    if is_instance_valid(status_label):
        status_label.text = message
