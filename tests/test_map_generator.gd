extends SceneTree

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const ValidatorScript = preload("res://core/maps/map_validator.gd")

var _checks := 0
var _failures: Array = []
var _case := ""


func _init() -> void:
	var validator = ValidatorScript.new()
	var status = ValidatorScript.Status

	_case = "determinismo"
	var params := _params(24, 18, 0.28, 5)
	var first: Dictionary = GeneratorScript.generate(1234, params)
	var second: Dictionary = GeneratorScript.generate(1234, params)
	_expect(bool(first.get("ok")), "la generacion valida debe tener ok=true")
	_expect(str(first) == str(second), "misma semilla y parametros deben dar el mismo resultado exacto")
	_expect(int(first.get("seed", -1)) == 1234, "la semilla debe conservarse en los metadatos")

	_case = "validez MapValidator para 20 semillas"
	for seed in range(1, 21):
		var meta: Dictionary = GeneratorScript.generate(seed, _params(20, 16, 0.32, 4))
		var validation: Dictionary = validator.validate(meta)
		var actual: int = int(validation.get("status", -1))
		_expect(
			actual == status.COMPATIBLE and (validation.get("errors", []) as Array).is_empty(),
			"semilla %d debe ser COMPATIBLE (%d: %s)"
			% [seed, actual, str(validation.get("errors", []))]
		)

	_case = "conectividad garantizada"
	var dense: Dictionary = GeneratorScript.generate(77, _params(24, 18, 1.0, 8))
	_expect(_all_spawns_connected(dense), "densidad 1.0 debe mantener todos los spawns conectados")
	var explicit: Dictionary = GeneratorScript.generate(78, {
		"width": 24,
		"height": 18,
		"obstacle_density": 1.0,
		"spawn_points": [Vector2i(1, 1), Vector2i(22, 16), Vector2i(12, 9)],
	})
	_expect(bool(explicit.get("ok")), "spawns explicitos validos deben generarse")
	_expect(_all_spawns_connected(explicit), "spawns explicitos deben quedar conectados")
	var largest: Dictionary = GeneratorScript.generate(79, _params(64, 64, 0.45, 16))
	_expect(bool(largest.get("ok")), "el tamano maximo permitido debe generarse")
	_expect(_all_spawns_connected(largest), "el mapa maximo debe tener spawns conectados")

	_case = "semillas distintas"
	var seed_a: Dictionary = GeneratorScript.generate(1, params)
	var seed_b: Dictionary = GeneratorScript.generate(2, params)
	_expect(str(seed_a) != str(seed_b), "semillas distintas deben producir mapas distintos")
	_expect(str(seed_a.get("id", "")) != str(seed_b.get("id", "")), "los ids deben diferir por semilla")

	_case = "parametros invalidos"
	var bad_cases: Array = [
		[{"width": 0}, "width"],
		[{"height": 7}, "height"],
		[{"width": 5000, "height": 5000}, "width"],
		[{"obstacle_density": -0.1}, "obstacle_density"],
		[{"obstacle_density": 1.5}, "obstacle_density"],
		[{"spawn_count": 0}, "spawn_count"],
		[{"spawn_count": 17}, "spawn_count"],
		[{"width": "abc"}, "width"],
		[{"density": true}, "obstacle_density"],
		[{"size": null}, "size"],
		[{"spawn_points": [Vector2i(99, 99)]}, "limites"],
		[{"spawn_points": [Vector2i(2, 2), Vector2i(2, 2)]}, "duplicado"],
	]
	for case in bad_cases:
		var bad_params: Dictionary = case[0]
		var needle: String = case[1]
		var result: Dictionary = GeneratorScript.generate(99, bad_params)
		_expect(not bool(result.get("ok", true)), "parametros %s deben rechazarse" % str(bad_params))
		_expect(_has_error(result, needle), "el error debe mencionar '%s' en %s" % [needle, str(bad_params)])

	_case = "limites y alias"
	var minimum: Dictionary = GeneratorScript.generate(7, _params(8, 8, 0.0, 1))
	_expect(bool(minimum.get("ok")), "el minimo 8x8 con un spawn debe generarse")
	_expect(int(minimum.get("width", 0)) == 8 and int(minimum.get("height", 0)) == 8, "el minimo debe respetarse")
	var aliased: Dictionary = GeneratorScript.generate(8, {
		"size": [16, 12],
		"density": 0.25,
		"spawns": 3,
	})
	_expect(bool(aliased.get("ok")), "los alias size/density/spawns deben aceptarse")
	_expect(int(aliased.get("width", 0)) == 16 and int(aliased.get("height", 0)) == 12, "size debe aplicarse")
	_expect(
		(aliased.get("spawn_points", []) as Array).size() == 3,
		"spawns debe aplicarse como cantidad de puntos"
	)
	var limits: Dictionary = GeneratorScript.get_limits()
	_expect(int(limits.get("max_cells", 0)) <= 4096, "el limite de celdas debe proteger memoria movil")

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _params(width: int, height: int, density: float, spawns: int) -> Dictionary:
	return {
		"width": width,
		"height": height,
		"obstacle_density": density,
		"spawn_count": spawns,
	}


func _has_error(result: Dictionary, needle: String) -> bool:
	for item in result.get("errors", []):
		if needle in str(item):
			return true
	return false


func _all_spawns_connected(meta: Dictionary) -> bool:
	var grid: Array = meta.get("grid", [])
	if grid.is_empty():
		return false
	var spawn_cells: Array = meta.get("spawn_cells", [])
	if spawn_cells.is_empty():
		return false

	var height: int = grid.size()
	var width: int = str(grid[0]).length()
	var start: Vector2i = spawn_cells[0]
	var visited: Dictionary = {_key(start.x, start.y): true}
	var queue: Array = [start]
	var index: int = 0
	var directions: Array = [[0, -1], [1, 0], [0, 1], [-1, 0]]
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		for direction in directions:
			var next_x: int = cell.x + int(direction[0])
			var next_y: int = cell.y + int(direction[1])
			if next_x < 0 or next_y < 0 or next_y >= height or next_x >= width:
				continue
			var key: String = _key(next_x, next_y)
			if visited.has(key):
				continue
			var character: String = str(grid[next_y]).substr(next_x, 1)
			if character == "#":
				continue
			visited[key] = true
			queue.append(Vector2i(next_x, next_y))

	for cell in spawn_cells:
		var point: Vector2i = cell
		if not visited.has(_key(point.x, point.y)):
			return false
	return true


func _key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])
