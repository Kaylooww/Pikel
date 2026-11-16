extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_camera.gd
## Camera maths and rig switching (RP-013). Headless: says nothing about how the views look.
var errors: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    var training: CameraRig = load("res://config/camera_training.tres")
    var chase: CameraRig = load("res://config/camera_match.tres")
    _assert(training != null and chase != null, "both rig files load as CameraRig")

    # The training rig reproduces the camera the prototype always had.
    var p := Vector3(2.0, 0.0, 5.0)
    _assert(training.desired_position(p).is_equal_approx(Vector3(0.7, 9.2, 12.0)), "training rig keeps the original raised view")
    _assert(training.look_target(p).is_equal_approx(Vector3(0.32, 0.0, -0.15)), "training rig keeps the original look point")
    _assert(is_equal_approx(training.desired_position(Vector3(2.0, 0.0, 1.0)).z, 12.0), "training camera does not move in depth")

    # The match rig is a lower chase view that follows the player in depth.
    _assert(chase.height < training.height, "match camera is lower")
    _assert(chase.desired_position(Vector3(0, 0, 6.0)).z > chase.desired_position(Vector3(0, 0, 1.0)).z, "match camera follows the player back")
    _assert(chase.desired_position(Vector3(0, 0, 0.35)).z > 0.35 + 3.0, "match camera stays behind a player at the net")
    _assert(chase.look_z < 0.0 and training.look_z < 0.0, "both rigs look at the far half")

    # Smoothing is frame-rate independent: two half steps equal one full step.
    var one: float = CameraRig.smooth_weight(4.0, 1.0 / 30.0)
    var half: float = CameraRig.smooth_weight(4.0, 1.0 / 60.0)
    _assert(is_equal_approx(1.0 - one, (1.0 - half) * (1.0 - half)), "smoothing is frame-rate independent")
    _assert(is_zero_approx(CameraRig.smooth_weight(4.0, 0.0)), "zero time means no movement")

    # The camera node follows a target and switches rigs.
    var target := Node3D.new()
    target.position = p
    var cam := CourtCamera.new()
    root.add_child(target)
    root.add_child(cam)
    _assert(cam.rigs.size() == 2 and cam.active_rig() == training, "camera starts on the training rig")
    cam.target = target
    cam.snap()
    _assert(cam.position.is_equal_approx(training.desired_position(p)), "snap puts the camera on the rig position")
    _assert(cam.basis.z.dot(cam.position - training.look_target(p)) > 0.0, "camera faces its look point")
    target.position = Vector3(-2.0, 0.0, 3.0)
    cam._process(1.0 / 60.0)
    var after_one: float = cam.position.distance_to(training.desired_position(target.position))
    _assert(after_one > 0.01, "camera does not teleport to a moved player")
    for i in range(300):
        cam._process(1.0 / 60.0)
    _assert(cam.position.distance_to(training.desired_position(target.position)) < 0.001, "camera settles on the player")
    cam.next_rig()
    _assert(cam.active_rig() == chase, "next_rig switches to the match rig")
    for i in range(300):
        cam._process(1.0 / 60.0)
    _assert(cam.position.distance_to(chase.desired_position(target.position)) < 0.001 and is_equal_approx(cam.fov, chase.fov), "camera glides to the match view")
    cam.next_rig()
    _assert(cam.active_rig() == training, "next_rig wraps around")
    cam.free()
    target.free()

    if errors.is_empty():
        print("PASS: %d camera checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
