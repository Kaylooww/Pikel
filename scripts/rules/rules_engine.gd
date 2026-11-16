extends RefCounted
class_name RulesEngine
## An expandable rules helper, NOT yet a full legal scoring/serving state machine.
## The first milestone deliberately ships only court/serve/kitchen predicates.

static func is_ball_in(pos: Vector3) -> bool:
    return CourtDimensions.inside_court(pos)

static func is_kitchen(pos: Vector3) -> bool:
    return CourtDimensions.inside_kitchen(pos)

static func service_landing_is_valid(pos: Vector3, serving_from_home: bool, right_side: bool) -> bool:
    return CourtDimensions.legal_serve_target(pos, serving_from_home, right_side)

static func is_cross_court_target(pos: Vector3, hitter_side: int) -> bool:
    return CourtDimensions.inside_court(pos) and CourtDimensions.side_from_z(pos.z) != hitter_side
