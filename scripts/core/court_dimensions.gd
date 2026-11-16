extends RefCounted
class_name CourtDimensions
## Canonical court dimensions in meters, centered on the net at world z=0.
## x is width, +z is the local home half; y is height.
const WIDTH: float = 6.096
const LENGTH: float = 13.4112
const HALF_WIDTH: float = WIDTH / 2.0
const HALF_LENGTH: float = LENGTH / 2.0
const KITCHEN_DEPTH: float = 2.1336
const NET_CENTER_HEIGHT: float = 0.8636
const NET_SIDE_HEIGHT: float = 0.9144
const NET_HALF_WIDTH: float = HALF_WIDTH + 0.15 # matches the prototype net mesh; regulation posts are 22 ft apart (3.3528)
const LINE_WIDTH: float = 0.0508
const BALL_VISUAL_RADIUS: float = 0.105 # deliberately exaggerated for readability

static func inside_court(pos: Vector3, tolerance: float = 0.01) -> bool:
    return absf(pos.x) <= HALF_WIDTH + tolerance and absf(pos.z) <= HALF_LENGTH + tolerance

static func inside_kitchen(pos: Vector3, tolerance: float = 0.01) -> bool:
    return inside_court(pos, tolerance) and absf(pos.z) <= KITCHEN_DEPTH + tolerance

## Net top height: 34 in at center rising linearly to 36 in at the sidelines.
static func net_height_at(x: float) -> float:
    return lerpf(NET_CENTER_HEIGHT, NET_SIDE_HEIGHT, minf(absf(x) / HALF_WIDTH, 1.0))

static func side_from_z(z: float) -> int:
    return 1 if z >= 0.0 else -1

static func legal_serve_target(pos: Vector3, serving_from_home: bool, serve_from_right: bool) -> bool:
    if not inside_court(pos) or absf(pos.z) <= KITCHEN_DEPTH:
        return false
    if serving_from_home and pos.z >= 0.0:
        return false
    if not serving_from_home and pos.z <= 0.0:
        return false
    # Right-side server (from their own perspective) serves cross-court.
    # Home team looks toward -Z; their right is -X. Away team looks toward +Z; their right is +X.
    var required_target_x_positive: bool = serve_from_right if serving_from_home else not serve_from_right
    return pos.x >= 0.0 if required_target_x_positive else pos.x <= 0.0
