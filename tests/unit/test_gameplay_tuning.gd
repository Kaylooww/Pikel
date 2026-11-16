extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_gameplay_tuning.gd
## Proves the tuning resource loads, is sane, and actually drives the ball (RP-005).
const BALL_SCENE := preload("res://scenes/ball/ball.tscn")
const STEP: float = 1.0 / 60.0
var errors: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    var shipped: Resource = load("res://config/gameplay_tuning.tres")
    _assert(shipped is GameplayTuning, "config/gameplay_tuning.tres is a GameplayTuning")
    var t: GameplayTuning = shipped
    _assert(t.gravity > 0.0, "gravity is positive")
    _assert(t.drive_speed > t.dink_speed and t.dink_speed > 0.0, "drive is faster than dink")
    _assert(t.min_flight_time > 0.0 and t.min_flight_time < t.max_flight_time, "flight time range is ordered")
    _assert(t.bounce_restitution > 0.0 and t.bounce_restitution < 1.0, "bounce loses height")
    _assert(t.sprint_speed >= t.move_speed and t.move_speed > 0.0, "sprint is not slower than run")
    _assert(t.min_net_distance > 0.0 and t.min_net_distance < t.max_back_distance, "player z range is ordered")
    _assert(t.player_reach > 0.0 and t.bot_reach > 0.0, "reach is positive")

    var ball: PickleballBall = BALL_SCENE.instantiate()
    _assert(ball.tuning == t, "ball uses the shipped tuning by default")

    # Swapping the resource changes behaviour with no script edits.
    var custom := GameplayTuning.new()
    custom.gravity = 0.0
    ball.tuning = custom
    ball.position = Vector3(0, 3.0, 3.0)
    ball.ball_velocity = Vector3(0, 1.0, 0)
    ball.moving = true
    ball._physics_process(STEP)
    _assert(is_equal_approx(ball.ball_velocity.y, 1.0), "zero gravity leaves vertical speed alone")

    custom.gravity = 20.0
    ball._physics_process(STEP)
    _assert(is_equal_approx(ball.ball_velocity.y, 1.0 - 20.0 * STEP), "gravity value is applied per step")

    custom.gravity = 0.0
    custom.bounce_restitution = 0.5
    custom.bounce_friction = 0.25
    ball.reset_ball(Vector3(0, PickleballBall.RADIUS + 0.01, 3.0))
    ball.ball_velocity = Vector3(4.0, -6.0, 0)
    ball.moving = true
    ball._physics_process(STEP)
    _assert(is_equal_approx(ball.ball_velocity.y, 3.0), "restitution scales the bounce")
    _assert(is_equal_approx(ball.ball_velocity.x, 1.0), "friction scales horizontal speed")

    # A slower drive speed means a longer flight, so lower horizontal velocity.
    custom.min_flight_time = 0.0
    custom.max_flight_time = 10.0
    custom.drive_speed = 10.0
    custom.dink_speed = 5.0
    ball.reset_ball(Vector3(0, 1.0, 5.0))
    ball.launch(Vector3(0, 0, -5.0), false, 1)
    _assert(is_equal_approx(ball.ball_velocity.z, -10.0), "drive uses drive_speed")
    ball.reset_ball(Vector3(0, 1.0, 5.0))
    ball.launch(Vector3(0, 0, -5.0), true, 1)
    _assert(is_equal_approx(ball.ball_velocity.z, -5.0), "dink uses dink_speed")
    ball.free()

    if errors.is_empty():
        print("PASS: %d gameplay tuning checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
