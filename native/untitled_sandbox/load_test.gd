extends Node

func _ready():
	print('Probe: ', Probe.new())
	print('Lua: ', LuaSandbox.new())
	print('Wasm: ', WasmSandbox.new())
	get_tree().quit()
