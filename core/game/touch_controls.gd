extends Control

signal move(vec: Vector2)
signal look(delta: Vector2)
signal jump_pressed
signal fire_pressed
signal fire_released
signal reload_pressed
signal interact_pressed
signal menu_pressed
signal hotbar_select(index: int)

const TouchLayoutScript = preload("res://core/game/touch_layout.gd")
const LayoutEditorScript = preload("res://core/game/layout_editor.gd")
const NODE_BY_CONTROL := {
	"joystick": "MovePad",
	"look": "LookPad",
	"fire": "FireButton",
	"jump": "JumpButton",
	"reload": "ReloadButton",
	"interact": "InteractButton",
	"menu": "MenuButton",
	"hotbar": "HotbarSlot",
}

@export var move_deadzone: float = 0.14
@export var look_sensitivity: float = 0.003
@export var joystick_radius: float = 110.0
@export var enable_mouse: bool = false

var layout
var _move_finger: int = -1
var _look_finger: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _look_last: Vector2 = Vector2.ZERO
var _move_pad: ColorRect
var _look_pad: ColorRect
var _knob: ColorRect
var _pause_overlay: Control
var _editor: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout = TouchLayoutScript.new()
	_build_ui()
	apply_layout(layout)
	resized.connect(_layout)


func _build_ui() -> void:
	_move_pad = ColorRect.new()
	_move_pad.name = "MovePad"
	_move_pad.color = Color(1.0, 1.0, 1.0, 0.08)
	_move_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_move_pad)

	_knob = ColorRect.new()
	_knob.name = "MoveKnob"
	_knob.color = Color(1.0, 1.0, 1.0, 0.35)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_knob)

	_look_pad = ColorRect.new()
	_look_pad.name = "LookPad"
	_look_pad.color = Color(0.4, 0.7, 1.0, 0.04)
	_look_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_look_pad)

	var jump := _make_button("SALTAR", "JumpButton")
	jump.pressed.connect(func() -> void: jump_pressed.emit())

	var fire := _make_button("DISPARAR", "FireButton")
	fire.button_down.connect(func() -> void: fire_pressed.emit())
	fire.button_up.connect(func() -> void: fire_released.emit())

	var reload := _make_button("RECARGAR", "ReloadButton")
	reload.pressed.connect(func() -> void: reload_pressed.emit())

	var interact := _make_button("INTERACTUAR", "InteractButton")
	interact.pressed.connect(func() -> void: interact_pressed.emit())

	var menu := _make_button("MENU", "MenuButton")
	menu.pressed.connect(_on_menu_pressed)

	var hotbar := _make_button("1", "HotbarSlot")
	hotbar.pressed.connect(func() -> void: hotbar_select.emit(0))


func _make_button(text: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2.ZERO
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(button)
	return button


func _area_size() -> Vector2:
	var s: Vector2 = size
	if s.x <= 0.0 or s.y <= 0.0:
		s = get_viewport_rect().size
	return s


func apply_layout(new_layout = null) -> void:
	if new_layout != null:
		layout = new_layout
	if layout == null:
		layout = TouchLayoutScript.new()
	_layout()


func _layout() -> void:
	if layout == null:
		return
	var s := _area_size()
	move_deadzone = layout.move_deadzone
	look_sensitivity = layout.look_sensitivity
	for id in NODE_BY_CONTROL.keys():
		var node_name: String = NODE_BY_CONTROL[id]
		var node := get_node_or_null(node_name) as Control
		if node == null:
			continue
		var item: Dictionary = layout.entry(str(id))
		var rect: Rect2 = layout.rect(str(id), s)
		node.position = rect.position
		node.size = rect.size
		node.modulate.a = float(item.get("opacity", 1.0))
		node.visible = bool(item.get("visible", true))
		if str(id) == "joystick":
			joystick_radius = maxf(1.0, minf(rect.size.x, rect.size.y) * 0.5)
			_knob.size = Vector2(60.0, 60.0)
			_knob.position = rect.position + (rect.size - _knob.size) * 0.5
			_knob.modulate.a = node.modulate.a
			_knob.visible = node.visible


func open_layout_editor() -> void:
	if _editor != null and is_instance_valid(_editor):
		_editor.visible = true
		if _editor.has_method("refresh"):
			_editor.call("refresh")
		return
	var editor = LayoutEditorScript.new()
	editor.name = "LayoutEditor"
	add_child(editor)
	editor.call("setup", self, layout)
	_editor = editor


func open_pause_menu() -> void:
	if _pause_overlay != null and is_instance_valid(_pause_overlay):
		_pause_overlay.visible = true
		return
	var overlay := Control.new()
	overlay.name = "PauseOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.02, 0.02, 0.04, 0.85)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(background)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	var title := Label.new()
	title.name = "Title"
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	column.add_child(title)
	var resume := _make_overlay_button("REANUDAR", "ResumeButton", column)
	resume.pressed.connect(close_pause_menu)
	var controls_button := _make_overlay_button("CONTROLES", "ControlsButton", column)
	controls_button.pressed.connect(open_layout_editor)
	_pause_overlay = overlay


func close_pause_menu() -> void:
	if _pause_overlay != null and is_instance_valid(_pause_overlay):
		_pause_overlay.visible = false


func _make_overlay_button(text: String, node_name: String, parent: Node) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(420.0, 110.0)
	button.add_theme_font_size_override("font_size", 34)
	parent.add_child(button)
	return button


func _on_menu_pressed() -> void:
	menu_pressed.emit()
	open_pause_menu()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _pause_overlay != null and is_instance_valid(_pause_overlay) and _pause_overlay.visible:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		_handle_pointer(e.index, e.position, e.pressed)
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		_handle_drag(e.index, e.position)
	elif enable_mouse and event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			_handle_pointer(0, e.position, e.pressed)
	elif enable_mouse and event is InputEventMouseMotion:
		var e := event as InputEventMouseMotion
		_handle_drag(0, e.position)


func _handle_pointer(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if _over_button(pos):
			return
		var s := _area_size()
		var in_joystick: bool = layout != null and layout.rect("joystick", s).has_point(pos)
		var in_look: bool = layout != null and layout.rect("look", s).has_point(pos)
		if (in_joystick or (not in_look and pos.x < s.x * 0.5)) and _move_finger == -1:
			_move_finger = index
			_move_origin = pos
			_apply_move(Vector2.ZERO)
		elif (in_look or pos.x >= s.x * 0.5) and _look_finger == -1:
			_look_finger = index
			_look_last = pos
	else:
		if index == _move_finger:
			_move_finger = -1
			_apply_move(Vector2.ZERO)
		if index == _look_finger:
			_look_finger = -1


func _handle_drag(index: int, pos: Vector2) -> void:
	if index == _move_finger:
		_apply_move((pos - _move_origin) / maxf(joystick_radius, 1.0))
	elif index == _look_finger:
		var delta: Vector2 = (pos - _look_last) * look_sensitivity
		_look_last = pos
		if delta != Vector2.ZERO:
			look.emit(delta)


func _apply_move(vec: Vector2) -> void:
	var v := vec
	if v.length() < move_deadzone:
		v = Vector2.ZERO
	elif v.length() > 1.0:
		v = v.normalized()
	move.emit(v)
	if _knob != null and _move_pad != null:
		_knob.position = _move_pad.position + (_move_pad.size - _knob.size) * 0.5 + v * joystick_radius * 0.5


func _over_button(pos: Vector2) -> bool:
	for child in get_children():
		if child is Button and (child as Control).get_rect().has_point(pos):
			return true
	return false


func inject_touch_down(index: int, pos: Vector2) -> void:
	_handle_pointer(index, pos, true)


func inject_touch_move(index: int, pos: Vector2) -> void:
	_handle_drag(index, pos)


func inject_touch_up(index: int) -> void:
	_handle_pointer(index, Vector2.ZERO, false)
