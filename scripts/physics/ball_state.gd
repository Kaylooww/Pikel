extends RefCounted
class_name BallState
## The ball as plain data plus its fixed-step physics. No scene access, so the same code
## runs in the visual ball node, the match simulation and tests.
## It only reports what physically happened; the rules decide what it means.
##
## Flight uses BallFlight (gravity, air drag, spin lift), stepped exactly. A bounce keeps
## `bounce_restitution` of the vertical speed and `bounce_friction` of the horizontal speed,
## then spin acts on it: topspin skids on faster and lower, backspin checks up and sits a
## little higher. The ball keeps `bounce_spin_keep` of its spin after each bounce.

enum Event { NONE, BOUNCE, NET }

const RADIUS: float = CourtDimensions.BALL_VISUAL_RADIUS
const REST_SPEED: float = 0.5 # a bounce slower than this leaves the ball lying still
const MAX_BOUNCE_KEEP: float = 0.95 # spin can never make a bounce livelier than this
const WORLD_LIMIT_X: float = 18.0
const WORLD_LIMIT_Z: float = 24.0

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var spin: float = 0.0 ## rev/s, positive is topspin
var moving: bool = false

func place(at: Vector3) -> void:
    position = at
    stop()

func stop() -> void:
    velocity = Vector3.ZERO
    spin = 0.0
    moving = false

func copy() -> BallState:
    var other := BallState.new()
    other.position = position
    other.velocity = velocity
    other.spin = spin
    other.moving = moving
    return other

## Hits the ball toward `target` if the solver finds a shot that clears the net.
## The ball is left untouched when the returned solution is not ok.
func launch(target: Vector3, recipe: ShotRecipe, tuning: GameplayTuning) -> ShotSolver.Solution:
    var shot: ShotSolver.Solution = ShotSolver.solve(position, target, recipe, tuning)
    if shot.ok:
        velocity = shot.velocity
        spin = shot.spin
        moving = true
    return shot

## Advances one step and says what happened during it.
func step(delta: float, tuning: GameplayTuning) -> Event:
    if not moving:
        return Event.NONE
    var previous: Vector3 = position
    # Exact step of the drag-and-spin flight, so it matches ShotSolver's arc.
    position = BallFlight.position_at(previous, velocity, spin, delta, tuning)
    velocity = BallFlight.velocity_at(velocity, spin, delta, tuning)
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
        bounce(tuning)
        if velocity.y < REST_SPEED:
            stop()
        event = Event.BOUNCE
    if absf(position.z) > WORLD_LIMIT_Z or absf(position.x) > WORLD_LIMIT_X:
        stop() # rolled far off the court; nothing left to report
    return event

## The floor contact itself: speed lost to the court, then the spin's effect.
func bounce(tuning: GameplayTuning) -> void:
    var keep_up: float = clampf(tuning.bounce_restitution * (1.0 - tuning.bounce_spin_height * spin), 0.0, MAX_BOUNCE_KEEP)
    velocity.y = -velocity.y * keep_up
    var flat := Vector2(velocity.x, velocity.z)
    var speed: float = flat.length()
    if speed > 0.0001:
        var along: float = maxf(speed * tuning.bounce_friction + tuning.bounce_spin_kick * spin, 0.0)
        flat = flat / speed * along
        velocity.x = flat.x
        velocity.z = flat.y
    spin *= tuning.bounce_spin_keep

## Where and when the ball first touches the floor (or the net) from here, by stepping a copy.
## Returns {"position": Vector3, "time": float, "event": Event}; event NONE means it never
## landed within `max_time`.
func predict_landing(tuning: GameplayTuning, dt: float = 1.0 / 60.0, max_time: float = 4.0) -> Dictionary:
    var ghost: BallState = copy()
    var t: float = 0.0
    while ghost.moving and t < max_time:
        var event: Event = ghost.step(dt, tuning)
        t += dt
        if event != Event.NONE:
            return {"position": ghost.position, "time": t, "event": event}
    return {"position": ghost.position, "time": t, "event": Event.NONE}
