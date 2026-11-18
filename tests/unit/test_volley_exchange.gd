extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_volley_exchange.gd
## Volley exchanges in the match simulation: a drive volleyed back with a well-timed tap dink,
## the answer volleyed again, a mistimed press missing the ball and losing the rally, and the
## kitchen and two-bounce rules still applying to volleys.
const P := RallyState.Phase
const F := RallyState.Fault
const S := MatchSimulation.SwingResult
const SW := PlayerInput.Swing
var errors: Array[String] = []
var checks: int = 0
var tuning := GameplayTuning.new()
var swings: Array = [] ## [side, result, shot kind]

func _initialize() -> void:
    # A drives at B, who stands just behind the kitchen line.
    var sim: MatchSimulation = _open_rally(Vector3(0.0, 0.0, 2.8), Vector3(0.0, 0.0, -2.8))
    var rally: RallyState = sim.referee.rally
    _swing(sim, 1, SW.DRIVE, Vector3(0.4, 0.0, -5.0), 0.6)
    _assert(_last() == [1, S.HIT, ShotRecipe.Kind.DRIVE] and sim.ball.spin > 0.0, "A's drive is hit with topspin")

    # B taps a dink as the ball arrives, before it bounces: a volley back toward B's aim.
    var aim_b := Vector3(-0.8, 0.0, 5.0)
    _assert(_wait_for_contact(sim, -1, 0.02), "the drive reaches B in the air")
    _assert(rally.bounces_since_hit == 0, "it has not bounced")
    _swing(sim, -1, SW.DINK, aim_b)
    _assert(_last() == [-1, S.HIT, ShotRecipe.Kind.DINK], "B's well-timed tap volleys it back")
    _assert(rally.last_hitter == -1 and not rally.is_over() and sim.ball.velocity.z > 0.0, "the rally goes on, the ball heading to A")
    var landing: Dictionary = sim.ball.predict_landing(tuning)
    _assert(Vector2(landing["position"].x - aim_b.x, landing["position"].z - aim_b.z).length() < 0.05, "the volley flies toward where B's mouse points")

    # A must time their own dink to keep it going.
    _assert(_wait_for_contact(sim, 1, 0.03), "B's volley reaches A in the air")
    _swing(sim, 1, SW.DINK, Vector3(0.6, 0.0, -5.0))
    _assert(_last() == [1, S.HIT, ShotRecipe.Kind.DINK] and not rally.is_over(), "A volleys it back: the exchange continues")

    # B presses far too early: the paddle misses, and B cannot swing again straight away.
    _assert(_wait_for_contact(sim, -1, tuning.volley_dink_window + 0.04), "A's volley comes within B's reach")
    _swing(sim, -1, SW.DINK, aim_b)
    _assert(_last()[1] == S.MISTIMED and rally.last_hitter == 1 and sim.ball.velocity.z < 0.0, "B's early press misses the ball: it flies on")
    sim.advance()
    _swing(sim, -1, SW.DINK, aim_b)
    _assert(_last()[1] == S.RECOVERING and rally.last_hitter == 1, "a second press straight after a miss does nothing")
    for i in range(600):
        if rally.is_over():
            break
        sim.step({})
    _assert(rally.is_over() and rally.winner_side == 1 and rally.fault_side == -1, "the mistimed volley loses B the rally")

    # A late press also misses.
    sim = _open_rally(Vector3(0.0, 0.0, 2.8), Vector3(0.0, 0.0, -2.8))
    _swing(sim, 1, SW.DINK, Vector3(0.4, 0.0, -5.0))
    _assert(_wait_for_contact(sim, -1, -tuning.volley_dink_window - 0.04), "the ball goes past B's ideal contact point")
    _swing(sim, -1, SW.DINK, aim_b)
    _assert(_last()[1] == S.MISTIMED or _last()[1] == S.OUT_OF_REACH, "a late press misses too")
    _assert(sim.referee.rally.last_hitter == 1, "and the ball is not returned")

    # A block soaks up a hard drive and drops it short, and is easier to time.
    sim = _open_rally(Vector3(0.0, 0.0, 2.8), Vector3(0.0, 0.0, -2.8))
    _swing(sim, 1, SW.DRIVE, Vector3(0.4, 0.0, -5.0), 1.0)
    var drive_speed: float = sim.ball.velocity.length()
    _assert(_wait_for_contact(sim, -1, tuning.volley_dink_window + 0.03), "the hard drive arrives")
    _swing(sim, -1, SW.BLOCK, Vector3(0.0, 0.0, 6.0))
    _assert(_last() == [-1, S.HIT, ShotRecipe.Kind.BLOCK], "a block pressed outside the dink window still connects")
    landing = sim.ball.predict_landing(tuning)
    _assert(sim.ball.velocity.length() < drive_speed * 0.6 and absf(landing["position"].z) <= tuning.block_max_depth + 0.01, "the block kills the pace and lands short")

    # Wrong side on a volley: it connects, but weaker.
    sim = _open_rally(Vector3(0.0, 0.0, 2.8), Vector3(0.0, 0.0, -2.8))
    _swing(sim, 1, SW.DRIVE, Vector3(0.6, 0.0, -5.0), 0.6)
    _assert(_wait_for_contact(sim, -1, 0.02), "the drive arrives again")
    var needed: SwingContact.Stroke = SwingContact.needed_stroke(sim.positions[-1], sim.ball.position, -1, tuning)
    var wrong: SwingContact.Stroke = SwingContact.Stroke.FOREHAND if needed == SwingContact.Stroke.BACKHAND else SwingContact.Stroke.BACKHAND
    sim.apply_input(-1, PlayerInput.make(Vector2.ZERO, false, SW.DINK, aim_b, 0, 0.0, wrong))
    _assert(_last()[1] != S.HIT or sim.ball.velocity.length() < tuning.volley_dink_speed * 1.2, "a wrong-side volley is no stronger than a clean one")

    # Rules still apply: no volleying from inside the kitchen.
    sim = _open_rally(Vector3(0.0, 0.0, 2.8), Vector3(0.0, 0.0, -1.8))
    _swing(sim, 1, SW.DINK, Vector3(0.0, 0.0, -5.0))
    _assert(_wait_for_contact(sim, -1, 0.02), "the ball reaches B, who is standing in the kitchen")
    _swing(sim, -1, SW.DINK, aim_b)
    _assert(sim.referee.rally.is_over() and sim.referee.rally.fault == F.KITCHEN_VOLLEY and sim.referee.rally.fault_side == -1, "a volley from the kitchen is a fault")

    # And the two-bounce rule: the return of serve may not be volleyed.
    sim = MatchSimulation.new(tuning)
    sim.swing_resolved.connect(_record)
    sim.positions[-1] = Vector3(-1.5, 0.0, -2.8)
    sim.apply_input(1, PlayerInput.make(Vector2.ZERO, false, SW.DRIVE, Vector3(-1.5, 0.0, -4.6), 0, 0.2, SwingContact.Stroke.FOREHAND))
    _assert(sim.referee.rally.phase == P.SERVE_IN_FLIGHT, "the serve is in the air")
    if _wait_for_contact(sim, -1, 0.02) and sim.referee.rally.bounces_since_hit == 0:
        _swing(sim, -1, SW.DINK, aim_b)
        _assert(sim.referee.rally.fault == F.VOLLEY_BEFORE_BOUNCE, "volleying the serve breaks the two-bounce rule")
    else:
        _assert(false, "the serve should reach a receiver at the kitchen line in the air")

    # The bot volleys too: put it at the net and drive at it.
    var volleyed: bool = false
    for seed in range(1, 9):
        sim = _open_rally(Vector3(0.0, 0.0, 2.8), Vector3(0.0, 0.0, -2.8))
        var bot := PracticeBot.new(-1, tuning, seed)
        bot.reaction_ticks = 0
        _swing(sim, 1, SW.DRIVE, Vector3(0.3, 0.0, -5.5), 0.3)
        for i in range(90):
            sim.step({-1: bot.decide(MatchView.from_simulation(sim, -1))})
            if sim.referee.rally.last_hitter == -1 or sim.referee.rally.is_over():
                break
        var rally_now: RallyState = sim.referee.rally
        if rally_now.last_hitter == -1 and rally_now.log.size() >= 2 and rally_now.log[-1].type == RallyEvent.Type.HIT and rally_now.log[-2].type == RallyEvent.Type.HIT:
            volleyed = true
            break
    _assert(volleyed, "the bot volleys a drive when it is at the net")

    if errors.is_empty():
        print("PASS: %d volley exchange checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

## A rally in open play with the ball sitting in A's (home) hand, ready for A's ground stroke.
func _open_rally(home: Vector3, away: Vector3) -> MatchSimulation:
    var sim := MatchSimulation.new(tuning)
    sim.swing_resolved.connect(_record)
    sim.positions[1] = home
    sim.positions[-1] = away
    var rally: RallyState = sim.referee.rally
    rally.phase = P.OPEN_RALLY
    rally.last_hitter = -1
    rally.bounces_since_hit = 1 # B's last shot bounced on A's side
    sim.ball.place(home + Vector3(0.5, 1.0, -0.4))
    return sim

## Swings for `side` at the ball with the right forehand/backhand for where it is.
func _swing(sim: MatchSimulation, side: int, kind: PlayerInput.Swing, aim: Vector3, charge: float = 0.0) -> void:
    var stroke: SwingContact.Stroke = SwingContact.needed_stroke(sim.positions[side], sim.ball.position, side, tuning)
    if stroke == SwingContact.Stroke.NONE:
        stroke = SwingContact.Stroke.FOREHAND
    sim.apply_input(side, PlayerInput.make(Vector2.ZERO, false, kind, aim, 0, charge, stroke))

## Steps the world until the ball, flying at `side`, is `seconds` from that player's ideal
## contact (negative: past it) and within reach. False if that never happens.
func _wait_for_contact(sim: MatchSimulation, side: int, seconds: float) -> bool:
    for i in range(240):
        var contact: SwingContact.Contact = SwingContact.evaluate(sim.positions[side], sim.ball.position, sim.ball.velocity, side, tuning)
        if contact.approaching and contact.in_reach and contact.seconds_early <= seconds:
            return true
        if sim.referee.rally.is_over() or not sim.ball.moving:
            return false
        sim.advance()
    return false

func _record(side: int, result: MatchSimulation.SwingResult, _contact: SwingContact.Contact, shot: ShotRecipe.Kind) -> void:
    swings.append([side, result, shot])

func _last() -> Array:
    return swings[-1] if not swings.is_empty() else []

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
