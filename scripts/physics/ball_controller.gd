extends Node3D
class_name PickleballBall
## The ball you see. Its physics is BallState; this node only carries it in the scene.
## It reports what physically happened. Whether a bounce or net contact is a fault is
## decided by the rules (RallyState), never here.
signal bounced(contact_point: Vector3)
signal net_hit(contact_point: Vector3)
@export var tuning: GameplayTuning = preload("res://config/gameplay_tuning.tres")
const RADIUS: float = BallState.RADIUS
var ball_velocity: Vector3 = Vector3.ZERO
var ball_spin: float = 0.0 ## rev/s, positive is topspin
var moving: bool = false

func reset_ball(home_pos: Vector3) -> void:
    position = home_pos
    stop()

func stop() -> void:
    ball_velocity = Vector3.ZERO
    ball_spin = 0.0
    moving = false

## Hits the ball toward `target` if the solver finds a shot that clears the net.
## The ball is left untouched when the returned solution is not ok.
func launch(target: Vector3, recipe: ShotRecipe) -> ShotSolver.Solution:
    var state: BallState = _state()
    var shot: ShotSolver.Solution = state.launch(target, recipe, tuning)
    _take(state)
    return shot

func _physics_process(delta: float) -> void:
    if not moving:
        return
    var state: BallState = _state()
    var event: BallState.Event = state.step(delta, tuning)
    _take(state)
    if event == BallState.Event.BOUNCE:
        bounced.emit(position)
    elif event == BallState.Event.NET:
        net_hit.emit(position)

func _state() -> BallState:
    var state := BallState.new()
    state.position = position
    state.velocity = ball_velocity
    state.spin = ball_spin
    state.moving = moving
    return state

func _take(state: BallState) -> void:
    position = state.position
    ball_velocity = state.velocity
    ball_spin = state.spin
    moving = state.moving
