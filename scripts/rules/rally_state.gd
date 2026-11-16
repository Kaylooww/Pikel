extends RefCounted
class_name RallyState
## State machine for one rally, from serve to the fault that ends it. Pure: it consumes
## RallyEvents and never touches the scene, UI or ball.
##
## Phases follow docs/05_PICKLEBALL_RULES.md:
##   WAITING_FOR_SERVE -> SERVE_IN_FLIGHT -> WAITING_FOR_RETURN -> RETURN_IN_FLIGHT -> OPEN_RALLY
## and any of them can go to ENDED with a fault. A rally ends exactly once: after ENDED,
## and for duplicate or stale event ids, apply() changes nothing.
##
## Not here yet: serve legality and service courts (RP-022), kitchen and momentum faults
## (RP-023), points and side-out (RP-024). A serve only has to land in on the receiver's half.

enum Phase { WAITING_FOR_SERVE, SERVE_IN_FLIGHT, WAITING_FOR_RETURN, RETURN_IN_FLIGHT, OPEN_RALLY, ENDED }
enum Fault {
    NONE,
    NET, ## ball stopped by the net
    OUT, ## ball landed outside the court
    OWN_SIDE, ## ball landed on the hitter's own half
    DOUBLE_BOUNCE, ## ball bounced twice before being returned
    VOLLEY_BEFORE_BOUNCE, ## serve or return hit out of the air (two-bounce rule)
    DOUBLE_HIT, ## same side hit the ball twice in a row
}

var rally_id: int = 0
var server_side: int = 1
var phase: Phase = Phase.WAITING_FOR_SERVE
var last_hitter: int = 0
var bounces_since_hit: int = 0
var fault: Fault = Fault.NONE
var fault_side: int = 0 ## side that committed the fault
var winner_side: int = 0 ## side that won the rally; 0 until it ends
var last_event_id: int = -1
var log: Array[RallyEvent] = [] ## every accepted event, in order

func _init(id: int = 0, serving_side: int = 1) -> void:
    rally_id = id
    server_side = serving_side

func is_over() -> bool:
    return phase == Phase.ENDED

## Feeds one event in. Returns true if it was accepted (logged and acted on), false if it
## was ignored: wrong rally, duplicate or stale id, rally already over, or meaningless in
## the current phase (for example a bounce before the serve).
func apply(event: RallyEvent) -> bool:
    if is_over() or event.rally_id != rally_id or event.id <= last_event_id:
        return false
    if phase == Phase.WAITING_FOR_SERVE and not (event.type == RallyEvent.Type.HIT and event.side == server_side):
        return false
    last_event_id = event.id
    log.append(event)
    match event.type:
        RallyEvent.Type.HIT: _on_hit(event.side)
        RallyEvent.Type.BOUNCE: _on_bounce(event.position)
        RallyEvent.Type.NET: _end(Fault.NET, last_hitter)
    return true

func _on_hit(side: int) -> void:
    if side == last_hitter:
        _end(Fault.DOUBLE_HIT, side)
        return
    match phase:
        Phase.WAITING_FOR_SERVE:
            phase = Phase.SERVE_IN_FLIGHT
        Phase.SERVE_IN_FLIGHT, Phase.RETURN_IN_FLIGHT:
            _end(Fault.VOLLEY_BEFORE_BOUNCE, side)
            return
        Phase.WAITING_FOR_RETURN:
            phase = Phase.RETURN_IN_FLIGHT
    last_hitter = side
    bounces_since_hit = 0

func _on_bounce(at: Vector3) -> void:
    if bounces_since_hit >= 1:
        # Already bounced in once: wherever it lands next, it was not returned in time.
        _end(Fault.DOUBLE_BOUNCE, -last_hitter)
        return
    if not CourtDimensions.inside_court(at):
        _end(Fault.OUT, last_hitter)
        return
    if CourtDimensions.side_from_z(at.z) == last_hitter:
        _end(Fault.OWN_SIDE, last_hitter)
        return
    bounces_since_hit += 1
    if phase == Phase.SERVE_IN_FLIGHT:
        phase = Phase.WAITING_FOR_RETURN
    elif phase == Phase.RETURN_IN_FLIGHT:
        phase = Phase.OPEN_RALLY

func _end(reason: Fault, guilty_side: int) -> void:
    phase = Phase.ENDED
    fault = reason
    fault_side = guilty_side
    winner_side = -guilty_side
