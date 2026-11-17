extends Node
class_name MatchServer
## The authority for one online singles match. It owns the MatchSimulation, steps it at a
## fixed 60 ticks per second, and is the only thing that decides positions, hits, faults
## and score. Clients send input requests; it sends back snapshots and events.
##
## What it will not accept from a client:
##   - anything before a correct `hello` (wrong protocol version is disconnected)
##   - a third player (seats are home and away only)
##   - input for a side the sender does not own: the side comes from who sent it, never from the message
##   - malformed input, input for another match, or old/repeated sequence numbers
##   - more than one input per tick on average (a short burst is allowed to catch up after jitter)
##
## shortcut: one match per server process, no accounts, no reconnect, no serve clock. Those
## are RP-034/RP-035. Run it on a trusted LAN only.

signal match_started(id: int)
signal match_finished(score: MatchScore)

const MAX_BURST: float = 4.0 ## inputs a player may have applied in one tick after a quiet spell
const MAX_QUEUE: int = 16 ## inputs kept waiting per player; older ones are dropped
const HELLO_TIMEOUT_TICKS: int = 300 ## a connection that has not said hello after 5 s is dropped
const REMATCH_DELAY_TICKS: int = 600 ## after a match, the same players start again 10 s later
const MAX_CONNECTIONS: int = 4 ## two players plus room to turn extra connections away politely
const REFUSAL_GAP_TICKS: int = 15 ## at most one "your swing missed" message per player per quarter second

@export var port: int = NetProtocol.DEFAULT_PORT
@export var points_to_win: int = 11
@export var win_by: int = 2
@export var fill_with_bot: bool = false ## start with one human and a bot in the other seat
@export var snapshot_every: int = 2 ## ticks between snapshots (2 = 30 per second)
@export var tuning: GameplayTuning = preload("res://config/gameplay_tuning.tres")

var link: NetLink ## set by the owner before listen(); with no link nothing is sent (unit tests)
var match_id: int = 0
var sim: MatchSimulation
var seats: Dictionary = {} ## peer id -> side
var bot: PracticeBot
var bot_side: int = 0
var rejected_inputs: int = 0
var dropped_inputs: int = 0
var events_sent: Array[Array] = [] ## every event of the current match, as sent
var _queues: Dictionary = {1: [], -1: []}
var _budget: Dictionary = {1: 0.0, -1: 0.0}
var _last_seq: Dictionary = {1: 0, -1: 0} ## highest sequence number received per side
var _acked: Dictionary = {1: 0, -1: 0} ## highest sequence number applied per side
var _silent: Dictionary = {} ## peer id -> ticks connected without a hello
var _next_event_id: int = 0
var _rematch_wait: int = 0
var _last_refusal: Dictionary = {1: -1000, -1: -1000} ## side -> tick of the last refused-swing message

func listen() -> Error:
    var peer := ENetMultiplayerPeer.new()
    var error: Error = peer.create_server(port, MAX_CONNECTIONS)
    if error != OK:
        return error
    multiplayer.multiplayer_peer = peer
    (multiplayer as SceneMultiplayer).server_relay = false # clients talk to the server only, never to each other
    multiplayer.peer_connected.connect(on_peer_connected)
    multiplayer.peer_disconnected.connect(on_peer_disconnected)
    link.hello_received.connect(on_hello)
    link.input_received.connect(on_input)
    return OK

func _physics_process(_delta: float) -> void:
    tick()

func _exit_tree() -> void:
    if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
        multiplayer.multiplayer_peer.close()

func on_peer_connected(peer_id: int) -> void:
    _silent[peer_id] = 0

func on_peer_disconnected(peer_id: int) -> void:
    _silent.erase(peer_id)
    if seats.has(peer_id):
        seats.erase(peer_id)
        if sim != null:
            _send_event(NetProtocol.EventType.MATCH_ABORTED, ["A player left the match."])
            sim = null

func on_hello(peer_id: int, version: int) -> void:
    if seats.has(peer_id):
        return
    var side: int = _free_side()
    if version != NetProtocol.VERSION or side == 0:
        _kick(peer_id)
        return
    _silent.erase(peer_id)
    seats[peer_id] = side
    _start_if_ready()

func on_input(peer_id: int, data: Variant) -> void:
    if sim == null or not seats.has(peer_id):
        rejected_inputs += 1
        return
    var side: int = seats[peer_id]
    var input: PlayerInput = NetProtocol.decode_input(data, match_id)
    if input == null or input.seq <= _last_seq[side] or input.seq > _last_seq[side] + NetProtocol.MAX_SEQ_JUMP:
        rejected_inputs += 1
        return
    _last_seq[side] = input.seq
    var queue: Array = _queues[side]
    queue.append(input)
    if queue.size() > MAX_QUEUE:
        queue.pop_front()
        dropped_inputs += 1

## One server tick. Applies what each player is allowed, advances the world, sends snapshots.
func tick() -> void:
    for peer_id: int in _silent.keys():
        _silent[peer_id] += 1
        if _silent[peer_id] > HELLO_TIMEOUT_TICKS:
            _silent.erase(peer_id)
            _kick(peer_id)
    if sim == null:
        return
    if sim.is_over():
        _rematch_wait -= 1
        if _rematch_wait <= 0:
            sim = null
            _start_if_ready()
        return
    for side: int in MatchSimulation.SIDES:
        if side == bot_side:
            sim.apply_input(side, bot.decide(MatchView.from_simulation(sim, side)))
            continue
        # No input, no movement: a player is moved exactly once per input they sent, so the
        # client's prediction and the server agree. The budget stops anyone sending faster than real time.
        _budget[side] = minf(_budget[side] + 1.0, MAX_BURST)
        var queue: Array = _queues[side]
        while _budget[side] >= 1.0 and not queue.is_empty():
            var input: PlayerInput = queue.pop_front()
            sim.apply_input(side, input)
            _acked[side] = input.seq
            _budget[side] -= 1.0
    sim.advance()
    if sim.tick % snapshot_every == 0 or sim.is_over():
        _send_snapshots()

func _free_side() -> int:
    for side: int in MatchSimulation.SIDES:
        if side != bot_side and not seats.values().has(side):
            return side
    return 0

func _start_if_ready() -> void:
    if sim != null or seats.is_empty() or (seats.size() < 2 and not fill_with_bot):
        return
    match_id = match_id + 1 if match_id != 0 else randi_range(1000, 999999)
    sim = MatchSimulation.new(tuning, 1, points_to_win, win_by)
    sim.rally_started.connect(_on_rally_started)
    sim.swing_resolved.connect(_on_swing_resolved)
    sim.rally_ended.connect(_on_rally_ended)
    sim.match_ended.connect(_on_match_ended)
    bot_side = 0
    bot = null
    if seats.size() < 2:
        bot_side = _free_side()
        bot = PracticeBot.new(bot_side, tuning, match_id)
    events_sent.clear()
    for side: int in MatchSimulation.SIDES:
        (_queues[side] as Array).clear()
        _budget[side] = 0.0
        _last_refusal[side] = -1000
        _last_seq[side] = 0
        _acked[side] = 0
    if link != null:
        for peer_id: int in seats:
            link.welcome.rpc_id(peer_id, NetProtocol.encode_welcome(match_id, seats[peer_id], points_to_win, win_by))
    match_started.emit(match_id)
    _on_rally_started(sim.referee.rally) # the first rally began inside the constructor, before anyone could listen
    _send_snapshots()

func _send_snapshots() -> void:
    if link == null:
        return
    for peer_id: int in seats:
        link.snapshot.rpc_id(peer_id, NetProtocol.encode_snapshot(sim, match_id, _acked[seats[peer_id]]))

## Sends to both players, or only to the player on `only_side` when that is not 0.
func _send_event(type: NetProtocol.EventType, payload: Array, only_side: int = 0) -> void:
    _next_event_id += 1
    var data: Array = NetProtocol.encode_event(_next_event_id, match_id, type, payload)
    events_sent.append(data)
    if link != null:
        for peer_id: int in seats:
            if only_side == 0 or seats[peer_id] == only_side:
                link.game_event.rpc_id(peer_id, data)

func _kick(peer_id: int) -> void:
    if is_inside_tree() and multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(peer_id):
        multiplayer.multiplayer_peer.disconnect_peer(peer_id)

func _on_rally_started(rally: RallyState) -> void:
    _send_event(NetProtocol.EventType.RALLY_STARTED, [rally.rally_id, rally.server_side, rally.serve_from_right])

func _on_swing_resolved(side: int, result: MatchSimulation.SwingResult, contact: SwingContact.Contact, soft: bool) -> void:
    var payload: Array = [side, int(result), soft, contact.label() if contact != null else ""]
    if result == MatchSimulation.SwingResult.HIT:
        _send_event(NetProtocol.EventType.SWING, payload)
    elif result != MatchSimulation.SwingResult.NOT_LIVE and result != MatchSimulation.SwingResult.ALREADY_HIT and sim.tick - _last_refusal[side] >= REFUSAL_GAP_TICKS:
        # Only the player who swung needs to know why it missed, and not sixty times a second.
        _last_refusal[side] = sim.tick
        _send_event(NetProtocol.EventType.SWING, payload, side)

func _on_rally_ended(rally: RallyState) -> void:
    var score: MatchScore = sim.score()
    _send_event(NetProtocol.EventType.RALLY_ENDED, [rally.rally_id, int(rally.fault), rally.fault_side, rally.winner_side, rally.serve_from_right, score.score_of(1), score.score_of(-1)])

func _on_match_ended(score: MatchScore) -> void:
    _send_event(NetProtocol.EventType.MATCH_ENDED, [score.winner_side, score.score_of(1), score.score_of(-1)])
    _rematch_wait = REMATCH_DELAY_TICKS
    match_finished.emit(score)
