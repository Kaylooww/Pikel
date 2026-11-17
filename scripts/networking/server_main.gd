extends Node
## Entry point of the dedicated match server. Run it headless with tools/run_server.ps1
## (or .sh), which passes options such as --port=7777 after a `--` separator.
## It has no window and draws nothing; it only runs the MatchServer and logs what happens.
@onready var link: NetLink = $NetLink
@onready var server: MatchServer = $MatchServer

func _ready() -> void:
    NetConfig.read_command_line()
    Engine.physics_ticks_per_second = MatchSimulation.TICK_RATE
    server.link = link
    server.port = NetConfig.port
    server.points_to_win = NetConfig.points_to_win
    server.win_by = NetConfig.win_by
    server.fill_with_bot = NetConfig.fill_with_bot
    server.match_code = NetConfig.match_code
    server.match_started.connect(_on_match_started)
    server.match_finished.connect(_on_match_finished)
    var error: Error = server.listen()
    if error != OK:
        printerr("SERVER could not listen on port %d (error %d). Is another server already running?" % [server.port, error])
        get_tree().quit(1)
        return
    print("SERVER listening on port %d, protocol v%d, %d ticks per second, first to %d win by %d%s" % [
        server.port, NetProtocol.VERSION, MatchSimulation.TICK_RATE, server.points_to_win, server.win_by,
        ", empty seat filled by a bot" if server.fill_with_bot else ""])
    print("SERVER match code: %s   (players type this next to the address)" % server.match_code)

func _on_match_started(id: int) -> void:
    print("SERVER match %d started with %d player(s)" % [id, server.seats.size()])

func _on_match_finished(score: MatchScore) -> void:
    print("SERVER FINAL %d-%d winner=%d match=%d ticks=%d rejected_inputs=%d" % [
        score.score_of(1), score.score_of(-1), score.winner_side, server.match_id, server.sim.tick, server.rejected_inputs])
    if NetConfig.exit_on_match_end:
        await get_tree().create_timer(1.0).timeout # let the final reliable messages go out
        get_tree().quit(0)
