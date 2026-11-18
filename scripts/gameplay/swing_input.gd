extends RefCounted
class_name SwingInput
## Feeds input events to SwingButtons, shared by the match and training scenes.
## Mouse presses start a swing, releases finish it, Q/E pick the side.

## Returns true when the event was a swing or side key and has been used.
## `on_swing` is called with the SwingButtons.Request when a release completes a swing.
static func handle(buttons: SwingButtons, event: InputEvent, now: float, on_swing: Callable) -> bool:
    if event.is_echo():
        return false
    for pair: Array in [[GameInput.SHOT_DINK_DRIVE, SwingButtons.Pad.MAIN], [GameInput.SHOT_BLOCK_LOB, SwingButtons.Pad.ALT]]:
        if event.is_action_pressed(pair[0]):
            buttons.press(pair[1], now)
            return true
        if event.is_action_released(pair[0]):
            var request: SwingButtons.Request = buttons.release(pair[1], now)
            if request != null:
                on_swing.call(request)
            return true
    if event.is_action_pressed(GameInput.BACKHAND):
        buttons.press_side(SwingContact.Stroke.BACKHAND, now)
        return true
    if event.is_action_pressed(GameInput.FOREHAND):
        buttons.press_side(SwingContact.Stroke.FOREHAND, now)
        return true
    return false
