extends RefCounted
class_name RallyController
## Turns what happens on court into numbered RallyEvents and feeds them to the current
## RallyState. Game scripts report hits, bounces and net contacts here and listen for
## `rally_ended`; they never decide faults themselves.
signal rally_ended(rally: RallyState)

var rally: RallyState
var _next_event_id: int = 0
var _next_rally_id: int = 0

func start(server_side: int, serve_from_right: bool = true) -> void:
    _next_rally_id += 1
    rally = RallyState.new(_next_rally_id, server_side, serve_from_right)

## `ball_at` is the ball at contact, `feet_at` the hitter's ground position.
func hit(side: int, ball_at: Vector3, feet_at: Vector3) -> bool:
    return _apply(RallyEvent.hit(_take_id(), rally.rally_id, Engine.get_physics_frames(), side, ball_at, feet_at))

func bounce(at: Vector3) -> bool:
    return _apply(RallyEvent.bounce(_take_id(), rally.rally_id, Engine.get_physics_frames(), at))

func net(at: Vector3) -> bool:
    return _apply(RallyEvent.net(_take_id(), rally.rally_id, Engine.get_physics_frames(), at))

func _take_id() -> int:
    _next_event_id += 1
    return _next_event_id

func _apply(event: RallyEvent) -> bool:
    var accepted: bool = rally.apply(event)
    if accepted and rally.is_over():
        rally_ended.emit(rally)
    return accepted
