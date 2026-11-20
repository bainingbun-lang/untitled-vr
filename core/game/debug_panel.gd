class_name DebugPanel
extends RefCounted

const CommandHandler = preload("res://core/commands/command_handler.gd")

static var _instance = null

var _commands: Dictionary = {}
var _history: Array = []
var _max_history: int = 100
var _output_callback: Callable = Callable()

static func instance() -> DebugPanel:
	if _instance == null:
		_instance = load("res://core/game/debug_panel.gd").new()
	return _instance

func register_command(name: String, handler: Callable, description: String = "", usage: String = "") -> void:
	_commands[name.to_lower()] = {
		"handler": handler,
		"description": description,
		"usage": usage,
	}

func unregister_command(name: String) -> void:
	_commands.erase(name.to_lower())

func execute(input: String) -> Dictionary:
	var trimmed: String = input.strip_edges()
	if trimmed.is_empty():
		return {"ok": false, "error": "comando vacio"}

	_history.append(trimmed)
	if _history.size() > _max_history:
		_history.remove_at(0)

	var parts: Array = _parse(trimmed)
	if parts.is_empty():
		return {"ok": false, "error": "no se pudo parsear"}

	var cmd_name: String = parts[0].to_lower()
	var args: Array = parts.slice(1)

	if not _commands.has(cmd_name):
		return {"ok": false, "error": "comando desconocido: '%s'" % cmd_name}

	var cmd: Dictionary = _commands[cmd_name]
	var handler: Callable = cmd["handler"]
	if not handler.is_valid():
		return {"ok": false, "error": "handler invalido para '%s'" % cmd_name}

	var result: Variant = handler.call(args)
	if result == null:
		return {"ok": false, "error": "handler retorno null"}

	var output: Dictionary = {
		"ok": true,
		"command": cmd_name,
		"args": args,
		"result": result,
	}

	if _output_callback.is_valid():
		_output_callback.call(output)

	return output

func _parse(input: String) -> Array:
	var result: Array = []
	var current: String = ""
	var in_quotes: bool = false
	var quote_char: String = ""
	var i: int = 0
	while i < input.length():
		var c: String = input[i]
		if (c == '"' or c == "'") and (i == 0 or input[i - 1] != "\\"):
			if not in_quotes:
				in_quotes = true
				quote_char = c
			elif c == quote_char:
				in_quotes = false
				quote_char = ""
			else:
				current += c
		elif c == " " and not in_quotes:
			if not current.is_empty():
				result.append(current)
				current = ""
		else:
			current += c
		i += 1
	if not current.is_empty():
		result.append(current)
	return result

func set_output_callback(callback: Callable) -> void:
	_output_callback = callback

func get_history() -> Array:
	return _history.duplicate()

func clear_history() -> void:
	_history.clear()

func get_commands() -> Dictionary:
	var result: Dictionary = {}
	for key in _commands:
		var cmd: Dictionary = _commands[key]
		var description: String = cmd["description"]
		var usage: String = cmd["usage"]
		result[key] = {
			"description": description,
			"usage": usage,
		}
	return result

func help(args: Array = []) -> Array:
	var lines: Array = ["Comandos disponibles:"]
	for key in _commands:
		var cmd: Dictionary = _commands[key]
		var usage: String = cmd["usage"]
		var description: String = cmd["description"]
		if usage.is_empty():
			usage = key
		lines.append("  %s - %s" % [usage, description])
	return lines