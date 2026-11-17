extends Node
class_name MatchClient
## One player's connection to a MatchServer. It sends that player's inputs, predicts their
## own movement so it feels instant, and keeps the server's snapshots for drawing everything
## else slightly in the past. It never decides a hit, a fault or the score: those only ever
## arrive from the server, as snapshots and events.

signal joined(side: int) ## the server started a match and gave this client a side
signal event(type: NetProtocol.EventType, payload: Array)
signal failed(reason: String) ## could not connect, or the server went away

enum Status { OFFLINE, CONNECTING, WAITING_FOR_MATCH, PLAYING }

@export var tuning: GameplayTuning = preload("res://config/gameplay_tuning.tres")
var link: NetLink ## set by the owner before join()
var status: Status = Status.OFFLINE
var side: int = 0
var match_id: int = 0
var points_to_win: int = 11
var win_by: int = 2
var latest: NetSnapshot ## newest snapshot of the current match, or null
var prediction: ClientPrediction
var interpolator := SnapshotInterpolator.new()
var snapshots_received: int = 0
var snapshots_ignored: int = 0 ## malformed, for another match, or not newer than the newest
var _seq: int = 0
var _last_event_id: int = 0

func join(host: String, port: int) -> Error:
    var peer := ENetMultiplayerPeer.new()
    var error: Error = peer.create_client(host, port)
    if error != OK:
        return error
    multiplayer.multiplayer_peer = peer
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.connection_failed.connect(_on_lost.bind("Could not reach the server."))
    multiplayer.server_disconnected.connect(_on_lost.bind("The server closed the connection."))
    link.welcome_received.connect(_on_welcome)
    link.snapshot_received.connect(_on_snapshot)
    link.event_received.connect(_on_event)
    status = Status.CONNECTING
    return OK

func leave() -> void:
    if status != Status.OFFLINE and is_inside_tree() and multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
    status = Status.OFFLINE

## Going back to the menu must not leave a connection open behind the player's back.
func _exit_tree() -> void:
    leave()

## True while there is a match to send input to.
func can_play() -> bool:
    return status == Status.PLAYING and latest != null and latest.winner_side == 0

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

func _on_connected() -> void:
    status = Status.WAITING_FOR_MATCH
    link.hello.rpc_id(1, NetProtocol.VERSION)

func _on_lost(reason: String) -> void:
    status = Status.OFFLINE
    failed.emit(reason)

func _on_welcome(data: Array) -> void:
    var welcome: Dictionary = NetProtocol.decode_welcome(data)
    if welcome.is_empty():
        return
    side = welcome["side"]
    match_id = welcome["match_id"]
    points_to_win = welcome["points_to_win"]
    win_by = welcome["win_by"]
    latest = null
    prediction = ClientPrediction.new(side, tuning)
    interpolator.clear()
    status = Status.PLAYING
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
    if decoded["type"] == NetProtocol.EventType.MATCH_ABORTED:
        status = Status.WAITING_FOR_MATCH # still connected; the server will welcome us into the next match
        latest = null
    event.emit(decoded["type"], decoded["payload"])
