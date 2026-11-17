extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_match_simulation.gd
## The whole match as a pure simulation, and the bot that plays it (RP-025).
const P := RallyState.Phase
const F := RallyState.Fault
const S := MatchSimulation.SwingResult
const DRIVE := PlayerInput.Swing.DRIVE
var errors: Array[String] = []
var checks: int = 0
var tuning := GameplayTuning.new()
var swings: Array = [] ## [side, result] of every swing the sim resolved
var ended: Array[RallyState] = []
var started: int = 0
var finals: Array[MatchScore] = []

func _initialize() -> void:
    var sim: MatchSimulation = _new_sim()

    # Setup: legal serve positions, ball in the server's hand.
    var rally: RallyState = sim.referee.rally
    _assert(sim.tick == 0 and rally.phase == P.WAITING_FOR_SERVE and rally.server_side == 1 and sim.rally_live(), "match starts with home to serve")
    _assert(CourtDimensions.legal_serve_position(sim.positions[1], true, true), "server starts on a legal serve spot")
    _assert(sim.positions[-1].z < 0.0 and sim.positions[-1].x < 0.0, "receiver starts in the diagonal court")
    _assert(not sim.ball.moving and sim.ball.position.distance_to(sim.positions[1] + Vector3(0.35, 1.0, -0.85)) < 0.001, "ball starts in the server's hand")
    sim.step({1: PlayerInput.make(Vector2(1, 0))})
    _assert(sim.tick == 1 and sim.ball.position.distance_to(sim.positions[1] + Vector3(0.35, 1.0, -0.85)) < 0.001, "the server carries the ball while moving")

    # Swings that must be refused.
    var diagonal := Vector3(-1.5, 0.0, -4.6)
    sim.apply_input(-1, PlayerInput.make(Vector2.ZERO, false, DRIVE, Vector3(1.5, 0.0, 4.6)))
    _assert(_last_swing() == [-1, S.NOT_LIVE] and not sim.ball.moving, "the receiver cannot hit the ball out of the server's hand")
    sim.apply_input(1, PlayerInput.make(Vector2.ZERO, false, DRIVE, Vector3(0.0, 0.0, 3.0)))
    _assert(_last_swing() == [1, S.NO_SHOT_OUT] and rally.phase == P.WAITING_FOR_SERVE, "aiming at your own half is refused and is not a serve")
    sim.apply_input(1, PlayerInput.make(Vector2.ZERO, false, DRIVE, Vector3(NAN, 0.0, -4.0)))
    _assert(_last_swing() == [1, S.NO_SHOT_OUT] and not sim.ball.moving, "a nonsense aim point is refused")

    # A legal serve, then the receiver does nothing: double bounce, point to the server.
    sim.apply_input(1, PlayerInput.make(Vector2.ZERO, false, DRIVE, diagonal))
    _assert(_last_swing() == [1, S.HIT] and rally.phase == P.SERVE_IN_FLIGHT and sim.ball.moving, "the serve is hit")
    sim.apply_input(1, PlayerInput.make(Vector2.ZERO, false, DRIVE, diagonal))
    _assert(_last_swing() == [1, S.ALREADY_HIT], "the server cannot hit their own serve again")
    sim.apply_input(-1, PlayerInput.make(Vector2.ZERO, false, DRIVE, Vector3(1.5, 0.0, 4.6)))
    _assert(_last_swing()[1] in [S.WRONG_HALF, S.OUT_OF_REACH] and not rally.is_over(), "the receiver cannot hit a ball that has not reached them")
    _run(sim, 600, func() -> bool: return rally.is_over())
    _assert(rally.fault == F.DOUBLE_BOUNCE and rally.winner_side == 1 and ended.size() == 1, "an unreturned serve ends the rally once")
    _assert(sim.score().score_call() == "1-0" and sim.pause_ticks > 0 and not sim.rally_live() and not sim.ball.moving, "the server scores and the game pauses")
    sim.apply_input(1, PlayerInput.make(Vector2.ZERO, false, DRIVE, diagonal))
    _assert(_last_swing() == [1, S.NOT_LIVE], "no swings between rallies")
    _run(sim, 600, func() -> bool: return sim.rally_live())
    var second: RallyState = sim.referee.rally
    _assert(second != rally and second.server_side == 1 and not second.serve_from_right and started == 2, "next rally: same server, left court")
    _assert(CourtDimensions.legal_serve_position(sim.positions[1], true, false) and sim.positions[-1].x > 0.0, "both players are placed for a left-court serve")

    # Foot fault: walk into the court and serve. Side-out.
    for i in range(40):
        sim.step({1: PlayerInput.make(Vector2(0, -1), true)})
    sim.apply_input(1, PlayerInput.make(Vector2.ZERO, false, DRIVE, Vector3(1.5, 0.0, -4.6)))
    _assert(second.is_over() and second.fault == F.SERVE_POSITION, "serving from inside the court is a foot fault")
    _assert(sim.score().score_call() == "0-1" and sim.score().server_side == -1, "the fault is a side-out")

    # Movement is capped whatever the input says.
    var before: Vector3 = sim.positions[-1]
    for i in range(60):
        sim.step({-1: PlayerInput.make(Vector2(900, 0), true)})
    _assert(before.distance_to(sim.positions[-1]) <= tuning.sprint_speed + 0.001, "a huge move vector is no faster than a sprint")

    # Two bots play a whole match. Same seeds give the same match, tick for tick.
    var a: MatchSimulation = MatchSimulation.new(tuning)
    var b: MatchSimulation = MatchSimulation.new(tuning)
    var bots_a: Array = [PracticeBot.new(1, tuning, 11), PracticeBot.new(-1, tuning, 22)]
    var bots_b: Array = [PracticeBot.new(1, tuning, 11), PracticeBot.new(-1, tuning, 22)]
    var identical: bool = true
    var limit: int = 60 * 60 * 30 # half an hour of game time
    while not a.is_over() and a.tick < limit:
        _bot_step(a, bots_a)
        _bot_step(b, bots_b)
        identical = identical and a.positions[1] == b.positions[1] and a.positions[-1] == b.positions[-1] and a.ball.position == b.ball.position
    var score: MatchScore = a.score()
    print("bot match: %d ticks (%.0f s), %d rallies, final %d-%d, winner %d" % [a.tick, a.tick / 60.0, score.last_rally_id, score.score_of(1), score.score_of(-1), score.winner_side])
    _assert(a.is_over(), "two bots finish a match to 11 within half an hour of game time")
    _assert(identical and b.is_over() and b.score().score_call() == score.score_call(), "the same seeds replay the same match exactly")
    var top: int = maxi(score.score_of(1), score.score_of(-1))
    var low: int = mini(score.score_of(1), score.score_of(-1))
    _assert(top >= 11 and top - low >= 2 and score.score_of(score.winner_side) == top, "the winner has at least 11 and leads by two")
    _assert(score.last_rally_id >= top + low, "every point came from a counted rally")
    var frozen: Vector3 = a.positions[1]
    var ball_at: Vector3 = a.ball.position
    a.step({1: PlayerInput.make(Vector2(1, 0), true, DRIVE, Vector3(0, 0, -4))})
    _assert(a.positions[1] == frozen and a.ball.position == ball_at and a.score().score_call() == score.score_call(), "nothing moves after the match is over")

    # A different seed plays a different match, and the bot can lose rallies as well as win them.
    var c: MatchSimulation = MatchSimulation.new(tuning, -1)
    var bots_c: Array = [PracticeBot.new(1, tuning, 5), PracticeBot.new(-1, tuning, 6)]
    while not c.is_over() and c.tick < limit:
        _bot_step(c, bots_c)
    print("bot match: %d ticks (%.0f s), %d rallies, final %d-%d, winner %d" % [c.tick, c.tick / 60.0, c.score().last_rally_id, c.score().score_of(1), c.score().score_of(-1), c.score().winner_side])
    _assert(c.is_over(), "a match where away serves first also finishes")
    _assert(c.score().score_of(1) + c.score().score_of(-1) > 11 or c.tick != a.tick, "different seeds give a different match")
    _assert(score.score_of(1) > 0 and score.score_of(-1) > 0, "both bots win points, so neither side is broken")

    if errors.is_empty():
        print("PASS: %d match simulation checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

func _new_sim() -> MatchSimulation:
    var sim := MatchSimulation.new(tuning)
    sim.swing_resolved.connect(func(side: int, result: MatchSimulation.SwingResult, _contact: SwingContact.Contact, _soft: bool) -> void: swings.append([side, result]))
    sim.rally_ended.connect(func(rally: RallyState) -> void: ended.append(rally))
    sim.rally_started.connect(func(_rally: RallyState) -> void: started += 1)
    sim.match_ended.connect(func(final: MatchScore) -> void: finals.append(final))
    started = 1 # the first rally starts inside the constructor, before anyone can listen
    return sim

func _bot_step(sim: MatchSimulation, bots: Array) -> void:
    sim.step({1: bots[0].decide(MatchView.from_simulation(sim, 1)), -1: bots[1].decide(MatchView.from_simulation(sim, -1))})

func _run(sim: MatchSimulation, max_ticks: int, done: Callable) -> void:
    for i in range(max_ticks):
        if done.call():
            return
        sim.step({})

func _last_swing() -> Array:
    return swings[-1] if not swings.is_empty() else []

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
