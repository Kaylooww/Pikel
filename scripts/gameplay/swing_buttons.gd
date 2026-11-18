extends RefCounted
class_name SwingButtons
## Turns raw button presses into swings. Pure: every call takes the time in seconds, so tests
## can drive it with exact timestamps and no real mouse.
##
##   main button (left mouse)   tap -> DINK    hold -> DRIVE, power grows with the hold
##   alt button  (right mouse)  tap -> BLOCK   hold -> LOB, height and depth grow with the hold
## A press shorter than `tap_threshold` is a tap. The swing happens when the button is let go.
## Q (backhand) or E (forehand) must be pressed with each swing: from `side_key_window`
## seconds before the mouse press until the release. The latest one pressed counts. A swing
## with neither is a weaker "no side" swing; an old press from an earlier swing does not carry over.
## While one button is held the other is ignored: one swing at a time.
## A held drive or lob also swings by itself when the ball reaches the ideal contact point
## (auto_release), so the player charges by pressing early instead of guessing the release.

enum Pad { MAIN, ALT }

class Request extends RefCounted:
    var swing: PlayerInput.Swing = PlayerInput.Swing.NONE
    var power: float = 0.0
    var stroke: SwingContact.Stroke = SwingContact.Stroke.NONE
    var held: float = 0.0 ## seconds the button was down

var tuning: GameplayTuning
var _held_button: int = -1
var _pressed_at: float = 0.0
var _side_times: Dictionary = {SwingContact.Stroke.FOREHAND: -INF, SwingContact.Stroke.BACKHAND: -INF}

func _init(game_tuning: GameplayTuning) -> void:
    tuning = game_tuning

func press(button: Pad, now: float) -> void:
    if _held_button != -1:
        return
    _held_button = button
    _pressed_at = now

## Returns the swing for this release, or null when that button was not the one held.
func release(button: Pad, now: float) -> Request:
    if _held_button != button:
        return null
    var request := Request.new()
    request.held = maxf(now - _pressed_at, 0.0)
    var tap: bool = request.held < tuning.tap_threshold
    if button == Pad.MAIN:
        request.swing = PlayerInput.Swing.DINK if tap else PlayerInput.Swing.DRIVE
    else:
        request.swing = PlayerInput.Swing.BLOCK if tap else PlayerInput.Swing.LOB
    request.power = 0.0 if tap else charge_for(request.held)
    request.stroke = _stroke_between(_pressed_at - tuning.side_key_window, now)
    _held_button = -1
    return request

## If a drive or lob is being held and the ball has just reached the ideal contact point,
## swings now with the charge so far. `contact` is the swing judgement for this moment (null
## when there is nothing to hit). Returns null when it is not time yet.
func auto_release(now: float, contact: SwingContact.Contact) -> Request:
    if _held_button == -1 or contact == null or now - _pressed_at < tuning.tap_threshold:
        return null
    if not (contact.in_reach and contact.approaching and contact.seconds_early <= AUTO_SWING_LEAD):
        return null
    return release(_held_button as Pad, now)

const AUTO_SWING_LEAD: float = 1.0 / 60.0 ## one tick: the swing lands on the ideal contact point

## Q or E was pressed at `now`.
func press_side(stroke: SwingContact.Stroke, now: float) -> void:
    if stroke != SwingContact.Stroke.NONE:
        _side_times[stroke] = now

## Forget a half-made swing (for example when the scene loses focus).
func cancel() -> void:
    _held_button = -1

func holding() -> bool:
    return _held_button != -1

func held_button() -> int:
    return _held_button

## What letting go right now would hit: NONE if nothing is held.
func pending_swing(now: float) -> PlayerInput.Swing:
    if _held_button == -1:
        return PlayerInput.Swing.NONE
    var tap: bool = now - _pressed_at < tuning.tap_threshold
    if _held_button == Pad.MAIN:
        return PlayerInput.Swing.DINK if tap else PlayerInput.Swing.DRIVE
    return PlayerInput.Swing.BLOCK if tap else PlayerInput.Swing.LOB

## 0..1 charge of the held button right now; 0 while it is still a tap or nothing is held.
func charge(now: float) -> float:
    return 0.0 if _held_button == -1 else charge_for(now - _pressed_at)

## Charge for a hold of `held` seconds: 0 at the tap threshold, 1 at `full_charge_time`.
func charge_for(held: float) -> float:
    var span: float = maxf(tuning.full_charge_time - tuning.tap_threshold, 0.001)
    return clampf((held - tuning.tap_threshold) / span, 0.0, 1.0)

## The side key pressed with this swing (the side key pressed in the window), if any.
func pending_stroke(now: float) -> SwingContact.Stroke:
    if _held_button == -1:
        return SwingContact.Stroke.NONE
    return _stroke_between(_pressed_at - tuning.side_key_window, now)

func _stroke_between(from: float, to: float) -> SwingContact.Stroke:
    var best: SwingContact.Stroke = SwingContact.Stroke.NONE
    var best_time: float = -INF
    for stroke: SwingContact.Stroke in _side_times:
        var at: float = _side_times[stroke]
        if at >= from and at <= to and at > best_time:
            best = stroke
            best_time = at
    return best
