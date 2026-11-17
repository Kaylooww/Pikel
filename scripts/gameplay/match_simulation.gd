extends RefCounted
class_name MatchSimulation
## A whole singles match as plain data advanced in fixed ticks: both players, the ball,
## the rally rules and the score. No scene access and no randomness, so the same inputs
## always give the same match. Local play steps it directly; the match server steps it
## as the only authority; visuals just read it.
##
## Players only ever send PlayerInput requests. Whether a move is allowed, a swing connects,
## a ball is in or a point is scored is decided here.

signal rally_started(rally: RallyState)
signal swing_resolved(side: int, result: SwingResult, contact: SwingContact.Contact, soft: bool) ## contact is null when the swing never got as far as judging reach
signal ball_bounced(at: Vector3)
signal rally_ended(rally: RallyState)
signal match_ended(score: MatchScore)

enum SwingResult {
    HIT,
    NOT_LIVE, ## between rallies, match over, or not this player's serve
    ALREADY_HIT, ## this player's own shot is still in play
    WRONG_HALF, ## ball is on the other half
    OUT_OF_REACH,
    NO_SHOT_NET, ## no allowed arc clears the net
    NO_SHOT_OUT, ## the (error-adjusted) target is not in the opponent's court
    NO_SHOT_TOO_FAST,
}

const TICK_RATE: int = 60
const DT: float = 1.0 / TICK_RATE
const SIDES: Array[int] = [1, -1]
const SERVE_X: float = 1.5 ## how far from the centre line the server and receiver stand
const SERVE_BEHIND: float = 0.3 ## how far behind the baseline the server stands
const RECEIVE_INSIDE: float = 0.6 ## how far inside the baseline the receiver stands
const HAND_OFFSET := Vector3(0.35, 1.0, -0.85) ## ball in a home server's hand, relative to the feet

var tuning: GameplayTuning
var tick: int = 0
var positions: Dictionary = {1: Vector3.ZERO, -1: Vector3.ZERO} ## side -> feet position
var ball := BallState.new()
var referee := RallyController.new()
var pause_ticks: int = 0 ## ticks left before the next rally is set up
var _in_kitchen: Dictionary = {1: false, -1: false}

func _init(game_tuning: GameplayTuning, first_server: int = 1, points_to_win: int = 11, win_by: int = 2, point_cap: int = 0) -> void:
    tuning = game_tuning
    referee.tick = 0
    referee.momentum_ticks = roundi(tuning.momentum_window * TICK_RATE)
    referee.rally_ended.connect(_on_rally_ended)
    referee.match_ended.connect(_on_match_ended) # a method, not a lambda: a lambda would keep this object alive forever
    referee.new_match(first_server, points_to_win, win_by, point_cap)
    _place_for_serve()

func score() -> MatchScore:
    return referee.score

func is_over() -> bool:
    return referee.score.is_over()

## True while a rally is being played or waiting for its serve.
func rally_live() -> bool:
    return pause_ticks == 0 and not referee.rally.is_over()

## One full tick: every side's input, then the world. `inputs` maps side -> PlayerInput;
## a missing side stands still.
func step(inputs: Dictionary) -> void:
    for side: int in SIDES:
        if inputs.has(side):
            apply_input(side, inputs[side])
    advance()

## Applies one player's request at the current tick: movement, then the swing if any.
## The server may call this more than once per tick for a side to catch up after jitter;
## it is the server's job to cap how many it accepts.
func apply_input(side: int, input: PlayerInput) -> void:
    if is_over():
        return
    positions[side] = PlayerMotion.step(positions[side], input.move, input.sprint, side, tuning, DT)
    if input.swing != PlayerInput.Swing.NONE:
        _try_swing(side, input)

## Advances the world by one tick: rally pauses, the ball, and kitchen entries.
func advance() -> void:
    tick += 1
    referee.tick = tick
    if is_over():
        return
    if pause_ticks > 0:
        pause_ticks -= 1
        if pause_ticks == 0 and referee.start_next():
            _place_for_serve()
        return
    var rally: RallyState = referee.rally
    if rally.phase == RallyState.Phase.WAITING_FOR_SERVE:
        ball.place(_hand_position(rally.server_side)) # the server carries the ball until they hit it
    match ball.step(DT, tuning):
        BallState.Event.BOUNCE:
            ball_bounced.emit(ball.position)
            referee.bounce(ball.position)
        BallState.Event.NET:
            referee.net(ball.position)
    for side: int in SIDES:
        var inside: bool = CourtDimensions.inside_kitchen(positions[side])
        if inside and not _in_kitchen[side] and rally_live():
            referee.kitchen_entry(side, positions[side])
        _in_kitchen[side] = inside

## Where the server stands for this rally: behind the baseline, in the court they serve from.
static func serve_spot(server_side: int, from_right: bool) -> Vector3:
    var x: float = SERVE_X * server_side * (1.0 if from_right else -1.0)
    return Vector3(x, 0.0, server_side * (CourtDimensions.HALF_LENGTH + SERVE_BEHIND))

## Where the receiver waits: in the service court diagonal to the server.
static func receive_spot(server_side: int, from_right: bool) -> Vector3:
    var x: float = -SERVE_X * server_side * (1.0 if from_right else -1.0)
    return Vector3(x, 0.0, -server_side * (CourtDimensions.HALF_LENGTH - RECEIVE_INSIDE))

func _place_for_serve() -> void:
    var rally: RallyState = referee.rally
    positions[rally.server_side] = serve_spot(rally.server_side, rally.serve_from_right)
    positions[-rally.server_side] = receive_spot(rally.server_side, rally.serve_from_right)
    ball.place(_hand_position(rally.server_side))
    for side: int in SIDES:
        _in_kitchen[side] = false
    rally_started.emit(rally)

func _hand_position(side: int) -> Vector3:
    return hand_position(positions[side], side)

## Where a server standing at `feet` holds the ball before serving.
static func hand_position(feet: Vector3, side: int) -> Vector3:
    return feet + Vector3(HAND_OFFSET.x * side, HAND_OFFSET.y, HAND_OFFSET.z * side)

func _try_swing(side: int, input: PlayerInput) -> void:
    var result: SwingResult = SwingResult.HIT
    var contact: SwingContact.Contact = null
    var rally: RallyState = referee.rally
    if not rally_live() or (rally.phase == RallyState.Phase.WAITING_FOR_SERVE and rally.server_side != side):
        result = SwingResult.NOT_LIVE
    elif rally.last_hitter == side:
        result = SwingResult.ALREADY_HIT
    elif CourtDimensions.side_from_z(ball.position.z) != side:
        result = SwingResult.WRONG_HALF
    elif not RulesEngine.is_cross_court_target(input.aim, side):
        result = SwingResult.NO_SHOT_OUT # the player must aim at the opponent's court; only swing error may miss it
    else:
        contact = SwingContact.evaluate(positions[side], ball.position, ball.velocity, side, tuning)
        if not contact.in_reach:
            result = SwingResult.OUT_OF_REACH
        else:
            var shot: ShotSolver.Solution = ball.launch(contact.apply(input.aim), input.swing == PlayerInput.Swing.DINK, tuning)
            match shot.reason:
                ShotSolver.Reason.NET: result = SwingResult.NO_SHOT_NET
                ShotSolver.Reason.BAD_TARGET: result = SwingResult.NO_SHOT_OUT
                ShotSolver.Reason.TOO_FAST: result = SwingResult.NO_SHOT_TOO_FAST
    swing_resolved.emit(side, result, contact, input.swing == PlayerInput.Swing.DINK)
    if result == SwingResult.HIT:
        referee.hit(side, ball.position, positions[side]) # may end the rally at once (foot fault, kitchen, two-bounce)

func _on_match_ended(final: MatchScore) -> void:
    match_ended.emit(final)

func _on_rally_ended(rally: RallyState) -> void:
    ball.stop()
    pause_ticks = maxi(1, roundi(tuning.fault_reset_delay * TICK_RATE))
    rally_ended.emit(rally)
