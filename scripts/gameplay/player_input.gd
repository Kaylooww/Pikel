extends RefCounted
class_name PlayerInput
## What one player asks for during one simulation tick. It is a request: the simulation
## decides whether the player may move there or whether the swing connects.

enum Swing { NONE, DRIVE, DINK }

var seq: int = 0 ## increases by one per input a client sends; 0 for local play
var move: Vector2 = Vector2.ZERO ## world space: x sideways, y along +z. Length is capped at 1 when used
var sprint: bool = false
var swing: Swing = Swing.NONE
var aim: Vector3 = Vector3.ZERO ## intended landing point on the court

static func make(move_vector: Vector2 = Vector2.ZERO, sprinting: bool = false, swing_type: Swing = Swing.NONE, aim_at: Vector3 = Vector3.ZERO, sequence: int = 0) -> PlayerInput:
    var input := PlayerInput.new()
    input.move = move_vector
    input.sprint = sprinting
    input.swing = swing_type
    input.aim = aim_at
    input.seq = sequence
    return input
