extends RefCounted
class_name BallState
## The ball as plain data plus its fixed-step physics. No scene access, so the same code
## runs in the visual ball node, the match simulation and tests.
## It only reports what physically happened; the rules decide what it means.

enum Event { NONE, BOUNCE, NET }

const RADIUS: float = CourtDimensions.BALL_VISUAL_RADIUS
const REST_SPEED: float = 0.5 # a bounce slower than this leaves the ball lying still
const WORLD_LIMIT_X: float = 18.0
const WORLD_LIMIT_Z: float = 24.0

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var moving: bool = false

func place(at: Vector3) -> void:
    position = at
    stop()

func stop() -> void:
    velocity = Vector3.ZERO
    moving = false

## Hits the ball toward `target` if the solver finds a shot that clears the net.
## The ball is left untouched when the returned solution is not ok.
func launch(target: Vector3, soft: bool, tuning: GameplayTuning) -> ShotSolver.Solution:
    var shot: ShotSolver.Solution = ShotSolver.solve(position, target, soft, tuning)
    if shot.ok:
        velocity = shot.velocity
        moving = true
    return shot

## Advances one step and says what happened during it.
func step(delta: float, tuning: GameplayTuning) -> Event:
    if not moving:
        return Event.NONE
    var previous: Vector3 = position
    # Exact step for constant gravity, so flight matches ShotSolver's parabola.
    position += velocity * delta + Vector3.DOWN * (0.5 * tuning.gravity * delta * delta)
    velocity.y -= tuning.gravity * delta
    if NetCollision.hits_net(previous, position, RADIUS):
        # shortcut: the net swallows the ball; give it a real rebound when net play matters.
        stop()
        return Event.NET
    var event: Event = Event.NONE
    if position.y <= RADIUS and velocity.y < 0.0:
        # Back up to the moment of floor contact so in/out is judged on the real landing point.
        if previous.y > position.y:
            position = previous.lerp(position, clampf((previous.y - RADIUS) / (previous.y - position.y), 0.0, 1.0))
        position.y = RADIUS
        velocity.y = -velocity.y * tuning.bounce_restitution
        velocity.x *= tuning.bounce_friction
        velocity.z *= tuning.bounce_friction
        if velocity.y < REST_SPEED:
            stop()
        event = Event.BOUNCE
    if absf(position.z) > WORLD_LIMIT_Z or absf(position.x) > WORLD_LIMIT_X:
        stop() # rolled far off the court; nothing left to report
    return event
