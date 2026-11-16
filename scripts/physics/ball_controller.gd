extends Node3D
class_name PickleballBall
## Fixed-step, custom training physics. Not a complete competition-grade solver.
signal bounced(side: int, side_bounces: int, contact_point: Vector3)
signal fault(reason: String)
@export var tuning: GameplayTuning = preload("res://config/gameplay_tuning.tres")
const RADIUS: float = CourtDimensions.BALL_VISUAL_RADIUS
var ball_velocity: Vector3 = Vector3.ZERO
var moving: bool = false
var bounces_this_half: int = 0
var current_side: int = 1
var last_hitter: int = 1

func reset_ball(home_pos: Vector3) -> void:
    position = home_pos
    ball_velocity = Vector3.ZERO
    moving = false
    bounces_this_half = 0
    current_side = CourtDimensions.side_from_z(home_pos.z)

func launch(target: Vector3, soft: bool, hitter_side: int) -> void:
    var flat: Vector3 = Vector3(target.x - position.x, 0.0, target.z - position.z)
    var speed: float = tuning.dink_speed if soft else tuning.drive_speed
    var flight_time: float = clampf(flat.length() / speed, tuning.min_flight_time, tuning.max_flight_time)
    # Solve a no-drag ballistic arc that lands at visual-ball radius.
    var new_y_speed: float = (RADIUS - position.y + 0.5 * tuning.gravity * flight_time * flight_time) / flight_time
    ball_velocity = Vector3(flat.x / flight_time, new_y_speed, flat.z / flight_time)
    moving = true
    bounces_this_half = 0
    current_side = CourtDimensions.side_from_z(position.z)
    last_hitter = hitter_side

func _physics_process(delta: float) -> void:
    if not moving:
        return
    var previous: Vector3 = position
    ball_velocity.y -= tuning.gravity * delta
    position += ball_velocity * delta
    if NetCollision.hits_net(previous, position, RADIUS):
        _signal_fault("NET — reset rally")
        return
    if previous.z * position.z <= 0.0 and absf(previous.z - position.z) > 0.0001:
        current_side = CourtDimensions.side_from_z(position.z)
        bounces_this_half = 0
    if position.y <= RADIUS and ball_velocity.y < 0.0:
        position.y = RADIUS
        if not CourtDimensions.inside_court(position):
            _signal_fault("OUT — reset rally")
            return
        var side: int = CourtDimensions.side_from_z(position.z)
        if side != current_side:
            current_side = side
            bounces_this_half = 0
        bounces_this_half += 1
        bounced.emit(side, bounces_this_half, position)
        if bounces_this_half >= 2:
            _signal_fault("DOUBLE BOUNCE — reset rally")
            return
        ball_velocity.y = -ball_velocity.y * tuning.bounce_restitution
        ball_velocity.x *= tuning.bounce_friction
        ball_velocity.z *= tuning.bounce_friction
    if absf(position.z) > 24.0 or absf(position.x) > 18.0 or position.y < -2.0:
        _signal_fault("OUT — reset rally")

func _signal_fault(reason: String) -> void:
    moving = false
    ball_velocity = Vector3.ZERO
    fault.emit(reason)
