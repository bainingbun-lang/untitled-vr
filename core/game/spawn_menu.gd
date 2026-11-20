class_name SpawnMenu
extends Control

# Menu tactil de aparicion de vehiculos (Android/PC).

signal spawn_requested(vehicle_id: String)
signal closed

const DbScript = preload("res://core/game/vehicle_db.gd")
const BUTTON_SIZE := Vector2(260.0, 96.0)

var buttons: Dictionary = {}
var _grid: GridContainer = null


func _ready() -> void:
	_build()


func _build() -> void:
	if _grid != null:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "VEHICULOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)
	_grid = GridContainer.new()
	_grid.columns = 2
	box.add_child(_grid)
	var all := DbScript.all()
	for id in DbScript.list_ids():
		var button := Button.new()
		button.name = "Spawn_" + str(id)
		button.text = "APARECER\n" + str((all[id] as Dictionary)["name"])
		button.custom_minimum_size = BUTTON_SIZE
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(func() -> void: spawn_requested.emit(str(id)))
		_grid.add_child(button)
		buttons[str(id)] = button
	var close := Button.new()
	close.name = "Close"
	close.text = "CERRAR"
	close.custom_minimum_size = Vector2(BUTTON_SIZE.x, 72.0)
	close.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	box.add_child(close)
