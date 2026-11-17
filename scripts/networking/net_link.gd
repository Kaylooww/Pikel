extends Node
class_name NetLink
## The only node that sends or receives network messages. The server and every client
## have one at the same path (a child named "NetLink" of the scene root), which is how
## Godot's RPC system matches them up.
##
## Direction is enforced here and by the RPC modes:
##   client -> server: hello, submit_input. Ignored unless this peer is the server.
##   server -> client: welcome, snapshot, game_event, refused. "authority" mode means Godot itself
##     rejects them from anyone but the server, so a client cannot fake them.
## Payloads are plain Arrays; NetProtocol builds and checks them.

signal hello_received(peer_id: int, version: int, token: String, code: String)
signal input_received(peer_id: int, data: Array)
signal welcome_received(data: Array)
signal snapshot_received(data: Array)
signal event_received(data: Array)
signal refused_received(reason: int)

@rpc("any_peer", "call_remote", "reliable")
## token: "" for a new player, or the seat ticket from an earlier welcome. code: the private match code.
func hello(version: int, token: String, code: String) -> void:
    if multiplayer.is_server():
        hello_received.emit(multiplayer.get_remote_sender_id(), version, token, code)

## Unreliable on purpose: a late input is useless, and the next one is already on its way.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(data: Array) -> void:
    if multiplayer.is_server():
        input_received.emit(multiplayer.get_remote_sender_id(), data)

@rpc("authority", "call_remote", "reliable")
func welcome(data: Array) -> void:
    welcome_received.emit(data)

@rpc("authority", "call_remote", "unreliable_ordered")
func snapshot(data: Array) -> void:
    snapshot_received.emit(data)

## Sent just before the server closes a connection it will not seat (a NetProtocol.Refusal).
@rpc("authority", "call_remote", "reliable")
func refused(reason: int) -> void:
    refused_received.emit(reason)

## Things that must not be lost: swing results, rally results, match start and end.
@rpc("authority", "call_remote", "reliable")
func game_event(data: Array) -> void:
    event_received.emit(data)
