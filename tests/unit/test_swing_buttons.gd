extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_swing_buttons.gd
## Tap/hold detection, drive and lob charge, and the Q/E side picked with each swing.
## Exact timestamps are fed in, so no real mouse or keyboard is involved.
const SW := PlayerInput.Swing
const ST := SwingContact.Stroke
const B := SwingButtons.Pad
var errors: Array[String] = []
var checks: int = 0
var tuning := GameplayTuning.new()

func _initialize() -> void:
    var tap: float = tuning.tap_threshold
    _assert(is_equal_approx(tap, 0.15), "the tap threshold starts at 150 ms")
    var buttons := SwingButtons.new(tuning)

    # Left button: tap is a dink, hold is a drive.
    buttons.press(B.MAIN, 10.0)
    _assert(buttons.holding() and buttons.pending_swing(10.05) == SW.DINK and buttons.charge(10.05) == 0.0, "a fresh press would still be a tap")
    var dink: SwingButtons.Request = buttons.release(B.MAIN, 10.0 + tap - 0.01)
    _assert(dink != null and dink.swing == SW.DINK and dink.power == 0.0, "a press just under the threshold is a dink")
    _assert(not buttons.holding(), "releasing ends the swing")
    buttons.press(B.MAIN, 20.0)
    _assert(buttons.pending_swing(20.0 + tap + 0.01) == SW.DRIVE, "past the threshold it becomes a drive")
    var drive: SwingButtons.Request = buttons.release(B.MAIN, 20.0 + tap + 0.01)
    _assert(drive.swing == SW.DRIVE and drive.power > 0.0 and drive.power < 0.05, "a press just over the threshold is a barely charged drive")

    # Charge grows with the hold, from the threshold to full_charge_time, then stays full.
    var half_time: float = tap + (tuning.full_charge_time - tap) * 0.5
    _assert(is_equal_approx(buttons.charge_for(half_time), 0.5), "halfway to full charge is 50%")
    _assert(buttons.charge_for(tuning.full_charge_time) == 1.0 and buttons.charge_for(5.0) == 1.0, "charge tops out at full and stays there")
    _assert(buttons.charge_for(0.0) == 0.0, "no hold, no charge")
    buttons.press(B.MAIN, 30.0)
    _assert(buttons.charge(30.0 + half_time) > buttons.charge(30.0 + tap + 0.05), "the meter rises while held")
    var full: SwingButtons.Request = buttons.release(B.MAIN, 32.0)
    _assert(full.swing == SW.DRIVE and full.power == 1.0, "a long hold is a full-power drive")

    # Right button: tap is a block, hold is a lob with the same charge rule.
    buttons.press(B.ALT, 40.0)
    var block: SwingButtons.Request = buttons.release(B.ALT, 40.08)
    _assert(block.swing == SW.BLOCK and block.power == 0.0, "a right tap is a block")
    buttons.press(B.ALT, 50.0)
    var lob: SwingButtons.Request = buttons.release(B.ALT, 50.0 + half_time)
    _assert(lob.swing == SW.LOB and is_equal_approx(lob.power, 0.5), "a right hold is a lob, charged like the drive")

    # One swing at a time; a stray release does nothing.
    buttons.press(B.MAIN, 60.0)
    buttons.press(B.ALT, 60.05)
    _assert(buttons.held_button() == B.MAIN, "the second button is ignored while the first is held")
    _assert(buttons.release(B.ALT, 60.1) == null, "releasing the ignored button makes no swing")
    _assert(buttons.release(B.MAIN, 60.1).swing == SW.DINK, "the held button still makes its swing")
    _assert(buttons.release(B.MAIN, 61.0) == null, "a release with nothing held makes no swing")
    buttons.press(B.MAIN, 62.0)
    buttons.cancel()
    _assert(not buttons.holding() and buttons.release(B.MAIN, 63.0) == null, "cancel drops a half-made swing")

    # The tap threshold is a setting.
    var slow := GameplayTuning.new()
    slow.tap_threshold = 0.3
    var slow_buttons := SwingButtons.new(slow)
    slow_buttons.press(B.MAIN, 0.0)
    _assert(slow_buttons.release(B.MAIN, 0.25).swing == SW.DINK, "with a 300 ms threshold a 250 ms press is still a tap")

    # Q/E must be pressed with each swing.
    buttons.press_side(ST.FOREHAND, 69.95)
    buttons.press(B.MAIN, 70.0)
    _assert(buttons.pending_stroke(70.05) == ST.FOREHAND, "E just before the click picks forehand")
    _assert(buttons.release(B.MAIN, 70.1).stroke == ST.FOREHAND, "the swing carries the forehand")
    buttons.press(B.MAIN, 71.0)
    _assert(buttons.release(B.MAIN, 71.1).stroke == ST.NONE, "the old E press does not carry over to the next swing")
    buttons.press(B.MAIN, 72.0)
    buttons.press_side(ST.BACKHAND, 72.3)
    _assert(buttons.release(B.MAIN, 72.5).stroke == ST.BACKHAND, "Q pressed during a hold picks backhand")
    buttons.press_side(ST.FOREHAND, 79.9)
    buttons.press(B.ALT, 80.0)
    buttons.press_side(ST.BACKHAND, 80.05)
    _assert(buttons.release(B.ALT, 80.1).stroke == ST.BACKHAND, "the latest side pressed wins")
    buttons.press_side(ST.FOREHAND, 90.0 - tuning.side_key_window - 0.05)
    buttons.press(B.MAIN, 90.0)
    _assert(buttons.release(B.MAIN, 90.05).stroke == ST.NONE, "a side pressed too long before the click does not count")
    buttons.press(B.MAIN, 95.0)
    var dropped: SwingButtons.Request = buttons.release(B.MAIN, 95.05)
    buttons.press_side(ST.FOREHAND, 95.06)
    _assert(dropped.stroke == ST.NONE, "a side pressed after the release does not count")

    # A held drive or lob swings by itself when the ball reaches the ideal contact point.
    var arriving := SwingContact.Contact.new()
    arriving.in_reach = true
    arriving.approaching = true
    arriving.seconds_early = 0.2
    buttons.press(B.ALT, 100.0)
    _assert(buttons.auto_release(100.5, arriving) == null and buttons.holding(), "no swing while the ball is still on its way")
    arriving.seconds_early = 0.0
    var auto: SwingButtons.Request = buttons.auto_release(100.6, arriving)
    _assert(auto != null and auto.swing == SW.LOB and auto.power > 0.5 and not buttons.holding(), "the held lob swings itself at contact with the charge so far")
    _assert(buttons.release(B.ALT, 100.7) == null, "the later mouse-up does not swing a second time")
    buttons.press(B.MAIN, 110.0)
    _assert(buttons.auto_release(110.05, arriving) == null and buttons.holding(), "a press still inside the tap time waits for the release (it may be a dink)")
    var out_of_reach := SwingContact.Contact.new()
    out_of_reach.approaching = true
    _assert(buttons.auto_release(110.5, out_of_reach) == null and buttons.auto_release(110.5, null) == null, "no auto swing at a ball out of reach or with nothing to hit")
    buttons.cancel()

    # Events: the real input actions reach the buttons.
    var fresh := SwingButtons.new(tuning)
    var made: Array = []
    var keep := func(request: SwingButtons.Request) -> void: made.append(request)
    _assert(SwingInput.handle(fresh, _action(GameInput.FOREHAND, true), 1.0, keep), "E is used as a swing key")
    _assert(SwingInput.handle(fresh, _action(GameInput.SHOT_DINK_DRIVE, true), 1.02, keep) and made.is_empty(), "the press starts a swing but hits nothing yet")
    _assert(SwingInput.handle(fresh, _action(GameInput.SHOT_DINK_DRIVE, false), 1.6, keep) and made.size() == 1, "the release makes one swing")
    var from_events: SwingButtons.Request = made[0]
    _assert(from_events.swing == SW.DRIVE and from_events.stroke == ST.FOREHAND and from_events.power > 0.5, "an E + left hold from real events is a charged forehand drive")
    _assert(not SwingInput.handle(fresh, _action(GameInput.CAMERA_NEXT, true), 2.0, keep), "other keys are left to the scene")

    if errors.is_empty():
        print("PASS: %d swing button checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

func _action(action: StringName, pressed: bool) -> InputEventAction:
    var event := InputEventAction.new()
    event.action = action
    event.pressed = pressed
    return event

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
