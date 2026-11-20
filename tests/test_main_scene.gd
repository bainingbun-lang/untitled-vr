extends SceneTree

var _fail := 0
var _n := 0


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _initialize() -> void:
	var scene: Control = load("res://scenes/main/main_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame  # _ready corre en el primer fotograma
	var button: Button = scene.get_node("Center/Box/Button")
	var label: Label = scene.get_node("Center/Box/Label")
	_expect(label.text == "Beta", "texto inicial")
	button.pressed.emit()
	_expect(label.text == "Clicks: 1", "un clic actualiza la etiqueta")
	button.pressed.emit()
	button.pressed.emit()
	_expect(label.text == "Clicks: 3", "tres clics")
	_expect(button.custom_minimum_size.y >= 100.0, "boton con tamano tactil")
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)
