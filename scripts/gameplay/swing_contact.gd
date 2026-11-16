extends RefCounted
class_name SwingContact
## Pure judgement of one swing: can the player reach the ball, was the timing early, clean
## or late, and how far that pushes the shot off the aim point. No scene access.
##
## The error is deterministic so it can be previewed and learned:
##   early    -> the ball is pulled across the body (to the hitter's left)
##   late     -> the ball is pushed wide (to the hitter's right)
##   stretched-> the shot comes up short (toward the net)
## shortcut: assumes a right-handed forehand for every swing; add handedness and backhand
## when characters and swing animations exist.

enum Timing { CLEAN, EARLY, LATE }

class Contact extends RefCounted:
    var in_reach: bool = false
    var timing: Timing = Timing.CLEAN
    var stretched: bool = false
    var side: int = 1
    var offset: Vector3 = Vector3.ZERO ## added to the aim point to get the real target

    func is_clean() -> bool:
        return in_reach and timing == Timing.CLEAN and not stretched

    ## Where the shot will really be aimed. Kept past the net so a mishit is a bad shot,
    ## not an impossible one.
    func apply(aim: Vector3) -> Vector3:
        var target: Vector3 = aim + offset
        target.z = minf(target.z, -MIN_DEPTH) if side == 1 else maxf(target.z, MIN_DEPTH)
        return target

    func label() -> String:
        var words: PackedStringArray = []
        if timing != Timing.CLEAN:
            words.append("EARLY" if timing == Timing.EARLY else "LATE")
        if stretched:
            words.append("STRETCHED")
        return "CLEAN" if words.is_empty() else " + ".join(words)

const MIN_DEPTH: float = 0.3 # a mishit target never comes closer to the net than this
const MIN_APPROACH_SPEED: float = 0.5 # slower than this toward the player counts as a still ball

## `side` is +1 for a player on the home half (facing -z), -1 for the away half.
static func evaluate(player_position: Vector3, ball_position: Vector3, ball_velocity: Vector3, side: int, tuning: GameplayTuning) -> Contact:
    var contact := Contact.new()
    contact.side = side
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
        if absf(seconds_early) > tuning.clean_timing_window:
            contact.timing = Timing.EARLY if seconds_early > 0.0 else Timing.LATE
            var amount: float = clampf((absf(seconds_early) - tuning.clean_timing_window) / (tuning.max_timing_window - tuning.clean_timing_window), 0.0, 1.0)
            var to_hitters_right: float = side * tuning.max_timing_error * amount
            contact.offset.x += -to_hitters_right if contact.timing == Timing.EARLY else to_hitters_right
    return contact
