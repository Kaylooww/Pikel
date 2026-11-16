extends CharacterBody3D
class_name PickleballPlayer
## Prototype player controller: one local character plus one basic scripted practice opponent.
@export var home_side: bool = true
@export var controlled_by_ai: bool = false
@export var move_speed: float = 5.4
@export var sprint_speed: float = 7.2
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
        if Input.is_key_pressed(KEY_A): move.x -= 1.0
        if Input.is_key_pressed(KEY_D): move.x += 1.0
        if Input.is_key_pressed(KEY_W): move.z -= 1.0
        if Input.is_key_pressed(KEY_S): move.z += 1.0
    move = move.normalized()
    var speed: float = sprint_speed if (not controlled_by_ai and Input.is_key_pressed(KEY_SHIFT)) else move_speed
    velocity = move * speed
    move_and_slide()
    position.x = clampf(position.x, -3.65, 3.65)
    if home_side:
        position.z = clampf(position.z, 0.35, 7.35)
    else:
        position.z = clampf(position.z, -7.35, -0.35)
    if move.length_squared() > 0.01:
        facing_direction = move
