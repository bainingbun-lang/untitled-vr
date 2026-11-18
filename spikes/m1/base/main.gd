extends Node

func _ready() -> void:
	var b = load("res://base.gd").new()
	print("M1 SCRIPT_INFO=", b.info())
	print("M1 EXTRA_EXISTS=", ResourceLoader.exists("res://mod_extra.gd"))
	print("M1 SCENE_EXISTS=", ResourceLoader.exists("res://mod_scene.tscn"))
	get_tree().quit(0)
