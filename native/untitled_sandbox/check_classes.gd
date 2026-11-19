extends SceneTree
func _init():
	print('Probe exists: ', ClassDB.class_exists('Probe'))
	print('LuaSandbox exists: ', ClassDB.class_exists('LuaSandbox'))
	print('WasmSandbox exists: ', ClassDB.class_exists('WasmSandbox'))
	quit()
