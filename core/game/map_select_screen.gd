class_name MapSelectScreen
extends Control

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const ThemesScript = preload("res://core/maps/map_themes.gd")
const LoaderScript = preload("res://core/maps/map_loader.gd")
const RegistryScript = preload("res://core/maps/map_registry.gd")
const SessionScript = preload("res://core/game/game_session.gd")

const MAPS_DIR: String = "res://maps"
const DEFAULT_SEEDS: Array = [1001, 2002, 3003]
const DEFAULT_DENSITIES: Array = [0.55, 0.55, 0.55]
const DEFAULT_THEMES: Array = ["urbano", "industrial", "rural"]
const THEME_OPTIONS: Array = [
	{"value": "", "label": "Arena de pruebas"},
	{"value": "urbano", "label": "Ciudad"},
	{"value": "industrial", "label": "Zona industrial"},
	{"value": "rural", "label": "Pueblo rural"},
]
const TIME_OPTIONS: Array = ["dia", "atardecer", "noche"]
const SIZE_PRESETS: Array = [
	{"label": "Pequeño", "width": 12, "height": 10},
	{"label": "Mediano", "width": 24, "height": 18},
	{"label": "Grande", "width": 40, "height": 30},
]
const FONT_SIZE: int = 56
const BUTTON_HEIGHT: float = 200.0

signal back_requested

var map_metas: Array = []
var selected_meta: Dictionary = {}
var generated_meta: Dictionary = {}
var last_seed: int = 0

var _map_buttons: Array = []
var _random_check: CheckButton = null
var _seed_spin: SpinBox = null
var _theme_option: OptionButton = null
var _time_option: OptionButton = null
var _size_option: OptionButton = null
var _density_slider: HSlider = null
var _status_label: Label = null


func _ready() -> void:
	_build_ui()
	_load_maps()
	_refresh_map_list()
	_mark_selected(0)
	if map_metas.is_empty():
		selected_meta = _fallback_meta()
	else:
		selected_meta = (map_metas[0] as Dictionary).duplicate(true)


func default_maps() -> Array:
	var result: Array = []
	for index in DEFAULT_SEEDS.size():
		var preset: Dictionary = SIZE_PRESETS[mini(1, SIZE_PRESETS.size() - 1)]
		var meta: Dictionary = ThemesScript.generate(int(DEFAULT_SEEDS[index]), {
			"theme": str(DEFAULT_THEMES[index]),
			"time_of_day": "atardecer",
			"theme_density": float(DEFAULT_DENSITIES[index]),
			"width": int(preset["width"]),
			"height": int(preset["height"]),
			"obstacle_density": 0.12,
			"spawn_count": 4,
		})
		if bool(meta.get("ok", false)):
			result.append(meta)
	return result


func generate_meta(seed_value: int) -> Dictionary:
	var index: int = clampi(_size_option.selected if _size_option != null else 1, 0, SIZE_PRESETS.size() - 1)
	var preset: Dictionary = SIZE_PRESETS[index]
	var density: float = _density_slider.value if _density_slider != null else GeneratorScript.DEFAULT_DENSITY
	var theme: String = ""
	if _theme_option != null and _theme_option.selected >= 0 and _theme_option.selected < THEME_OPTIONS.size():
		theme = str((THEME_OPTIONS[_theme_option.selected] as Dictionary)["value"])
	var time_of_day: String = "atardecer"
	if _time_option != null and _time_option.selected >= 0 and _time_option.selected < TIME_OPTIONS.size():
		time_of_day = str(TIME_OPTIONS[_time_option.selected])
	var params: Dictionary = {
		"width": int(preset["width"]),
		"height": int(preset["height"]),
		"obstacle_density": density,
		"spawn_count": 4,
	}
	var meta: Dictionary
	if theme.is_empty():
		meta = GeneratorScript.generate(seed_value, params)
	else:
		params["theme"] = theme
		params["theme_density"] = 0.55
		params["time_of_day"] = time_of_day
		meta = ThemesScript.generate(seed_value, params)
	if not bool(meta.get("ok", false)):
		_set_status("No se pudo generar: " + str(meta.get("errors", [])))
		return {}
	last_seed = seed_value
	generated_meta = meta
	selected_meta = meta.duplicate(true)
	_set_status("Generado: %s [%s/%s] (semilla %d)" % [
		str(meta.get("id", "")), str(meta.get("theme", "arena")), time_of_day, seed_value
	])
	return meta


func play_now() -> Error:
	var meta: Dictionary = selected_meta.duplicate(true) if not selected_meta.is_empty() else _fallback_meta()
	if meta.is_empty():
		_set_status("No hay ningun mapa jugable")
		return ERR_INVALID_DATA
	return SessionScript.start(meta, get_tree())


func _load_maps() -> void:
	map_metas = default_maps()
	var directory := DirAccess.open(MAPS_DIR)
	if directory == null:
		return
	var registry := RegistryScript.new()
	var report: Dictionary = LoaderScript.new().load_dir(MAPS_DIR, registry)
	for id in report.get("registered", []):
		var meta: Dictionary = registry.get_map(str(id))
		if not meta.is_empty():
			map_metas.append(meta)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.04, 0.05, 0.08, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)

	var title := Label.new()
	title.name = "Title"
	title.text = "MAPAS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", FONT_SIZE + 8)
	column.add_child(title)

	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "VOLVER"
	back_button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	back_button.add_theme_font_size_override("font_size", FONT_SIZE)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	column.add_child(back_button)

	var scroll := ScrollContainer.new()
	scroll.name = "MapScroll"
	scroll.custom_minimum_size = Vector2(0, 360.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.name = "MapList"
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)

	var generator := VBoxContainer.new()
	generator.name = "GeneratePanel"
	generator.add_theme_constant_override("separation", 12)
	column.add_child(generator)

	var generator_title := Label.new()
	generator_title.name = "GenerateTitle"
	generator_title.text = "Generar mapa"
	generator_title.add_theme_font_size_override("font_size", FONT_SIZE)
	generator.add_child(generator_title)

	_random_check = CheckButton.new()
	_random_check.name = "RandomSeedCheck"
	_random_check.text = "Semilla aleatoria"
	_random_check.button_pressed = true
	_random_check.custom_minimum_size = Vector2(0, 120.0)
	_random_check.add_theme_font_size_override("font_size", FONT_SIZE)
	generator.add_child(_random_check)

	_seed_spin = SpinBox.new()
	_seed_spin.name = "SeedSpin"
	_seed_spin.min_value = 0.0
	_seed_spin.max_value = 2147483647.0
	_seed_spin.step = 1.0
	_seed_spin.value = 4242.0
	_seed_spin.custom_minimum_size = Vector2(0, 120.0)
	_seed_spin.add_theme_font_size_override("font_size", FONT_SIZE)
	generator.add_child(_seed_spin)

	_theme_option = OptionButton.new()
	_theme_option.name = "ThemeOption"
	for option in THEME_OPTIONS:
		_theme_option.add_item(str((option as Dictionary)["label"]))
	_theme_option.selected = 1
	_theme_option.custom_minimum_size = Vector2(0, 120.0)
	_theme_option.add_theme_font_size_override("font_size", FONT_SIZE)
	generator.add_child(_theme_option)

	_time_option = OptionButton.new()
	_time_option.name = "TimeOption"
	for value in TIME_OPTIONS:
		_time_option.add_item(str(value))
	_time_option.selected = 1
	_time_option.custom_minimum_size = Vector2(0, 120.0)
	_time_option.add_theme_font_size_override("font_size", FONT_SIZE)
	generator.add_child(_time_option)

	_size_option = OptionButton.new()
	_size_option.name = "SizeOption"
	for preset in SIZE_PRESETS:
		_size_option.add_item(str(preset["label"]))
	_size_option.selected = 1
	_size_option.custom_minimum_size = Vector2(0, 120.0)
	_size_option.add_theme_font_size_override("font_size", FONT_SIZE)
	generator.add_child(_size_option)

	_density_slider = HSlider.new()
	_density_slider.name = "DensitySlider"
	_density_slider.min_value = 0.0
	_density_slider.max_value = 0.6
	_density_slider.step = 0.01
	_density_slider.value = GeneratorScript.DEFAULT_DENSITY
	_density_slider.custom_minimum_size = Vector2(0, 120.0)
	generator.add_child(_density_slider)

	var generate_button := Button.new()
	generate_button.name = "GenerateButton"
	generate_button.text = "GENERAR"
	generate_button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	generate_button.add_theme_font_size_override("font_size", FONT_SIZE)
	generate_button.pressed.connect(_on_generate_pressed)
	generator.add_child(generate_button)

	_status_label = Label.new()
	_status_label.name = "GenerateStatus"
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 40)
	generator.add_child(_status_label)

	var play_button := Button.new()
	play_button.name = "PlayButton"
	play_button.text = "JUGAR"
	play_button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	play_button.add_theme_font_size_override("font_size", FONT_SIZE + 8)
	play_button.pressed.connect(_on_play_pressed)
	column.add_child(play_button)


func _refresh_map_list() -> void:
	var list_container := get_node_or_null("Margin/Column/MapScroll/MapList") as VBoxContainer
	if list_container == null:
		return
	for child in list_container.get_children():
		list_container.remove_child(child)
		child.queue_free()
	_map_buttons.clear()
	for index in map_metas.size():
		var meta: Dictionary = map_metas[index]
		var map_button := Button.new()
		map_button.name = "MapButton%d" % index
		map_button.text = _map_label(meta)
		map_button.toggle_mode = true
		map_button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
		map_button.add_theme_font_size_override("font_size", FONT_SIZE)
		map_button.pressed.connect(_select_map.bind(index))
		list_container.add_child(map_button)
		_map_buttons.append(map_button)


func _map_label(meta: Dictionary) -> String:
	var id := str(meta.get("id", "mapa"))
	var theme := str(meta.get("theme", "arena"))
	var width := int(meta.get("width", 0))
	var height := int(meta.get("height", 0))
	if width > 0 and height > 0:
		return "%s [%s] (%dx%d)" % [id, theme, width, height]
	return "%s [%s]" % [id, theme]


func _mark_selected(index: int) -> void:
	for i in _map_buttons.size():
		var button: Button = _map_buttons[i]
		button.button_pressed = (i == index)


func _select_map(index: int) -> void:
	if index < 0 or index >= map_metas.size():
		return
	selected_meta = (map_metas[index] as Dictionary).duplicate(true)
	generated_meta = {}
	_mark_selected(index)
	_set_status("Mapa: " + str(selected_meta.get("id", "")))


func _on_generate_pressed() -> void:
	var seed_value: int = int(_seed_spin.value) if _random_check != null and not _random_check.button_pressed else int(RandomNumberGenerator.new().randi() % 1000000)
	generate_meta(seed_value)


func _on_play_pressed() -> void:
	var error: Error = play_now()
	if error != OK:
		_set_status("No se pudo iniciar (error %d)" % error)


func _fallback_meta() -> Dictionary:
	var meta: Dictionary = GeneratorScript.generate(0, {})
	return meta if bool(meta.get("ok", false)) else {}


func _set_status(message: String) -> void:
	if _status_label != null and is_instance_valid(_status_label):
		_status_label.text = message
