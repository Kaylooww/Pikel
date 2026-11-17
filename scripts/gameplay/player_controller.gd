extends CharacterBody3D
class_name PickleballPlayer
## The player you see. In practice it moves itself from local input or a scripted direction;
## in a match the simulation owns positions and this node's physics processing is switched off.
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

func _physics_process(delta: float) -> void:
    var move: Vector2 = Vector2(ai_direction.x, ai_direction.z) if controlled_by_ai else GameInput.move_vector()
    var sprint: bool = not controlled_by_ai and Input.is_action_pressed(GameInput.SPRINT)
    position = PlayerMotion.step(position, move, sprint, 1 if home_side else -1, tuning, delta)
    if move.length_squared() > 0.01:
        facing_direction = Vector3(move.x, 0.0, move.y)
