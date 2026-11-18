extends Control
class_name ChargeMeter
## The power bar shown while a drive or lob is being charged. Display only: it is told what
## SwingButtons says and decides nothing.

const BAR_SIZE := Vector2(260, 18)
var bar := ProgressBar.new()
var caption := Label.new()

func _init() -> void:
    set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    position = Vector2(-BAR_SIZE.x / 2.0, -86)
    var stack := VBoxContainer.new()
    add_child(stack)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.custom_minimum_size = Vector2(BAR_SIZE.x, 0)
    caption.add_theme_font_size_override("font_size", 16)
    stack.add_child(caption)
    bar.custom_minimum_size = BAR_SIZE
    bar.min_value = 0.0
    bar.max_value = 1.0
    bar.step = 0.0
    bar.show_percentage = false
    stack.add_child(bar)
    visible = false

## Shows the charge of a held drive or lob; hides for taps and when nothing is held.
func show_charge(swing: PlayerInput.Swing, charge: float, stroke: SwingContact.Stroke) -> void:
    var charging: bool = swing == PlayerInput.Swing.DRIVE or swing == PlayerInput.Swing.LOB
    visible = charging
    if not charging:
        return
    bar.value = charge
    var side: String = "" if stroke == SwingContact.Stroke.NONE else "  ·  " + SwingContact.stroke_key_name(stroke)
    caption.text = "%s  %d%%%s" % [ShotRecipe.kind_name(int(swing) as ShotRecipe.Kind), roundi(charge * 100.0), side]
