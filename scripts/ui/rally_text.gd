extends RefCounted
class_name RallyText
## Words for the HUD. It only describes decisions the rules already made.

static func fault(rally: RallyState, my_side: int) -> String:
    var what: String
    match rally.fault:
        RallyState.Fault.NET: what = "NET"
        RallyState.Fault.OUT: what = "OUT"
        RallyState.Fault.OWN_SIDE: what = "DID NOT CROSS THE NET"
        RallyState.Fault.DOUBLE_BOUNCE: what = "DOUBLE BOUNCE"
        RallyState.Fault.VOLLEY_BEFORE_BOUNCE: what = "TWO-BOUNCE RULE — the ball had to bounce first"
        RallyState.Fault.KITCHEN_VOLLEY: what = "KITCHEN FAULT — no volleys while standing in the kitchen"
        RallyState.Fault.KITCHEN_MOMENTUM: what = "KITCHEN FAULT — momentum carried into the kitchen after a volley"
        RallyState.Fault.SERVE_POSITION: what = "FOOT FAULT — serve from behind the baseline, %s half" % ("right" if rally.serve_from_right else "left")
        RallyState.Fault.SERVE_COURT: what = "SERVICE FAULT — serve must land in the diagonal service court"
        _: what = "DOUBLE HIT"
    return "%s  —  %s" % [what, "you win the rally" if rally.winner_side == my_side else "opponent wins the rally"]

static func swing(result: MatchSimulation.SwingResult, soft: bool, contact: SwingContact.Contact) -> String:
    match result:
        MatchSimulation.SwingResult.HIT: return "%s  —  %s" % ["DINK" if soft else "DRIVE", contact.label()]
        MatchSimulation.SwingResult.OUT_OF_REACH: return "Too far from ball — move closer."
        MatchSimulation.SwingResult.WRONG_HALF: return "Ball is still on the other half."
        MatchSimulation.SwingResult.NO_SHOT_NET: return "Can't clear the net from here — get under the ball or aim shorter."
        MatchSimulation.SwingResult.NO_SHOT_OUT: return "That swing would send the ball out."
        MatchSimulation.SwingResult.NO_SHOT_TOO_FAST: return "Too far for that shot."
        _: return "" # not live, or your own shot: nothing worth saying

## "YOU 3  –  2 OPPONENT   |   You serve, right court"
static func score_line(home_points: int, away_points: int, server_side: int, serve_from_right: bool, my_side: int) -> String:
    var mine: int = home_points if my_side == 1 else away_points
    var theirs: int = away_points if my_side == 1 else home_points
    var who: String = "You serve" if server_side == my_side else "Opponent serves"
    return "YOU %d  –  %d OPPONENT   |   %s, %s court" % [mine, theirs, who, "right" if serve_from_right else "left"]

static func match_result(winner_side: int, my_side: int) -> String:
    return "MATCH WON!" if winner_side == my_side else "MATCH LOST"
