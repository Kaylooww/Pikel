extends RefCounted
class_name SnapshotInterpolator
## Draws what the client cannot predict (the opponent and the ball) smoothly, by showing
## the recent past. Snapshots arrive a few times per tick at uneven moments; this keeps a
## short buffer and renders a fixed number of ticks behind the newest one, blending
## between the two snapshots either side of that moment. It never guesses ahead.

const MAX_BUFFER: int = 32
const DELAY_TICKS: float = 4.0 ## how far behind the newest snapshot to render (about two snapshots at 30 Hz)
const RESYNC_TICKS: float = 12.0 ## if the render clock drifts further than this, jump instead of easing
const EASE: float = 0.1 ## fraction of the clock error corrected per tick

var render_tick: float = 0.0
var _buffer: Array[NetSnapshot] = [] ## oldest first

func clear() -> void:
    _buffer.clear()
    render_tick = 0.0

func newest_tick() -> int:
    return _buffer[-1].tick if not _buffer.is_empty() else -1

## Adds a snapshot. Returns false, and ignores it, if it is not newer than the newest held.
func push(snapshot: NetSnapshot) -> bool:
    if snapshot.tick <= newest_tick():
        return false
    if _buffer.is_empty():
        render_tick = snapshot.tick - DELAY_TICKS
    _buffer.append(snapshot)
    if _buffer.size() > MAX_BUFFER:
        _buffer.pop_front()
    return true

## Call once per local tick. Moves the render clock forward one tick and eases it toward
## its target, so small differences in clock speed or bursts of snapshots do not show.
func advance() -> void:
    if _buffer.is_empty():
        return
    render_tick += 1.0
    var error: float = (newest_tick() - DELAY_TICKS) - render_tick
    if absf(error) > RESYNC_TICKS:
        render_tick += error
    else:
        render_tick += error * EASE

## Positions at the render clock: {home, away, ball}. Empty before the first snapshot.
func sample() -> Dictionary:
    return sample_at(render_tick)

func sample_at(at_tick: float) -> Dictionary:
    if _buffer.is_empty():
        return {}
    var older: NetSnapshot = _buffer[0]
    var newer: NetSnapshot = _buffer[0]
    for snapshot: NetSnapshot in _buffer:
        newer = snapshot
        if snapshot.tick >= at_tick:
            break
        older = snapshot
    var span: float = newer.tick - older.tick
    var weight: float = clampf((at_tick - older.tick) / span, 0.0, 1.0) if span > 0.0 else 0.0
    return {
        "home": older.home_position.lerp(newer.home_position, weight),
        "away": older.away_position.lerp(newer.away_position, weight),
        "ball": older.ball_position.lerp(newer.ball_position, weight),
    }
