extends SceneTree

func _initialize() -> void:
	await process_frame
	print("Simple test running")
	await process_frame
	quit(0)