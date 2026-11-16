extends CharacterBody3D
class_name PickleballPlayer
## Prototype player controller: one local character plus one basic scripted practice opponent.
@export var home_side: bool = true
@export var controlled_by_ai: bool = false
@export var tuning: GameplayTuning = preload("res://config/gameplay_tuning.tres")
var ai_direction: Vector3 = Vector3.ZERO
var facing_direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
    var body: MeshInstance3D = get_node("Body")
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("ff846c") if home_side else Color("4dd4bd")
    body.material_override = material

func _physics_process(_delta: float) -> void:
    var move: Vector3 = Vector3.ZERO
    if controlled_by_ai:
        move = ai_direction
    else:
        var input: Vector2 = GameInput.move_vector()
        move = Vector3(input.x, 0.0, input.y)
    move = move.normalized()
    var speed: float = tuning.sprint_speed if (not controlled_by_ai and Input.is_action_pressed(GameInput.SPRINT)) else tuning.move_speed
    velocity = move * speed
    move_and_slide()
    position.x = clampf(position.x, -tuning.max_side_distance, tuning.max_side_distance)
    if home_side:
        position.z = clampf(position.z, tuning.min_net_distance, tuning.max_back_distance)
    else:
        position.z = clampf(position.z, -tuning.max_back_distance, -tuning.min_net_distance)
    if move.length_squared() > 0.01:
        facing_direction = move
