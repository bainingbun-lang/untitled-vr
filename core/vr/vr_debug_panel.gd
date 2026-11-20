class_name VrDebugPanel
extends Node3D

signal debug_toggled(enabled: bool)
signal command_executed(cmd: String, args: Array)

const MenuScript = preload("res://core/vr/vr_menu.gd")
const VrOnboardingScript = preload("res://core/vr/vr_onboarding.gd")

var panel_size: Vector2 = Vector2(0.35, 0.4)
var panel_distance: float = 0.4
var panel_height_offset: float = 0.1
var is_open: bool = false
var wrist_side: String = "left"

var panel_root: Node3D = null
var panel_mesh: MeshInstance3D = null
var _button_labels: Dictionary = {}
var _built: bool = false
var _panel_transform: Transform3D = Transform3D.IDENTITY
var _sections: Dictionary = {}
var _active_section: String = "main"
var _command_history: Array = []
var _history_index: int = -1
var _output_label: Label3D = null

var _pc_shortcut_key: int = KEY_F1
var _vr_enabled: bool = true
var _pc_enabled: bool = true

func _ready() -> void:
	_build_panel()

func _build_panel() -> void:
	if _built:
		return
	_built = true

	panel_root = Node3D.new()
	panel_root.name = "DebugPanelRoot"
	add_child(panel_root)

	var plane := PlaneMesh.new()
	plane.size = panel_size
	panel_mesh = MeshInstance3D.new()
	panel_mesh.name = "PanelMesh"
	panel_mesh.mesh = plane

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.05, 0.05, 0.1, 0.95)
	panel_mesh.material_override = material

	panel_root.add_child(panel_mesh)
	panel_root.visible = is_open

	_build_main_section()
	_build_logs_section()
	_build_perf_section()
	_build_mods_section()

	_build_output_label()

func _build_main_section() -> void:
	var section := Node3D.new()
	section.name = "Section_Main"
	panel_root.add_child(section)
	_sections["main"] = section

	var buttons: Array = [
		{"id": "section:logs", "label": "LOGS", "rect": Rect2(-0.16, 0.18, 0.15, 0.04)},
		{"id": "section:perf", "label": "PERF", "rect": Rect2(0.01, 0.18, 0.15, 0.04)},
		{"id": "section:mods", "label": "MODS", "rect": Rect2(-0.16, 0.13, 0.15, 0.04)},
		{"id": "cmd:reload_mods", "label": "Reload Mods", "rect": Rect2(0.01, 0.13, 0.15, 0.04)},
		{"id": "cmd:list_mods", "label": "List Mods", "rect": Rect2(-0.16, 0.08, 0.15, 0.04)},
		{"id": "cmd:print_scene", "label": "Print Scene Tree", "rect": Rect2(0.01, 0.08, 0.15, 0.04)},
		{"id": "cmd:print_nodes", "label": "Print Debug Nodes", "rect": Rect2(-0.16, 0.03, 0.15, 0.04)},
		{"id": "cmd:gc", "label": "Force GC", "rect": Rect2(0.01, 0.03, 0.15, 0.04)},
		{"id": "cmd:clear_logs", "label": "Clear Logs", "rect": Rect2(-0.16, -0.02, 0.15, 0.04)},
		{"id": "cmd:toggle_vr", "label": "Toggle VR Panel", "rect": Rect2(0.01, -0.02, 0.15, 0.04)},
		{"id": "cmd:toggle_pc", "label": "Toggle PC Shortcut", "rect": Rect2(-0.16, -0.07, 0.15, 0.04)},
		{"id": "cmd:close", "label": "CLOSE", "rect": Rect2(0.01, -0.07, 0.15, 0.04)},
	]
	_create_buttons_for_section("main", buttons)

func _build_logs_section() -> void:
	var section := Node3D.new()
	section.name = "Section_Logs"
	panel_root.add_child(section)
	section.visible = false
	_sections["logs"] = section

	var buttons: Array = [
		{"id": "section:main", "label": "BACK", "rect": Rect2(-0.16, 0.18, 0.15, 0.04)},
		{"id": "cmd:log_error", "label": "Test Error", "rect": Rect2(0.01, 0.18, 0.15, 0.04)},
		{"id": "cmd:log_warning", "label": "Test Warning", "rect": Rect2(-0.16, 0.13, 0.15, 0.04)},
		{"id": "cmd:log_info", "label": "Test Info", "rect": Rect2(0.01, 0.13, 0.15, 0.04)},
	]
	_create_buttons_for_section("logs", buttons)

	_output_label = Label3D.new()
	_output_label.name = "LogOutput"
	_output_label.text = "Debug Logs:\n[No logs yet]"
	_output_label.pixel_size = 0.0018
	_output_label.position = Vector3(-0.16, 0.05, 0.01)
	_output_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_output_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	section.add_child(_output_label)

func _build_perf_section() -> void:
	var section := Node3D.new()
	section.name = "Section_Perf"
	panel_root.add_child(section)
	section.visible = false
	_sections["perf"] = section

	var buttons: Array = [
		{"id": "section:main", "label": "BACK", "rect": Rect2(-0.16, 0.18, 0.15, 0.04)},
		{"id": "cmd:print_perf", "label": "Print Performance", "rect": Rect2(0.01, 0.18, 0.15, 0.04)},
		{"id": "cmd:mem_usage", "label": "Memory Usage", "rect": Rect2(-0.16, 0.13, 0.15, 0.04)},
		{"id": "cmd:fps_graph", "label": "FPS Graph", "rect": Rect2(0.01, 0.13, 0.15, 0.04)},
	]
	_create_buttons_for_section("perf", buttons)

func _build_mods_section() -> void:
	var section := Node3D.new()
	section.name = "Section_Mods"
	panel_root.add_child(section)
	section.visible = false
	_sections["mods"] = section

	var buttons: Array = [
		{"id": "section:main", "label": "BACK", "rect": Rect2(-0.16, 0.18, 0.15, 0.04)},
		{"id": "cmd:reload_mods", "label": "Reload All Mods", "rect": Rect2(0.01, 0.18, 0.15, 0.04)},
		{"id": "cmd:list_mods", "label": "List Loaded Mods", "rect": Rect2(-0.16, 0.13, 0.15, 0.04)},
		{"id": "cmd:mod_capabilities", "label": "Show Capabilities", "rect": Rect2(0.01, 0.13, 0.15, 0.04)},
		{"id": "cmd:validate_mods", "label": "Validate Mods", "rect": Rect2(-0.16, 0.08, 0.15, 0.04)},
	]
	_create_buttons_for_section("mods", buttons)

func _create_buttons_for_section(section_name: String, buttons: Array) -> void:
	var section: Node3D = _sections.get(section_name)
	if section == null:
		return

	for raw in buttons:
		if not (raw is Dictionary):
			continue
		var button: Dictionary = raw
		var id := str(button.get("id", ""))
		if id.is_empty():
			continue
		var rect: Rect2 = button.get("rect", Rect2())
		var center := rect.get_center()
		var label := Label3D.new()
		label.name = "Btn_" + id
		label.text = str(button.get("label", id))
		label.pixel_size = 0.0022
		label.position = Vector3(center.x, center.y, 0.01)
		section.add_child(label)
		_button_labels[id] = label

func _build_input_field() -> void:
	pass

func _build_output_label() -> void:
	if _output_label == null:
		_output_label = Label3D.new()
		_output_label.name = "OutputLabel"
		_output_label.text = ""
		_output_label.pixel_size = 0.0018
		_output_label.position = Vector3(-0.16, -0.12, 0.01)
		_output_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_output_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_output_label.visible = false
		panel_root.add_child(_output_label)

func show_section(section_name: String) -> void:
	if not _sections.has(section_name):
		return
	for name in _sections:
		var section: Node3D = _sections[name]
		section.visible = (name == section_name)
	_active_section = section_name
	if section_name == "logs":
		_update_log_output()

func _update_log_output() -> void:
	if _output_label == null:
		return
	var text: String = "Debug Logs:\n"
	if _command_history.is_empty():
		text += "[No logs yet]"
	else:
		for i in range(max(0, _command_history.size() - 10), _command_history.size()):
			text += "> " + _command_history[i] + "\n"
	_output_label.text = text

func open_at_wrist(wrist_transform: Transform3D) -> void:
	is_open = true
	panel_root.visible = true
	var forward := -wrist_transform.basis.z
	var up := wrist_transform.basis.y
	var origin := wrist_transform.origin + forward * panel_distance + up * panel_height_offset
	var basis := Basis.looking_at(forward, up)
	_panel_transform = Transform3D(basis, origin)
	global_transform = _panel_transform
	debug_toggled.emit(true)

func close_panel() -> void:
	if not is_open:
		return
	is_open = false
	panel_root.visible = false
	debug_toggled.emit(false)

func toggle_at_wrist(wrist_transform: Transform3D) -> bool:
	if is_open:
		close_panel()
		return false
	open_at_wrist(wrist_transform)
	return true

func try_press(ray_origin: Vector3, ray_direction: Vector3, trigger_pressed: bool) -> String:
	if not trigger_pressed or not is_open:
		return ""
	var hit := pointer_hit(ray_origin, ray_direction)
	if bool(hit.get("hit", false)):
		var id := str(hit.get("button_id", ""))
		if not id.is_empty():
			_handle_button(id)
			return id
	return ""

func pointer_hit(ray_origin: Vector3, ray_direction: Vector3) -> Dictionary:
	if not is_open:
		return {"hit": false, "button_id": "", "point": Vector3.ZERO, "uv": Vector2.ZERO}
	var xform := _panel_transform
	if is_inside_tree():
		xform = global_transform
	return _raycast_buttons(ray_origin, ray_direction, xform, panel_size, _get_visible_buttons())

func _get_visible_buttons() -> Array:
	var visible: Array = []
	if _sections.has(_active_section):
		var section: Node3D = _sections[_active_section]
		for child in section.get_children():
			if child is Label3D and child.name.begins_with("Btn_"):
				var id: String = child.name.substr(4)
				var btn_data := _find_button_data(id)
				if btn_data != null:
					visible.append(btn_data)
	return visible

func _find_button_data(id: String) -> Dictionary:
	for section_name in _sections:
		var buttons := _get_section_buttons(section_name)
		for btn in buttons:
			if str(btn.get("id", "")) == id:
				return btn
	return {}

func _get_section_buttons(section_name: String) -> Array:
	match section_name:
		"main": return [
			{"id": "section:logs", "label": "LOGS", "rect": Rect2(-0.16, 0.18, 0.15, 0.04)},
			{"id": "section:perf", "label": "PERF", "rect": Rect2(0.01, 0.18, 0.15, 0.04)},
			{"id": "section:mods", "label": "MODS", "rect": Rect2(-0.16, 0.13, 0.15, 0.04)},
			{"id": "cmd:reload_mods", "label": "Reload Mods", "rect": Rect2(0.01, 0.13, 0.15, 0.04)},
			{"id": "cmd:list_mods", "label": "List Mods", "rect": Rect2(-0.16, 0.08, 0.15, 0.04)},
			{"id": "cmd:print_scene", "label": "Print Scene Tree", "rect": Rect2(0.01, 0.08, 0.15, 0.04)},
			{"id": "cmd:print_nodes", "label": "Print Debug Nodes", "rect": Rect2(-0.16, 0.03, 0.15, 0.04)},
			{"id": "cmd:gc", "label": "Force GC", "rect": Rect2(0.01, 0.03, 0.15, 0.04)},
			{"id": "cmd:clear_logs", "label": "Clear Logs", "rect": Rect2(-0.16, -0.02, 0.15, 0.04)},
			{"id": "cmd:toggle_vr", "label": "Toggle VR Panel", "rect": Rect2(0.01, -0.02, 0.15, 0.04)},
			{"id": "cmd:toggle_pc", "label": "Toggle PC Shortcut", "rect": Rect2(-0.16, -0.07, 0.15, 0.04)},
			{"id": "cmd:close", "label": "CLOSE", "rect": Rect2(0.01, -0.07, 0.15, 0.04)},
		]
		"logs": return [
			{"id": "section:main", "label": "BACK", "rect": Rect2(-0.16, 0.18, 0.15, 0.04)},
			{"id": "cmd:log_error", "label": "Test Error", "rect": Rect2(0.01, 0.18, 0.15, 0.04)},
			{"id": "cmd:log_warning", "label": "Test Warning", "rect": Rect2(-0.16, 0.13, 0.15, 0.04)},
			{"id": "cmd:log_info", "label": "Test Info", "rect": Rect2(0.01, 0.13, 0.15, 0.04)},
		]
		"perf": return [
			{"id": "section:main", "label": "BACK", "rect": Rect2(-0.16, 0.18, 0.15, 0.04)},
			{"id": "cmd:print_perf", "label": "Print Performance", "rect": Rect2(0.01, 0.18, 0.15, 0.04)},
			{"id": "cmd:mem_usage", "label": "Memory Usage", "rect": Rect2(-0.16, 0.13, 0.15, 0.04)},
			{"id": "cmd:fps_graph", "label": "FPS Graph", "rect": Rect2(0.01, 0.13, 0.15, 0.04)},
		]
		"mods": return [
			{"id": "section:main", "label": "BACK", "rect": Rect2(-0.16, 0.18, 0.15, 0.04)},
			{"id": "cmd:reload_mods", "label": "Reload All Mods", "rect": Rect2(0.01, 0.18, 0.15, 0.04)},
			{"id": "cmd:list_mods", "label": "List Loaded Mods", "rect": Rect2(-0.16, 0.13, 0.15, 0.04)},
			{"id": "cmd:mod_capabilities", "label": "Show Capabilities", "rect": Rect2(0.01, 0.13, 0.15, 0.04)},
			{"id": "cmd:validate_mods", "label": "Validate Mods", "rect": Rect2(-0.16, 0.08, 0.15, 0.04)},
		]
	return []

func _handle_button(button_id: String) -> void:
	if button_id.begins_with("section:"):
		show_section(button_id.substr(8))
		return
	if button_id == "cmd:close":
		close_panel()
		return
	if button_id == "cmd:toggle_vr":
		_vr_enabled = not _vr_enabled
		_append_log("VR panel " + ("enabled" if _vr_enabled else "disabled"))
		return
	if button_id == "cmd:toggle_pc":
		_pc_enabled = not _pc_enabled
		_append_log("PC shortcut " + ("enabled" if _pc_enabled else "disabled"))
		return

	_execute_command(button_id)

func _execute_command(cmd_id: String) -> void:
	var cmd: String = cmd_id.substr(4)
	var args: Array = []
	_command_history.append(cmd_id)
	_history_index = _command_history.size()

	match cmd:
		"reload_mods":
			_reload_mods()
		"list_mods":
			_list_mods()
		"print_scene":
			_print_scene_tree()
		"print_nodes":
			_print_debug_nodes()
		"gc":
			_force_gc()
		"clear_logs":
			_clear_logs()
		"log_error":
			push_error("Test error from debug panel")
			_append_log("ERROR: Test error logged")
		"log_warning":
			push_warning("Test warning from debug panel")
			_append_log("WARNING: Test warning logged")
		"log_info":
			print("Test info from debug panel")
			_append_log("INFO: Test info logged")
		"print_perf":
			_print_performance()
		"mem_usage":
			_print_memory_usage()
		"fps_graph":
			_append_log("FPS graph not implemented yet")
		"mod_capabilities":
			_show_mod_capabilities()
		"validate_mods":
			_validate_mods()
		_:
			_append_log("Unknown command: " + cmd)

	command_executed.emit(cmd, args)

func _reload_mods() -> void:
	if not ResourceLoader.exists("res://core/mod_reloader.gd"):
		_append_log("ModReloader not found")
		return
	_append_log("Mod reload requested (requires ModReloader instance with dependencies)")

func _list_mods() -> void:
	if not ResourceLoader.exists("res://core/mod_registry.gd"):
		_append_log("ModRegistry not found")
		return
	_append_log("Mod list requested (requires ModRegistry instance with bus)")

func _print_scene_tree() -> void:
	var root_node := get_tree().root
	if root_node == null:
		_append_log("No root node")
		return
	var text: String = "Scene Tree:\n"
	_print_node_recursive(root_node, text, 0)
	_append_log(text)

func _print_node_recursive(node: Node, text: String, depth: int) -> void:
	var indent := "  ".repeat(depth)
	text += "%s%s (%s)\n" % [indent, node.name, node.get_class()]
	for child in node.get_children():
		_print_node_recursive(child, text, depth + 1)

func _print_debug_nodes() -> void:
	var root_node := get_tree().root
	if root_node == null:
		_append_log("No root node")
		return
	var text: String = "Debug Nodes:\n"
	_find_debug_nodes(root_node, text, 0)
	_append_log(text)

func _find_debug_nodes(node: Node, text: String, depth: int) -> void:
	if node.name.to_lower().contains("debug") or node.get_class().to_lower().contains("debug"):
		var indent := "  ".repeat(depth)
		text += "%s%s (%s)\n" % [indent, node.name, node.get_class()]
	for child in node.get_children():
		_find_debug_nodes(child, text, depth + 1)

func _force_gc() -> void:
	var mem_before := OS.get_static_memory_usage()
	OS.low_processor_usage_mode_sleep_usec = 0
	var mem_after := OS.get_static_memory_usage()
	_append_log("GC forced. Memory: %d -> %d KB" % [mem_before / 1024, mem_after / 1024])

func _clear_logs() -> void:
	_command_history.clear()
	_history_index = -1
	_update_log_output()
	_append_log("Logs cleared")

func _print_performance() -> void:
	var fps := Engine.get_frames_per_second()
	var physics_fps := Engine.physics_ticks_per_second
	var mem := OS.get_static_memory_usage() / 1024
	var text: String = "Performance:\n  FPS: %d\n  Physics TPS: %d\n  Memory: %d KB" % [fps, physics_fps, mem]
	_append_log(text)

func _print_memory_usage() -> void:
	var mem := OS.get_static_memory_usage() / 1024
	var text: String = "Memory Usage:\n  Static: %d KB" % mem
	_append_log(text)

func _show_mod_capabilities() -> void:
	if not ResourceLoader.exists("res://core/mod_capabilities.gd"):
		_append_log("ModCapabilities not found")
		return
	var caps_script = preload("res://core/mod_capabilities.gd")
	var caps = caps_script.new()
	var all_caps: Array = caps.get_all_capabilities()
	var text: String = "Mod Capabilities:\n"
	for cap in all_caps:
		text += "  - %s: %s\n" % [cap.name, cap.description]
	_append_log(text)

func _validate_mods() -> void:
	if not ResourceLoader.exists("res://core/mod_lint.gd"):
		_append_log("ModLint not found")
		return
	var lint_script = preload("res://core/mod_lint.gd")
	var lint = lint_script.new()
	var results: Array = lint.validate_all()
	var text: String = "Mod Validation (%d issues):\n" % results.size()
	for r in results:
		text += "  [%s] %s: %s\n" % [r.severity, r.file, r.message]
	_append_log(text)

func _append_log(message: String) -> void:
	print("[DebugPanel] " + message)
	_command_history.append(message)
	if _command_history.size() > 100:
		_command_history = _command_history.slice(-100)
	_update_log_output()

func handle_pc_input(event: InputEvent) -> bool:
	if not _pc_enabled:
		return false
	if event is InputEventKey and event.pressed and event.keycode == _pc_shortcut_key:
		if is_open:
			close_panel()
		else:
			_open_pc_panel()
		return true
	return false

func _open_pc_panel() -> void:
	is_open = true
	panel_root.visible = true
	var viewport_size := get_viewport().get_visible_rect().size
	var origin := Vector3(viewport_size.x * 0.5, viewport_size.y * 0.5, 0)
	var basis := Basis.IDENTITY
	_panel_transform = Transform3D(basis, origin)
	global_transform = _panel_transform
	debug_toggled.emit(true)

func set_pc_shortcut(keycode: int) -> void:
	_pc_shortcut_key = keycode

func set_vr_enabled(enabled: bool) -> void:
	_vr_enabled = enabled

func set_pc_enabled(enabled: bool) -> void:
	_pc_enabled = enabled

static func _raycast_buttons(ray_origin: Vector3, ray_direction: Vector3, panel_transform: Transform3D, size: Vector2, raw_buttons: Array) -> Dictionary:
	var dir := ray_direction
	if dir.length_squared() <= 0.000001:
		return {"hit": false, "button_id": "", "point": Vector3.ZERO, "uv": Vector2.ZERO}
	dir = dir.normalized()
	var normal := panel_transform.basis.z
	if normal.length_squared() <= 0.000001:
		normal = Vector3.BACK
	normal = normal.normalized()
	var denom := normal.dot(dir)
	if absf(denom) <= 0.000001:
		return {"hit": false, "button_id": "", "point": Vector3.ZERO, "uv": Vector2.ZERO}
	var t := normal.dot(panel_transform.origin - ray_origin) / denom
	if t < 0.0:
		return {"hit": false, "button_id": "", "point": Vector3.ZERO, "uv": Vector2.ZERO}
	var point := ray_origin + dir * t
	var local := panel_transform.affine_inverse() * point
	var half_w := maxf(size.x, 0.0) * 0.5
	var half_h := maxf(size.y, 0.0) * 0.5
	if absf(local.x) > half_w or absf(local.y) > half_h or absf(local.z) > 0.02:
		return {"hit": false, "button_id": "", "point": point, "uv": Vector2.ZERO}
	var uv := Vector2((local.x + half_w) / maxf(size.x, 0.0001), (half_h - local.y) / maxf(size.y, 0.0001))
	var hit_id := ""
	for raw in raw_buttons:
		if not (raw is Dictionary):
			continue
		var button: Dictionary = raw
		var rect: Rect2 = button.get("rect", Rect2())
		if rect.has_point(Vector2(local.x, local.y)):
			hit_id = str(button.get("id", ""))
			break
	return {
		"hit": not hit_id.is_empty(),
		"button_id": hit_id,
		"point": point,
		"uv": uv,
		"local": Vector2(local.x, local.y),
	}