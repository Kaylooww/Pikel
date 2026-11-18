extends RefCounted
class_name NetSnapshot
## The server's view of the match at one tick, as a client receives it.

var match_id: int = 0
var tick: int = 0
var ack_seq: int = 0 ## last input sequence number of the receiving client that the server applied
var home_position: Vector3 = Vector3.ZERO
var away_position: Vector3 = Vector3.ZERO
var ball_position: Vector3 = Vector3.ZERO
var ball_velocity: Vector3 = Vector3.ZERO
var ball_spin: float = 0.0
var ball_moving: bool = false
var home_points: int = 0
var away_points: int = 0
var server_side: int = 1
var serve_from_right: bool = true
var rally_id: int = 0
var phase: RallyState.Phase = RallyState.Phase.WAITING_FOR_SERVE
var last_hitter: int = 0
var bounces_since_hit: int = 0
var live: bool = false
var winner_side: int = 0 ## 0 until the match is won

func position_of(side: int) -> Vector3:
    return home_position if side == 1 else away_position

## The match as `side` sees it. `my_position` lets a client use its own predicted position.
func to_view(side: int, my_position: Vector3) -> MatchView:
    var view := MatchView.new()
    view.side = side
    view.my_position = my_position
    view.opponent_position = position_of(-side)
    view.ball_position = ball_position
    view.ball_velocity = ball_velocity
    view.ball_spin = ball_spin
    view.live = live
    view.phase = phase
    view.server_side = server_side
    view.serve_from_right = serve_from_right
    view.last_hitter = last_hitter
    view.bounces_since_hit = bounces_since_hit
    view.rally_id = rally_id
    return view
