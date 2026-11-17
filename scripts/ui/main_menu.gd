extends Control
var address: LineEdit
var code: LineEdit
var join_note: Label

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
    var singles := Button.new()
    singles.text = "PLAY SINGLES MATCH (vs bot)"
    singles.custom_minimum_size = Vector2(420, 58)
    column.add_child(singles)
    singles.pressed.connect(_on_singles)
    var play := Button.new()
    play.text = "PRACTICE COURT"
    play.custom_minimum_size = Vector2(420, 58)
    column.add_child(play)
    play.pressed.connect(_on_play)
    var join_row := HBoxContainer.new()
    join_row.add_theme_constant_override("separation", 8)
    column.add_child(join_row)
    address = LineEdit.new()
    address.text = "%s:%d" % [NetConfig.host, NetConfig.port]
    address.placeholder_text = "server address, e.g. 192.168.1.20:7777"
    address.custom_minimum_size = Vector2(200, 58)
    address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    join_row.add_child(address)
    code = LineEdit.new()
    code.text = NetConfig.match_code
    code.placeholder_text = "match code"
    code.max_length = NetProtocol.CODE_LENGTH + 2
    code.custom_minimum_size = Vector2(120, 58)
    join_row.add_child(code)
    var join := Button.new()
    join.text = "JOIN MATCH"
    join.custom_minimum_size = Vector2(150, 58)
    join_row.add_child(join)
    join.pressed.connect(_on_join)
    join_note = Label.new()
    join_note.text = "To host: run tools/run_server.ps1 on one PC. Both players enter its address and the match code it prints."
    join_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    join_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(join_note)
    var note := Label.new()
    note.text = "Prototype: placeholder art, a basic bot, singles only. Doubles and cosmetics are planned."
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(note)
    var help := Label.new()
    help.text = "WASD move  •  SHIFT sprint  •  mouse aim  •  left-click drive  •  right-click dink  •  R reset"
    help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(help)

func _on_join() -> void:
    if not NetConfig.set_address(address.text):
        join_note.text = "That is not a valid address. Use an IP or name, optionally with :port."
        return
    NetConfig.match_code = NetProtocol.clean_code(code.text)
    if NetConfig.match_code == "":
        join_note.text = "Enter the 6-character match code the host's server printed."
        return
    get_tree().change_scene_to_file("res://scenes/game/online_match.tscn")

func _on_singles() -> void:
    get_tree().change_scene_to_file("res://scenes/game/singles_match.tscn")

func _on_play() -> void:
    get_tree().change_scene_to_file("res://scenes/game/training.tscn")
