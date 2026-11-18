extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_shot_solver.gd
## Checks the solver's answers and that the real ball, with drag and spin, flies where the
## solver says (RP-011), for every shot type.
const BALL_SCENE := preload("res://scenes/ball/ball.tscn")
const STEP: float = 1.0 / 60.0
const R: float = CourtDimensions.BALL_VISUAL_RADIUS
const K := ShotRecipe.Kind
var errors: Array[String] = []
var checks: int = 0
var landing: Vector3 = Vector3.INF
var fault_reason: String = ""
var t := GameplayTuning.new()

func _initialize() -> void:
    # A normal drive from mid-court.
    var origin := Vector3(0.3, 1.0, 5.0)
    var target := Vector3(-1.5, 0.0, -4.5)
    var drive: ShotSolver.Solution = ShotSolver.solve(origin, target, _r(K.DRIVE, 0.5), t)
    _assert(drive.ok and drive.reason == ShotSolver.Reason.NONE and drive.spin > 0.0, "clean drive is accepted, with topspin")
    var end: Vector3 = BallFlight.position_at(origin, drive.velocity, drive.spin, drive.flight_time, t)
    _assert(end.distance_to(Vector3(target.x, R, target.z)) < 0.001, "solved arc ends on the target")
    var dink: ShotSolver.Solution = ShotSolver.solve(origin, target, _r(K.DINK), t)
    _assert(dink.ok and dink.flight_time > drive.flight_time and dink.spin < 0.0, "dink flies longer than drive, with backspin")
    var hard: ShotSolver.Solution = ShotSolver.solve(origin, target, _r(K.DRIVE, 1.0), t)
    var soft: ShotSolver.Solution = ShotSolver.solve(origin, target, _r(K.DRIVE, 0.0), t)
    _assert(hard.ok and soft.ok and hard.flight_time < soft.flight_time and hard.velocity.length() > soft.velocity.length(), "more charge means a faster drive")
    var low_lob: ShotSolver.Solution = ShotSolver.solve(origin, target, _r(K.LOB, 0.0), t)
    var high_lob: ShotSolver.Solution = ShotSolver.solve(origin, target, _r(K.LOB, 1.0), t)
    _assert(low_lob.ok and high_lob.ok and _apex(origin, high_lob) > _apex(origin, low_lob) + 0.5, "more charge means a higher lob")
    _assert(_apex(origin, low_lob) > _apex(origin, dink) + 1.0, "a lob arcs far higher than a dink")
    _assert(high_lob.target.z < target.z - 1.0 and CourtDimensions.inside_court(high_lob.target), "a charged lob carries deeper than the aim but stays in")
    var block: ShotSolver.Solution = ShotSolver.solve(origin, Vector3(1.0, 0.0, -6.0), _r(K.BLOCK), t)
    _assert(block.ok and absf(block.target.z) <= t.block_max_depth + 0.001 and block.target.x == 1.0, "a block always lands short, on the aimed line")

    # Drag and spin really shape the flight.
    var drive_mid: Vector3 = BallFlight.position_at(origin, drive.velocity, drive.spin, drive.flight_time * 0.5, t)
    var no_spin_mid: Vector3 = BallFlight.position_at(origin, drive.velocity, 0.0, drive.flight_time * 0.5, t)
    _assert(drive_mid.y < no_spin_mid.y, "topspin pulls the drive down (it dips)")
    var dink_mid: Vector3 = BallFlight.position_at(origin, dink.velocity, dink.spin, dink.flight_time * 0.5, t)
    var dink_flat_mid: Vector3 = BallFlight.position_at(origin, dink.velocity, 0.0, dink.flight_time * 0.5, t)
    _assert(dink_mid.y > dink_flat_mid.y, "backspin holds the dink up (it floats)")
    var still_air := GameplayTuning.new()
    still_air.air_drag = 0.0
    var v_drag: Vector3 = BallFlight.velocity_at(Vector3(0, 0, -15), 0.0, 0.5, t)
    var v_none: Vector3 = BallFlight.velocity_at(Vector3(0, 0, -15), 0.0, 0.5, still_air)
    _assert(absf(v_drag.z) < absf(v_none.z) and is_equal_approx(v_none.z, -15.0), "air drag slows the ball; no drag keeps its pace")

    # Preferred flight time would hit the net, a higher arc clears: the solver must lift it.
    var low_origin := Vector3(0.0, 0.4, 1.0)
    var short_target := Vector3(0.0, 0.0, -3.0)
    var flat_time: float = t.min_flight_time
    var flat_velocity: Vector3 = BallFlight.launch_velocity(low_origin, Vector3(0, R, -3.0), t.dink_spin, flat_time, t)
    _assert(not ShotSolver.clears_net(low_origin, flat_velocity, t.dink_spin, flat_time, t), "the unadjusted arc really hits the net")
    var lifted: ShotSolver.Solution = ShotSolver.solve(low_origin, short_target, _r(K.DINK), t)
    _assert(lifted.ok and lifted.flight_time > t.min_flight_time, "solver raises the arc to clear")

    # Refusals.
    var hopeless: ShotSolver.Solution = ShotSolver.solve(Vector3(0.0, 0.3, 0.4), Vector3(0.0, 0.0, -6.5), _r(K.DRIVE), t)
    _assert(not hopeless.ok and hopeless.reason == ShotSolver.Reason.NET, "low ball at the net aimed deep is refused")
    _assert(ShotSolver.solve(origin, Vector3(0, 0, 3.0), _r(K.DRIVE), t).reason == ShotSolver.Reason.BAD_TARGET, "own half is refused")
    _assert(ShotSolver.solve(origin, Vector3(5.0, 0, -4.0), _r(K.DRIVE), t).reason == ShotSolver.Reason.BAD_TARGET, "target outside the court is refused")
    var slow := GameplayTuning.new()
    slow.max_launch_speed = 5.0
    _assert(ShotSolver.solve(origin, target, ShotRecipe.make(K.DRIVE, 0.5, false, slow), slow).reason == ShotSolver.Reason.TOO_FAST, "shot above max launch speed is refused")

    # The real ball lands where the solver aimed, for every shot type and the lifted shot.
    for kind: K in [K.DRIVE, K.DINK, K.BLOCK, K.LOB]:
        for charge: float in [0.0, 1.0]:
            var recipe: ShotRecipe = _r(kind, charge)
            var shot: ShotSolver.Solution = ShotSolver.solve(origin, target, recipe, t)
            var landed: Vector3 = _fly(origin, target, recipe)
            _assert(shot.ok and landed.distance_to(Vector3(shot.target.x, R, shot.target.z)) < 0.02 and fault_reason == "",
                "%s at charge %.0f lands on its target" % [ShotRecipe.kind_name(kind), charge])
    _assert(_fly(low_origin, short_target, _r(K.DINK)).distance_to(Vector3(short_target.x, R, short_target.z)) < 0.02, "ball lands on the lifted target")
    _assert(fault_reason == "", "lifted shot does not fault")
    var corner := Vector3(-CourtDimensions.HALF_WIDTH, 0, -CourtDimensions.HALF_LENGTH)
    _assert(_fly(Vector3(2.5, 0.9, 6.0), corner, _r(K.DRIVE, 0.7)).distance_to(Vector3(corner.x, R, corner.z)) < 0.02, "ball lands on the far corner")
    _assert(fault_reason == "", "a shot aimed exactly at the corner is in")

    # Preview points come from the same solved arc (RP-012).
    var arc: PackedVector3Array = ShotSolver.sample_arc(origin, drive, t, 16)
    _assert(arc.size() == 16, "arc has the requested number of points")
    _assert(arc[0].is_equal_approx(origin), "arc starts at the ball")
    _assert(arc[15].distance_to(Vector3(target.x, R, target.z)) < 0.001, "arc ends on the target")
    var forward: bool = true
    for i in range(1, arc.size()):
        forward = forward and arc[i].z < arc[i - 1].z and arc[i].y >= R - 0.001
    _assert(forward, "arc moves toward the target and stays above the floor")
    _assert(ShotSolver.sample_arc(Vector3(0.0, 0.3, 0.4), hopeless, t).is_empty(), "a refused shot has no arc")
    var preview := TrajectoryPreview.new()
    preview.show_points(arc)
    _assert(preview.multimesh.visible_instance_count == 16, "preview shows one dot per point")
    _assert(preview.shown_points[15].is_equal_approx(arc[15]), "last dot sits on the landing point")
    preview.show_points(PackedVector3Array())
    _assert(preview.multimesh.visible_instance_count == 0, "empty arc hides the preview")
    preview.free()

    # A refused shot leaves the ball alone.
    var ball: PickleballBall = BALL_SCENE.instantiate()
    ball.reset_ball(Vector3(0.0, 0.3, 0.4))
    _assert(not ball.launch(Vector3(0.0, 0.0, -6.5), _r(K.DRIVE)).ok and not ball.moving, "refused shot does not move the ball")
    ball.free()

    if errors.is_empty():
        print("PASS: %d shot solver checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

func _r(kind: ShotRecipe.Kind, charge: float = 0.5) -> ShotRecipe:
    return ShotRecipe.make(kind, charge, false, t)

## Highest point of a solved flight, sampled every tick.
func _apex(origin: Vector3, shot: ShotSolver.Solution) -> float:
    var top: float = origin.y
    var time: float = 0.0
    while time < shot.flight_time:
        time += STEP
        top = maxf(top, BallFlight.position_at(origin, shot.velocity, shot.spin, time, t).y)
    return top

## Launches a real ball and steps it until its first bounce or fault. Returns the landing point.
func _fly(origin: Vector3, target: Vector3, recipe: ShotRecipe) -> Vector3:
    var ball: PickleballBall = BALL_SCENE.instantiate()
    ball.tuning = t
    landing = Vector3.INF
    fault_reason = ""
    ball.bounced.connect(func(point: Vector3) -> void:
        if landing == Vector3.INF:
            landing = point
            if not CourtDimensions.inside_court(point): fault_reason = "OUT")
    ball.net_hit.connect(func(_point: Vector3) -> void: fault_reason = "NET")
    ball.reset_ball(origin)
    ball.launch(target, recipe)
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
