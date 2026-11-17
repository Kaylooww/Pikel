extends RefCounted
class_name RallyController
## Turns what happens on court into numbered RallyEvents and feeds them to the current
## RallyState. Game scripts report hits, bounces and net contacts here and listen for
## `rally_ended`; they never decide faults themselves.
## With a match running (new_match), each finished rally is also scored before `rally_ended`
## fires, and start_next() sets up the next rally with the right server and serve side.
signal rally_ended(rally: RallyState)
signal match_ended(score: MatchScore)

var rally: RallyState
var score: MatchScore ## null when rallies are played without a match (practice)
var momentum_ticks: int = 36 ## copied into every new rally
var _next_event_id: int = 0
var _next_rally_id: int = 0

## Starts a scored match and its first rally.
func new_match(first_server: int = 1, points_to_win: int = 11, win_by: int = 2, point_cap: int = 0) -> void:
    score = MatchScore.new(first_server, points_to_win, win_by, point_cap)
    start_next()

## Starts the next rally of the match. Returns false, and starts nothing, once the match is won.
func start_next() -> bool:
    if score == null or score.is_over():
        return false
    start(score.server_side, score.serve_from_right())
    return true

## Starts a rally directly. Practice uses this; a match uses start_next().
func start(server_side: int, serve_from_right: bool = true) -> void:
    _next_rally_id += 1
    rally = RallyState.new(_next_rally_id, server_side, serve_from_right)
    rally.momentum_ticks = momentum_ticks

## `ball_at` is the ball at contact, `feet_at` the hitter's ground position.
func hit(side: int, ball_at: Vector3, feet_at: Vector3) -> bool:
    return _apply(RallyEvent.hit(_take_id(), rally.rally_id, Engine.get_physics_frames(), side, ball_at, feet_at))

## Report every time a player steps into the kitchen; the rules ignore it unless it matters.
func kitchen_entry(side: int, feet_at: Vector3) -> bool:
    return _apply(RallyEvent.kitchen_entry(_take_id(), rally.rally_id, Engine.get_physics_frames(), side, feet_at))

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
        if score != null:
            score.record_rally(rally.rally_id, rally.winner_side)
        rally_ended.emit(rally)
        if score != null and score.is_over():
            match_ended.emit(score)
    return accepted
