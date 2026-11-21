class_name MapGenerator
extends RefCounted

const ValidatorScript = preload("res://core/maps/map_validator.gd")

const MIN_SIZE := 8
const MAX_SIZE := 64
const MAX_CELLS := 4096
const DEFAULT_WIDTH := 24
const DEFAULT_HEIGHT := 18
const DEFAULT_DENSITY := 0.18
const DEFAULT_SPAWNS := 4
const MAX_SPAWNS := 16
const MAX_FORBIDDEN_ZONES := 12
const CELL_WALKABLE := 0
const CELL_OBSTACLE := 1
const DIRECTIONS: Array = [[0, -1], [1, 0], [0, 1], [-1, 0]]

const SIZE_ALIASES: Array = ["size", "grid_size", "map_size", "dimensions"]
const WIDTH_ALIASES: Array = ["width", "w", "grid_width", "map_width", "cols", "columns", "size_x"]
const HEIGHT_ALIASES: Array = ["height", "h", "grid_height", "map_height", "rows", "size_y"]
const DENSITY_ALIASES: Array = [
	"obstacle_density", "density", "obstacle_chance", "wall_density", "obstacle_rate",
]
const SPAWN_ALIASES: Array = [
	"spawn_points", "spawns", "spawn_count", "num_spawns", "spawn_point_count",
	"player_spawns", "player_spawn_points",
]


static func get_limits() -> Dictionary:
	return {
		"min_size": MIN_SIZE,
		"max_size": MAX_SIZE,
		"max_cells": MAX_CELLS,
		"min_density": 0.0,
		"max_density": 1.0,
		"min_spawns": 1,
		"max_spawns": MAX_SPAWNS,
	}


static func generate(seed: int, params: Dictionary) -> Dictionary:
	var errors: Array = []
	var settings: Dictionary = _parse_params(params, errors)
	if not errors.is_empty():
		return _reject(errors)

	var width: int = int(settings["width"])
	var height: int = int(settings["height"])
	var density: float = float(settings["density"])
	var forced_cells: Array = settings["forced_cells"]
	var spawn_count: int = int(settings["spawn_count"])

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var spawn_cells: Array = _select_spawns(width, height, spawn_count, forced_cells, rng)
	settings["spawn_cells"] = spawn_cells

	var grid: Array = _build_grid(width, height, density, rng, spawn_cells)
	var connectivity: Dictionary = _ensure_connectivity(grid, spawn_cells, rng)
	if not bool(connectivity["ok"]):
		errors.append("no se pudo garantizar la conectividad de los puntos de aparicion")
		return _reject(errors)

	var meta: Dictionary = _build_metadata(seed, settings, grid, connectivity, rng)
	var validator = ValidatorScript.new()
	var validation: Dictionary = validator.validate(meta)
	if int(validation.get("status", ValidatorScript.Status.INCOMPATIBLE)) > ValidatorScript.Status.COMPATIBLE_WITH_WARNINGS:
		errors.append("el mapa generado no supera MapValidator")
		for message in validation.get("errors", []):
			errors.append(str(message))
		return _reject(errors)

	meta["validation"] = {
		"status": int(validation.get("status", ValidatorScript.Status.COMPATIBLE)),
		"errors": [],
		"warnings": validation.get("warnings", []),
	}
	meta["ok"] = true
	meta["errors"] = []
	return meta


static func _parse_params(params: Dictionary, errors: Array) -> Dictionary:
	var settings: Dictionary = {
		"width": DEFAULT_WIDTH,
		"height": DEFAULT_HEIGHT,
		"density": DEFAULT_DENSITY,
		"spawn_count": DEFAULT_SPAWNS,
		"forced_cells": [],
		"theme": "",
	}

	for key in SIZE_ALIASES + WIDTH_ALIASES + HEIGHT_ALIASES + DENSITY_ALIASES + SPAWN_ALIASES:
		if params.has(key) and params[key] == null:
			errors.append("%s: valor nulo no permitido" % str(key))

	var size_value: Variant = _first_value(params, SIZE_ALIASES)
	if size_value != null:
		_apply_size(size_value, settings, errors)

	var width_value: Variant = _first_value(params, WIDTH_ALIASES)
	if width_value != null:
		var parsed: Variant = _as_int(width_value)
		if parsed == null:
			errors.append("width: se esperaba un entero, se recibio %s" % type_string(typeof(width_value)))
		else:
			settings["width"] = int(parsed)

	var height_value: Variant = _first_value(params, HEIGHT_ALIASES)
	if height_value != null:
		var parsed: Variant = _as_int(height_value)
		if parsed == null:
			errors.append("height: se esperaba un entero, se recibio %s" % type_string(typeof(height_value)))
		else:
			settings["height"] = int(parsed)

	var density_value: Variant = _first_value(params, DENSITY_ALIASES)
	if density_value != null:
		var parsed: Variant = _as_float(density_value)
		if parsed == null:
			errors.append("obstacle_density: se esperaba un numero entre 0 y 1")
		else:
			settings["density"] = float(parsed)

	_apply_spawns(params, settings, errors)

	var theme_value: Variant = params.get("theme", null)
	if theme_value != null:
		settings["theme"] = str(theme_value)

	var width: int = int(settings["width"])
	var height: int = int(settings["height"])
	var density: float = float(settings["density"])
	var spawn_count: int = int(settings["spawn_count"])
	var forced_cells: Array = settings["forced_cells"]

	if width < MIN_SIZE or width > MAX_SIZE:
		errors.append("width: debe estar entre %d y %d (recibido %d)" % [MIN_SIZE, MAX_SIZE, width])
	if height < MIN_SIZE or height > MAX_SIZE:
		errors.append("height: debe estar entre %d y %d (recibido %d)" % [MIN_SIZE, MAX_SIZE, height])
	if width >= MIN_SIZE and height >= MIN_SIZE and width * height > MAX_CELLS:
		errors.append("size: area maxima de %d celdas excedida (%d)" % [MAX_CELLS, width * height])
	if density < 0.0 or density > 1.0:
		errors.append("obstacle_density: debe estar entre 0 y 1 (recibido %f)" % density)
	if spawn_count < 1 or spawn_count > MAX_SPAWNS:
		errors.append("spawn_count: debe estar entre 1 y %d (recibido %d)" % [MAX_SPAWNS, spawn_count])

	var seen: Dictionary = {}
	for cell in forced_cells:
		if not (cell is Vector2i):
			errors.append("spawn_points: punto de aparicion invalido")
			continue
		var point: Vector2i = cell
		if point.x < 0 or point.y < 0 or point.x >= width or point.y >= height:
			errors.append(
				"spawn_points: punto (%d, %d) fuera de los limites %dx%d"
				% [point.x, point.y, width, height]
			)
			continue
		var key: String = _cell_key(point.x, point.y)
		if seen.has(key):
			errors.append("spawn_points: punto duplicado (%d, %d)" % [point.x, point.y])
		else:
			seen[key] = true

	return settings


static func _apply_size(value: Variant, settings: Dictionary, errors: Array) -> void:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			var parsed: Variant = _as_int(value)
			if parsed == null:
				errors.append("size: se esperaba un entero o una pareja de enteros")
				return
			var side: int = int(parsed)
			settings["width"] = side
			settings["height"] = side
		TYPE_ARRAY:
			var values: Array = value
			if values.size() < 2:
				errors.append("size: se esperaban dos dimensiones")
				return
			var parsed_width: Variant = _as_int(values[0])
			var parsed_height: Variant = _as_int(values[1])
			if parsed_width == null or parsed_height == null:
				errors.append("size: se esperaban dos enteros")
				return
			settings["width"] = int(parsed_width)
			settings["height"] = int(parsed_height)
		TYPE_DICTIONARY:
			var values: Dictionary = value
			var raw_width: Variant = null
			var raw_height: Variant = null
			for key in ["width", "w"]:
				if values.has(key):
					raw_width = values[key]
					break
			for key in ["height", "h"]:
				if values.has(key):
					raw_height = values[key]
					break
			var parsed_width: Variant = _as_int(raw_width)
			var parsed_height: Variant = _as_int(raw_height)
			if parsed_width == null or parsed_height == null:
				errors.append("size: se esperaban 'width' y 'height' enteros")
				return
			settings["width"] = int(parsed_width)
			settings["height"] = int(parsed_height)
		_:
			errors.append("size: tipo no admitido %s" % type_string(typeof(value)))


static func _apply_spawns(params: Dictionary, settings: Dictionary, errors: Array) -> void:
	var value: Variant = _first_value(params, SPAWN_ALIASES)
	if value == null:
		return

	if _is_int_like(value):
		var parsed: Variant = _as_int(value)
		if parsed == null:
			errors.append("spawn_count: se esperaba un entero")
			return
		settings["spawn_count"] = int(parsed)
		return

	if value is Array:
		var points: Array = value
		if points.is_empty():
			errors.append("spawn_points: se requiere al menos un punto de aparicion")
			return
		var cells: Array = []
		for item in points:
			var cell: Variant = _as_cell(item)
			if cell == null:
				errors.append("spawn_points: se esperaban coordenadas enteras x, y")
				return
			cells.append(cell)
		settings["forced_cells"] = cells
		settings["spawn_count"] = cells.size()
		return

	if value is Dictionary:
		var values: Dictionary = value
		if values.has("count"):
			var parsed: Variant = _as_int(values["count"])
			if parsed == null:
				errors.append("spawn_count: se esperaba un entero")
			else:
				settings["spawn_count"] = int(parsed)
			return
		var cell: Variant = _as_cell(value)
		if cell == null:
			errors.append("spawn_points: se esperaban coordenadas enteras x, y")
			return
		settings["forced_cells"] = [cell]
		settings["spawn_count"] = 1
		return

	errors.append("spawn_points: se esperaba un numero o una lista de coordenadas")


static func _as_cell(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2I:
			var point: Vector2i = value
			return point
		TYPE_VECTOR2:
			var point: Vector2 = value
			return Vector2i(int(point.x), int(point.y))
		TYPE_VECTOR3:
			var point: Vector3 = value
			return Vector2i(int(point.x), int(point.z))
		TYPE_VECTOR4:
			var point: Vector4 = value
			return Vector2i(int(point.x), int(point.z))
		TYPE_ARRAY:
			var values: Array = value
			if values.size() < 2:
				return null
			var x_value: Variant = _as_int(values[0])
			var y_value: Variant = _as_int(values[1])
			if x_value == null or y_value == null:
				return null
			return Vector2i(int(x_value), int(y_value))
		TYPE_DICTIONARY:
			var values: Dictionary = value
			var x_value: Variant = _as_int(values.get("x"))
			var y_value: Variant = _as_int(values.get("y"))
			if x_value == null or y_value == null:
				return null
			return Vector2i(int(x_value), int(y_value))
		TYPE_STRING:
			var parts: Array = str(value).split(",")
			if parts.size() != 2:
				return null
			var x_value: Variant = _as_int(parts[0])
			var y_value: Variant = _as_int(parts[1])
			if x_value == null or y_value == null:
				return null
			return Vector2i(int(x_value), int(y_value))
		_:
			return null


static func _first_value(params: Dictionary, keys: Array) -> Variant:
	for key in keys:
		if params.has(key):
			return params[key]
	return null


static func _is_int_like(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING]


static func _as_int(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			var number: float = value
			if is_nan(number) or is_inf(number) or floor(number) != number:
				return null
			return int(number)
		TYPE_STRING:
			var text: String = str(value).strip_edges()
			if text.is_valid_int():
				return int(text)
			if text.is_valid_float():
				var number: float = text.to_float()
				if not is_nan(number) and not is_inf(number) and floor(number) == number:
					return int(number)
			return null
		_:
			return null


static func _as_float(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return float(value)
		TYPE_FLOAT:
			var number: float = value
			if is_nan(number) or is_inf(number):
				return null
			return number
		TYPE_STRING:
			var text: String = str(value).strip_edges()
			if not text.is_valid_float() and not text.is_valid_int():
				return null
			var number: float = text.to_float()
			if is_nan(number) or is_inf(number):
				return null
			return number
		_:
			return null


static func _select_spawns(
	width: int, height: int, count: int, forced_cells: Array, rng: RandomNumberGenerator
) -> Array:
	if not forced_cells.is_empty():
		return forced_cells.duplicate()

	var cells: Array = []
	var attempts: int = 0
	var max_attempts: int = count * 200 + 200
	while cells.size() < count and attempts < max_attempts:
		var cell := Vector2i(
			rng.randi_range(1, maxi(1, width - 2)),
			rng.randi_range(1, maxi(1, height - 2))
		)
		if not cells.has(cell):
			cells.append(cell)
		attempts += 1

	if cells.size() >= count:
		return cells

	for y in range(1, maxi(1, height - 1)):
		for x in range(1, maxi(1, width - 1)):
			if cells.size() >= count:
				return cells
			var cell := Vector2i(x, y)
			if not cells.has(cell):
				cells.append(cell)
	return cells


static func _build_grid(
	width: int, height: int, density: float, rng: RandomNumberGenerator, spawn_cells: Array
) -> Array:
	var grid: Array = []
	for y in range(height):
		var row: Array = []
		for x in range(width):
			var blocked := false
			if x > 0 and y > 0 and x < width - 1 and y < height - 1:
				blocked = rng.randf() < density
			row.append(CELL_OBSTACLE if blocked else CELL_WALKABLE)
		grid.append(row)

	for cell in spawn_cells:
		var point: Vector2i = cell
		grid[point.y][point.x] = CELL_WALKABLE
	return grid


static func _ensure_connectivity(
	grid: Array, spawn_cells: Array, rng: RandomNumberGenerator
) -> Dictionary:
	if spawn_cells.is_empty():
		return {"ok": false, "reachable_cells": 0}

	var hub: Vector2i = spawn_cells[0]
	for index in range(1, spawn_cells.size()):
		var from: Vector2i = spawn_cells[index]
		_carve_corridor(grid, from, hub, rng.randi_range(0, 1) == 0)

	var reached: Array = _flood_fill(grid, hub)
	var all_reached := true
	for cell in spawn_cells:
		var point: Vector2i = cell
		if not reached.has(point):
			all_reached = false
			break

	if not all_reached:
		for y in range(grid.size()):
			var row: Array = grid[y]
			for x in range(row.size()):
				row[x] = CELL_WALKABLE
		reached = _flood_fill(grid, hub)
		all_reached = true
		for cell in spawn_cells:
			var point: Vector2i = cell
			if not reached.has(point):
				all_reached = false
				break

	return {
		"ok": all_reached,
		"reachable_cells": reached.size(),
		"hub": hub,
	}


static func _carve_corridor(
	grid: Array, from: Vector2i, to: Vector2i, horizontal_first: bool
) -> void:
	grid[from.y][from.x] = CELL_WALKABLE
	var x: int = from.x
	var y: int = from.y

	if horizontal_first:
		while x != to.x:
			grid[y][x] = CELL_WALKABLE
			x += signi(to.x - x)
		while y != to.y:
			grid[y][x] = CELL_WALKABLE
			y += signi(to.y - y)
	else:
		while y != to.y:
			grid[y][x] = CELL_WALKABLE
			y += signi(to.y - y)
		while x != to.x:
			grid[y][x] = CELL_WALKABLE
			x += signi(to.x - x)

	grid[to.y][to.x] = CELL_WALKABLE


static func _flood_fill(grid: Array, start: Vector2i) -> Array:
	var queue: Array = [start]
	var seen: Dictionary = {_cell_key(start.x, start.y): true}
	var index: int = 0
	var height: int = grid.size()
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		for direction in DIRECTIONS:
			var next_x: int = cell.x + int(direction[0])
			var next_y: int = cell.y + int(direction[1])
			if next_x < 0 or next_y < 0 or next_y >= height or next_x >= grid[next_y].size():
				continue
			if int(grid[next_y][next_x]) != CELL_WALKABLE:
				continue
			var key: String = _cell_key(next_x, next_y)
			if seen.has(key):
				continue
			seen[key] = true
			queue.append(Vector2i(next_x, next_y))
	return queue


static func _cell_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


static func _build_metadata(
	seed: int, settings: Dictionary, grid: Array, connectivity: Dictionary, rng: RandomNumberGenerator
) -> Dictionary:
	var width: int = int(settings["width"])
	var height: int = int(settings["height"])
	var density: float = float(settings["density"])
	var spawn_cells: Array = settings["spawn_cells"]
	var spawn_count: int = int(settings["spawn_count"])

	var rows: Array = []
	var obstacle_cells: Array = []
	var obstacles: Array = []
	for y in range(height):
		var row_text := ""
		var row: Array = grid[y]
		for x in range(width):
			var point := Vector2i(x, y)
			var blocked: bool = int(row[x]) == CELL_OBSTACLE
			if spawn_cells.has(point):
				row_text += "S"
			elif blocked:
				row_text += "#"
			else:
				row_text += "."
			if blocked:
				obstacle_cells.append(point)
				obstacles.append(Vector3(float(x), 0.0, float(y)))
		rows.append(row_text)

	var spawn_points: Array = []
	for cell in spawn_cells:
		var point: Vector2i = cell
		spawn_points.append(Vector3(float(point.x) + 0.5, 0.0, float(point.y) + 0.5))

	var normalized_params: Dictionary = {
		"width": width,
		"height": height,
		"obstacle_density": density,
		"spawn_count": spawn_count,
		"spawn_cells": spawn_cells.duplicate(),
	}

	var center := Vector3(float(width) * 0.5, 0.0, float(height) * 0.5)
	var exit_y := float(height) * 0.5
	var map_id := "gen_%d_%dx%d_%dsp" % [seed, width, height, spawn_count]
	var reachable_cells: int = int(connectivity.get("reachable_cells", 0))
	var total_cells: int = width * height

	return {
		"id": map_id,
		"version": "1.0.0",
		"author": "MapGenerator",
		"license": "Project-Standard",
		"scale": 1.0,
		"theme": settings.get("theme", ""),
		"main_scene": "res://scenes/maps/generated_map.tscn",
		"has_collisions": true,
		"has_navigation": true,
		"spawn_points": spawn_points,
		"forbidden_zones": _build_forbidden_zones(obstacle_cells, width, height),
		"boundaries": {
			"min": Vector3(0.0, 0.0, 0.0),
			"max": Vector3(float(width), 0.0, float(height)),
			"width": width,
			"height": height,
		},
		"exits": [
			{
				"id": "exit_west",
				"cell": Vector2i(0, height / 2),
				"position": Vector3(0.0, 0.0, exit_y),
			},
			{
				"id": "exit_east",
				"cell": Vector2i(width - 1, height / 2),
				"position": Vector3(float(width), 0.0, exit_y),
			},
		],
		"zones": [
			{"id": "spawn_area", "center": center, "radius": float(mini(width, height)) * 0.25},
			{"id": "central_area", "center": center, "radius": float(mini(width, height)) * 0.15},
		],
		"performance_profiles": {
			"android": {"max_cells": MAX_CELLS, "obstacle_count": obstacle_cells.size()},
			"pc": {"max_cells": MAX_CELLS, "obstacle_count": obstacle_cells.size()},
			"vr": {"max_cells": MAX_CELLS, "obstacle_count": obstacle_cells.size()},
		},
		"platforms": ["android", "pc", "vr"],
		"tags": ["generated", "procedural", "mapgen"],
		"players_min": 1,
		"players_max": maxi(1, spawn_count),
		"seed": seed,
		"width": width,
		"height": height,
		"obstacle_density": density,
		"grid": rows,
		"obstacle_cells": obstacle_cells,
		"obstacles": obstacles,
		"spawn_cells": spawn_cells.duplicate(),
		"connectivity": {
			"ok": true,
			"method": "flood_fill_bfs",
			"reachable_cells": reachable_cells,
			"total_cells": total_cells,
			"reachable_ratio": float(reachable_cells) / float(maxi(1, total_cells)),
			"spawn_count": spawn_count,
		},
		"normalized_params": normalized_params,
		"generator_salt": rng.randi(),
	}


static func _build_forbidden_zones(
	obstacle_cells: Array, width: int, height: int
) -> Array:
	var zones: Array = []
	if obstacle_cells.is_empty():
		return zones

	var columns: int = 4
	var rows_count: int = 3
	var step_x: int = maxi(1, int(ceil(float(width) / float(columns))))
	var step_y: int = maxi(1, int(ceil(float(height) / float(rows_count))))
	var groups: Dictionary = {}
	for cell in obstacle_cells:
		var point: Vector2i = cell
		var group_x: int = mini(columns - 1, int(float(point.x) / float(step_x)))
		var group_y: int = mini(rows_count - 1, int(float(point.y) / float(step_y)))
		var key: String = _cell_key(group_x, group_y)
		if not groups.has(key):
			groups[key] = []
		var cells: Array = groups[key]
		cells.append(point)

	var keys: Array = groups.keys()
	keys.sort()
	for key in keys:
		var cells: Array = groups[key]
		if cells.is_empty():
			continue
		var min_x: int = width
		var max_x: int = -1
		var min_y: int = height
		var max_y: int = -1
		for cell in cells:
			var point: Vector2i = cell
			min_x = mini(min_x, point.x)
			max_x = maxi(max_x, point.x)
			min_y = mini(min_y, point.y)
			max_y = maxi(max_y, point.y)
		zones.append({
			"id": "forbidden_" + key,
			"cells": cells.duplicate(),
			"center": Vector3(
				float(min_x + max_x) * 0.5, 0.0, float(min_y + max_y) * 0.5
			),
			"size": Vector3(
				float(max_x - min_x + 1), 1.0, float(max_y - min_y + 1)
			),
		})
		if zones.size() >= MAX_FORBIDDEN_ZONES:
			break
	return zones


static func _reject(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"errors": errors.duplicate(),
		"meta": {},
		"id": "",
	}
