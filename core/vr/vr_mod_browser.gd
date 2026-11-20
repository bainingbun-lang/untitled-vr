class_name VrModBrowser
extends Node3D

signal mod_toggled(mod_id: String, enabled: bool)
signal mod_reordered(mod_id: String, new_priority: int)
signal mod_reloaded(mod_id: String, success: bool, error: String)
signal browser_closed()

const ModLoaderScript = preload("res://core/mod_loader.gd")
const ModRegistryScript = preload("res://core/mod_registry.gd")
const ModReloaderScript = preload("res://core/mod_reloader.gd")
const EventBusScript = preload("res://core/event_bus.gd")
const ContentRegistryScript = preload("res://core/game/content_registry.gd")

var panel_size: Vector2 = Vector2(0.7, 0.5)
var panel_distance: float = 1.2
var panel_height_offset: float = 0.0
var is_open: bool = false
var mods_dir: String = "user://mods"

var panel_root: Node3D = null
var panel_mesh: MeshInstance3D = null
var _button_labels: Dictionary = {}
var _mod_entries: Dictionary = {}
var _built: bool = false
var _panel_transform: Transform3D = Transform3D.IDENTITY
var _mod_list_scroll: int = 0
var _max_visible_mods: int = 10
var _selected_mod_id: String = ""
var _mode: String = "list"
var _bus: Variant = null
var _loader: Variant = null
var _registry: Variant = null

func _ready() -> void:
	_build_panel()

func _build_panel() -> void:
	if _built:
		return
	_built = true

	panel_root = Node3D.new()
	panel_root.name = "ModBrowserRoot"
	add_child(panel_root)

	var plane := PlaneMesh.new()
	plane.size = panel_size
	panel_mesh = MeshInstance3D.new()
	panel_mesh.name = "PanelMesh"
	panel_mesh.mesh = plane

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.08, 0.08, 0.12, 0.95)
	panel_mesh.material_override = material

	panel_root.add_child(panel_mesh)
	panel_root.visible = is_open

	_build_header()
	_build_mod_list_area()
	_build_mod_detail_area()
	_build_footer()

func _build_header() -> void:
	var header = Node3D.new()
	header.name = "Header"
	panel_root.add_child(header)

	var title = Label3D.new()
	title.name = "Title"
	title.text = "MOD BROWSER"
	title.pixel_size = 0.0035
	title.position = Vector3(-0.32, 0.22, 0.015)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)

	var subtitle = Label3D.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Laser pointer: trigger = select, grip = scroll"
	subtitle.pixel_size = 0.0018
	subtitle.position = Vector3(-0.32, 0.17, 0.015)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.modulate = Color(0.7, 0.7, 0.8)
	header.add_child(subtitle)

	var close_btn = Label3D.new()
	close_btn.name = "Btn_close"
	close_btn.text = "[X] CLOSE"
	close_btn.pixel_size = 0.0022
	close_btn.position = Vector3(0.25, 0.22, 0.015)
	close_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(close_btn)
	_button_labels["close"] = close_btn

	var reload_all_btn = Label3D.new()
	reload_all_btn.name = "Btn_reload_all"
	reload_all_btn.text = "[R] Reload All"
	reload_all_btn.pixel_size = 0.0022
	reload_all_btn.position = Vector3(0.25, 0.17, 0.015)
	reload_all_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(reload_all_btn)
	_button_labels["reload_all"] = reload_all_btn

func _build_mod_list_area() -> void:
	var list_area = Node3D.new()
	list_area.name = "ModListArea"
	panel_root.add_child(list_area)

	var bg = Label3D.new()
	bg.name = "ListBg"
	bg.text = ""
	bg.pixel_size = 0.001
	bg.position = Vector3(-0.33, -0.02, 0.005)
	var bg_rect := Rect2(-0.33, -0.02, 0.64, 0.38)
	panel_root.add_child(bg)

	var list_title = Label3D.new()
	list_title.name = "ListTitle"
	list_title.text = "LOADED MODS (trigger to toggle, grip to reorder)"
	list_title.pixel_size = 0.002
	list_title.position = Vector3(-0.32, 0.12, 0.015)
	list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	list_title.modulate = Color(0.6, 0.9, 0.6)
	list_area.add_child(list_title)

	var scroll_up = Label3D.new()
	scroll_up.name = "Btn_scroll_up"
	scroll_up.text = "^ UP"
	scroll_up.pixel_size = 0.002
	scroll_up.position = Vector3(-0.32, -0.17, 0.015)
	scroll_up.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	list_area.add_child(scroll_up)
	_button_labels["scroll_up"] = scroll_up

	var scroll_down = Label3D.new()
	scroll_down.name = "Btn_scroll_down"
	scroll_down.text = "DOWN v"
	scroll_down.pixel_size = 0.002
	scroll_down.position = Vector3(0.22, -0.17, 0.015)
	scroll_down.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	list_area.add_child(scroll_down)
	_button_labels["scroll_down"] = scroll_down

func _build_mod_detail_area() -> void:
	var detail_area = Node3D.new()
	detail_area.name = "ModDetailArea"
	panel_root.add_child(detail_area)

	var detail_title = Label3D.new()
	detail_title.name = "DetailTitle"
	detail_title.text = "MOD DETAILS"
	detail_title.pixel_size = 0.002
	detail_title.position = Vector3(-0.32, -0.22, 0.015)
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail_title.modulate = Color(0.6, 0.7, 1.0)
	detail_area.add_child(detail_title)

	var detail_text = Label3D.new()
	detail_text.name = "DetailText"
	detail_text.text = "Select a mod to see details"
	detail_text.pixel_size = 0.0018
	detail_text.position = Vector3(-0.32, -0.26, 0.01)
	detail_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail_area.add_child(detail_text)
	_button_labels["detail_text"] = detail_text

	var toggle_btn = Label3D.new()
	toggle_btn.name = "Btn_toggle"
	toggle_btn.text = "[T] Toggle Enable/Disable"
	toggle_btn.pixel_size = 0.002
	toggle_btn.position = Vector3(-0.32, -0.40, 0.015)
	toggle_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail_area.add_child(toggle_btn)
	_button_labels["toggle"] = toggle_btn

	var reload_btn = Label3D.new()
	reload_btn.name = "Btn_reload"
	reload_btn.text = "[L] Hot Reload"
	reload_btn.pixel_size = 0.002
	reload_btn.position = Vector3(0.05, -0.40, 0.015)
	reload_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail_area.add_child(reload_btn)
	_button_labels["reload"] = reload_btn

	var priority_up_btn = Label3D.new()
	priority_up_btn.name = "Btn_priority_up"
	priority_up_btn.text = "[+] Priority Up"
	priority_up_btn.pixel_size = 0.002
	priority_up_btn.position = Vector3(-0.32, -0.44, 0.015)
	priority_up_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail_area.add_child(priority_up_btn)
	_button_labels["priority_up"] = priority_up_btn

	var priority_down_btn = Label3D.new()
	priority_down_btn.name = "Btn_priority_down"
	priority_down_btn.text = "[-] Priority Down"
	priority_down_btn.pixel_size = 0.002
	priority_down_btn.position = Vector3(0.05, -0.44, 0.015)
	priority_down_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail_area.add_child(priority_down_btn)
	_button_labels["priority_down"] = priority_down_btn

func _build_footer() -> void:
	var footer = Node3D.new()
	footer.name = "Footer"
	panel_root.add_child(footer)

	var available_title = Label3D.new()
	available_title.name = "AvailableTitle"
	available_title.text = "AVAILABLE MODS (not loaded)"
	available_title.pixel_size = 0.002
	available_title.position = Vector3(-0.32, -0.22, 0.015)
	available_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	available_title.modulate = Color(0.9, 0.7, 0.5)
	footer.add_child(available_title)

	var scan_btn = Label3D.new()
	scan_btn.name = "Btn_scan"
	scan_btn.text = "[S] Scan for New Mods"
	scan_btn.pixel_size = 0.002
	scan_btn.position = Vector3(-0.32, -0.26, 0.015)
	scan_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	footer.add_child(scan_btn)
	_button_labels["scan"] = scan_btn

	var load_btn = Label3D.new()
	load_btn.name = "Btn_load"
	load_btn.text = "[O] Load Selected"
	load_btn.pixel_size = 0.002
	load_btn.position = Vector3(0.05, -0.26, 0.015)
	load_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	footer.add_child(load_btn)
	_button_labels["load"] = load_btn

func setup(bus, loader, registry) -> void:
	_bus = bus
	_loader = loader
	_registry = registry

func open_in_front(head_position: Vector3, head_forward: Vector3, head_up: Vector3 = Vector3.UP) -> Transform3D:
	is_open = true
	var forward := Vector3(head_forward.x, 0.0, head_forward.z)
	if forward.length_squared() <= 0.000001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var up := head_up
	if up.length_squared() <= 0.000001:
		up = Vector3.UP
	up = up.normalized()
	var origin := head_position + forward * maxf(panel_distance, 0.2) + Vector3.UP * panel_height_offset
	var basis := Basis.looking_at(forward, up)
	_panel_transform = Transform3D(basis, origin)
	if is_inside_tree():
		global_transform = _panel_transform
	else:
		transform = _panel_transform
	if panel_root != null:
		panel_root.visible = true
	_refresh_mod_list()
	return _panel_transform

func close_menu() -> void:
	if not is_open:
		return
	is_open = false
	if panel_root != null:
		panel_root.visible = false
	browser_closed.emit()

func toggle(head_position: Vector3, head_forward: Vector3, head_up: Vector3 = Vector3.UP) -> bool:
	if is_open:
		close_menu()
		return false
	open_in_front(head_position, head_forward, head_up)
	return true

func pointer_hit(ray_origin: Vector3, ray_direction: Vector3) -> Dictionary:
	if not is_open:
		return {"hit": false, "button_id": "", "point": Vector3.ZERO, "uv": Vector2.ZERO}
	var xform := _panel_transform
	if is_inside_tree():
		xform = global_transform
	return _raycast_buttons(ray_origin, ray_direction, xform, panel_size, _get_visible_buttons())

func try_press(ray_origin: Vector3, ray_direction: Vector3, trigger_pressed: bool, grip_pressed: bool = false) -> String:
	if not trigger_pressed and not grip_pressed:
		return ""
	var hit := pointer_hit(ray_origin, ray_direction)
	if bool(hit.get("hit", false)):
		var id := str(hit.get("button_id", ""))
		if not id.is_empty():
			if grip_pressed:
				_handle_grip(id)
			else:
				_handle_trigger(id)
			return id
	return ""

func _get_visible_buttons() -> Array:
	var visible: Array = []
	for key in _button_labels:
		var label: Label3D = _button_labels[key]
		if is_instance_valid(label) and label.get_parent() != null:
			var btn_data := _get_button_data(key)
			if btn_data != null:
				visible.append(btn_data)
	for mod_id in _mod_entries:
		var entry: Dictionary = _mod_entries[mod_id]
		if entry.has("btn_toggle"):
			visible.append(entry["btn_toggle"])
		if entry.has("btn_reload"):
			visible.append(entry["btn_reload"])
		if entry.has("btn_priority_up"):
			visible.append(entry["btn_priority_up"])
		if entry.has("btn_priority_down"):
			visible.append(entry["btn_priority_down"])
	return visible

func _get_button_data(id: String) -> Dictionary:
	var label: Label3D = _button_labels.get(id)
	if label == null or not is_instance_valid(label):
		return {}
	var parent = label.get_parent()
	if parent == null:
		return {}
	var rect = _estimate_button_rect(label, parent)
	return {"id": id, "label": label.text, "rect": rect}

func _estimate_button_rect(label: Label3D, parent: Node) -> Rect2:
	var pos := label.position
	var text_size: Vector2 = label.get_text_size()
	var width: float = text_size.x * label.pixel_size
	var height: float = text_size.y * label.pixel_size
	var center_x: float = pos.x
	var center_y: float = pos.y
	return Rect2(center_x - width * 0.5, center_y - height * 0.5, width, height)

func _refresh_mod_list() -> void:
	if _registry == null:
		return

	for mod_id in _mod_entries:
		var entry: Dictionary = _mod_entries[mod_id]
		for key in ["btn_toggle", "btn_reload", "btn_priority_up", "btn_priority_down", "label"]:
			if entry.has(key) and is_instance_valid(entry[key]):
				entry[key].queue_free()
	_mod_entries.clear()

	var loaded_ids: Array = _registry.loaded_ids()
	var all_mods: Dictionary = {}
	var scan_result: Dictionary = _registry.scan(mods_dir)
	if scan_result.has("candidates"):
		for candidate in scan_result["candidates"]:
			var manifest: Dictionary = candidate["manifest"]
			var mid := str(manifest.get("id", ""))
			if not mid.is_empty():
				all_mods[mid] = {
					"manifest": manifest,
					"dir": candidate["dir"],
					"loaded": loaded_ids.has(mid),
				}

	var y_start := 0.08
	var line_height := 0.035
	var visible_count := 0

	for mod_id in all_mods:
		if visible_count < _mod_list_scroll:
			visible_count += 1
			continue
		if visible_count >= _mod_list_scroll + _max_visible_mods:
			break

		var mod_data: Dictionary = all_mods[mod_id]
		var is_loaded: bool = mod_data["loaded"]
		var manifest: Dictionary = mod_data["manifest"]
		var dir: String = mod_data["dir"]

		var entry: Dictionary = {}
		entry["mod_id"] = mod_id
		entry["manifest"] = manifest
		entry["dir"] = dir
		entry["loaded"] = is_loaded

		var base_y := y_start - visible_count * line_height

		var status_text := "ON" if is_loaded else "OFF"
		var status_color := Color(0.4, 1.0, 0.4) if is_loaded else Color(0.8, 0.4, 0.4)

		var label = Label3D.new()
		label.name = "ModLabel_%s" % mod_id
		label.text = "%s  [%s]  v%s  (pri: %d)" % [
			mod_id, status_text, str(manifest.get("version", "?")), int(manifest.get("priority", 100))
		]
		label.pixel_size = 0.002
		label.position = Vector3(-0.32, base_y, 0.01)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.modulate = status_color
		panel_root.add_child(label)
		entry["label"] = label

		var toggle_btn = Label3D.new()
		toggle_btn.name = "Btn_toggle_%s" % mod_id
		toggle_btn.text = "T"
		toggle_btn.pixel_size = 0.0018
		toggle_btn.position = Vector3(0.28, base_y, 0.01)
		toggle_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		toggle_btn.modulate = Color(1.0, 0.8, 0.3)
		panel_root.add_child(toggle_btn)
		entry["btn_toggle"] = toggle_btn
		_button_labels["toggle_%s" % mod_id] = toggle_btn

		var reload_btn = Label3D.new()
		reload_btn.name = "Btn_reload_%s" % mod_id
		reload_btn.text = "L"
		reload_btn.pixel_size = 0.0018
		reload_btn.position = Vector3(0.31, base_y, 0.01)
		reload_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		reload_btn.modulate = Color(0.5, 0.8, 1.0)
		if is_loaded:
			panel_root.add_child(reload_btn)
		entry["btn_reload"] = reload_btn
		_button_labels["reload_%s" % mod_id] = reload_btn

		var priority_up_btn = Label3D.new()
		priority_up_btn.name = "Btn_priority_up_%s" % mod_id
		priority_up_btn.text = "+"
		priority_up_btn.pixel_size = 0.0018
		priority_up_btn.position = Vector3(0.22, base_y, 0.01)
		priority_up_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		priority_up_btn.modulate = Color(0.5, 1.0, 0.5)
		if is_loaded:
			panel_root.add_child(priority_up_btn)
		entry["btn_priority_up"] = priority_up_btn
		_button_labels["priority_up_%s" % mod_id] = priority_up_btn

		var priority_down_btn = Label3D.new()
		priority_down_btn.name = "Btn_priority_down_%s" % mod_id
		priority_down_btn.text = "-"
		priority_down_btn.pixel_size = 0.0018
		priority_down_btn.position = Vector3(0.25, base_y, 0.01)
		priority_down_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		priority_down_btn.modulate = Color(1.0, 0.5, 0.5)
		if is_loaded:
			panel_root.add_child(priority_down_btn)
		entry["btn_priority_down"] = priority_down_btn
		_button_labels["priority_down_%s" % mod_id] = priority_down_btn

		_mod_entries[mod_id] = entry
		visible_count += 1

	_update_detail_panel()

func _update_detail_panel() -> void:
	var detail_text: Label3D = _button_labels.get("detail_text")
	if detail_text == null or not is_instance_valid(detail_text):
		return

	var mod_id := _selected_mod_id
	if mod_id.is_empty() or not _mod_entries.has(mod_id):
		detail_text.text = "Select a mod to see details"
		return

	var entry: Dictionary = _mod_entries[mod_id]
	var manifest: Dictionary = entry["manifest"]
	var loaded: bool = entry["loaded"]
	var dir: String = entry["dir"]

	var text := "ID: %s\n" % mod_id
	text += "Version: %s\n" % str(manifest.get("version", "?"))
	text += "Priority: %d\n" % int(manifest.get("priority", 100))
	text += "Runtime: %s\n" % str(manifest.get("runtime", "gdscript"))
	text += "Status: %s\n" % ("LOADED" if loaded else "NOT LOADED")
	text += "Dir: %s\n" % dir

	var depends: Variant = manifest.get("depends", {})
	if typeof(depends) == TYPE_DICTIONARY and not depends.is_empty():
		text += "Depends: "
		for dep in depends:
			text += "%s (%s) " % [dep, str(depends[dep])]
		text += "\n"

	var replaces: Variant = manifest.get("replaces", [])
	if typeof(replaces) == TYPE_ARRAY and not replaces.is_empty():
		text += "Replaces: %s\n" % ", ".join(replaces)

	detail_text.text = text

	_set_button_visibility("toggle", true)
	_set_button_visibility("reload", loaded)
	_set_button_visibility("priority_up", loaded)
	_set_button_visibility("priority_down", loaded)
	_set_button_text("toggle", "[T] Disable" if loaded else "[T] Enable")

func _set_button_visibility(btn_key: String, visible: bool) -> void:
	var label: Label3D = _button_labels.get(btn_key)
	if label != null and is_instance_valid(label):
		label.visible = visible

func _set_button_text(btn_key: String, text: String) -> void:
	var label: Label3D = _button_labels.get(btn_key)
	if label != null and is_instance_valid(label):
		label.text = text

func _handle_trigger(button_id: String) -> void:
	if button_id == "close":
		close_menu()
	elif button_id == "reload_all":
		_reload_all_mods()
	elif button_id == "scroll_up":
		_mod_list_scroll = max(0, _mod_list_scroll - 1)
		_refresh_mod_list()
	elif button_id == "scroll_down":
		_mod_list_scroll += 1
		_refresh_mod_list()
	elif button_id == "scan":
		_scan_available_mods()
	elif button_id == "load":
		_load_selected_available()
	elif button_id == "toggle":
		_toggle_selected_mod()
	elif button_id == "reload":
		_reload_selected_mod()
	elif button_id == "priority_up":
		_change_priority(_selected_mod_id, 10)
	elif button_id == "priority_down":
		_change_priority(_selected_mod_id, -10)
	elif button_id.begins_with("toggle_"):
		var mod_id := button_id.substr(7)
		_select_mod(mod_id)
		_toggle_mod(mod_id)
	elif button_id.begins_with("reload_"):
		var mod_id := button_id.substr(7)
		_select_mod(mod_id)
		_reload_mod(mod_id)
	elif button_id.begins_with("priority_up_"):
		var mod_id := button_id.substr(12)
		_select_mod(mod_id)
		_change_priority(mod_id, 10)
	elif button_id.begins_with("priority_down_"):
		var mod_id := button_id.substr(14)
		_select_mod(mod_id)
		_change_priority(mod_id, -10)
	else:
		_select_mod(button_id)

func _handle_grip(button_id: String) -> void:
	if button_id.begins_with("ModLabel_") or button_id.begins_with("toggle_") or button_id.begins_with("reload_") or button_id.begins_with("priority_up_") or button_id.begins_with("priority_down_"):
		var mod_id := ""
		if button_id.begins_with("ModLabel_"):
			mod_id = button_id.substr(9)
		elif button_id.begins_with("toggle_"):
			mod_id = button_id.substr(7)
		elif button_id.begins_with("reload_"):
			mod_id = button_id.substr(7)
		elif button_id.begins_with("priority_up_"):
			mod_id = button_id.substr(12)
		elif button_id.begins_with("priority_down_"):
			mod_id = button_id.substr(14)
		if not mod_id.is_empty():
			_select_mod(mod_id)

func _select_mod(mod_id: String) -> void:
	if _selected_mod_id == mod_id:
		return
	_selected_mod_id = mod_id
	_update_detail_panel()

func _toggle_mod(mod_id: String) -> void:
	if _registry == null or not _mod_entries.has(mod_id):
		return
	var entry: Dictionary = _mod_entries[mod_id]
	var loaded: bool = entry["loaded"]
	var manifest: Dictionary = entry["manifest"]
	var dir: String = entry["dir"]

	if loaded:
		var result: Dictionary = _registry.unload(mod_id)
		if bool(result.get("ok", false)):
			mod_toggled.emit(mod_id, false)
			_refresh_mod_list()
		else:
			push_error("Failed to unload mod %s: %s" % [mod_id, str(result.get("errors", []))])
	else:
		var candidate := {"manifest": manifest, "dir": dir}
		var result: Dictionary = _registry.load_all([candidate])
		if bool(result.get("ok", false)):
			mod_toggled.emit(mod_id, true)
			_refresh_mod_list()
		else:
			push_error("Failed to load mod %s: %s" % [mod_id, str(result.get("errors", []))])

func _toggle_selected_mod() -> void:
	if not _selected_mod_id.is_empty():
		_toggle_mod(_selected_mod_id)

func _reload_mod(mod_id: String) -> void:
	if _registry == null or _loader == null or not _mod_entries.has(mod_id):
		return

	var entry: Dictionary = _mod_entries[mod_id]
	var dir: String = entry["dir"]

	if not ResourceLoader.exists("res://core/mod_reloader.gd"):
		push_error("ModReloader not available")
		mod_reloaded.emit(mod_id, false, "ModReloader not available")
		return

	var reloader = ModReloaderScript.new()
	var result: Dictionary = reloader.reload(_registry, _loader, mod_id, dir)

	if bool(result.get("ok", false)):
		mod_reloaded.emit(mod_id, true, "")
		_refresh_mod_list()
	else:
		var error := str(result.get("error", "unknown"))
		push_error("Failed to reload mod %s: %s" % [mod_id, error])
		mod_reloaded.emit(mod_id, false, error)

func _reload_selected_mod() -> void:
	if not _selected_mod_id.is_empty():
		_reload_mod(_selected_mod_id)

func _reload_all_mods() -> void:
	if _registry == null or _loader == null:
		return

	var loaded_ids: Array = _registry.loaded_ids().duplicate()
	for mod_id in loaded_ids:
		if _mod_entries.has(mod_id):
			var dir: String = _mod_entries[mod_id]["dir"]
			var reloader = ModReloaderScript.new()
			var result: Dictionary = reloader.reload(_registry, _loader, mod_id, dir)
			if not bool(result.get("ok", false)):
				push_error("Failed to reload mod %s: %s" % [mod_id, str(result.get("error", "unknown"))])
	_refresh_mod_list()

func _change_priority(mod_id: String, delta: int) -> void:
	if _registry == null or not _mod_entries.has(mod_id):
		return

	var entry: Dictionary = _mod_entries[mod_id]
	var manifest: Dictionary = entry["manifest"]
	var current_priority := int(manifest.get("priority", 100))
	var new_priority := current_priority + delta
	new_priority = clampi(new_priority, 0, 1000)

	manifest["priority"] = new_priority

	var mod_dir: String = entry["dir"]
	var manifest_path: String = mod_dir.path_join("mod.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file != null:
		var json_text := JSON.stringify(manifest, "\t")
		file.store_string(json_text)
		file.close()

		mod_reordered.emit(mod_id, new_priority)
		_refresh_mod_list()
	else:
		push_error("Failed to write mod.json for %s" % mod_id)

func _scan_available_mods() -> void:
	_refresh_mod_list()

func _load_selected_available() -> void:
	if _selected_mod_id.is_empty() or not _mod_entries.has(_selected_mod_id):
		return
	var entry: Dictionary = _mod_entries[_selected_mod_id]
	if not entry["loaded"]:
		_toggle_mod(_selected_mod_id)

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