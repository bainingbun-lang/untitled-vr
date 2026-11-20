class_name LayoutEditor
extends Control

const TouchLayoutScript = preload("res://core/game/touch_layout.gd")

signal layout_changed(id: String)
signal layout_saved

@export var enable_mouse: bool = false

var layout
var controls: Node
var handles: Dictionary = {}
var selected_id: String = ""
var _drag_finger: int = -1
var _drag_start: Vector2 = Vector2.ZERO
var _drag_origin: Vector2 = Vector2.ZERO
var _info: Label
var _panel: Control
var _title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if layout == null:
		layout = TouchLayoutScript.new()
	_build_ui()
	refresh()


func setup(controls_node: Node, layout_obj = null) -> void:
	controls = controls_node
	if layout_obj != null:
		layout = layout_obj
	elif layout == null:
		layout = TouchLayoutScript.new()
	refresh()


func show_editor() -> void:
	visible = true
	refresh()


func _area_size() -> Vector2:
	var s: Vector2 = size
	if s.x <= 0.0 or s.y <= 0.0:
		s = get_viewport_rect().size
	return s


func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.03, 0.04, 0.07, 0.94)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	for id in TouchLayoutScript.CONTROL_IDS:
		var handle := ColorRect.new()
		handle.name = "Handle_%s" % id
		handle.color = _handle_color(str(id))
		handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(handle)
		handles[id] = handle

	_title = Label.new()
	_title.name = "Title"
	_title.text = "AJUSTAR CONTROLES"
	_title.position = Vector2(24.0, 12.0)
	_title.add_theme_font_size_override("font_size", 34)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_info = Label.new()
	_info.name = "Info"
	_info.position = Vector2(24.0, 58.0)
	_info.add_theme_font_size_override("font_size", 24)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info)

	_panel = VBoxContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.custom_minimum_size = Vector2(0.0, 400.0)
	_panel.offset_top -= 400.0
	_panel.add_theme_constant_override("separation", 8)
	add_child(_panel)

	var profiles := HBoxContainer.new()
	profiles.name = "Profiles"
	_panel.add_child(profiles)
	_add_button(profiles, "DIESTRO", "ProfileDiestro", func() -> void: apply_profile(TouchLayoutScript.PROFILE_DIESTRO))
	_add_button(profiles, "ZURDO", "ProfileZurdo", func() -> void: apply_profile(TouchLayoutScript.PROFILE_ZURDO))
	_add_button(profiles, "COMPACTO", "ProfileCompacto", func() -> void: apply_profile(TouchLayoutScript.PROFILE_COMPACTO))

	var adjust := HBoxContainer.new()
	adjust.name = "Adjust"
	_panel.add_child(adjust)
	_add_button(adjust, "TAM -", "ScaleDown", func() -> void: change_scale(-0.1))
	_add_button(adjust, "TAM +", "ScaleUp", func() -> void: change_scale(0.1))
	_add_button(adjust, "OPAC -", "OpacityDown", func() -> void: change_opacity(-0.1))
	_add_button(adjust, "OPAC +", "OpacityUp", func() -> void: change_opacity(0.1))

	var toggles := HBoxContainer.new()
	toggles.name = "Toggles"
	_panel.add_child(toggles)
	_add_button(toggles, "VISIBLE", "ToggleVisible", toggle_visible)
	_add_button(toggles, "LADO", "ToggleSide", toggle_side)
	_add_button(toggles, "RESTABLECER", "Restore", restore_defaults)

	var fine := HBoxContainer.new()
	fine.name = "Fine"
	_panel.add_child(fine)
	_add_button(fine, "MIRADA -", "SensitivityDown", func() -> void: change_sensitivity(-0.0005))
	_add_button(fine, "MIRADA +", "SensitivityUp", func() -> void: change_sensitivity(0.0005))
	_add_button(fine, "MUERTA -", "DeadzoneDown", func() -> void: change_deadzone(-0.02))
	_add_button(fine, "MUERTA +", "DeadzoneUp", func() -> void: change_deadzone(0.02))

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	_panel.add_child(actions)
	_add_button(actions, "GUARDAR", "SaveButton", save)
	_add_button(actions, "CERRAR", "CloseButton", hide)


func _add_button(parent: Node, text: String, node_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(170.0, 64.0)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _handle_color(id: String) -> Color:
	match id:
		"joystick":
			return Color(0.35, 0.85, 0.55, 0.5)
		"look":
			return Color(0.35, 0.55, 0.95, 0.25)
		"fire":
			return Color(0.95, 0.35, 0.30, 0.6)
		"jump":
			return Color(0.95, 0.75, 0.25, 0.6)
		"reload":
			return Color(0.65, 0.40, 0.95, 0.6)
		"interact":
			return Color(0.30, 0.85, 0.90, 0.6)
		"menu":
			return Color(0.90, 0.55, 0.75, 0.6)
	return Color(0.75, 0.75, 0.75, 0.6)


func refresh() -> void:
	if layout == null:
		return
	var s := _area_size()
	for id in TouchLayoutScript.CONTROL_IDS:
		var handle := handles.get(id) as Control
		if handle == null:
			continue
		var rect: Rect2 = layout.rect(str(id), s)
		var visual_size := Vector2(maxf(rect.size.x, 96.0), maxf(rect.size.y, 64.0))
		handle.position = rect.position + (rect.size - visual_size) * 0.5
		handle.size = visual_size
		var item: Dictionary = layout.entry(str(id))
		var alpha := 0.2 + 0.65 * float(item.get("opacity", 1.0))
		var base := _handle_color(str(id))
		handle.color = Color(base.r, base.g, base.b, alpha)
		if str(id) == selected_id:
			handle.color = handle.color.lightened(0.35)
	if _info == null:
		return
	if selected_id.is_empty() or not layout.controls.has(selected_id):
		_info.text = "Toca un control para editarlo"
		return
	var item: Dictionary = layout.entry(selected_id)
	var pos: Vector2 = item["position"]
	_info.text = "%s  pos(%.2f, %.2f)  tam %.2f  opac %.2f  %s  visible=%s  mirada %.4f  muerta %.2f" % [
		selected_id, pos.x, pos.y, float(item["scale"]), float(item["opacity"]),
		str(item["side"]), str(item["visible"]), layout.look_sensitivity, layout.move_deadzone,
	]


func select_control(id: String) -> void:
	if layout == null or not layout.controls.has(id):
		return
	selected_id = id
	refresh()


func _hit_handle(pos: Vector2) -> String:
	if _panel != null and (_panel as Control).get_rect().has_point(pos):
		return ""
	var ids: Array = TouchLayoutScript.CONTROL_IDS
	for i in range(ids.size() - 1, -1, -1):
		var id: String = ids[i]
		var handle := handles.get(id) as Control
		if handle != null and handle.get_rect().has_point(pos):
			return id
	return ""


func begin_drag(index: int, pos: Vector2) -> void:
	if _drag_finger != -1 or layout == null:
		return
	var id := _hit_handle(pos)
	if id.is_empty():
		return
	select_control(id)
	_drag_finger = index
	_drag_start = pos
	_drag_origin = layout.position(id)


func move_drag(index: int, pos: Vector2) -> void:
	if index != _drag_finger or selected_id.is_empty() or layout == null:
		return
	var s := _area_size()
	var delta := (pos - _drag_start) / Vector2(maxf(s.x, 1.0), maxf(s.y, 1.0))
	layout.set_position(selected_id, _drag_origin + delta)
	_apply()


func end_drag(index: int) -> void:
	if index != _drag_finger:
		return
	_drag_finger = -1
	save()


func drag_control(id: String, from: Vector2, to: Vector2) -> void:
	if layout == null or not layout.controls.has(id):
		return
	select_control(id)
	_drag_finger = -1
	_drag_start = from
	_drag_origin = layout.position(id)
	move_drag(-1, to)
	end_drag(-1)


func apply_profile(profile_id: String) -> void:
	if layout == null:
		return
	layout.set_profile(profile_id)
	_apply()


func change_scale(delta: float) -> void:
	if layout == null or selected_id.is_empty():
		return
	layout.set_control_scale(selected_id, float(layout.entry(selected_id).get("scale", 1.0)) + delta)
	_apply()


func change_opacity(delta: float) -> void:
	if layout == null or selected_id.is_empty():
		return
	layout.set_control_opacity(selected_id, float(layout.entry(selected_id).get("opacity", 1.0)) + delta)
	_apply()


func toggle_visible() -> void:
	if layout == null or selected_id.is_empty():
		return
	layout.set_control_visible(selected_id, not bool(layout.entry(selected_id).get("visible", true)))
	_apply()


func toggle_side() -> void:
	if layout == null or selected_id.is_empty():
		return
	var side := str(layout.entry(selected_id).get("side", "right"))
	layout.set_control_side(selected_id, "left" if side == "right" else "right")
	_apply()


func change_sensitivity(delta: float) -> void:
	if layout == null:
		return
	layout.set_look_sensitivity(layout.look_sensitivity + delta)
	_apply()


func change_deadzone(delta: float) -> void:
	if layout == null:
		return
	layout.set_move_deadzone(layout.move_deadzone + delta)
	_apply()


func restore_defaults() -> void:
	if layout == null:
		return
	layout.reset(layout.profile)
	selected_id = ""
	_apply()


func save() -> bool:
	if layout == null:
		return false
	var ok: bool = layout.save_to_disk()
	if ok:
		layout_saved.emit()
	refresh()
	return ok


func _apply() -> void:
	if controls != null and is_instance_valid(controls) and controls.has_method("apply_layout"):
		controls.apply_layout(layout)
	refresh()
	if not selected_id.is_empty():
		layout_changed.emit(selected_id)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			begin_drag(e.index, e.position)
		else:
			end_drag(e.index)
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		move_drag(e.index, e.position)
	elif enable_mouse and event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				begin_drag(0, e.position)
			else:
				end_drag(0)
	elif enable_mouse and event is InputEventMouseMotion:
		var e := event as InputEventMouseMotion
		move_drag(0, e.position)


static func open(parent: Node, layout_obj = null, controls_node: Node = null):
	var script = load("res://core/game/layout_editor.gd") as Script
	if script == null:
		return null
	var editor = script.new()
	parent.add_child(editor)
	var target: Node = controls_node
	if target == null and parent.has_method("apply_layout"):
		target = parent
	editor.call("setup", target, layout_obj)
	editor.call("show_editor")
	return editor
