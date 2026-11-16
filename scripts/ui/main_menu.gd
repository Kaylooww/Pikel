extends Control

func _ready() -> void:
    var background := ColorRect.new()
    background.color = Color("14374d")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var column := VBoxContainer.new()
    column.custom_minimum_size = Vector2(480, 0)
    column.add_theme_constant_override("separation", 18)
    center.add_child(column)
    var title := Label.new()
    title.text = "RALLYPOP  /  PICKLEBALL"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 38)
    column.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "Cursor-based 3D pickleball • Original Godot starter"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 16)
    column.add_child(subtitle)
    var play := Button.new()
    play.text = "PLAY PRACTICE PROTOTYPE"
    play.custom_minimum_size = Vector2(420, 58)
    column.add_child(play)
    play.pressed.connect(_on_play)
    var note := Label.new()
    note.text = "Prototype only: multiplayer, full serve/scoring rules and cosmetics are planned."
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(note)
    var help := Label.new()
    help.text = "WASD move  •  SHIFT sprint  •  mouse aim  •  left-click drive  •  right-click dink  •  R reset"
    help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(help)

func _on_play() -> void:
    get_tree().change_scene_to_file("res://scenes/game/training.tscn")
