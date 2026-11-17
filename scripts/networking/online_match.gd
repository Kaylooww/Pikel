extends Node
## A singles match played against another person through a MatchServer. This scene decides
## nothing about the game: it sends the local player's input, and draws what the server
## reports (this player predicted, the opponent and ball slightly in the past).
## The scene root must be named "NetGame" so its NetLink has the same path as the server's.
@onready var court: MatchCourt = $MatchCourt
@onready var link: NetLink = $NetLink
@onready var client: MatchClient = $MatchClient
var bot: PracticeBot

func _ready() -> void:
    NetConfig.read_command_line()
    client.link = link
    client.tuning = court.tuning
    client.joined.connect(_on_joined)
    client.event.connect(_on_event)
    client.failed.connect(_on_failed)
    court.show_score("ONLINE MATCH")
    court.show_status("Connecting to %s:%d …" % [NetConfig.host, NetConfig.port])
    var error: Error = client.join(NetConfig.host, NetConfig.port)
    if error != OK:
        _on_failed("Could not start a connection (error %d)." % error)

func _physics_process(_delta: float) -> void:
    client.tick()
    if client.status == MatchClient.Status.WAITING_FOR_MATCH:
        court.show_status("Connected. Waiting for an opponent …")
    var view: MatchView = client.view()
    if view == null:
        return
    if client.can_play():
        client.send(bot.decide(view) if NetConfig.autoplay else court.take_input())
    var ball: Vector3 = client.shown_ball()
    if view.phase == RallyState.Phase.WAITING_FOR_SERVE and view.server_side == client.side:
        ball = MatchSimulation.hand_position(client.shown_position(client.side), client.side) # keep the ball in the hand we draw
    court.show_world(client.shown_position(1), client.shown_position(-1), ball)
    court.show_aim(view)
    var snapshot: NetSnapshot = client.latest
    court.show_score(RallyText.score_line(snapshot.home_points, snapshot.away_points, snapshot.server_side, snapshot.serve_from_right, client.side))

func _on_joined(side: int) -> void:
    court.play_as(side)
    bot = PracticeBot.new(side, court.tuning, NetConfig.bot_seed)
    court.show_status("Match found. You play from the %s end. First to %d, win by %d." % ["near" if side == 1 else "far", client.points_to_win, client.win_by])

func _on_event(type: NetProtocol.EventType, payload: Array) -> void:
    match type:
        NetProtocol.EventType.RALLY_STARTED:
            court.show_status("%s to serve." % ("You are" if payload[1] == client.side else "Opponent is"))
        NetProtocol.EventType.SWING:
            if payload[0] == client.side:
                court.show_status(RallyText.swing(payload[1], payload[2], payload[3]))
        NetProtocol.EventType.RALLY_ENDED:
            court.show_status(RallyText.fault_text(payload[1], payload[3], payload[4], client.side))
        NetProtocol.EventType.MATCH_ENDED:
            court.show_status("%s  Final score %s.  A rematch starts in 10 seconds." % [
                RallyText.match_result(payload[0], client.side), _score_text(payload[1], payload[2])])
            print("CLIENT side=%d FINAL %d-%d winner=%d snapshots=%d corrections=%d/%d" % [
                client.side, payload[1], payload[2], payload[0], client.snapshots_received, client.prediction.corrections, client.prediction.reconciles])
            _quit_if_automated(0)
        NetProtocol.EventType.MATCH_ABORTED:
            court.show_status("%s Waiting for a new opponent …" % payload[0])

func _on_failed(reason: String) -> void:
    court.show_status("%s Press %s for the menu." % [reason, GameInput.label(GameInput.MENU_BACK)])
    printerr("CLIENT FAILED: ", reason)
    _quit_if_automated(1)

func _score_text(home_points: int, away_points: int) -> String:
    return "%d – %d" % ([home_points, away_points] if client.side == 1 else [away_points, home_points])

func _quit_if_automated(code: int) -> void:
    if NetConfig.exit_on_match_end:
        await get_tree().create_timer(0.5).timeout
        get_tree().quit(code)
