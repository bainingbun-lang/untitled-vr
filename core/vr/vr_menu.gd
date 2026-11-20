class_name VrMenu
extends Node3D

signal button_pressed(button_id: String)
signal closed()

var panel_size: Vector2 = Vector2(0.6, 0.35)
var panel_distance: float = 1.4
var panel_height_offset: float = -0.05
var is_open: bool = false
var buttons: Array = []

var panel_root: Node3D = null
var panel_mesh: MeshInstance3D = null
var _button_labels: Dictionary = {}
var _built: bool = false
var _panel_transform: Transform3D = Transform3D.IDENTITY


func build() -> bool:
	if _built:
		return true
	_built = true
	panel_root = Node3D.new()
	panel_root.name = "PanelRoot"
	add_child(panel_root)

	var plane := PlaneMesh.new()
	plane.size = panel_size
	panel_mesh = MeshInstance3D.new()
	panel_mesh.name = "PanelMesh"
	panel_mesh.mesh = plane
	panel_root.add_child(panel_mesh)
	panel_root.visible = is_open
	_rebuild_button_labels()
	return true


func is_built() -> bool:
	return _built


func set_buttons(new_buttons: Array) -> void:
	buttons = normalize_buttons(new_buttons)
	_rebuild_button_labels()


func open_in_front(head_position: Vector3, head_forward: Vector3, head_up: Vector3 = Vector3.UP) -> Transform3D:
	is_open = true
	var xform := placement_transform(head_position, head_forward, panel_distance, panel_height_offset, head_up)
	_panel_transform = xform
	if is_inside_tree():
		global_transform = xform
	else:
		transform = xform
	if panel_root != null:
		panel_root.visible = true
	return xform


func close_menu() -> void:
	if not is_open:
		return
	is_open = false
	if panel_root != null:
		panel_root.visible = false
	closed.emit()


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
	var result := raycast_buttons(ray_origin, ray_direction, xform, panel_size, buttons)
	if bool(result.get("hit", false)):
		return result
	return {"hit": false, "button_id": "", "point": Vector3.ZERO, "uv": Vector2.ZERO}


func try_press(ray_origin: Vector3, ray_direction: Vector3, trigger_pressed: bool) -> String:
	if not trigger_pressed:
		return ""
	var hit := pointer_hit(ray_origin, ray_direction)
	if bool(hit.get("hit", false)):
		var id := str(hit.get("button_id", ""))
		if not id.is_empty():
			button_pressed.emit(id)
		return id
	return ""


func _rebuild_button_labels() -> void:
	if panel_root == null:
		return
	for child in _button_labels.values():
		if is_instance_valid(child):
			child.queue_free()
	_button_labels.clear()
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
		label.pixel_size = 0.0025
		label.position = Vector3(center.x, center.y, 0.01)
		panel_root.add_child(label)
		_button_labels[id] = label


static func placement_transform(head_position: Vector3, head_forward: Vector3, distance: float = 1.4, height_offset: float = -0.05, head_up: Vector3 = Vector3.UP) -> Transform3D:
	var forward := Vector3(head_forward.x, 0.0, head_forward.z)
	if forward.length_squared() <= 0.000001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var up := head_up
	if up.length_squared() <= 0.000001:
		up = Vector3.UP
	up = up.normalized()
	var origin := head_position + forward * maxf(distance, 0.2) + Vector3.UP * height_offset
	# -Z points toward 'forward' arg, so +Z faces back toward the player (-forward).
	var basis := Basis.looking_at(forward, up)
	return Transform3D(basis, origin)


static func normalize_buttons(raw_buttons: Array) -> Array:
	var normalized: Array = []
	if raw_buttons == null:
		return normalized
	for raw in raw_buttons:
		if not (raw is Dictionary):
			continue
		var button: Dictionary = raw
		var id := str(button.get("id", ""))
		if id.is_empty():
			continue
		var rect_val = button.get("rect", Rect2())
		if not (rect_val is Rect2):
			continue
		normalized.append({
			"id": id,
			"label": str(button.get("label", id)),
			"rect": rect_val,
		})
	return normalized


static func raycast_buttons(ray_origin: Vector3, ray_direction: Vector3, panel_transform: Transform3D, size: Vector2, raw_buttons: Array) -> Dictionary:
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
	for raw in normalize_buttons(raw_buttons):
		var button: Dictionary = raw
		var rect: Rect2 = button["rect"]
		if rect.has_point(Vector2(local.x, local.y)):
			hit_id = str(button["id"])
			break
	return {
		"hit": not hit_id.is_empty(),
		"button_id": hit_id,
		"point": point,
		"uv": uv,
		"local": Vector2(local.x, local.y),
	}
