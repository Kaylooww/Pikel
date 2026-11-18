extends SceneTree
## Run with: godot --headless --path . --script res://tests/unit/test_camera.gd
## Camera maths and rig switching (RP-013). Headless: says nothing about how the views look.
var errors: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    var training: CameraRig = load("res://config/camera_training.tres")
    var chase: CameraRig = load("res://config/camera_match.tres")
    var behind: CameraRig = load("res://config/camera_chase.tres")
    _assert(training != null and chase != null and behind != null, "all rig files load as CameraRig")

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

    # The default rig is a low third-person view that rides behind the player.
    for z in [0.35, 3.0, 7.0]:
        var at := Vector3(1.5, 0.0, z)
        var cam_at: Vector3 = behind.desired_position(at)
        var look: Vector3 = behind.look_target(at)
        _assert(is_equal_approx(cam_at.z - z, behind.base_z), "behind-the-player camera keeps the same distance at z=%s" % z)
        var pitch: float = rad_to_deg(atan2(cam_at.y, cam_at.z - look.z))
        _assert(pitch > 15.0 and pitch < 30.0, "behind-the-player camera looks down only %d degrees, not from above (z=%s)" % [pitch, z])
        # Degrees below the horizon of a point on the ground; the vertical fov is centred on the pitch.
        var feet: float = rad_to_deg(atan2(cam_at.y, cam_at.z - z))
        var far_baseline: float = rad_to_deg(atan2(cam_at.y, cam_at.z + CourtDimensions.HALF_LENGTH))
        _assert(feet > pitch and feet < pitch + behind.fov * 0.5, "the player stands in the lower half of the view (z=%s)" % z)
        _assert(far_baseline > pitch - behind.fov * 0.5, "the whole far court is in view (z=%s)" % z)
    _assert(behind.height < chase.height, "behind-the-player camera is the lowest")

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
    _assert(cam.rigs.size() == 3 and cam.active_rig() == behind, "camera starts on the behind-the-player rig")
    cam.rig_index = cam.rigs.find(training)
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
    _assert(cam.active_rig() == behind, "next_rig wraps around to the default rig")
    cam.next_rig()
    _assert(cam.active_rig() == chase, "C cycles on to the match rig")
    for i in range(300):
        cam._process(1.0 / 60.0)
    _assert(cam.position.distance_to(chase.desired_position(target.position)) < 0.001 and is_equal_approx(cam.fov, chase.fov), "camera glides to the match view")
    cam.next_rig()
    _assert(cam.active_rig() == training, "then to the training rig")
    # Away side: the same view mirrored to the other end of the court.
    cam.side = -1
    target.position = Vector3(2.0, 0.0, -5.0)
    cam.snap()
    var home_view: Vector3 = training.desired_position(Vector3(-2.0, 0.0, 5.0))
    _assert(cam.position.is_equal_approx(Vector3(-home_view.x, home_view.y, -home_view.z)), "away camera sits behind the away baseline, mirrored")
    _assert(cam.position.z < -5.0 and (-cam.basis.z).z > 0.0, "away camera looks toward the home half")
    # Mouse aim needs the camera inside the tree, which only happens after the first frame.
    aim_cam = cam
    aim_target = target

var aim_cam: CourtCamera
var aim_target: Node3D

func _process(_delta: float) -> bool:
    var cam: CourtCamera = aim_cam
    var target: Node3D = aim_target
    # Mouse aim from the default behind-the-player view.
    cam.side = 1
    cam.rig_index = 0
    target.position = Vector3(0.5, 0.0, 6.0)
    cam.snap()
    var size: Vector2 = cam.get_viewport().get_visible_rect().size
    var middle: Vector3 = CourtAim.target_from_mouse(cam, size * Vector2(0.5, 0.35), 1, Vector3.ZERO)
    var higher: Vector3 = CourtAim.target_from_mouse(cam, size * Vector2(0.5, 0.3), 1, Vector3.ZERO)
    var sky: Vector3 = CourtAim.target_from_mouse(cam, size * Vector2(0.7, 0.02), 1, Vector3.ZERO)
    _assert(middle.z < 0.0 and higher.z < middle.z, "moving the cursor up aims deeper into the far court")
    _assert(is_equal_approx(sky.z, -(CourtDimensions.HALF_LENGTH - CourtAim.BASELINE_MARGIN)) and sky.x > 0.0, "a cursor above the horizon aims at the far baseline on its side")
    cam.free()
    target.free()

    if errors.is_empty():
        print("PASS: %d camera checks" % checks)
        quit(0)
    else:
        for error in errors: printerr("FAIL: ", error)
        quit(1)
    return false

func _assert(condition: bool, desc: String) -> void:
    checks += 1
    if not condition:
        errors.append(desc)
