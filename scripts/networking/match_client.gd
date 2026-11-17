extends Node
class_name MatchClient
## One player's connection to a MatchServer. It sends that player's inputs, predicts their
## own movement so it feels instant, and keeps the server's snapshots for drawing everything
## else slightly in the past. It never decides a hit, a fault or the score: those only ever
## arrive from the server, as snapshots and events.
##
## If the connection drops after the server has given this player a seat, the client keeps
## trying to get back for RECONNECT_TICKS and shows the seat ticket from its welcome; the
## server puts it back in the same match if the seat is still being kept.

signal joined(side: int) ## the server started a match and gave this client a side
signal event(type: NetProtocol.EventType, payload: Array)
signal notice(text: String) ## connection news worth showing: lost, reconnecting, back
signal failed(reason: String) ## could not connect, was refused, or the server went away for good

enum Status { OFFLINE, CONNECTING, WAITING_FOR_MATCH, PLAYING, RECONNECTING }
const CONNECT_TIMEOUT_TICKS: int = 480 ## give up after 8 seconds; ENet alone would keep trying for about 30
const RECONNECT_TICKS: int = 1200 ## after a drop, keep trying for 20 seconds (as long as the server keeps the seat)
const RETRY_TICKS: int = 120 ## one new connection attempt every 2 seconds

@export var tuning: GameplayTuning = preload("res://config/gameplay_tuning.tres")
var link: NetLink ## set by the owner before join()
var status: Status = Status.OFFLINE
var side: int = 0
var match_id: int = 0
var points_to_win: int = 11
var win_by: int = 2
var latest: NetSnapshot ## newest snapshot of the current match, or null
var paused: bool = false ## the server is holding the match still for a dropped opponent
var prediction: ClientPrediction
var interpolator := SnapshotInterpolator.new()
var snapshots_received: int = 0
var snapshots_ignored: int = 0 ## malformed, for another match, or not newer than the newest
var _seq: int = 0
var _last_event_id: int = 0
var _connecting_ticks: int = 0
var _host: String = ""
var _port: int = 0
var _code: String = "" ## private match code given to join()
var _token: String = "" ## seat ticket from the last welcome; "" until the server has seated us in a match
var _reconnect_ticks: int = 0
var _resuming: bool = false ## the next welcome may be our old match coming back

func join(host: String, port: int, code: String = "") -> Error:
    _host = host
    _port = port
    _code = code
    var error: Error = _open()
    if error != OK:
        return error
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.connection_failed.connect(_on_lost.bind("Could not reach the server."))
    multiplayer.server_disconnected.connect(_on_lost.bind("The server closed the connection."))
    link.welcome_received.connect(_on_welcome)
    link.snapshot_received.connect(_on_snapshot)
    link.event_received.connect(_on_event)
    link.refused_received.connect(_on_refused)
    status = Status.CONNECTING
    return OK

func leave() -> void:
    if status != Status.OFFLINE and is_inside_tree() and multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
    status = Status.OFFLINE
    _token = ""

## Going back to the menu must not leave a connection open behind the player's back.
func _exit_tree() -> void:
    leave()

## True while there is a match to send input to.
func can_play() -> bool:
    return status == Status.PLAYING and latest != null and latest.winner_side == 0 and not paused

## Sends one tick's input and predicts its effect on this player's own position.
func send(input: PlayerInput) -> void:
    if not can_play():
        return
    _seq += 1
    input.seq = _seq
    link.submit_input.rpc_id(1, NetProtocol.encode_input(match_id, input))
    prediction.apply_local(input)

## Call once per physics tick.
func tick() -> void:
    if status == Status.CONNECTING:
        _connecting_ticks += 1
        if _connecting_ticks > CONNECT_TIMEOUT_TICKS:
            leave()
            failed.emit("No server answered at that address.")
    elif status == Status.RECONNECTING:
        _reconnect_ticks += 1
        if _reconnect_ticks > RECONNECT_TICKS:
            leave()
            failed.emit("Lost the connection to the server.")
        elif _reconnect_ticks % RETRY_TICKS == 1:
            _open()
    interpolator.advance()
    if prediction != null:
        prediction.decay(MatchSimulation.DT)

## Where to draw `for_side`: this player predicted, everyone else interpolated.
func shown_position(for_side: int) -> Vector3:
    if for_side == side and prediction != null and prediction.has_state:
        return prediction.render_position()
    var sample: Dictionary = interpolator.sample()
    return sample.get("home" if for_side == 1 else "away", Vector3.ZERO)

func shown_ball() -> Vector3:
    return interpolator.sample().get("ball", Vector3.ZERO)

## The freshest known state as this player sees it, for the aim hints and for bots.
func view() -> MatchView:
    if latest == null:
        return null
    return latest.to_view(side, prediction.position if prediction.has_state else latest.position_of(side))

## Starts one connection attempt, dropping whatever is left of an earlier one.
func _open() -> Error:
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
    var peer := ENetMultiplayerPeer.new()
    var error: Error = peer.create_client(_host, _port)
    if error == OK:
        multiplayer.multiplayer_peer = peer
    return error

func _on_connected() -> void:
    status = Status.WAITING_FOR_MATCH
    NetProtocol.set_timeouts(multiplayer.multiplayer_peer, 1)
    link.hello.rpc_id(1, NetProtocol.VERSION, _token, _code)

func _on_lost(reason: String) -> void:
    if status == Status.OFFLINE or status == Status.RECONNECTING:
        return # we closed it ourselves, or one retry failed and tick() will make the next
    if _token != "":
        status = Status.RECONNECTING
        _reconnect_ticks = 0
        _resuming = true
        notice.emit("Connection lost. Trying to reconnect …")
        return
    status = Status.OFFLINE
    failed.emit(reason)

func _on_refused(reason: int) -> void:
    leave()
    match reason:
        NetProtocol.Refusal.VERSION: failed.emit("This game and the server are different versions.")
        NetProtocol.Refusal.FULL: failed.emit("That server already has two players.")
        NetProtocol.Refusal.CODE: failed.emit("Wrong match code. Ask the host for the code their server printed.")
        _: failed.emit("The server refused the connection.")

func _on_welcome(data: Array) -> void:
    var welcome: Dictionary = NetProtocol.decode_welcome(data)
    if welcome.is_empty():
        return
    var resumed: bool = _resuming and welcome["match_id"] == match_id
    _resuming = false
    side = welcome["side"]
    match_id = welcome["match_id"]
    points_to_win = welcome["points_to_win"]
    win_by = welcome["win_by"]
    _token = welcome["token"]
    latest = null
    paused = false
    prediction = ClientPrediction.new(side, tuning)
    interpolator.clear()
    status = Status.PLAYING
    if resumed:
        notice.emit("Reconnected. The match continues.")
    else:
        _last_event_id = 0 # a restarted server numbers its events from the start again
        joined.emit(side)

func _on_snapshot(data: Array) -> void:
    var snapshot: NetSnapshot = NetProtocol.decode_snapshot(data)
    if snapshot == null or status != Status.PLAYING or snapshot.match_id != match_id or not interpolator.push(snapshot):
        snapshots_ignored += 1
        return
    snapshots_received += 1
    latest = snapshot
    prediction.reconcile(snapshot.position_of(side), snapshot.ack_seq)

func _on_event(data: Array) -> void:
    var decoded: Dictionary = NetProtocol.decode_event(data)
    if decoded.is_empty() or decoded["match_id"] != match_id or decoded["id"] <= _last_event_id:
        return # malformed, from another match, or one we already handled
    _last_event_id = decoded["id"]
    match decoded["type"]:
        NetProtocol.EventType.MATCH_ABORTED:
            status = Status.WAITING_FOR_MATCH # still connected; the server will welcome us into the next match
            latest = null
            paused = false
        NetProtocol.EventType.OPPONENT_AWAY: paused = true
        NetProtocol.EventType.OPPONENT_BACK: paused = false
    event.emit(decoded["type"], decoded["payload"])
