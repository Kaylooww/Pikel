extends RefCounted
class_name PlayerInput
## What one player asks for during one simulation tick. It is a request: the simulation
## decides whether the player may move there or whether the swing connects.

enum Swing { NONE, DRIVE, DINK, BLOCK, LOB } ## same numbers as ShotRecipe.Kind

var seq: int = 0 ## increases by one per input a client sends; 0 for local play
var move: Vector2 = Vector2.ZERO ## world space: x sideways, y along +z. Length is capped at 1 when used
var sprint: bool = false
var swing: Swing = Swing.NONE
var power: float = 0.0 ## 0..1 charge of a drive or lob; ignored for dinks and blocks
var stroke: SwingContact.Stroke = SwingContact.Stroke.NONE ## the side picked with Q (backhand) or E (forehand) for this swing
var aim: Vector3 = Vector3.ZERO ## intended landing point on the court

static func make(move_vector: Vector2 = Vector2.ZERO, sprinting: bool = false, swing_type: Swing = Swing.NONE, aim_at: Vector3 = Vector3.ZERO, sequence: int = 0, charge: float = 0.0, side_stroke: SwingContact.Stroke = SwingContact.Stroke.NONE) -> PlayerInput:
    var input := PlayerInput.new()
    input.move = move_vector
    input.sprint = sprinting
    input.swing = swing_type
    input.aim = aim_at
    input.seq = sequence
    input.power = clampf(charge, 0.0, 1.0)
    input.stroke = side_stroke
    return input

func shot_kind() -> ShotRecipe.Kind:
    return int(swing) as ShotRecipe.Kind
