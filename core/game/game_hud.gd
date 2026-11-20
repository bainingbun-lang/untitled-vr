class_name GameHud
extends Control

const FULL_RECT := Control.PRESET_FULL_RECT
const HEALTH_COLOR := Color(0.25, 0.82, 0.35)
const DAMAGE_COLOR := Color(0.85, 0.12, 0.12)
const REFERENCE_HEIGHT := 1080.0
const MIN_UI_SCALE := 0.85
const BASE_FONT_SIZE := 30
const AMMO_FONT_SIZE := 46

var player: Node = null
var health_bar: ProgressBar = null
var health_label: Label = null
var ammo_label: Label = null
var weapon_label: Label = null
var damage_label: Label = null
var damage_flash: ColorRect = null
var crosshair: Control = null
var subtitle_label: Label = null

var _crosshair_lines: Array = []
var _crosshair_spread := 0.0
var _damage_time := 0.0
var _built := false
var _ui_scale := 1.0
var _base_layout: Dictionary = {}
var _base_font_sizes: Dictionary = {}
var _subtitle_time := 0.0


func _ready() -> void:
	_build()


func setup(target: Node) -> void:
	player = target
	_build()
	_connect_player()
	refresh()


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	damage_flash = ColorRect.new()
	damage_flash.name = "DamageFlash"
	damage_flash.color = Color(DAMAGE_COLOR.r, DAMAGE_COLOR.g, DAMAGE_COLOR.b, 0.0)
	damage_flash.set_anchors_and_offsets_preset(FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_flash)

	health_label = _make_label("HealthLabel", "VIDA 100/100", BASE_FONT_SIZE)
	_anchor(health_label, 0.03, 0.43, 1.0, 1.0, 0.0, -196.0, 0.0, -164.0)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(health_label)

	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.step = 1.0
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = HEALTH_COLOR
	health_bar.add_theme_stylebox_override("fill", fill_style)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.10, 0.12, 0.16, 0.85)
	health_bar.add_theme_stylebox_override("background", back_style)
	_anchor(health_bar, 0.03, 0.43, 1.0, 1.0, 0.0, -160.0, 0.0, -118.0)
	add_child(health_bar)

	weapon_label = _make_label("WeaponLabel", "ARMA: -", 32)
	_anchor(weapon_label, 0.55, 0.97, 1.0, 1.0, 0.0, -196.0, 0.0, -164.0)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(weapon_label)

	ammo_label = _make_label("AmmoLabel", "MUNICION: - / -", AMMO_FONT_SIZE)
	_anchor(ammo_label, 0.55, 0.97, 1.0, 1.0, 0.0, -160.0, 0.0, -110.0)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ammo_label)

	crosshair = Control.new()
	crosshair.name = "Crosshair"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.size = Vector2(96.0, 96.0)
	crosshair.position = -crosshair.size * 0.5
	add_child(crosshair)
	for i in range(4):
		var line := ColorRect.new()
		line.name = "Line%d" % i
		line.color = Color(0.95, 0.95, 0.95, 0.9)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(line)
		_crosshair_lines.append(line)
	_update_crosshair()

	damage_label = _make_label("DamageNotice", "¡DAÑO!", 48)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.modulate = DAMAGE_COLOR
	damage_label.visible = false
	_anchor(damage_label, 0.30, 0.70, 1.0, 1.0, 0.0, -340.0, 0.0, -290.0)
	add_child(damage_label)

	subtitle_label = _make_label("SubtitleLabel", "", 32)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.visible = false
	_anchor(subtitle_label, 0.12, 0.88, 0.78, 0.78, 0.0, 0.0, 0.0, 72.0)
	add_child(subtitle_label)

	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	_apply_ui_scale()


func show_subtitle(text: String, npc: String = "") -> void:
	if subtitle_label == null or text.is_empty():
		return
	subtitle_label.text = ("%s: " % npc if not npc.is_empty() else "") + text
	subtitle_label.visible = true
	_subtitle_time = 2.6


func ui_scale() -> float:
	return _ui_scale


func _on_resized() -> void:
	_apply_ui_scale()


func _apply_ui_scale() -> void:
	var viewport := get_viewport_rect()
	var height: float = viewport.size.y if viewport.size.y > 0.0 else REFERENCE_HEIGHT
	_ui_scale = maxf(MIN_UI_SCALE, height / REFERENCE_HEIGHT)
	for path in _base_layout.keys():
		var target := get_node_or_null(NodePath(str(path))) as Control
		var base: Array = _base_layout[path]
		if target == null:
			continue
		target.offset_left = float(base[0]) * _ui_scale
		target.offset_top = float(base[1]) * _ui_scale
		target.offset_right = float(base[2]) * _ui_scale
		target.offset_bottom = float(base[3]) * _ui_scale
	for path in _base_font_sizes.keys():
		var label := get_node_or_null(NodePath(str(path))) as Label
		if label == null:
			continue
		var size := int(_base_font_sizes[path])
		var minimum: int = 28 if str(path) != "DamageNotice" else 40
		if str(path).find("Ammo") >= 0:
			minimum = 38
		label.add_theme_font_size_override("font_size", maxi(roundi(float(size) * _ui_scale), minimum))
	if crosshair != null:
		var size: float = 96.0 * _ui_scale
		crosshair.size = Vector2(size, size)
		crosshair.position = -crosshair.size * 0.5
	_update_crosshair()


func _make_label(node_name: String, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_font_sizes[node_name] = font_size
	return label


func _anchor(control: Control, left: float, right: float, top: float, bottom: float,
		off_left: float, off_top: float, off_right: float, off_bottom: float) -> void:
	control.anchor_left = left
	control.anchor_right = right
	control.anchor_top = top
	control.anchor_bottom = bottom
	_base_layout[control.name] = [off_left, off_top, off_right, off_bottom]
	control.offset_left = off_left
	control.offset_top = off_top
	control.offset_right = off_right
	control.offset_bottom = off_bottom


func _connect_player() -> void:
	if player == null:
		return
	var bindings := [
		["health_changed", "_on_health_changed"],
		["damaged", "_on_player_damaged"],
		["weapon_changed", "_on_weapon_changed"],
		["ammo_changed", "_on_ammo_changed"],
		["fired", "_on_fired"],
		["reloaded", "_on_reloaded"],
		["died", "_on_player_died"],
	]
	for pair in bindings:
		var signal_name: String = pair[0]
		var method: String = pair[1]
		if player.has_signal(signal_name):
			var callable := Callable(self, method)
			if not player.is_connected(signal_name, callable):
				player.connect(signal_name, callable)


func refresh() -> void:
	if not _built or player == null or not is_instance_valid(player):
		return
	var current := _number(player.get("health"), 0.0)
	var maximum := _number(player.get("max_health"), 100.0)
	if maximum <= 0.0:
		maximum = 100.0
	health_bar.max_value = maximum
	health_bar.value = clampf(current, 0.0, maximum)
	health_label.text = "VIDA %d/%d" % [int(current), int(maximum)]

	var name_text := ""
	if player.has_method("weapon_name"):
		name_text = str(player.call("weapon_name"))
	if name_text.is_empty():
		name_text = str(player.get("equipped_weapon"))
	weapon_label.text = "ARMA: %s" % (name_text if not name_text.is_empty() else "-")

	var reloading := bool(player.call("is_reloading")) if player.has_method("is_reloading") else false
	var loaded := int(player.call("current_ammo")) if player.has_method("current_ammo") else -1
	var reserve := int(player.call("current_reserve")) if player.has_method("current_reserve") else 0
	if reloading:
		ammo_label.text = "RECARGANDO..."
	elif loaded < 0:
		ammo_label.text = "MUNICION: - / -"
	else:
		ammo_label.text = "MUNICION: %d / %d" % [loaded, reserve]


func _on_health_changed(_current: float, _maximum: float) -> void:
	refresh()


func _on_player_damaged(amount: float, _point: Vector3, _normal: Vector3) -> void:
	if amount <= 0.0:
		return
	_damage_time = 0.5
	damage_label.visible = true
	refresh()


func _on_weapon_changed(_item_id) -> void:
	refresh()


func _on_ammo_changed(_loaded: int, _reserve: int) -> void:
	refresh()


func _on_fired(_result: Dictionary) -> void:
	_crosshair_spread = 1.0
	_update_crosshair()
	refresh()


func _on_reloaded(_item_id: String) -> void:
	refresh()


func _on_player_died() -> void:
	_damage_time = 0.5
	damage_label.visible = true


func _update_crosshair() -> void:
	if _crosshair_lines.size() < 4:
		return
	var center := crosshair.size * 0.5
	var gap: float = 8.0 + _crosshair_spread * 16.0
	var horizontal := Vector2(14.0 + _crosshair_spread * 8.0, 3.0)
	var vertical := Vector2(3.0, 14.0 + _crosshair_spread * 8.0)
	var top := _crosshair_lines[0] as ColorRect
	var bottom := _crosshair_lines[1] as ColorRect
	var left := _crosshair_lines[2] as ColorRect
	var right := _crosshair_lines[3] as ColorRect
	top.position = center + Vector2(-horizontal.x * 0.5, -gap - horizontal.y)
	top.size = horizontal
	bottom.position = center + Vector2(-horizontal.x * 0.5, gap)
	bottom.size = horizontal
	left.position = center + Vector2(-gap - vertical.x, -vertical.y * 0.5)
	left.size = vertical
	right.position = center + Vector2(gap, -vertical.y * 0.5)
	right.size = vertical


func _process(delta: float) -> void:
	if _crosshair_spread > 0.0:
		_crosshair_spread = maxf(_crosshair_spread - delta * 4.0, 0.0)
		_update_crosshair()
	if _subtitle_time > 0.0:
		_subtitle_time = maxf(_subtitle_time - delta, 0.0)
		if subtitle_label != null and _subtitle_time <= 0.0:
			subtitle_label.visible = false
			subtitle_label.text = ""
	if _damage_time > 0.0:
		_damage_time = maxf(_damage_time - delta, 0.0)
		var alpha: float = clampf(_damage_time / 0.5, 0.0, 1.0)
		damage_flash.color.a = alpha * 0.32
		damage_label.visible = alpha > 0.0
		if alpha <= 0.0:
			damage_flash.color.a = 0.0


func health_value() -> float:
	return health_bar.value if health_bar != null else 0.0


func ammo_text() -> String:
	return ammo_label.text if ammo_label != null else ""


func weapon_text() -> String:
	return weapon_label.text if weapon_label != null else ""


func spread() -> float:
	return _crosshair_spread


func damage_visible() -> bool:
	return damage_label != null and damage_label.visible


func _number(value: Variant, fallback: float) -> float:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return float(value)
		_:
			return fallback
