extends RefCounted
class_name AimAdvice
## What would happen if this player swung right now at this aim point. Pure: it is the one
## place that turns the match state into the preview's colour, arcs and hint text, for
## local play and online play alike. It predicts; the simulation still decides.
##
## Two arcs are previewed for the button the player is holding (or the main button when
## none is): the tap shot (dink, or block on the alt button) and the hold shot at the
## current charge (drive, or lob on the alt button).

enum State { IDLE, BLOCKED, OK }

var state: State = State.IDLE
var text: String = ""
var contact: SwingContact.Contact = null ## judged with the correct side, so the preview shows a well-sided swing
var needed: SwingContact.Stroke = SwingContact.Stroke.NONE ## the side the ball is on right now
var volley: bool = false ## the ball has not bounced: a swing now is a volley with a hard timing window
var real_target: Vector3 = Vector3.ZERO ## the aim point after swing error
var tap_kind: ShotRecipe.Kind = ShotRecipe.Kind.DINK
var hold_kind: ShotRecipe.Kind = ShotRecipe.Kind.DRIVE
var tap: ShotSolver.Solution = null ## set when the swing can be judged; check .ok
var hold: ShotSolver.Solution = null

## `alt_button` is true while the block/lob button is held; `charge` is the hold shot's charge.
static func evaluate(view: MatchView, aim: Vector3, tuning: GameplayTuning, alt_button: bool = false, charge: float = 0.0) -> AimAdvice:
    var advice := AimAdvice.new()
    var side: int = view.side
    var serving: bool = view.phase == RallyState.Phase.WAITING_FOR_SERVE
    if alt_button:
        advice.tap_kind = ShotRecipe.Kind.BLOCK
        advice.hold_kind = ShotRecipe.Kind.LOB
    if not view.live:
        advice.text = "Next rally is being set up"
    elif view.last_hitter == side:
        advice.text = "Your shot is in play"
    elif serving and view.server_side != side:
        advice.text = "Opponent is serving"
    elif CourtDimensions.side_from_z(view.ball_position.z) != side:
        advice.text = "Ball is on the other half"
    else:
        advice.needed = SwingContact.needed_stroke(view.my_position, view.ball_position, side, tuning)
        var stroke: SwingContact.Stroke = advice.needed if advice.needed != SwingContact.Stroke.NONE else SwingContact.Stroke.FOREHAND
        advice.contact = SwingContact.evaluate(view.my_position, view.ball_position, view.ball_velocity, side, tuning, stroke)
        advice.volley = not serving and view.last_hitter != 0 and view.bounces_since_hit == 0
        if not advice.contact.in_reach:
            advice.text = "Ball not in reach"
        elif advice.volley and view.phase in [RallyState.Phase.SERVE_IN_FLIGHT, RallyState.Phase.RETURN_IN_FLIGHT]:
            advice.state = State.BLOCKED
            advice.text = "WAIT  —  let it bounce first (two-bounce rule)"
        elif advice.volley and view.phase == RallyState.Phase.OPEN_RALLY and CourtDimensions.inside_kitchen(view.my_position):
            advice.state = State.BLOCKED
            advice.text = "KITCHEN  —  no volleys here: let it bounce or step back"
        else:
            _judge_swing(advice, view, aim, serving, charge, tuning)
    return advice

static func _judge_swing(advice: AimAdvice, view: MatchView, aim: Vector3, serving: bool, charge: float, tuning: GameplayTuning) -> void:
    var label: String = "%s %s" % [_side_hint(advice.needed), advice.contact.label()]
    advice.real_target = advice.contact.apply(aim)
    advice.tap = ShotSolver.solve(view.ball_position, advice.real_target, ShotRecipe.make(advice.tap_kind, 0.0, advice.volley, tuning), tuning)
    advice.hold = ShotSolver.solve(view.ball_position, advice.real_target, ShotRecipe.make(advice.hold_kind, charge, advice.volley, tuning), tuning)
    var home: bool = view.side == 1
    var tap_name: String = ShotRecipe.kind_name(advice.tap_kind).to_lower()
    var hold_name: String = ShotRecipe.kind_name(advice.hold_kind).to_lower()
    var volley_note: String = "VOLLEY: time it as the ball arrives  —  " if advice.volley else ""
    if not advice.tap.ok and not advice.hold.ok:
        advice.state = State.BLOCKED
        advice.text = "AIM BLOCKED  —  %s  —  no shot lands in from here" % label
    elif serving and not CourtDimensions.legal_serve_position(view.my_position, home, view.serve_from_right):
        advice.state = State.BLOCKED
        advice.text = "SERVE FAULT IF HIT  —  stand behind the baseline, on the %s half" % ("right" if view.serve_from_right else "left")
    elif serving and not CourtDimensions.legal_serve_target(advice.real_target, home, view.serve_from_right):
        advice.state = State.BLOCKED
        advice.text = "SERVE FAULT IF HIT  —  aim at the diagonal service court, past the kitchen line"
    elif advice.tap.ok and advice.hold.ok:
        advice.state = State.OK
        advice.text = "AIM OK  —  %s%s  —  aqua: %s   yellow: %s" % [volley_note, label, tap_name, hold_name]
    else:
        advice.state = State.OK
        advice.text = "AIM OK  —  %s%s  —  only the %s clears the net from here" % [volley_note, label, tap_name if advice.tap.ok else hold_name]

## "E FOREHAND", "Q BACKHAND" or "Q/E" (ball in front of the body), using the real bindings.
static func _side_hint(needed: SwingContact.Stroke) -> String:
    match needed:
        SwingContact.Stroke.FOREHAND: return "%s FOREHAND  —" % GameInput.label(GameInput.FOREHAND)
        SwingContact.Stroke.BACKHAND: return "%s BACKHAND  —" % GameInput.label(GameInput.BACKHAND)
        _: return "%s/%s  —" % [GameInput.label(GameInput.BACKHAND), GameInput.label(GameInput.FOREHAND)]
