extends RefCounted
class_name SwingContact
## Pure judgement of one swing: can the player reach the ball, was the timing early, clean
## or late, was it struck on the right side (forehand or backhand), and how far that pushes
## the shot off the aim point. No scene access.
##
## The error is deterministic so it can be previewed and learned:
##   early      -> the ball is pulled across the body (to the hitter's left)
##   late       -> the ball is pushed wide (to the hitter's right)
##   stretched  -> the shot comes up short (toward the net)
##   wrong side -> weaker, short, and sprayed toward the side it was struck on
##   no side    -> a little weaker and a little off
## A volley (ball still in the air) has a hard timing window: outside it the swing misses
## the ball completely (whiffed).
## shortcut: everyone is right-handed: forehand on the right (E), backhand on the left (Q).

enum Timing { CLEAN, EARLY, LATE }
enum Stroke { NONE, FOREHAND, BACKHAND }

class Contact extends RefCounted:
    var in_reach: bool = false
    var timing: Timing = Timing.CLEAN
    var stretched: bool = false
    var approaching: bool = false ## the ball is flying toward the hitter, so timing is being judged
    var seconds_early: float = 0.0 ## time until ideal contact; negative once the ball has gone past
    var side: int = 1
    var stroke: Stroke = Stroke.NONE ## the side the player swung on
    var needed: Stroke = Stroke.NONE ## the side the ball is on; NONE when it is in front of the body, where both work
    var whiffed: bool = false ## a volley pressed outside its window: the paddle misses the ball
    var power: float = 1.0 ## share of the shot's pace this swing keeps
    var offset: Vector3 = Vector3.ZERO ## added to the aim point to get the real target

    func stroke_ok() -> bool:
        return stroke != Stroke.NONE and (needed == Stroke.NONE or stroke == needed)

    func is_clean() -> bool:
        return in_reach and timing == Timing.CLEAN and not stretched and stroke_ok() and not whiffed

    ## Where the shot will really be aimed. Kept past the net so a mishit is a bad shot,
    ## not an impossible one.
    func apply(aim: Vector3) -> Vector3:
        var target: Vector3 = aim + offset
        target.z = minf(target.z, -MIN_DEPTH) if side == 1 else maxf(target.z, MIN_DEPTH)
        return target

    func label() -> String:
        var words: PackedStringArray = []
        if whiffed:
            words.append("MISSED")
        if timing != Timing.CLEAN:
            words.append("EARLY" if timing == Timing.EARLY else "LATE")
        if stretched:
            words.append("STRETCHED")
        if stroke == Stroke.NONE:
            words.append("NO SIDE")
        elif not stroke_ok():
            words.append("WRONG SIDE")
        return "CLEAN" if words.is_empty() else " + ".join(words)

const MIN_DEPTH: float = 0.3 # a mishit target never comes closer to the net than this
const MIN_APPROACH_SPEED: float = 0.5 # slower than this toward the player counts as a still ball

## `side` is +1 for a player on the home half (facing -z), -1 for the away half.
## `stroke` is the side the player picked for this swing. `volley_window` is the hard timing
## window in seconds when the ball is being volleyed, or 0 for a ball that has bounced.
static func evaluate(player_position: Vector3, ball_position: Vector3, ball_velocity: Vector3, side: int, tuning: GameplayTuning, stroke: Stroke = Stroke.NONE, volley_window: float = 0.0) -> Contact:
    var contact := Contact.new()
    contact.side = side
    contact.stroke = stroke
    contact.needed = needed_stroke(player_position, ball_position, side, tuning)
    var distance: float = ball_position.distance_to(player_position + Vector3.UP * tuning.player_contact_height)
    contact.in_reach = distance <= tuning.player_reach
    if not contact.in_reach:
        return contact

    # Reach: beyond the comfortable radius the shot gets shorter, up to max_reach_error at full stretch.
    if distance > tuning.clean_reach:
        contact.stretched = true
        var stretch: float = (distance - tuning.clean_reach) / (tuning.player_reach - tuning.clean_reach)
        contact.offset.z += side * tuning.max_reach_error * stretch

    # Timing: seconds until the ball reaches the ideal contact plane just in front of the body.
    var approach_speed: float = ball_velocity.z * side
    if approach_speed > MIN_APPROACH_SPEED:
        var contact_z: float = player_position.z - side * tuning.contact_lead
        var seconds_early: float = (contact_z - ball_position.z) * side / approach_speed
        contact.approaching = true
        contact.seconds_early = seconds_early
        if absf(seconds_early) > tuning.clean_timing_window:
            contact.timing = Timing.EARLY if seconds_early > 0.0 else Timing.LATE
            var amount: float = clampf((absf(seconds_early) - tuning.clean_timing_window) / (tuning.max_timing_window - tuning.clean_timing_window), 0.0, 1.0)
            var to_hitters_right: float = side * tuning.max_timing_error * amount
            contact.offset.x += -to_hitters_right if contact.timing == Timing.EARLY else to_hitters_right
        if volley_window > 0.0 and absf(seconds_early) > volley_window:
            contact.whiffed = true

    # Forehand / backhand.
    if stroke == Stroke.NONE:
        contact.power = tuning.no_side_power
        _spray(contact, tuning.no_side_error, side)
    elif not contact.stroke_ok():
        contact.power = tuning.wrong_side_power
        _spray(contact, tuning.wrong_side_error, side)
    return contact

## Which side of the body the ball is on: FOREHAND to the player's right, BACKHAND to the
## left, NONE in front of the body (within `body_deadzone`), where either stroke works.
static func needed_stroke(player_position: Vector3, ball_position: Vector3, side: int, tuning: GameplayTuning) -> Stroke:
    var to_right: float = (ball_position.x - player_position.x) * side # home faces -z, so +x is their right
    if absf(to_right) <= tuning.body_deadzone:
        return Stroke.NONE
    return Stroke.FOREHAND if to_right > 0.0 else Stroke.BACKHAND

static func stroke_key_name(stroke: Stroke) -> String:
    match stroke:
        Stroke.FOREHAND: return "FOREHAND"
        Stroke.BACKHAND: return "BACKHAND"
        _: return "EITHER SIDE"

## A badly sided swing: falls short and sprays toward the side the ball was struck on.
static func _spray(contact: Contact, amount: float, side: int) -> void:
    var toward: float = 1.0 if contact.needed != Stroke.BACKHAND else -1.0
    contact.offset.z += side * amount * 0.7
    contact.offset.x += side * toward * amount * 0.7
