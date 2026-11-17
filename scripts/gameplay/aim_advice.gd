extends RefCounted
class_name AimAdvice
## What would happen if this player swung right now at this aim point. Pure: it is the one
## place that turns the match state into the preview's colour, arcs and hint text, for
## local play and online play alike. It predicts; the simulation still decides.

enum State { IDLE, BLOCKED, OK }

var state: State = State.IDLE
var text: String = ""
var contact: SwingContact.Contact = null
var real_target: Vector3 = Vector3.ZERO ## the aim point after swing error
var drive: ShotSolver.Solution = null ## set when the swing can be judged; check .ok
var dink: ShotSolver.Solution = null

static func evaluate(view: MatchView, aim: Vector3, tuning: GameplayTuning) -> AimAdvice:
    var advice := AimAdvice.new()
    var side: int = view.side
    var serving: bool = view.phase == RallyState.Phase.WAITING_FOR_SERVE
    if not view.live:
        advice.text = "Next rally is being set up"
    elif view.last_hitter == side:
        advice.text = "Your shot is in play"
    elif serving and view.server_side != side:
        advice.text = "Opponent is serving"
    elif CourtDimensions.side_from_z(view.ball_position.z) != side:
        advice.text = "Ball is on the other half"
    else:
        advice.contact = SwingContact.evaluate(view.my_position, view.ball_position, view.ball_velocity, side, tuning)
        if not advice.contact.in_reach:
            advice.text = "Ball not in reach"
        elif view.bounces_since_hit == 0 and view.phase in [RallyState.Phase.SERVE_IN_FLIGHT, RallyState.Phase.RETURN_IN_FLIGHT]:
            advice.state = State.BLOCKED
            advice.text = "WAIT  —  let it bounce first (two-bounce rule)"
        elif view.bounces_since_hit == 0 and view.phase == RallyState.Phase.OPEN_RALLY and CourtDimensions.inside_kitchen(view.my_position):
            advice.state = State.BLOCKED
            advice.text = "KITCHEN  —  no volleys here: let it bounce or step back"
        else:
            _judge_swing(advice, view, aim, serving, tuning)
    return advice

static func _judge_swing(advice: AimAdvice, view: MatchView, aim: Vector3, serving: bool, tuning: GameplayTuning) -> void:
    var label: String = advice.contact.label()
    advice.real_target = advice.contact.apply(aim)
    advice.drive = ShotSolver.solve(view.ball_position, advice.real_target, false, tuning)
    advice.dink = ShotSolver.solve(view.ball_position, advice.real_target, true, tuning)
    var home: bool = view.side == 1
    if not advice.drive.ok and not advice.dink.ok:
        advice.state = State.BLOCKED
        advice.text = "AIM BLOCKED  —  contact: %s  —  no shot lands in from here" % label
    elif serving and not CourtDimensions.legal_serve_position(view.my_position, home, view.serve_from_right):
        advice.state = State.BLOCKED
        advice.text = "SERVE FAULT IF HIT  —  stand behind the baseline, on the %s half" % ("right" if view.serve_from_right else "left")
    elif serving and not CourtDimensions.legal_serve_target(advice.real_target, home, view.serve_from_right):
        advice.state = State.BLOCKED
        advice.text = "SERVE FAULT IF HIT  —  aim at the diagonal service court, past the kitchen line"
    elif advice.drive.ok and advice.dink.ok:
        advice.state = State.OK
        advice.text = "AIM OK  —  contact: %s  —  yellow dots: drive   aqua dots: dink" % label
    else:
        advice.state = State.OK
        advice.text = "AIM OK  —  contact: %s  —  only the %s clears the net from here" % [label, "drive" if advice.drive.ok else "dink"]
