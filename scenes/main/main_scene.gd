extends Control

var clicks := 0

@onready var label: Label = $Center/Box/Label
@onready var button: Button = $Center/Box/Button


func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	print("Beta Scene Loaded")


func _on_button_pressed() -> void:
	clicks += 1
	label.text = "Clicks: %d" % clicks
