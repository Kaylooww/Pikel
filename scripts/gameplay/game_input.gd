extends RefCounted
class_name GameInput
## Names of the input actions defined in project.godot (Project Settings > Input Map), plus
## the small API a future settings screen needs to rebind them. Gameplay scripts read
## actions through these names and never check raw keys.
## shortcut: rebinds last until the game closes; save and load them when a settings screen exists.

const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const MOVE_FORWARD := &"move_forward"
const MOVE_BACK := &"move_back"
const SPRINT := &"sprint"
const SHOT_DRIVE := &"shot_drive"
const SHOT_DINK := &"shot_dink"
const RESET_BALL := &"reset_ball"
const CAMERA_NEXT := &"camera_next"
const MENU_BACK := &"menu_back"

const ALL: Array[StringName] = [MOVE_LEFT, MOVE_RIGHT, MOVE_FORWARD, MOVE_BACK, SPRINT,
    SHOT_DRIVE, SHOT_DINK, RESET_BALL, CAMERA_NEXT, MENU_BACK]

## Movement on the court plane: x is sideways, y is toward the player's own baseline.
## Length is at most 1, so diagonals are not faster.
static func move_vector() -> Vector2:
    return Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_FORWARD, MOVE_BACK)

## Replace every binding of `action` with `event`.
static func rebind(action: StringName, event: InputEvent) -> void:
    InputMap.action_erase_events(action)
    InputMap.action_add_event(action, event)

## Put every action back to the project defaults.
static func reset_to_defaults() -> void:
    InputMap.load_from_project_settings()

## Human-readable name of the first binding, for HUD hints ("W", "Shift", "Left Mouse Button").
static func label(action: StringName) -> String:
    var events: Array[InputEvent] = InputMap.action_get_events(action)
    if events.is_empty():
        return "unbound"
    return events[0].as_text().trim_suffix(" - Physical") # Godot's tag for layout-independent keys
