extends RefCounted
class_name PracticeBot
## A simple singles opponent. It produces PlayerInput like a human would, so it obeys the
## same movement limits, reach, timing and rules. It serves to the legal court, runs to
## where the ball will land, lets the ball bounce, and hits it back. Like a human it can
## only aim inside the court; it misses because its swing timing is imperfect, which the
## swing rules turn into sideways error. It never volleys and has no tactics beyond aiming
## away from the opponent.
## Seeded, so a given seed always plays the same match.

const HOME_DEPTH: float = 5.2 ## where it waits between shots, measured from the net
const STAND_BEHIND_BOUNCE: float = 1.8 ## how far past the landing point it sets up
const ARRIVE_DISTANCE: float = 0.15
const SPRINT_DISTANCE: float = 1.2

var side: int = -1
var tuning: GameplayTuning
var aim_error: float = 0.3 ## metres of random scatter on where it chooses to aim (always kept inside the court)
var timing_error: float = 0.2 ## seconds: each swing is early or late by up to this much. This is what makes it miss
var serve_delay_ticks: int = 45 ## how long it holds the ball before serving
var reaction_ticks: int = 12 ## ticks it stands still after the opponent hits
var _rng := RandomNumberGenerator.new()
var _serve_wait: int = 0
var _react_wait: int = 0
var _slip: float = 0.0 ## this shot's timing mistake, in seconds; positive swings early
var _seen_hits: int = 0
var _seen_rally: int = -1
var _spot: Vector3 = Vector3.ZERO

func _init(bot_side: int, game_tuning: GameplayTuning, rng_seed: int = 1) -> void:
    side = bot_side
    tuning = game_tuning
    _rng.seed = rng_seed

func decide(view: MatchView) -> PlayerInput:
    var input := PlayerInput.new()
    if view.rally_id != _seen_rally:
        _seen_rally = view.rally_id
        _serve_wait = 0
        _react_wait = 0
        _seen_hits = 0
    if not view.live:
        return input
    if view.phase == RallyState.Phase.WAITING_FOR_SERVE:
        if view.server_side == side:
            _serve_wait += 1
            if _serve_wait >= serve_delay_ticks:
                input.swing = PlayerInput.Swing.DRIVE
                input.aim = _scatter(_serve_target(view), 0.5)
        return input
    if view.last_hitter == side:
        _move_toward(input, view, Vector3(0.0, 0.0, side * HOME_DEPTH)) # my shot is away: recover
        _seen_hits = 0
        return input
    # The opponent's ball is coming. Notice it, wait out the reaction time, then go.
    if _seen_hits == 0:
        _seen_hits = 1
        _react_wait = reaction_ticks
        _slip = _rng.randf_range(-timing_error, timing_error)
    if _react_wait > 0:
        _react_wait -= 1
        return input
    if view.bounces_since_hit == 0:
        _spot = _setup_spot(view)
    _move_toward(input, view, _spot)
    if view.bounces_since_hit >= 1 and CourtDimensions.side_from_z(view.ball_position.z) == side:
        var contact: SwingContact.Contact = SwingContact.evaluate(view.my_position, view.ball_position, view.ball_velocity, side, tuning)
        if contact.in_reach and (not contact.approaching or contact.seconds_early <= _slip):
            input.swing = PlayerInput.Swing.DRIVE
            input.aim = _scatter(_rally_target(view), 1.0)
    return input

## Where to stand: a little past the spot the ball will land, along its line of flight.
func _setup_spot(view: MatchView) -> Vector3:
    var p: Vector3 = view.ball_position
    var v: Vector3 = view.ball_velocity
    var drop: float = maxf(p.y - BallState.RADIUS, 0.0)
    var time_to_floor: float = (v.y + sqrt(v.y * v.y + 2.0 * tuning.gravity * drop)) / tuning.gravity
    var landing := Vector3(p.x + v.x * time_to_floor, 0.0, p.z + v.z * time_to_floor)
    var along := Vector3(v.x, 0.0, v.z)
    if along.length() < 0.01:
        return landing
    return landing + along.normalized() * STAND_BEHIND_BOUNCE

func _move_toward(input: PlayerInput, view: MatchView, spot: Vector3) -> void:
    var gap := Vector2(spot.x - view.my_position.x, spot.z - view.my_position.z)
    if gap.length() > ARRIVE_DISTANCE:
        input.move = gap.normalized()
        input.sprint = gap.length() > SPRINT_DISTANCE

## Middle of the service court diagonal to the server.
func _serve_target(view: MatchView) -> Vector3:
    var x: float = -MatchSimulation.SERVE_X * side * (1.0 if view.serve_from_right else -1.0)
    return Vector3(x, 0.0, -side * 4.6)

## Deep and wide, on the half of the court the opponent is not standing in. Close enough
## to the lines that a badly timed swing puts it out.
func _rally_target(view: MatchView) -> Vector3:
    var away_from: float = -1.0 if view.opponent_position.x >= 0.0 else 1.0
    return Vector3(away_from * 2.6, 0.0, -side * 5.6)

func _scatter(target: Vector3, amount: float) -> Vector3:
    var angle: float = _rng.randf() * TAU
    var radius: float = _rng.randf() * aim_error * amount
    var aim: Vector3 = target + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
    var edge: float = 0.05 # a player always aims inside the opponent's court
    aim.x = clampf(aim.x, -CourtDimensions.HALF_WIDTH + edge, CourtDimensions.HALF_WIDTH - edge)
    var depth: float = clampf(absf(aim.z), SwingContact.MIN_DEPTH, CourtDimensions.HALF_LENGTH - edge)
    aim.z = -side * depth
    return aim
