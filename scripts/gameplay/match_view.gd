extends RefCounted
class_name MatchView
## The match as one side sees it: what a bot needs to play and what the HUD needs to give
## aiming advice. Built from the local simulation or from a network snapshot, so the same
## bot and the same preview work locally, on the server and on a client.

var side: int = 1
var my_position: Vector3 = Vector3.ZERO
var opponent_position: Vector3 = Vector3.ZERO
var ball_position: Vector3 = Vector3.ZERO
var ball_velocity: Vector3 = Vector3.ZERO
var ball_spin: float = 0.0 ## rev/s, positive is topspin
var live: bool = false ## a rally is waiting for its serve or being played
var phase: RallyState.Phase = RallyState.Phase.WAITING_FOR_SERVE
var server_side: int = 1
var serve_from_right: bool = true
var last_hitter: int = 0
var bounces_since_hit: int = 0
var rally_id: int = 0

static func from_simulation(sim: MatchSimulation, for_side: int) -> MatchView:
    var view := MatchView.new()
    var rally: RallyState = sim.referee.rally
    view.side = for_side
    view.my_position = sim.positions[for_side]
    view.opponent_position = sim.positions[-for_side]
    view.ball_position = sim.ball.position
    view.ball_velocity = sim.ball.velocity
    view.ball_spin = sim.ball.spin
    view.live = sim.rally_live()
    view.phase = rally.phase
    view.server_side = rally.server_side
    view.serve_from_right = rally.serve_from_right
    view.last_hitter = rally.last_hitter
    view.bounces_since_hit = rally.bounces_since_hit
    view.rally_id = rally.rally_id
    return view
