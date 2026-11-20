class_name MainMenu
extends Control

const SessionScript = preload("res://core/game/game_session.gd")
const MapSelectScript = preload("res://core/game/map_select_screen.gd")

const FONT_SIZE: int = 56
const BUTTON_HEIGHT: float = 200.0

var _menu_root: Control = null
var _gore_check: CheckButton = null
var _map_screen: Control = null


func _ready() -> void:
	_build_ui()


func set_gore(enabled: bool) -> void:
	SessionScript.gore_enabled = enabled
	if _gore_check != null and is_instance_valid(_gore_check):
		_gore_check.set_pressed_no_signal(enabled)
		_gore_check.text = _gore_text(enabled)


func show_maps() -> void:
	if _menu_root != null:
		_menu_root.visible = false
	if _map_screen != null:
		_map_screen.visible = true


func show_menu() -> void:
	if _map_screen != null:
		_map_screen.visible = false
	if _menu_root != null:
		_menu_root.visible = true


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
	margin.add_theme_constant_override("margin_top", 96)
	margin.add_theme_constant_override("margin_bottom", 96)
	add_child(margin)
	_menu_root = margin

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 40)
	margin.add_child(column)

	var title := Label.new()
	title.name = "Title"
	title.text = "UNTITLED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", FONT_SIZE + 24)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Elige una partida"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", FONT_SIZE)
	column.add_child(subtitle)

	var play_button := Button.new()
	play_button.name = "PlayButton"
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	play_button.add_theme_font_size_override("font_size", FONT_SIZE + 8)
	play_button.pressed.connect(show_maps)
	column.add_child(play_button)

	_gore_check = CheckButton.new()
	_gore_check.name = "GoreCheck"
	_gore_check.text = _gore_text(SessionScript.gore_enabled)
	_gore_check.button_pressed = SessionScript.gore_enabled
	_gore_check.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	_gore_check.add_theme_font_size_override("font_size", FONT_SIZE)
	_gore_check.toggled.connect(_on_gore_toggled)
	column.add_child(_gore_check)

	_map_screen = MapSelectScript.new() as Control
	_map_screen.name = "MapSelectScreen"
	_map_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_screen.connect("back_requested", show_menu)
	_map_screen.visible = false
	add_child(_map_screen)


func _on_gore_toggled(enabled: bool) -> void:
	SessionScript.gore_enabled = enabled
	if _gore_check != null and is_instance_valid(_gore_check):
		_gore_check.text = _gore_text(enabled)


func _gore_text(enabled: bool) -> String:
	return "Gore: ON" if enabled else "Gore: OFF"
