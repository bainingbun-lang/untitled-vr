class_name Hotbar
extends Control

signal selected(item_id: String)

const LoadoutScript = preload("res://core/game/loadout.gd")
const SLOT_WIDTH := 116.0
const SLOT_HEIGHT := 96.0

var _inventory = null
var _item_db = null
var _ids: Array = []
var _buttons: Array = []
var _current_index := -1
var _slots_root: HBoxContainer = null
var _label: Label = null
var _ready_done := false


func _ready() -> void:
	_ready_done = true
	_rebuild()


func setup(inventory, item_db) -> void:
	_inventory = inventory
	_item_db = item_db
	_refresh_ids()
	if _ready_done:
		_rebuild()


func refresh() -> void:
	_refresh_ids()
	if _ready_done:
		_rebuild()


func weapon_ids() -> Array:
	return _ids.duplicate()


func slot_buttons() -> Array:
	return _buttons.duplicate()


func current_index() -> int:
	return _current_index


func current_id() -> String:
	if _current_index < 0 or _current_index >= _ids.size():
		return ""
	return str(_ids[_current_index])


func select(index: int) -> void:
	if index < 0 or index >= _ids.size():
		return
	_current_index = index
	_update_styles()
	selected.emit(str(_ids[index]))


func select_id(item_id: String) -> bool:
	var index := _ids.find(item_id)
	if index < 0:
		return false
	select(index)
	return true


func handle_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		var index := _index_for_key(key.keycode)
		if index >= 0:
			select(index)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed:
			return
		if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select(positive_modulo(_current_index + 1, _ids.size()))
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			select(positive_modulo(_current_index - 1, _ids.size()))
		elif mouse.button_index == MOUSE_BUTTON_LEFT:
			var index := slot_at_point(mouse.position)
			if index >= 0:
				select(index)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var index := slot_at_point(touch.position)
			if index >= 0:
				select(index)


func slot_at_point(point: Vector2) -> int:
	for i in range(_buttons.size()):
		var button := _buttons[i] as Control
		if button != null and button.get_global_rect().has_point(point):
			return i
	if not _buttons.is_empty():
		var first := _buttons[0] as Control
		if first != null and first.get_global_rect().size.x <= 0.0:
			var estimated := int(floor(point.x / SLOT_WIDTH))
			if estimated >= 0 and estimated < _buttons.size():
				return estimated
	return -1


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey or event is InputEventMouseButton:
		handle_input(event)


func _refresh_ids() -> void:
	_ids = []
	if _inventory == null or not _inventory.has_method("count"):
		return
	for id in LoadoutScript.weapon_ids(_item_db):
		if int(_inventory.count(str(id))) > 0:
			_ids.append(str(id))
	if _current_index >= _ids.size():
		_current_index = -1


func _rebuild() -> void:
	_clear_children()
	if _ids.is_empty():
		return

	_slots_root = HBoxContainer.new()
	_slots_root.name = "Slots"
	_slots_root.position = Vector2(12.0, 12.0)
	_slots_root.add_theme_constant_override("separation", 8)
	add_child(_slots_root)

	for i in range(_ids.size()):
		var id := str(_ids[i])
		var button := Button.new()
		button.name = "Slot%d" % i
		button.text = "%d %s" % [i + 1, _display_name(id)]
		button.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.pressed.connect(_on_slot_pressed.bind(i))
		_slots_root.add_child(button)
		_buttons.append(button)

	_label = Label.new()
	_label.name = "CurrentWeapon"
	_label.position = Vector2(12.0, SLOT_HEIGHT + 24.0)
	_label.text = "ARMA: %s" % (current_id() if not current_id().is_empty() else "-")
	add_child(_label)
	_update_styles()


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_buttons = []
	_slots_root = null
	_label = null


func _on_slot_pressed(index: int) -> void:
	select(index)


func _update_styles() -> void:
	for i in range(_buttons.size()):
		var button := _buttons[i] as Button
		if button == null:
			continue
		button.modulate = Color(1.0, 0.82, 0.25, 1.0) if i == _current_index else Color(1.0, 1.0, 1.0, 1.0)
	if _label != null:
		var id := current_id()
		_label.text = "ARMA: %s" % (_display_name(id) if not id.is_empty() else "-")


func _display_name(id: String) -> String:
	if _item_db != null and _item_db.has_method("get_def"):
		var def: Dictionary = _item_db.get_def(id)
		var name := str(def.get("nombre", def.get("name", "")))
		if not name.is_empty():
			return name
	return id


func _index_for_key(keycode: Key) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1
	if keycode >= KEY_KP_1 and keycode <= KEY_KP_9:
		return keycode - KEY_KP_1
	if keycode == KEY_0 or keycode == KEY_KP_0:
		return 9
	return -1


func positive_modulo(value: int, modulus: int) -> int:
	if modulus <= 0:
		return -1
	return value % modulus if value >= 0 else ((value % modulus) + modulus) % modulus
