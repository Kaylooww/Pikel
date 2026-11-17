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
var _pending_swing: PlayerInput.Swing = PlayerInput.Swing.NONE

func _ready() -> void:
    # Positions come from the match owner; the models must not move themselves.
    for node: Node in [home_player, away_player, ball_node]:
        node.set_physics_process(false)
    var ball_material := StandardMaterial3D.new()
    ball_material.albedo_color = Color("ffe86b")
    ball_node.get_node("Visual").material_override = ball_material
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
    var advice: AimAdvice = AimAdvice.evaluate(view, target_position, tuning)
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
    var input: PlayerInput = PlayerInput.make(move, Input.is_action_pressed(GameInput.SPRINT), _pending_swing, target_position, seq)
    _pending_swing = PlayerInput.Swing.NONE
    return input

func _process(_delta: float) -> void:
    target_position = CourtAim.target_from_mouse(camera, get_viewport().get_mouse_position(), my_side, target_position)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(GameInput.SHOT_DRIVE):
        _pending_swing = PlayerInput.Swing.DRIVE
    elif event.is_action_pressed(GameInput.SHOT_DINK):
        _pending_swing = PlayerInput.Swing.DINK
    elif event.is_action_pressed(GameInput.RESET_BALL):
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
    help.text = "%s/%s/%s/%s move | %s sprint | Mouse aim | %s drive | %s dink | %s rematch (after a match) | %s camera | %s menu" % [
        GameInput.label(GameInput.MOVE_FORWARD), GameInput.label(GameInput.MOVE_LEFT), GameInput.label(GameInput.MOVE_BACK),
        GameInput.label(GameInput.MOVE_RIGHT), GameInput.label(GameInput.SPRINT), GameInput.label(GameInput.SHOT_DRIVE),
        GameInput.label(GameInput.SHOT_DINK), GameInput.label(GameInput.RESET_BALL), GameInput.label(GameInput.CAMERA_NEXT),
        GameInput.label(GameInput.MENU_BACK)]
    stack.add_child(help)
