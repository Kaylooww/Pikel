extends Node3D
class_name PickleballBall
## Fixed-step, custom training physics. Not a complete competition-grade solver.
## The ball only reports what physically happened. Whether a bounce or net contact is a
## fault is decided by the rules (RallyState), never here.
signal bounced(contact_point: Vector3)
signal net_hit(contact_point: Vector3)
@export var tuning: GameplayTuning = preload("res://config/gameplay_tuning.tres")
const RADIUS: float = CourtDimensions.BALL_VISUAL_RADIUS
const REST_SPEED: float = 0.5 # a bounce slower than this leaves the ball lying still
var ball_velocity: Vector3 = Vector3.ZERO
var moving: bool = false

func reset_ball(home_pos: Vector3) -> void:
    position = home_pos
    stop()

func stop() -> void:
    ball_velocity = Vector3.ZERO
    moving = false

## Hits the ball toward `target` if the solver finds a shot that clears the net.
## The ball is left untouched when the returned solution is not ok.
func launch(target: Vector3, soft: bool) -> ShotSolver.Solution:
    var shot: ShotSolver.Solution = ShotSolver.solve(position, target, soft, tuning)
    if shot.ok:
        ball_velocity = shot.velocity
        moving = true
    return shot

func _physics_process(delta: float) -> void:
    if not moving:
        return
    var previous: Vector3 = position
    # Exact step for constant gravity, so flight matches ShotSolver's parabola.
    position += ball_velocity * delta + Vector3.DOWN * (0.5 * tuning.gravity * delta * delta)
    ball_velocity.y -= tuning.gravity * delta
    if NetCollision.hits_net(previous, position, RADIUS):
        # shortcut: the net swallows the ball; give it a real rebound when net play matters.
        stop()
        net_hit.emit(position)
        return
    if position.y <= RADIUS and ball_velocity.y < 0.0:
        # Back up to the moment of floor contact so in/out is judged on the real landing point.
        if previous.y > position.y:
            position = previous.lerp(position, clampf((previous.y - RADIUS) / (previous.y - position.y), 0.0, 1.0))
        position.y = RADIUS
        ball_velocity.y = -ball_velocity.y * tuning.bounce_restitution
        ball_velocity.x *= tuning.bounce_friction
        ball_velocity.z *= tuning.bounce_friction
        if ball_velocity.y < REST_SPEED:
            stop()
        bounced.emit(position)
    if absf(position.z) > 24.0 or absf(position.x) > 18.0:
        stop() # rolled far off the court; nothing left to report
