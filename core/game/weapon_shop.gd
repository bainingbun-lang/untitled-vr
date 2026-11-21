class_name WeaponShop
extends Node3D

# Adapted from GodotFPS-Template (https://github.com/bukkbeek/GodotFPS-Template)
# Original: common/weapon/weapon.gd, common/autoloads/bullets.gd (shop integration patterns)
# Adapted from Godot-FPS-Template (https://github.com/AxelReviron/Godot-FPS-Template)
# Original: WeaponController.gd, objects/weapon_interaction_component.gd (interaction patterns)
# License: MIT (c) 2026 bukkbeek, 2026 Axel Reviron - see third_party/GODOTFPS_TEMPLATE_LICENSE.txt, third_party/GODOT_FPS_TEMPLATE_LICENSE.txt

signal weapon_selected(shop_item: Dictionary)
signal weapon_purchased(shop_item: Dictionary, success: bool)
signal ammo_purchased(ammo_type: String, rounds: int, success: bool)
signal player_entered_shop(body: Node3D)
signal player_exited_shop(body: Node3D)

@export var shop_name: String = "Weapon Shop"
@export var shop_config: String = "res://data/base/weapon_shop.json"
@export var interaction_distance: float = 2.5
@export var show_prices: bool = true
@export var allow_purchase: bool = true
@export var currency_item_id: String = "credits"

const PICKUP_SCRIPT := preload("res://core/game/weapon_pickup.gd")
const AmmoSystemScript = preload("res://core/game/ammo_system.gd")
const InventoryScript = preload("res://core/game/inventory.gd")

var _shop_data: Dictionary = {}
var _display_items: Array = []
var _display_root: Node3D = null
var _interaction_area: Area3D = null
var _player_in_range: bool = false
var _player_body: Node3D = null
var _ui_root: Control = null
var _initialized: bool = false
var _price_multiplier: float = 1.0

func _ready() -> void:
	_load_shop_config()
	_setup_shop()
	_setup_interaction_area()
	_setup_ui()
	_initialized = true

func _load_shop_config() -> void:
	var file = FileAccess.open(shop_config, FileAccess.READ)
	if file:
		var json_str := file.get_as_text()
		file.close()
		var parsed: Variant = JSON.parse_string(json_str)
		if parsed is Dictionary:
			_shop_data = parsed
		else:
			push_error("weapon_shop.json: JSON invalido")
			_create_default_config()
	else:
		push_error("weapon_shop.json: no se pudo abrir")
		_create_default_config()

func _create_default_config() -> void:
	_shop_data = {
		"name": shop_name,
		"categories": {
			"pistols": {
				"display_name": "Pistols",
				"items": ["pistol"]
			},
			"smgs": {
				"display_name": "SMGs",
				"items": ["submachine_gun"]
			},
			"rifles": {
				"display_name": "Rifles",
				"items": ["assault_rifle", "sniper_rifle"]
			},
			"shotguns": {
				"display_name": "Shotguns",
				"items": ["shotgun"]
			},
			"melee": {
				"display_name": "Melee",
				"items": ["bat"]
			},
			"ammo": {
				"display_name": "Ammunition",
				"items": [
					"ammo_box_9mm_medium",
					"ammo_box_556_medium",
					"ammo_box_762x39_medium",
					"ammo_box_12g_medium"
				]
			}
		},
		"display": {
			"table_model": "res://assets/models/props/wooden_crate_02/model.gltf",
			"slots_per_row": 3,
			"slot_spacing": 0.8,
			"rotation_speed": 30.0
		}
	}

func _ensure_core_systems() -> void:
	_load_shop_config()
	_build_display_items()

func _build_display_items() -> void:
	var all_items = []
	for category_id in _shop_data.categories:
		var category_data = _shop_data.categories[category_id]
		var category_name = str(category_data.get("display_name", category_id))
		for item_entry in category_data.get("items", []):
			var item_id := ""
			var price_override := -1
			if item_entry is Dictionary:
				item_id = str((item_entry as Dictionary).get("id", ""))
				if (item_entry as Dictionary).has("price"):
					price_override = int((item_entry as Dictionary).get("price", 0))
			else:
				item_id = str(item_entry)
			if item_id.is_empty():
				continue
			all_items.append({
				"id": item_id,
				"category": category_id,
				"category_name": category_name,
				"price_override": price_override,
			})

	_display_items = all_items

func _setup_shop() -> void:
	_display_root = Node3D.new()
	_display_root.name = "DisplayRoot"
	add_child(_display_root)
	
	_build_display()

func _build_display() -> void:
	var display_config = _shop_data.get("display", {})
	var table_model_path = display_config.get("table_model", "")
	var slots_per_row = display_config.get("slots_per_row", 3)
	var slot_spacing = display_config.get("slot_spacing", 0.8)
	var rotation_speed = display_config.get("rotation_speed", 30.0)
	
	if table_model_path != "":
		var table_scene = load(table_model_path)
		if table_scene:
			var table_instance = table_scene.instantiate()
			table_instance.name = "ShopTable"
			_display_root.add_child(table_instance)
	
	var all_items = []
	for category_id in _shop_data.categories:
		var category_data = _shop_data.categories[category_id]
		var category_name = str(category_data.get("display_name", category_id))
		for item_entry in category_data.get("items", []):
			var item_id := ""
			var price_override := -1
			if item_entry is Dictionary:
				item_id = str((item_entry as Dictionary).get("id", ""))
				if (item_entry as Dictionary).has("price"):
					price_override = int((item_entry as Dictionary).get("price", 0))
			else:
				item_id = str(item_entry)
			if item_id.is_empty():
				continue
			all_items.append({
				"id": item_id,
				"category": category_id,
				"category_name": category_name,
				"price_override": price_override,
			})

	_display_items = all_items
	
	for i in range(all_items.size()):
		var item = all_items[i]
		var slot_pos = _calculate_slot_position(i, slots_per_row, slot_spacing)
		_create_display_slot(item, slot_pos, rotation_speed)

func _calculate_slot_position(index: int, slots_per_row: int, spacing: float) -> Vector3:
	var row = int(index / slots_per_row)
	var col = index % slots_per_row
	var x = (col - (slots_per_row - 1) * 0.5) * spacing
	var z = row * spacing * 1.2
	return Vector3(x, 0.5, z)

func _create_display_slot(item_data: Dictionary, position: Vector3, rotation_speed: float) -> void:
	var slot = Node3D.new()
	slot.name = "Slot_" + item_data.id
	slot.global_position = _display_root.global_position + position
	_display_root.add_child(slot)
	
	var item_id = item_data.id
	var is_ammo = item_id.begins_with("ammo_box_")
	
	if is_ammo:
		_create_ammo_display(slot, item_id, rotation_speed)
	else:
		_create_weapon_display(slot, item_id, rotation_speed)
	
	var label = _create_info_label(item_data, is_ammo)
	slot.add_child(label)
	
	var interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.monitoring = true
	interaction_area.monitorable = true
	interaction_area.collision_layer = 0
	interaction_area.collision_mask = 2
	var col_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.4
	col_shape.shape = sphere
	interaction_area.add_child(col_shape)
	interaction_area.body_entered.connect(_on_slot_body_entered.bind(item_data))
	interaction_area.body_exited.connect(_on_slot_body_exited.bind(item_data))
	slot.add_child(interaction_area)

func _create_weapon_display(slot: Node3D, weapon_id: String, rotation_speed: float) -> void:
	var model_path = PICKUP_SCRIPT.weapon_model_path(weapon_id)
	if model_path.is_empty():
		return

	var model_scene = load(model_path)
	if model_scene:
		var rotator = Node3D.new()
		rotator.name = "Rotator"
		var model_instance = model_scene.instantiate()
		model_instance.name = "WeaponModel"
		model_instance.rotation = Vector3(0, deg_to_rad(90), deg_to_rad(-90))
		model_instance.scale = Vector3(0.8, 0.8, 0.8)
		rotator.add_child(model_instance)
		slot.add_child(rotator)

		var tween = create_tween()
		tween.tween_property(rotator, "rotation:y", deg_to_rad(360), 360.0 / rotation_speed)
		tween.set_loops()

func _create_ammo_display(slot: Node3D, box_id: String, rotation_speed: float) -> void:
	var ammo_system = AmmoSystemScript.get_singleton()
	var box_def = ammo_system.get_box_definition(box_id)
	if box_def.is_empty():
		return

	var model_path = str(box_def.get("model", "res://assets/models/props/ammo_box/model.gltf"))
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return

	var model_scene = load(model_path)
	if model_scene:
		var rotator = Node3D.new()
		rotator.name = "Rotator"
		var model_instance = model_scene.instantiate()
		model_instance.name = "AmmoBoxModel"
		model_instance.scale = Vector3(0.6, 0.6, 0.6)
		rotator.add_child(model_instance)
		slot.add_child(rotator)

		var tween = create_tween()
		tween.tween_property(rotator, "rotation:y", deg_to_rad(360), 360.0 / rotation_speed)
		tween.set_loops()

func _create_info_label(item_data: Dictionary, is_ammo: bool) -> Label3D:
	var label = Label3D.new()
	label.name = "InfoLabel"
	var ammo_system = AmmoSystemScript.get_singleton()

	if is_ammo:
		var box_def = ammo_system.get_box_definition(item_data.id)
		var ammo_data = ammo_system.get_ammo_data(box_def.get("ammo_type", "9mm"))
		var price = _effective_price(item_data, int(box_def.get("price", 0)))
		label.text = "%s\n%s x%d\n$%d" % [
			ammo_data.get("caliber", "Unknown"),
			item_data.category_name,
			box_def.get("rounds", 0),
			price
		]
	else:
		var info = PICKUP_SCRIPT.weapon_info(item_data.id)
		var price = _effective_price(item_data, int(info.price))
		label.text = "%s\n%s\n$%d" % [
			info.display_name,
			info.caliber_name if not info.is_melee else "Melee",
			price
		]

	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var settings = LabelSettings.new()
	settings.font_size = 14
	label.label_settings = settings
	return label

func _effective_price(item_data: Dictionary, base_price: int) -> int:
	var override = int(item_data.get("price_override", -1))
	var price = base_price if override < 0 else override
	return int(round(float(price) * _price_multiplier))

func _setup_interaction_area() -> void:
	_interaction_area = Area3D.new()
	_interaction_area.name = "ShopInteractionArea"
	_interaction_area.monitoring = true
	_interaction_area.monitorable = true
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 2
	var col_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = interaction_distance
	col_shape.shape = sphere
	_interaction_area.add_child(col_shape)
	_interaction_area.body_entered.connect(_on_shop_body_entered.bind())
	_interaction_area.body_exited.connect(_on_shop_body_exited.bind())
	add_child(_interaction_area)

func _setup_ui() -> void:
	_ui_root = Control.new()
	_ui_root.name = "ShopUI"
	_ui_root.visible = false
	
	var panel = Panel.new()
	panel.name = "ShopPanel"
	panel.anchors_preset = Control.PRESET_CENTER
	panel.offset_left = -300
	panel.offset_top = -200
	panel.offset_right = 300
	panel.offset_bottom = 200
	_ui_root.add_child(panel)
	
	var title = Label.new()
	title.name = "Title"
	title.text = _shop_data.get("name", shop_name)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchors_preset = Control.PRESET_TOP_WIDE
	title.offset_top = 20
	title.offset_bottom = 60
	panel.add_child(title)
	
	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Close"
	close_btn.anchors_preset = Control.PRESET_TOP_RIGHT
	close_btn.offset_left = -80
	close_btn.offset_top = 10
	close_btn.offset_right = -10
	close_btn.offset_bottom = 50
	close_btn.pressed.connect(_on_close_pressed.bind())
	panel.add_child(close_btn)
	
	var item_list = ItemList.new()
	item_list.name = "ItemList"
	item_list.anchors_preset = 10
	item_list.offset_left = 10
	item_list.offset_top = 70
	item_list.offset_right = -10
	item_list.offset_bottom = -10
	item_list.select_mode = ItemList.SELECT_SINGLE
	item_list.item_selected.connect(_on_item_selected.bind())
	panel.add_child(item_list)
	
	var buy_btn = Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.text = "Buy"
	buy_btn.disabled = true
	buy_btn.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	buy_btn.offset_left = -100
	buy_btn.offset_top = -50
	buy_btn.offset_right = -10
	buy_btn.offset_bottom = -10
	buy_btn.pressed.connect(_on_buy_pressed.bind())
	panel.add_child(buy_btn)
	
	get_tree().root.add_child(_ui_root)

func _on_shop_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_in_range = true
	_player_body = body
	player_entered_shop.emit(body)
	_show_ui()

func _on_shop_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_in_range = false
	if _player_body == body:
		_player_body = null
	player_exited_shop.emit(body)
	_hide_ui()

func _on_slot_body_entered(item_data: Dictionary, body: Node3D) -> void:
	if not _is_player(body):
		return
	weapon_selected.emit(_build_shop_item(item_data))

func _on_slot_body_exited(item_data: Dictionary, body: Node3D) -> void:
	if not _is_player(body):
		return

func _show_ui() -> void:
	if _ui_root:
		_ui_root.visible = true
		_populate_item_list()

func _hide_ui() -> void:
	if _ui_root:
		_ui_root.visible = false

func _populate_item_list() -> void:
	var item_list = _ui_root.get_node("ShopPanel/ItemList")
	item_list.clear()
	for item_data in _display_items:
		var shop_item = _build_shop_item(item_data)
		item_list.add_item(shop_item.display_text, shop_item)
	item_list.select(0)

func _build_shop_item(item_data: Dictionary) -> Dictionary:
	var ammo_system = AmmoSystemScript.get_singleton()
	var is_ammo = item_data.id.begins_with("ammo_box_")

	if is_ammo:
		var box_def = ammo_system.get_box_definition(item_data.id)
		if box_def.is_empty():
			return {}
		var ammo_data = ammo_system.get_ammo_data(box_def.get("ammo_type", "9mm"))
		var price = _effective_price(item_data, int(box_def.get("price", 0)))
		return {
			"id": item_data.id,
			"type": "ammo",
			"category": item_data.category,
			"name": "%s (%s x%d)" % [item_data.category_name, ammo_data.get("caliber", "???"), box_def.get("rounds", 0)],
			"display_text": "%s (%s x%d) - $%d" % [item_data.category_name, ammo_data.get("caliber", "???"), box_def.get("rounds", 0), price],
			"price": price,
			"ammo_type": box_def.get("ammo_type", "9mm"),
			"rounds": box_def.get("rounds", 0),
			"caliber": ammo_data.get("caliber", "Unknown")
		}
	else:
		var info = PICKUP_SCRIPT.weapon_info(item_data.id)
		var price = _effective_price(item_data, int(info.price))
		return {
			"id": item_data.id,
			"type": "weapon",
			"category": item_data.category,
			"name": info.display_name,
			"display_text": "%s (%s) - $%d" % [info.display_name, info.caliber_name if not info.is_melee else "Melee", price],
			"price": price,
			"weapon_id": item_data.id,
			"ammo_type": info.ammo_type,
			"caliber": info.caliber_name,
			"damage": info.damage,
			"fire_rate": info.fire_rate,
			"magazine_size": info.magazine_size,
			"is_melee": info.is_melee
		}

func _on_item_selected(index: int) -> void:
	var item_list = _ui_root.get_node("ShopPanel/ItemList")
	var buy_btn = _ui_root.get_node("ShopPanel/BuyButton")
	if index >= 0 and index < item_list.get_item_count():
		var item_data = item_list.get_item_metadata(index)
		buy_btn.disabled = not allow_purchase
		buy_btn.tooltip_text = "Price: $%d" % item_data.get("price", 0)
	else:
		buy_btn.disabled = true

func _on_buy_pressed() -> void:
	var item_list = _ui_root.get_node("ShopPanel/ItemList")
	var index = item_list.get_selected_items()
	if index.is_empty():
		return
	var item_data = item_list.get_item_metadata(index[0])
	_attempt_purchase(item_data)

func _attempt_purchase(shop_item: Dictionary) -> void:
	if not _player_body:
		weapon_purchased.emit(shop_item, false)
		return
	
	var inventory = _get_player_inventory(_player_body)
	if not inventory:
		weapon_purchased.emit(shop_item, false)
		return
	
	var price = shop_item.get("price", 0)
	var currency_count = inventory.count(currency_item_id)
	
	if currency_count < price:
		weapon_purchased.emit(shop_item, false)
		return
	
	var success = false
	if shop_item.type == "weapon":
		var weapon_id = shop_item.get("weapon_id", "")
		var add_result = inventory.add(weapon_id, 1)
		if add_result.ok:
			inventory.remove(currency_item_id, price)
			success = true
			weapon_purchased.emit(shop_item, true)
	elif shop_item.type == "ammo":
		var ammo_type = shop_item.get("ammo_type", "9mm")
		var rounds = shop_item.get("rounds", 0)
		var ammo_system = AmmoSystemScript.get_singleton()
		var added = ammo_system.add_reserve(ammo_type, rounds)
		if added > 0:
			inventory.remove(currency_item_id, price)
			success = true
			ammo_purchased.emit(ammo_type, rounds, true)
	
	if not success:
		weapon_purchased.emit(shop_item, false)

func _on_close_pressed() -> void:
	_hide_ui()

func _is_player(body: Node3D) -> bool:
	return body.is_in_group("player") or body.has_method("is_player") or body.name == "Player"

func _get_player_inventory(player: Node3D) -> InventoryScript:
	if player.has_method("get_inventory"):
		return player.get_inventory()
	var inventory_node = player.get_node_or_null("Inventory")
	if inventory_node and inventory_node.has_method("get_inventory"):
		return inventory_node.get_inventory()
	return null

func get_shop_items() -> Array:
	var result = []
	for item_data in _display_items:
		result.append(_build_shop_item(item_data))
	return result

func restock_item(item_id: String) -> void:
	print("Restocking: ", item_id)

func set_prices(price_multiplier: float) -> void:
	_price_multiplier = maxf(price_multiplier, 0.0)
	if _ui_root and _ui_root.visible:
		_populate_item_list()

var player_currency: int = 0

static func create_shop(position: Vector3, config_path: String = "") -> WeaponShop:
	var shop = WeaponShop.new()
	shop.global_position = position
	if config_path != "":
		shop.shop_config = config_path
	return shop

func get_shop_displays(category: String = "") -> Array:
	var result = []
	for item_data in _display_items:
		if category == "" or item_data.category == category:
			result.append(_build_shop_item(item_data))
	return result

func get_categories() -> Array:
	var cats = []
	for cat_id in _shop_data.get("categories", {}):
		cats.append(cat_id)
	return cats

func calculate_price(item_id: String, quantity: int) -> int:
	for item_data in _display_items:
		if item_data.id == item_id:
			var shop_item = _build_shop_item(item_data)
			return int(shop_item.get("price", 0) * quantity)
	return 0

func restock() -> void:
	for item_data in _display_items:
		restock_item(item_data.id)

func purchase_item(item_id: String, quantity: int) -> Dictionary:
	for item_data in _display_items:
		if item_data.id == item_id:
			var shop_item = _build_shop_item(item_data)
			var price = int(shop_item.get("price", 0) * quantity)
			
			if player_currency < price:
				return {"success": false, "message": "Insufficient funds"}
			
			var success = false
			if shop_item.type == "weapon":
				success = true
			elif shop_item.type == "ammo":
				var ammo_system = AmmoSystemScript.get_singleton()
				var added = ammo_system.add_reserve(shop_item.ammo_type, shop_item.rounds * quantity)
				if added > 0:
					success = true
			
			if success:
				player_currency -= price
				return {"success": true, "message": "Purchase successful"}
			else:
				return {"success": false, "message": "Purchase failed"}
	
	return {"success": false, "message": "Item not found"}

func _ensure_initialized() -> void:
	if not _initialized:
		_load_shop_config()
		_setup_shop()
		_setup_interaction_area()
		_setup_ui()
		_initialized = true