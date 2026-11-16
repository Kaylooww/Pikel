extends RefCounted
class_name RallyEvent
## One thing that happened to the ball during a rally. Whoever simulates the ball (later:
## the server) creates these with increasing ids; RallyState is the only thing that
## decides what they mean.

enum Type { HIT, BOUNCE, NET, KITCHEN_ENTRY }

var id: int = 0 ## increases with every event in a match; used to drop duplicates
var rally_id: int = 0
var tick: int = 0 ## simulation tick the event happened on
var type: Type = Type.HIT
var side: int = 0 ## HIT and KITCHEN_ENTRY: the +1 home or -1 away player involved
var position: Vector3 = Vector3.ZERO ## where the ball was; BOUNCE uses it for in/out and side
var player_position: Vector3 = Vector3.ZERO ## HIT and KITCHEN_ENTRY: the player's feet, for serve and kitchen rules

static func hit(event_id: int, in_rally: int, at_tick: int, hitter_side: int, ball_at: Vector3 = Vector3.ZERO, feet_at: Vector3 = Vector3.ZERO) -> RallyEvent:
    var event: RallyEvent = _make(event_id, in_rally, at_tick, Type.HIT, hitter_side, ball_at)
    event.player_position = feet_at
    return event

static func bounce(event_id: int, in_rally: int, at_tick: int, at: Vector3) -> RallyEvent:
    return _make(event_id, in_rally, at_tick, Type.BOUNCE, 0, at)

## A player stepped into the kitchen (non-volley zone). Only matters right after a volley.
static func kitchen_entry(event_id: int, in_rally: int, at_tick: int, player_side: int, feet_at: Vector3 = Vector3.ZERO) -> RallyEvent:
    var event: RallyEvent = _make(event_id, in_rally, at_tick, Type.KITCHEN_ENTRY, player_side, Vector3.ZERO)
    event.player_position = feet_at
    return event

## The ball was stopped by the net.
static func net(event_id: int, in_rally: int, at_tick: int, at: Vector3 = Vector3.ZERO) -> RallyEvent:
    return _make(event_id, in_rally, at_tick, Type.NET, 0, at)

static func _make(event_id: int, in_rally: int, at_tick: int, kind: Type, hitter_side: int, at: Vector3) -> RallyEvent:
    var event := RallyEvent.new()
    event.id = event_id
    event.rally_id = in_rally
    event.tick = at_tick
    event.type = kind
    event.side = hitter_side
    event.position = at
    return event
