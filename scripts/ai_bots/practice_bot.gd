extends RefCounted
class_name PracticeBot
## A simple singles opponent. It produces PlayerInput like a human would, so it obeys the
## same movement limits, reach, timing, side (Q/E) and rules. It serves to the legal court,
## runs to where the ball will land, and plays every shot type:
##   ground strokes: drives with a random charge, dinks into the kitchen when it is up at the
##   net, and the odd lob over an opponent who has come to the net;
##   volleys: once it is at the net (after its own dink or block) it steps across to meet a
##   ball in the air and taps a volley dink, or a block against a hard ball.
## It misses because its swing timing is imperfect (sideways error on the ground, a whiff on a
## volley outside the window) and because it now and then swings on the wrong side.
## Seeded, so a given seed always plays the same match.

const HOME_DEPTH: float = 5.2 ## where it waits after a drive or lob, measured from the net
const NET_DEPTH: float = 2.6 ## where it waits after a dink or block: just behind the kitchen line
const STAND_BEHIND_BOUNCE: float = 1.8 ## how far past the landing point it sets up
const ARRIVE_DISTANCE: float = 0.15
const SPRINT_DISTANCE: float = 1.2
const VOLLEY_MIN_HEIGHT: float = 0.3 ## lowest ball it will try to volley
const VOLLEY_MAX_HEIGHT: float = 2.0
const VOLLEY_STANCE: float = 0.5 ## how far left of the ball it stands, so the volley is a forehand

var side: int = -1
var tuning: GameplayTuning
var aim_error: float = 0.3 ## metres of random scatter on where it chooses to aim (always kept inside the court)
var timing_error: float = 0.2 ## seconds: each ground stroke is early or late by up to this much
var volley_timing_error: float = 0.12 ## seconds of slip on a volley; past the volley window it whiffs
var wrong_side_chance: float = 0.08 ## chance a swing is made on the wrong side
var lob_chance: float = 0.25 ## chance it lobs when the opponent is at the net
var block_speed: float = 11.0 ## m/s: an incoming volley at least this fast is blocked rather than dinked
var serve_delay_ticks: int = 45 ## how long it holds the ball before serving
var reaction_ticks: int = 12 ## ticks it stands still after the opponent hits
var _rng := RandomNumberGenerator.new()
var _serve_wait: int = 0
var _react_wait: int = 0
var _slip: float = 0.0 ## this shot's timing mistake, in seconds; positive swings early
var _seen_hits: int = 0
var _seen_rally: int = -1
var _spot: Vector3 = Vector3.ZERO
var _volleying: bool = false ## this ball will be met in the air
var _at_net: bool = false ## its last shot was soft, so it moves up to the kitchen line
var _plan: PlayerInput.Swing = PlayerInput.Swing.DRIVE ## ground stroke chosen for this ball
var _plan_power: float = 0.5
var _plan_wrong_side: bool = false

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
        _at_net = false
    if not view.live:
        return input
    if view.phase == RallyState.Phase.WAITING_FOR_SERVE:
        if view.server_side == side:
            _serve_wait += 1
            if _serve_wait >= serve_delay_ticks:
                input.swing = PlayerInput.Swing.DRIVE
                input.power = 0.3
                input.stroke = _stroke_for(view, false)
                input.aim = _scatter(_serve_target(view), 0.5)
        return input
    if view.last_hitter == side:
        _move_toward(input, view, Vector3(0.0, 0.0, side * (NET_DEPTH if _at_net else HOME_DEPTH))) # my shot is away: recover
        _seen_hits = 0
        return input
    # The opponent's ball is coming. Notice it, wait out the reaction time, then go.
    if _seen_hits == 0:
        _seen_hits = 1
        _react_wait = reaction_ticks
        _volleying = false
        _plan_wrong_side = _rng.randf() < wrong_side_chance
        _choose_ground_stroke(view)
    if _react_wait > 0:
        _react_wait -= 1
        return input
    if view.bounces_since_hit == 0:
        var meet: Vector3 = _air_intercept(view)
        _volleying = meet != Vector3.INF
        if _volleying:
            if _seen_hits == 1:
                _slip = _rng.randf_range(-volley_timing_error, volley_timing_error)
                _seen_hits = 2
            _spot = Vector3(meet.x - side * VOLLEY_STANCE, 0.0, view.my_position.z)
        else:
            _spot = _setup_spot(view)
    _move_toward(input, view, _spot)
    if CourtDimensions.side_from_z(view.ball_position.z) != side:
        return input
    if view.bounces_since_hit == 0 and _volleying:
        _try_volley(input, view)
    elif view.bounces_since_hit >= 1:
        _try_ground_stroke(input, view)
    return input

func _try_volley(input: PlayerInput, view: MatchView) -> void:
    var incoming: float = view.ball_velocity.length()
    var kind: PlayerInput.Swing = PlayerInput.Swing.BLOCK if incoming >= block_speed else PlayerInput.Swing.DINK
    var window: float = MatchSimulation.volley_window(int(kind) as ShotRecipe.Kind, tuning)
    var stroke: SwingContact.Stroke = _stroke_for(view, _plan_wrong_side)
    var contact: SwingContact.Contact = SwingContact.evaluate(view.my_position, view.ball_position, view.ball_velocity, side, tuning, stroke, window)
    if contact.in_reach and contact.approaching and contact.seconds_early <= _slip:
        input.swing = kind
        input.stroke = stroke
        input.aim = _scatter(_rally_target(view), 1.0)
        _at_net = true

func _try_ground_stroke(input: PlayerInput, view: MatchView) -> void:
    if _seen_hits < 3:
        _seen_hits = 3
        _slip = _rng.randf_range(-timing_error, timing_error)
    var stroke: SwingContact.Stroke = _stroke_for(view, _plan_wrong_side)
    var contact: SwingContact.Contact = SwingContact.evaluate(view.my_position, view.ball_position, view.ball_velocity, side, tuning, stroke)
    if contact.in_reach and (not contact.approaching or contact.seconds_early <= _slip):
        input.swing = _plan
        input.power = _plan_power
        input.stroke = stroke
        match _plan:
            PlayerInput.Swing.DINK: input.aim = _scatter(_dink_target(view), 0.6)
            PlayerInput.Swing.LOB: input.aim = _scatter(_lob_target(view), 1.0)
            _: input.aim = _scatter(_rally_target(view), 1.0)
        _at_net = _plan == PlayerInput.Swing.DINK

func _choose_ground_stroke(view: MatchView) -> void:
    var me_at_net: bool = absf(view.my_position.z) < NET_DEPTH + 1.0
    var opponent_at_net: bool = absf(view.opponent_position.z) < NET_DEPTH + 1.0
    if opponent_at_net and _rng.randf() < lob_chance:
        _plan = PlayerInput.Swing.LOB
        _plan_power = _rng.randf_range(0.4, 1.0)
    elif me_at_net:
        _plan = PlayerInput.Swing.DINK
        _plan_power = 0.0
    else:
        _plan = PlayerInput.Swing.DRIVE
        _plan_power = _rng.randf_range(0.3, 0.9)

## Forehand or backhand for where the ball is now; `wrong` picks the other one on purpose.
func _stroke_for(view: MatchView, wrong: bool) -> SwingContact.Stroke:
    var needed: SwingContact.Stroke = SwingContact.needed_stroke(view.my_position, view.ball_position, side, tuning)
    if needed == SwingContact.Stroke.NONE:
        needed = SwingContact.Stroke.FOREHAND
    if not wrong:
        return needed
    return SwingContact.Stroke.BACKHAND if needed == SwingContact.Stroke.FOREHAND else SwingContact.Stroke.FOREHAND

## Where a ball still in the air would cross this bot's contact plane, if it gets there
## before bouncing, at a height it can volley, and close enough to step across to.
## Returns Vector3.INF when there is no such volley (or a volley would be illegal).
func _air_intercept(view: MatchView) -> Vector3:
    if view.phase != RallyState.Phase.OPEN_RALLY or CourtDimensions.inside_kitchen(view.my_position):
        return Vector3.INF
    var ghost := BallState.new()
    ghost.position = view.ball_position
    ghost.velocity = view.ball_velocity
    ghost.spin = view.ball_spin
    ghost.moving = true
    var plane: float = (view.my_position.z - side * tuning.contact_lead) * side
    var t: float = 0.0
    while ghost.moving and t < 2.5:
        if ghost.step(MatchSimulation.DT, tuning) != BallState.Event.NONE:
            return Vector3.INF # bounced or netted first
        t += MatchSimulation.DT
        if ghost.position.z * side >= plane:
            var height_ok: bool = ghost.position.y >= VOLLEY_MIN_HEIGHT and ghost.position.y <= VOLLEY_MAX_HEIGHT
            var step_across: float = absf(ghost.position.x - side * VOLLEY_STANCE - view.my_position.x)
            if height_ok and step_across <= tuning.sprint_speed * t + 0.3:
                return ghost.position
            return Vector3.INF
    return Vector3.INF

## Where to stand: a little past the spot the ball will land, along its line of flight.
func _setup_spot(view: MatchView) -> Vector3:
    var ghost := BallState.new()
    ghost.position = view.ball_position
    ghost.velocity = view.ball_velocity
    ghost.spin = view.ball_spin
    ghost.moving = true
    var landed: Dictionary = ghost.predict_landing(tuning, MatchSimulation.DT)
    var landing: Vector3 = landed["position"]
    landing.y = 0.0
    var along := Vector3(view.ball_velocity.x, 0.0, view.ball_velocity.z)
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
    return Vector3(_away_from(view) * 2.6, 0.0, -side * 5.6)

## Short, into the opponent's kitchen, away from them.
func _dink_target(view: MatchView) -> Vector3:
    return Vector3(_away_from(view) * 1.6, 0.0, -side * 1.4)

## Deep over an opponent at the net.
func _lob_target(view: MatchView) -> Vector3:
    return Vector3(_away_from(view) * 1.5, 0.0, -side * 5.0)

func _away_from(view: MatchView) -> float:
    return -1.0 if view.opponent_position.x >= 0.0 else 1.0

func _scatter(target: Vector3, amount: float) -> Vector3:
    var angle: float = _rng.randf() * TAU
    var radius: float = _rng.randf() * aim_error * amount
    var aim: Vector3 = target + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
    var edge: float = 0.05 # a player always aims inside the opponent's court
    aim.x = clampf(aim.x, -CourtDimensions.HALF_WIDTH + edge, CourtDimensions.HALF_WIDTH - edge)
    var depth: float = clampf(absf(aim.z), SwingContact.MIN_DEPTH, CourtDimensions.HALF_LENGTH - edge)
    aim.z = -side * depth
    return aim
