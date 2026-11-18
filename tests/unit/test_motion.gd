extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_motion.gd
## Pure player movement and pure ball stepping, shared by local play, server and prediction.
const DT: float = 1.0 / 60.0
var errors: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    var t := GameplayTuning.new()

    # Player movement.
    var start := Vector3(0.0, 0.0, 5.0)
    var walked: Vector3 = PlayerMotion.step(start, Vector2(1, 0), false, 1, t, DT)
    _assert(is_equal_approx(walked.x, t.move_speed * DT) and is_equal_approx(walked.z, 5.0), "one step sideways covers move_speed * dt")
    var sprinted: Vector3 = PlayerMotion.step(start, Vector2(0, -1), true, 1, t, DT)
    _assert(is_equal_approx(start.z - sprinted.z, t.sprint_speed * DT), "sprint uses sprint_speed")
    var cheat: Vector3 = PlayerMotion.step(start, Vector2(50, -50), true, 1, t, DT)
    _assert(start.distance_to(cheat) <= t.sprint_speed * DT + 0.00001, "an oversized input vector cannot exceed top speed")
    var diagonal: Vector3 = PlayerMotion.step(start, Vector2(1, 1), false, 1, t, DT)
    _assert(start.distance_to(diagonal) <= t.move_speed * DT + 0.00001, "diagonal movement is not faster")
    _assert(PlayerMotion.step(start, Vector2.ZERO, true, 1, t, DT) == start, "no input, no movement")
    var p: Vector3 = start
    for i in range(600):
        p = PlayerMotion.step(p, Vector2(0, -1), true, 1, t, DT)
    _assert(is_equal_approx(p.z, t.min_net_distance), "home player cannot run through the net")
    p = Vector3(0.0, 0.0, -5.0)
    for i in range(600):
        p = PlayerMotion.step(p, Vector2(1, 1), true, -1, t, DT)
    _assert(is_equal_approx(p.z, -t.min_net_distance) and is_equal_approx(p.x, t.max_side_distance), "away player is held on their half and inside the side limit")
    _assert(PlayerMotion.step(Vector3(0, 3, 5), Vector2.ZERO, false, 1, t, DT).y == 0.0, "players stay on the ground")

    # Ball: the node and the pure state must fly identically.
    var state := BallState.new()
    state.place(Vector3(0.3, 1.0, 5.0))
    var node: PickleballBall = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
    node.tuning = t
    node.reset_ball(state.position)
    _assert(state.launch(Vector3(-1.5, 0, -4.5), ShotRecipe.make(ShotRecipe.Kind.DRIVE, 0.5, false, t), t).ok and node.launch(Vector3(-1.5, 0, -4.5), ShotRecipe.make(ShotRecipe.Kind.DRIVE, 0.5, false, t)).ok, "both accept the same shot")
    var same: bool = true
    var bounces: int = 0
    for i in range(240):
        if state.step(DT, t) == BallState.Event.BOUNCE:
            bounces += 1
        node._physics_process(DT)
        same = same and state.position == node.position and state.velocity == node.ball_velocity and state.spin == node.ball_spin and state.moving == node.moving
    _assert(same, "ball node and BallState stay identical for four seconds")
    _assert(bounces >= 2 and not state.moving, "the ball bounces and comes to rest")
    node.free()

    # Ball events.
    state.place(Vector3(0.0, 0.5, 1.0))
    state.velocity = Vector3(0.0, 0.0, -10.0)
    state.moving = true
    var event: BallState.Event = BallState.Event.NONE
    for i in range(30):
        event = state.step(DT, t)
        if event != BallState.Event.NONE:
            break
    _assert(event == BallState.Event.NET and not state.moving, "a low flat ball reports NET and stops")
    state.place(Vector3(0.0, 0.3, 3.0))
    _assert(state.step(DT, t) == BallState.Event.NONE and state.position == Vector3(0.0, 0.3, 3.0), "a ball that is not moving stays put")
    _assert(not state.launch(Vector3(0.0, 0.0, 3.0), ShotRecipe.make(ShotRecipe.Kind.DRIVE, 0.5, false, t), t).ok and not state.moving, "a refused shot leaves the ball alone")

    # Spin at the bounce: topspin skids on faster and lower, backspin checks up.
    var top: BallState = _bounce_once(Vector3(0.0, -6.0, -10.0), 25.0, t)
    var flat: BallState = _bounce_once(Vector3(0.0, -6.0, -10.0), 0.0, t)
    var back: BallState = _bounce_once(Vector3(0.0, -6.0, -10.0), -12.0, t)
    _assert(absf(top.velocity.z) > absf(flat.velocity.z) and absf(flat.velocity.z) > absf(back.velocity.z), "topspin kicks on, backspin checks up")
    _assert(top.velocity.y < flat.velocity.y and back.velocity.y > flat.velocity.y, "topspin bounces lower, backspin a little higher")
    _assert(absf(flat.velocity.z) < 10.0 and flat.velocity.y < 6.0, "every bounce loses speed")
    _assert(is_equal_approx(top.spin, 25.0 * t.bounce_spin_keep), "the ball keeps only part of its spin")
    _assert(back.velocity.z <= 0.0, "backspin never pulls the ball back toward the hitter")
    var landing_check := BallState.new()
    landing_check.position = Vector3(0.0, 1.0, 3.0)
    landing_check.launch(Vector3(0.5, 0.0, -4.0), ShotRecipe.make(ShotRecipe.Kind.DINK, 0.0, false, t), t)
    var predicted: Dictionary = landing_check.predict_landing(t)
    _assert(predicted["event"] == BallState.Event.BOUNCE and Vector2(predicted["position"].x - 0.5, predicted["position"].z + 4.0).length() < 0.02, "predict_landing finds the solved landing point")
    _assert(landing_check.moving and landing_check.position == Vector3(0.0, 1.0, 3.0), "predicting does not move the real ball")

    if errors.is_empty():
        print("PASS: %d motion checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

## One floor contact of a ball arriving with this velocity and spin.
func _bounce_once(velocity: Vector3, spin: float, tuning: GameplayTuning) -> BallState:
    var ball := BallState.new()
    ball.position = Vector3(0.0, BallState.RADIUS, 2.0)
    ball.velocity = velocity
    ball.spin = spin
    ball.moving = true
    ball.bounce(tuning)
    return ball

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
