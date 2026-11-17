extends Node
## A full local singles match against the bot. The MatchSimulation owns the game; this
## scene feeds it the local player's input and the bot's, steps it once per physics tick,
## and shows the result on the MatchCourt.
@export var tuning: GameplayTuning = preload("res://config/gameplay_tuning.tres")
@export var points_to_win: int = 11
@export var win_by: int = 2
@export var bot_seed: int = 1
@export var autoplay: bool = false ## a second bot plays the home side (demo and tests)
@onready var court: MatchCourt = $MatchCourt
var sim: MatchSimulation
var opponent: PracticeBot
var stand_in: PracticeBot
var matches_started: int = 0
var _awaiting_landing: bool = false

func _ready() -> void:
    court.tuning = tuning
    court.rematch_requested.connect(_on_rematch_requested)
    start_match()

func start_match() -> void:
    matches_started += 1
    sim = MatchSimulation.new(tuning, 1, points_to_win, win_by)
    sim.swing_resolved.connect(_on_swing_resolved)
    sim.ball_bounced.connect(_on_ball_bounced)
    sim.rally_started.connect(_on_rally_started)
    sim.rally_ended.connect(_on_rally_ended)
    sim.match_ended.connect(_on_match_ended)
    # A new seed each rematch so the bot does not replay the same match.
    opponent = PracticeBot.new(-1, tuning, bot_seed + matches_started)
    stand_in = PracticeBot.new(1, tuning, bot_seed + 1000 + matches_started)
    court.preview.hide_landing()
    court.show_status("First to %d, win by %d. You serve first." % [points_to_win, win_by])
    _show()

func _physics_process(_delta: float) -> void:
    var mine: PlayerInput = stand_in.decide(MatchView.from_simulation(sim, 1)) if autoplay else court.take_input()
    sim.step({1: mine, -1: opponent.decide(MatchView.from_simulation(sim, -1))})
    _show()

func _show() -> void:
    court.show_world(sim.positions[1], sim.positions[-1], sim.ball.position)
    court.show_aim(MatchView.from_simulation(sim, 1))
    var score: MatchScore = sim.score()
    court.show_score(RallyText.score_line(score.score_of(1), score.score_of(-1), score.server_side, score.serve_from_right(), 1))

func _on_swing_resolved(side: int, result: MatchSimulation.SwingResult, contact: SwingContact.Contact, soft: bool) -> void:
    if side != 1:
        return
    court.show_status(RallyText.swing(result, soft, contact.label() if contact != null else ""))
    if result == MatchSimulation.SwingResult.HIT:
        _awaiting_landing = true
        court.preview.hide_landing()

func _on_ball_bounced(at: Vector3) -> void:
    if _awaiting_landing:
        _awaiting_landing = false
        court.preview.show_landing(at)

func _on_rally_started(rally: RallyState) -> void:
    court.show_status("%s to serve." % ("You are" if rally.server_side == 1 else "Opponent is"))

func _on_rally_ended(rally: RallyState) -> void:
    _awaiting_landing = false
    court.show_status(RallyText.fault(rally, 1))

func _on_match_ended(score: MatchScore) -> void:
    court.show_status("%s  Final score %d – %d.  Press %s for a rematch." % [
        RallyText.match_result(score.winner_side, 1), score.score_of(1), score.score_of(-1), GameInput.label(GameInput.RESET_BALL)])

func _on_rematch_requested() -> void:
    if sim.is_over():
        start_match()
