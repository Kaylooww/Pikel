extends RefCounted
class_name CourtDimensions
## Canonical court dimensions in meters, centered on the net at world z=0.
## x is width, +z is the local home half; y is height. A player facing -z has +x on their right.
## All dimensions are measured to the OUTSIDE edge of the lines, so lines are in.
## Positions passed to predicates are the ball's contact point (its center projected to the floor).
const WIDTH: float = 6.096
const LENGTH: float = 13.4112
const HALF_WIDTH: float = WIDTH / 2.0
const HALF_LENGTH: float = LENGTH / 2.0
const KITCHEN_DEPTH: float = 2.1336
const NET_CENTER_HEIGHT: float = 0.8636
const NET_SIDE_HEIGHT: float = 0.9144
const NET_HALF_WIDTH: float = 3.3528 # posts are 22 ft apart, 1 ft outside each sideline
const LINE_WIDTH: float = 0.0508
const BALL_VISUAL_RADIUS: float = 0.105 # deliberately exaggerated for readability

## Vector3 stores 32-bit floats, so a point exactly on a line edge can round a hair outside.
## 0.1 mm absorbs that rounding and nothing else.
const LINE_EPSILON: float = 0.0001

## Boundary lines are in.
static func inside_court(pos: Vector3, tolerance: float = LINE_EPSILON) -> bool:
    return absf(pos.x) <= HALF_WIDTH + tolerance and absf(pos.z) <= HALF_LENGTH + tolerance

## The non-volley-zone line is part of the kitchen.
static func inside_kitchen(pos: Vector3, tolerance: float = LINE_EPSILON) -> bool:
    return inside_court(pos, tolerance) and absf(pos.z) <= KITCHEN_DEPTH + tolerance

## Net top height: 34 in at center rising linearly to 36 in at the sidelines.
static func net_height_at(x: float) -> float:
    return lerpf(NET_CENTER_HEIGHT, NET_SIDE_HEIGHT, minf(absf(x) / HALF_WIDTH, 1.0))

## +1 is the home half (z >= 0), -1 the away half.
static func side_from_z(z: float) -> int:
    return 1 if z >= 0.0 else -1

## Where the server may stand at contact: behind their own baseline (on the line is a foot
## fault), between the centerline and sideline extensions of the court they serve from.
## `feet` is the player's ground position. The right court is on the server's right hand.
static func legal_serve_position(feet: Vector3, serving_from_home: bool, serve_from_right: bool) -> bool:
    var behind: float = feet.z if serving_from_home else -feet.z
    if behind <= HALF_LENGTH + LINE_EPSILON:
        return false
    var to_right: float = feet.x if serving_from_home else -feet.x
    var across: float = to_right if serve_from_right else -to_right
    return across >= -LINE_EPSILON and across <= HALF_WIDTH + LINE_EPSILON

## A serve must land in the receiver's service court diagonally opposite the server.
## Sideline, baseline and centerline are in; the kitchen line is a fault.
static func legal_serve_target(pos: Vector3, serving_from_home: bool, serve_from_right: bool) -> bool:
    if not inside_court(pos) or inside_kitchen(pos):
        return false
    if serving_from_home and pos.z >= 0.0:
        return false
    if not serving_from_home and pos.z <= 0.0:
        return false
    # Home faces -z, so their right court is +x and its diagonal is -x on the away half.
    # Away faces +z, so their right court is -x and its diagonal is +x on the home half.
    var target_x_positive: bool = serve_from_right != serving_from_home
    var half_line: float = LINE_WIDTH / 2.0 # the centerline belongs to both service courts
    return pos.x >= -half_line if target_x_positive else pos.x <= half_line
