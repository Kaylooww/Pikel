extends RefCounted
class_name NetProtocol
## The wire format, in one place. Messages are plain Arrays. Every decode_ function checks
## size, types and ranges and returns null (or an empty Dictionary) for anything that does
## not fit, so nothing downstream ever handles an unchecked network value.
##
## What a client is allowed to say is deliberately tiny: "this is my input number N: move
## this way, sprint or not, swing or not, aiming here". There is no message for "I hit the
## ball", "I am at this position" or "the score is". The server works those out.
## A swing request carries its shot type, its charge (0..1) and the side picked with Q/E;
## the server still judges reach, timing and side itself.

const VERSION: int = 4
const DEFAULT_PORT: int = 7777
const MAX_SEQ_JUMP: int = 600 ## an input this far ahead of the last one is not believable
const AIM_LIMIT: float = 20.0 ## metres; aim points are clamped to this before use

enum EventType { RALLY_STARTED, SWING, RALLY_ENDED, MATCH_ENDED, MATCH_ABORTED, OPPONENT_AWAY, OPPONENT_BACK }
enum Refusal { VERSION, FULL, CODE } ## why the server would not seat a connection
const CODE_LENGTH: int = 6
const CODE_LETTERS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" ## no O/0 or I/1, which are easy to misread

## A fresh private match code, for example "K7QX2M".
static func new_match_code() -> String:
    var code: String = ""
    for byte: int in Crypto.new().generate_random_bytes(CODE_LENGTH):
        code += CODE_LETTERS[byte % CODE_LETTERS.length()]
    return code

## What a player typed, as a code: upper case, spaces and dashes removed. "" if it cannot be a code.
static func clean_code(text: String) -> String:
    var code: String = text.strip_edges().to_upper().replace(" ", "").replace("-", "")
    if code.length() != CODE_LENGTH:
        return ""
    for letter: String in code:
        if not CODE_LETTERS.contains(letter):
            return ""
    return code

## A vanished peer is noticed after 3 to 6 seconds instead of the ENet default of 5 to 30.
static func set_timeouts(peer: MultiplayerPeer, peer_id: int) -> void:
    if peer is ENetMultiplayerPeer:
        (peer as ENetMultiplayerPeer).get_peer(peer_id).set_timeout(0, 3000, 6000)

# --- client -> server -----------------------------------------------------------------

static func encode_input(match_id: int, input: PlayerInput) -> Array:
    return [match_id, input.seq, input.move, input.sprint, int(input.swing), Vector2(input.aim.x, input.aim.z), input.power, int(input.stroke)]

## Returns a cleaned PlayerInput, or null if the message is malformed or for another match.
static func decode_input(data: Variant, match_id: int) -> PlayerInput:
    if not _fits(data, [TYPE_INT, TYPE_INT, TYPE_VECTOR2, TYPE_BOOL, TYPE_INT, TYPE_VECTOR2, TYPE_FLOAT, TYPE_INT]):
        return null
    var move: Vector2 = data[2]
    var aim: Vector2 = data[5]
    if data[0] != match_id or data[1] < 1 or data[4] < 0 or data[4] > PlayerInput.Swing.LOB or not move.is_finite() or not aim.is_finite() \
            or not is_finite(data[6]) or data[7] < 0 or data[7] > SwingContact.Stroke.BACKHAND:
        return null
    var input := PlayerInput.new()
    input.seq = data[1]
    input.move = move.limit_length(1.0)
    input.sprint = data[3]
    input.swing = data[4] as PlayerInput.Swing
    input.power = clampf(data[6], 0.0, 1.0)
    input.stroke = data[7] as SwingContact.Stroke
    input.aim = Vector3(clampf(aim.x, -AIM_LIMIT, AIM_LIMIT), 0.0, clampf(aim.y, -AIM_LIMIT, AIM_LIMIT))
    return input

# --- server -> client -----------------------------------------------------------------

## `token` is this player's seat ticket: a client that loses its connection shows it to get the seat back.
static func encode_welcome(match_id: int, side: int, points_to_win: int, win_by: int, token: String) -> Array:
    return [VERSION, match_id, side, MatchSimulation.TICK_RATE, points_to_win, win_by, token]

## Returns {match_id, side, tick_rate, points_to_win, win_by, token}, or {} if malformed.
static func decode_welcome(data: Variant) -> Dictionary:
    if not _fits(data, [TYPE_INT, TYPE_INT, TYPE_INT, TYPE_INT, TYPE_INT, TYPE_INT, TYPE_STRING]) or data[0] != VERSION or absi(data[2]) != 1:
        return {}
    return {"match_id": data[1], "side": data[2], "tick_rate": data[3], "points_to_win": data[4], "win_by": data[5], "token": data[6]}

static func encode_snapshot(sim: MatchSimulation, match_id: int, ack_seq: int) -> Array:
    var rally: RallyState = sim.referee.rally
    var score: MatchScore = sim.score()
    return [match_id, sim.tick, ack_seq,
        sim.positions[1], sim.positions[-1], sim.ball.position, sim.ball.velocity, sim.ball.moving, sim.ball.spin,
        score.score_of(1), score.score_of(-1), rally.server_side, rally.serve_from_right,
        rally.rally_id, int(rally.phase), rally.last_hitter, rally.bounces_since_hit, sim.rally_live(), score.winner_side]

static func decode_snapshot(data: Variant) -> NetSnapshot:
    if not _fits(data, [TYPE_INT, TYPE_INT, TYPE_INT,
            TYPE_VECTOR3, TYPE_VECTOR3, TYPE_VECTOR3, TYPE_VECTOR3, TYPE_BOOL, TYPE_FLOAT,
            TYPE_INT, TYPE_INT, TYPE_INT, TYPE_BOOL,
            TYPE_INT, TYPE_INT, TYPE_INT, TYPE_INT, TYPE_BOOL, TYPE_INT]):
        return null
    for i: int in [3, 4, 5, 6]:
        if not (data[i] as Vector3).is_finite():
            return null
    if data[14] < 0 or data[14] > RallyState.Phase.ENDED or absi(data[11]) != 1:
        return null
    var snap := NetSnapshot.new()
    snap.match_id = data[0]
    snap.tick = data[1]
    snap.ack_seq = data[2]
    snap.home_position = data[3]
    snap.away_position = data[4]
    snap.ball_position = data[5]
    snap.ball_velocity = data[6]
    snap.ball_moving = data[7]
    if not is_finite(data[8]):
        return null
    snap.ball_spin = data[8]
    snap.home_points = data[9]
    snap.away_points = data[10]
    snap.server_side = data[11]
    snap.serve_from_right = data[12]
    snap.rally_id = data[13]
    snap.phase = data[14] as RallyState.Phase
    snap.last_hitter = data[15]
    snap.bounces_since_hit = data[16]
    snap.live = data[17]
    snap.winner_side = data[18]
    return snap

## Events are [event_id, match_id, type, payload...]. Ids increase, so a client can tell a
## repeat from something new.
static func encode_event(event_id: int, match_id: int, type: EventType, payload: Array) -> Array:
    var data: Array = [event_id, match_id, int(type)]
    data.append_array(payload)
    return data

## Returns {id, match_id, type, payload}, or {} if malformed or the payload has the wrong shape.
static func decode_event(data: Variant) -> Dictionary:
    if not (data is Array) or data.size() < 3 or typeof(data[0]) != TYPE_INT or typeof(data[1]) != TYPE_INT or typeof(data[2]) != TYPE_INT:
        return {}
    var payload: Array = data.slice(3)
    var shape: Array
    match data[2]:
        EventType.RALLY_STARTED: shape = [TYPE_INT, TYPE_INT, TYPE_BOOL] # rally_id, server_side, serve_from_right
        EventType.SWING: shape = [TYPE_INT, TYPE_INT, TYPE_INT, TYPE_STRING] # side, result, shot kind, contact label
        EventType.RALLY_ENDED: shape = [TYPE_INT, TYPE_INT, TYPE_INT, TYPE_INT, TYPE_BOOL, TYPE_INT, TYPE_INT] # rally_id, fault, fault_side, winner_side, serve_from_right, home_points, away_points
        EventType.MATCH_ENDED: shape = [TYPE_INT, TYPE_INT, TYPE_INT] # winner_side, home_points, away_points
        EventType.MATCH_ABORTED: shape = [TYPE_STRING] # reason
        EventType.OPPONENT_AWAY: shape = [TYPE_INT] # seconds the match will wait for them
        EventType.OPPONENT_BACK: shape = []
        _: return {}
    if not _fits(payload, shape):
        return {}
    return {"id": data[0], "match_id": data[1], "type": data[2], "payload": payload}

## True if `data` is an Array with exactly these element types.
static func _fits(data: Variant, types: Array) -> bool:
    if not (data is Array) or data.size() != types.size():
        return false
    for i in range(types.size()):
        if typeof(data[i]) != types[i]:
            return false
    return true
