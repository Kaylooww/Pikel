extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_shot_solver.gd
## Checks the solver's answers and that the real ball flies where the solver says (RP-011).
const BALL_SCENE := preload("res://scenes/ball/ball.tscn")
const STEP: float = 1.0 / 60.0
const R: float = CourtDimensions.BALL_VISUAL_RADIUS
var errors: Array[String] = []
var checks: int = 0
var landing: Vector3 = Vector3.INF
var fault_reason: String = ""

func _initialize() -> void:
    var t := GameplayTuning.new()

    # A normal drive from mid-court.
    var origin := Vector3(0.3, 1.0, 5.0)
    var target := Vector3(-1.5, 0.0, -4.5)
    var drive: ShotSolver.Solution = ShotSolver.solve(origin, target, false, t)
    _assert(drive.ok and drive.reason == ShotSolver.Reason.NONE, "clean drive is accepted")
    var end: Vector3 = ShotSolver.position_at(origin, drive.velocity, t.gravity, drive.flight_time)
    _assert(end.distance_to(Vector3(target.x, R, target.z)) < 0.001, "solved arc ends on the target")
    var dink: ShotSolver.Solution = ShotSolver.solve(origin, target, true, t)
    _assert(dink.ok and dink.flight_time > drive.flight_time, "dink flies longer than drive")

    # Preferred flight time would hit the net, a higher arc clears: the solver must lift it.
    var low_origin := Vector3(0.0, 0.4, 1.0)
    var short_target := Vector3(0.0, 0.0, -3.0)
    var flat_time: float = t.min_flight_time
    var flat_rise: float = (R - low_origin.y + 0.5 * t.gravity * flat_time * flat_time) / flat_time
    var flat_velocity := Vector3(0.0, flat_rise, (short_target.z - low_origin.z) / flat_time)
    _assert(not ShotSolver.clears_net(low_origin, flat_velocity, flat_time, t.gravity, R), "the unadjusted arc really hits the net")
    var lifted: ShotSolver.Solution = ShotSolver.solve(low_origin, short_target, false, t)
    _assert(lifted.ok and lifted.flight_time > t.min_flight_time, "solver raises the arc to clear")

    # Refusals.
    var hopeless: ShotSolver.Solution = ShotSolver.solve(Vector3(0.0, 0.3, 0.4), Vector3(0.0, 0.0, -6.5), false, t)
    _assert(not hopeless.ok and hopeless.reason == ShotSolver.Reason.NET, "low ball at the net aimed deep is refused")
    _assert(ShotSolver.solve(origin, Vector3(0, 0, 3.0), false, t).reason == ShotSolver.Reason.BAD_TARGET, "own half is refused")
    _assert(ShotSolver.solve(origin, Vector3(5.0, 0, -4.0), false, t).reason == ShotSolver.Reason.BAD_TARGET, "target outside the court is refused")
    var slow := GameplayTuning.new()
    slow.max_launch_speed = 5.0
    _assert(ShotSolver.solve(origin, target, false, slow).reason == ShotSolver.Reason.TOO_FAST, "shot above max launch speed is refused")

    # The real ball lands where the solver aimed, for both the easy and the lifted shot.
    _assert(_fly(origin, target, false, t).distance_to(Vector3(target.x, R, target.z)) < 0.02, "ball lands on the drive target")
    _assert(fault_reason == "", "drive does not fault")
    _assert(_fly(low_origin, short_target, false, t).distance_to(Vector3(short_target.x, R, short_target.z)) < 0.02, "ball lands on the lifted target")
    _assert(fault_reason == "", "lifted shot does not fault")
    _assert(_fly(Vector3(2.5, 0.9, 6.0), Vector3(-CourtDimensions.HALF_WIDTH, 0, -CourtDimensions.HALF_LENGTH), false, t).distance_to(Vector3(-CourtDimensions.HALF_WIDTH, R, -CourtDimensions.HALF_LENGTH)) < 0.02, "ball lands on the far corner")
    _assert(fault_reason == "", "a shot aimed exactly at the corner is in")

    # A refused shot leaves the ball alone.
    var ball: PickleballBall = BALL_SCENE.instantiate()
    ball.reset_ball(Vector3(0.0, 0.3, 0.4))
    _assert(not ball.launch(Vector3(0.0, 0.0, -6.5), false, 1).ok and not ball.moving, "refused shot does not move the ball")
    ball.free()

    if errors.is_empty():
        print("PASS: %d shot solver checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

## Launches a real ball and steps it until its first bounce or fault. Returns the landing point.
func _fly(origin: Vector3, target: Vector3, soft: bool, tuning: GameplayTuning) -> Vector3:
    var ball: PickleballBall = BALL_SCENE.instantiate()
    ball.tuning = tuning
    landing = Vector3.INF
    fault_reason = ""
    ball.bounced.connect(func(_side: int, _count: int, point: Vector3) -> void:
        if landing == Vector3.INF: landing = point)
    ball.fault.connect(func(reason: String) -> void: fault_reason = reason)
    ball.reset_ball(origin)
    ball.launch(target, soft, CourtDimensions.side_from_z(origin.z))
    for i in range(600):
        if landing != Vector3.INF or fault_reason != "":
            break
        ball._physics_process(STEP)
    ball.free()
    return landing

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
