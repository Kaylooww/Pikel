extends RefCounted
class_name CourtScenery
## Sky colour and sunlight shared by every court scene. Placeholder look, not final art.

static func add_environment(parent: Node) -> void:
    var env := WorldEnvironment.new()
    var world := Environment.new()
    world.background_mode = Environment.BG_COLOR
    world.background_color = Color("bde8f1")
    world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    world.ambient_light_color = Color("ffffff")
    world.ambient_light_energy = 0.8
    env.environment = world
    parent.add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55.0, -24.0, 0.0)
    sun.light_energy = 1.15
    parent.add_child(sun)
