extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_input.gd
## Input action map and the rebinding API (RP-014). Simulated input only: no real keyboard.
var errors: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    for action in GameInput.ALL:
        _assert(InputMap.has_action(action) and InputMap.action_get_events(action).size() == 1, "%s has one default binding" % action)

    # Default keys, pressed as a real keyboard would report them.
    _assert(InputMap.event_is_action(_key(KEY_A), GameInput.MOVE_LEFT), "A is move_left")
    _assert(InputMap.event_is_action(_key(KEY_W), GameInput.MOVE_FORWARD), "W is move_forward")
    _assert(InputMap.event_is_action(_key(KEY_SHIFT), GameInput.SPRINT), "Shift is sprint")
    _assert(not InputMap.event_is_action(_key(KEY_A), GameInput.MOVE_RIGHT), "A is not move_right")
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    _assert(click.is_action_pressed(GameInput.SHOT_DINK_DRIVE) and not click.is_action_pressed(GameInput.SHOT_BLOCK_LOB), "left click is the dink/drive button only")
    var right_click := InputEventMouseButton.new()
    right_click.button_index = MOUSE_BUTTON_RIGHT
    right_click.pressed = true
    _assert(right_click.is_action_pressed(GameInput.SHOT_BLOCK_LOB) and not right_click.is_action_pressed(GameInput.SHOT_DINK_DRIVE), "right click is the block/lob button only")
    _assert(InputMap.event_is_action(_key(KEY_Q), GameInput.BACKHAND), "Q is backhand")
    _assert(InputMap.event_is_action(_key(KEY_E), GameInput.FOREHAND), "E is forehand")
    var device_zero: InputEventKey = _key(KEY_D)
    device_zero.device = 0
    _assert(InputMap.event_is_action(device_zero, GameInput.MOVE_RIGHT), "bindings match any device id")

    # Movement vector: axes and diagonal length.
    _assert(GameInput.move_vector() == Vector2.ZERO, "no input means no movement")
    Input.action_press(GameInput.MOVE_LEFT)
    _assert(GameInput.move_vector().is_equal_approx(Vector2(-1, 0)), "move_left is -x")
    Input.action_press(GameInput.MOVE_FORWARD)
    var diagonal: Vector2 = GameInput.move_vector()
    _assert(diagonal.x < 0.0 and diagonal.y < 0.0 and is_equal_approx(diagonal.length(), 1.0), "diagonal is toward the net and not faster")
    Input.action_release(GameInput.MOVE_LEFT)
    Input.action_release(GameInput.MOVE_FORWARD)
    Input.action_press(GameInput.MOVE_BACK)
    _assert(GameInput.move_vector().is_equal_approx(Vector2(0, 1)), "move_back is +y (toward own baseline)")
    Input.action_release(GameInput.MOVE_BACK)

    # Rebinding replaces the old key, and reset restores the default.
    GameInput.rebind(GameInput.MOVE_LEFT, _key(KEY_J))
    _assert(InputMap.event_is_action(_key(KEY_J), GameInput.MOVE_LEFT), "rebound key works")
    _assert(not InputMap.event_is_action(_key(KEY_A), GameInput.MOVE_LEFT), "old key no longer works")
    _assert(GameInput.label(GameInput.MOVE_LEFT) == "J", "label follows the rebind")
    GameInput.reset_to_defaults()
    _assert(InputMap.event_is_action(_key(KEY_A), GameInput.MOVE_LEFT) and not InputMap.event_is_action(_key(KEY_J), GameInput.MOVE_LEFT), "reset restores the default")
    _assert(GameInput.label(GameInput.MOVE_LEFT) == "A", "label reads A by default")
    _assert(GameInput.label(GameInput.SPRINT) == "Shift", "label reads Shift for sprint")

    if errors.is_empty():
        print("PASS: %d input checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

func _key(code: Key) -> InputEventKey:
    var event := InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = true
    return event

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
