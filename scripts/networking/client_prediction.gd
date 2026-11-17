extends RefCounted
class_name ClientPrediction
## Makes the local player feel instant. Each input is applied locally the moment it is sent,
## with the same PlayerMotion maths the server uses, and remembered. When a snapshot says
## "at your input N you were here", everything up to N is forgotten and the rest is replayed
## from the server's position. If the server agreed, nothing visibly changes. If it did not
## (a lost input, a teleport to the serve spot), the predicted position is corrected at once
## and the picture slides to it over a few frames, unless the jump is too big to hide.

const SNAP_DISTANCE: float = 1.5 ## corrections larger than this are shown at once (teleports)
const SMOOTHING_RATE: float = 12.0 ## per second; how fast a small correction is blended away
const MAX_PENDING: int = 240 ## four seconds of unacknowledged inputs; beyond that the link is effectively dead

var side: int = 1
var tuning: GameplayTuning
var position: Vector3 = Vector3.ZERO ## where the simulation says the player is, as far as the client can tell
var has_state: bool = false ## false until the first snapshot arrives
var last_correction: float = 0.0 ## metres the last reconcile moved the predicted position
var corrections: int = 0 ## reconciles that moved it by more than a millimetre
var reconciles: int = 0
var _pending: Array[PlayerInput] = []
var _visual_offset: Vector3 = Vector3.ZERO

func _init(player_side: int, game_tuning: GameplayTuning) -> void:
    side = player_side
    tuning = game_tuning

## Call for every input sent to the server, in order.
func apply_local(input: PlayerInput) -> void:
    if not has_state:
        return
    _pending.append(input)
    if _pending.size() > MAX_PENDING:
        _pending.pop_front()
    position = _step(position, input)

## Call for every new snapshot: the server's position for this player and the last input it applied.
func reconcile(server_position: Vector3, ack_seq: int) -> void:
    while not _pending.is_empty() and _pending[0].seq <= ack_seq:
        _pending.pop_front()
    var replayed: Vector3 = server_position
    for input: PlayerInput in _pending:
        replayed = _step(replayed, input)
    reconciles += 1
    last_correction = position.distance_to(replayed) if has_state else 0.0
    if last_correction > 0.001:
        corrections += 1
    if has_state and last_correction <= SNAP_DISTANCE:
        _visual_offset += position - replayed # keep the picture where it was; decay() slides it over
    else:
        _visual_offset = Vector3.ZERO
    position = replayed
    has_state = true

## Call once per rendered tick to blend small corrections away.
func decay(delta: float) -> void:
    _visual_offset *= exp(-SMOOTHING_RATE * delta)

## Where to draw the player.
func render_position() -> Vector3:
    return position + _visual_offset

func pending_count() -> int:
    return _pending.size()

func _step(from: Vector3, input: PlayerInput) -> Vector3:
    return PlayerMotion.step(from, input.move, input.sprint, side, tuning, MatchSimulation.DT)
