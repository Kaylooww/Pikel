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
## Serves: the server must stand behind the baseline on the side they serve from, and the
## ball must land in the diagonal service court (kitchen line is a fault, other lines in).
## Every serve is treated as a drop serve, so there are no swing-motion checks.
## Kitchen: a volley (hit before the ball bounces) is a fault if the hitter stands in the
## kitchen, line included, or steps into it within `momentum_ticks` after the volley.
## Standing in the kitchen and hitting a ball that has bounced are both fine.
## Not here yet: points and side-out (RP-024).

enum Phase { WAITING_FOR_SERVE, SERVE_IN_FLIGHT, WAITING_FOR_RETURN, RETURN_IN_FLIGHT, OPEN_RALLY, ENDED }
enum Fault {
    NONE,
    NET, ## ball stopped by the net
    OUT, ## ball landed outside the court
    OWN_SIDE, ## ball landed on the hitter's own half
    DOUBLE_BOUNCE, ## ball bounced twice before being returned
    VOLLEY_BEFORE_BOUNCE, ## serve or return hit out of the air (two-bounce rule)
    DOUBLE_HIT, ## same side hit the ball twice in a row
    SERVE_POSITION, ## server was not behind the baseline in the correct half (foot fault)
    SERVE_COURT, ## serve landed in the kitchen or the wrong service court
    KITCHEN_VOLLEY, ## volleyed while standing in the kitchen
    KITCHEN_MOMENTUM, ## stepped into the kitchen right after a volley
    SERVE_CLOCK, ## server did not serve in time
}

var rally_id: int = 0
var server_side: int = 1
var serve_from_right: bool = true ## which of the server's courts they serve from
var phase: Phase = Phase.WAITING_FOR_SERVE
var last_hitter: int = 0
var bounces_since_hit: int = 0
var fault: Fault = Fault.NONE
var fault_side: int = 0 ## side that committed the fault
var winner_side: int = 0 ## side that won the rally; 0 until it ends
var last_event_id: int = -1
var log: Array[RallyEvent] = [] ## every accepted event, in order
var momentum_ticks: int = 36 ## how long after a volley stepping into the kitchen is still a fault (0.6 s at 60 Hz)
var _volley_ticks: Dictionary = {} ## side -> tick of that side's latest volley

func _init(id: int = 0, serving_side: int = 1, from_right: bool = true) -> void:
    rally_id = id
    server_side = serving_side
    serve_from_right = from_right

func is_over() -> bool:
    return phase == Phase.ENDED

## Feeds one event in. Returns true if it was accepted (logged and acted on), false if it
## was ignored: wrong rally, duplicate or stale id, rally already over, or meaningless in
## the current phase (for example a bounce before the serve).
func apply(event: RallyEvent) -> bool:
    if is_over() or event.rally_id != rally_id or event.id <= last_event_id:
        return false
    if event.type == RallyEvent.Type.SERVE_TIMEOUT:
        if phase != Phase.WAITING_FOR_SERVE:
            return false # the serve was hit; the clock no longer matters
    elif phase == Phase.WAITING_FOR_SERVE and not (event.type == RallyEvent.Type.HIT and event.side == server_side):
        return false
    if event.type == RallyEvent.Type.KITCHEN_ENTRY and not _within_momentum(event.side, event.tick):
        return false # walking into the kitchen is only a problem right after a volley
    last_event_id = event.id
    log.append(event)
    match event.type:
        RallyEvent.Type.HIT: _on_hit(event.side, event.player_position, event.tick)
        RallyEvent.Type.BOUNCE: _on_bounce(event.position)
        RallyEvent.Type.NET: _end(Fault.NET, last_hitter)
        RallyEvent.Type.KITCHEN_ENTRY: _end(Fault.KITCHEN_MOMENTUM, event.side)
        RallyEvent.Type.SERVE_TIMEOUT: _end(Fault.SERVE_CLOCK, server_side)
    return true

func _within_momentum(side: int, tick: int) -> bool:
    return _volley_ticks.has(side) and tick - int(_volley_ticks[side]) <= momentum_ticks

func _on_hit(side: int, feet: Vector3, tick: int) -> void:
    if side == last_hitter:
        _end(Fault.DOUBLE_HIT, side)
        return
    match phase:
        Phase.WAITING_FOR_SERVE:
            if not CourtDimensions.legal_serve_position(feet, side == 1, serve_from_right):
                last_hitter = side
                _end(Fault.SERVE_POSITION, side)
                return
            phase = Phase.SERVE_IN_FLIGHT
        Phase.SERVE_IN_FLIGHT, Phase.RETURN_IN_FLIGHT:
            _end(Fault.VOLLEY_BEFORE_BOUNCE, side)
            return
        Phase.WAITING_FOR_RETURN:
            phase = Phase.RETURN_IN_FLIGHT
        Phase.OPEN_RALLY:
            if bounces_since_hit == 0: # a volley
                if CourtDimensions.inside_kitchen(feet):
                    _end(Fault.KITCHEN_VOLLEY, side)
                    return
                _volley_ticks[side] = tick
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
        if not CourtDimensions.legal_serve_target(at, server_side == 1, serve_from_right):
            _end(Fault.SERVE_COURT, server_side)
            return
        phase = Phase.WAITING_FOR_RETURN
    elif phase == Phase.RETURN_IN_FLIGHT:
        phase = Phase.OPEN_RALLY

func _end(reason: Fault, guilty_side: int) -> void:
    phase = Phase.ENDED
    fault = reason
    fault_side = guilty_side
    winner_side = -guilty_side
