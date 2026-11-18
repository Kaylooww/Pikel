extends Node3D
class_name MatchCourt
## Everything a match shows and everything the local player presses, with no authority:
## the court, both player models, the ball, camera, aiming aids and HUD, plus collecting
## the local player's input. Whoever owns the match (the local simulation or the network
## client) tells it what to show and asks it for input.
signal rematch_requested

@export var tuning: GameplayTuning = preload("res://config/gameplay_tuning.tres")
@onready var home_player: PickleballPlayer = $HomePlayer
@onready var away_player: PickleballPlayer = $AwayPlayer
@onready var ball_node: PickleballBall = $Ball
@onready var camera: CourtCamera = $Camera3D
var my_side: int = 1
var target_position: Vector3 = Vector3(0.0, 0.0, -4.5)
var preview := AimPreview.new()
var score_label := Label.new()
var status_label := Label.new()
var aim_label := Label.new()
var charge_meter := ChargeMeter.new()
var buttons: SwingButtons
var clock: Callable = func() -> float: return Time.get_ticks_usec() / 1000000.0 ## seconds; tests replace it
var _pending: SwingButtons.Request = null

func _ready() -> void:
    # Positions come from the match owner; the models must not move themselves.
    for node: Node in [home_player, away_player, ball_node]:
        node.set_physics_process(false)
    var ball_material := StandardMaterial3D.new()
    ball_material.albedo_color = Color("ffe86b")
    ball_node.get_node("Visual").material_override = ball_material
    buttons = SwingButtons.new(tuning)
    add_child(preview)
    CourtScenery.add_environment(self)
    _make_hud()
    play_as(my_side)

## Which side the local player controls: decides the camera end and where they aim.
func play_as(side: int) -> void:
    my_side = side
    target_position = Vector3(0.0, 0.0, -side * 4.5)
    camera.side = side
    camera.target = home_player if side == 1 else away_player
    camera.snap()

func show_world(home_position: Vector3, away_position: Vector3, ball_position: Vector3) -> void:
    home_player.position = home_position
    away_player.position = away_position
    ball_node.position = ball_position

## Updates the aiming aids and hint line for the local player. Returns the advice shown.
func show_aim(view: MatchView) -> AimAdvice:
    var now: float = clock.call()
    var alt: bool = buttons.held_button() == SwingButtons.Pad.ALT
    var advice: AimAdvice = AimAdvice.evaluate(view, target_position, tuning, alt, buttons.charge(now))
    preview.show_advice(advice, target_position, view.ball_position, tuning)
    aim_label.text = advice.text
    return advice

func show_score(text: String) -> void:
    score_label.text = text

func show_status(text: String) -> void:
    if text != "":
        status_label.text = text

## The local player's request for this tick, in world space. Clears the queued swing.
func take_input(seq: int = 0) -> PlayerInput:
    # Keys are relative to the player's view; the away player looks the other way down the court.
    var move: Vector2 = GameInput.move_vector() * float(my_side)
    var input: PlayerInput = PlayerInput.make(move, Input.is_action_pressed(GameInput.SPRINT), PlayerInput.Swing.NONE, target_position, seq)
    if _pending != null:
        input.swing = _pending.swing
        input.power = _pending.power
        input.stroke = _pending.stroke
        _pending = null
    return input

func _process(_delta: float) -> void:
    target_position = CourtAim.target_from_mouse(camera, get_viewport().get_mouse_position(), my_side, target_position)
    var now: float = clock.call()
    charge_meter.show_charge(buttons.pending_swing(now), buttons.charge(now), buttons.pending_stroke(now))

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT and buttons != null:
        buttons.cancel() # a release the window never sees must not leave a drive charging forever

func _unhandled_input(event: InputEvent) -> void:
    var now: float = clock.call()
    if SwingInput.handle(buttons, event, now, func(request: SwingButtons.Request) -> void: _pending = request):
        return
    if event.is_action_pressed(GameInput.RESET_BALL):
        rematch_requested.emit()
    elif event.is_action_pressed(GameInput.CAMERA_NEXT):
        camera.next_rig()
    elif event.is_action_pressed(GameInput.MENU_BACK):
        get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

func _make_hud() -> void:
    var hud := CanvasLayer.new()
    add_child(hud)
    var panel := PanelContainer.new()
    panel.position = Vector2(16, 12)
    panel.custom_minimum_size = Vector2(600, 92)
    hud.add_child(panel)
    var stack := VBoxContainer.new()
    panel.add_child(stack)
    score_label.add_theme_font_size_override("font_size", 19)
    stack.add_child(score_label)
    status_label.add_theme_font_size_override("font_size", 16)
    stack.add_child(status_label)
    stack.add_child(aim_label)
    var help := Label.new()
    help.text = RallyText.controls_hint("%s rematch (after a match)" % GameInput.label(GameInput.RESET_BALL))
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help.custom_minimum_size = Vector2(600, 0)
    stack.add_child(help)
    hud.add_child(charge_meter)
