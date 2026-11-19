class_name NPCNavigation
extends RefCounted

const DEFAULT_MAX_EXPANSIONS: int = 4096
const SQRT2: float = 1.4142135623730951

var width: int = 0
var height: int = 0
var obstacles: Dictionary = {}
var allow_diagonal: bool = false
var max_expansions: int = DEFAULT_MAX_EXPANSIONS


func _init(p_width: int = 0, p_height: int = 0, p_obstacles: Array = [], p_options: Dictionary = {}) -> void:
	configure(p_width, p_height, p_obstacles, p_options)


func configure(p_width: int, p_height: int, p_obstacles: Array = [], p_options: Dictionary = {}) -> void:
	width = maxi(0, int(p_width))
	height = maxi(0, int(p_height))
	obstacles.clear()
	set_obstacles(p_obstacles)
	allow_diagonal = bool(p_options.get("allow_diagonal", allow_diagonal))
	max_expansions = maxi(1, int(p_options.get("max_expansions", max_expansions)))


func set_obstacles(cells: Array) -> void:
	for value in cells:
		var cell: Variant = _as_cell(value)
		if cell != null:
			obstacles[cell] = true


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_blocked(cell: Vector2i) -> bool:
	return obstacles.has(cell)


func find_path(start_value, goal_value, options: Dictionary = {}) -> Dictionary:
	var start: Variant = _as_cell(start_value)
	var goal: Variant = _as_cell(goal_value)
	if start == null or goal == null or not is_inside(start) or not is_inside(goal):
		return _result(false, [], "out_of_bounds", 0)
	if obstacles.has(start):
		return _result(false, [], "blocked_start", 0)
	if obstacles.has(goal):
		return _result(false, [], "blocked_goal", 0)
	if start == goal:
		return _result(true, [start], "ok", 0)

	var diagonal: bool = bool(options.get("allow_diagonal", allow_diagonal))
	var budget: int = maxi(1, int(options.get("max_expansions", max_expansions)))
	var smooth: bool = bool(options.get("smooth", false))

	var open: Dictionary = {}
	var costs: Dictionary = {}
	var came_from: Dictionary = {}
	var closed: Dictionary = {}
	costs[start] = 0.0
	var start_h: float = _heuristic(start, goal, diagonal)
	open[start] = {"f": start_h, "h": start_h}

	var expanded: int = 0
	while not open.is_empty():
		if expanded >= budget:
			return _result(false, [], "node_limit", expanded)
		var current: Vector2i = _pop_best(open)
		expanded += 1
		if current == goal:
			var path: Array = _reconstruct(came_from, current)
			if smooth:
				path = smooth_path(path)
			return _result(true, path, "ok", expanded)
		closed[current] = true
		for next_cell in _neighbors(current, diagonal):
			if closed.has(next_cell) or obstacles.has(next_cell):
				continue
			var distance: int = absi(next_cell.x - current.x) + absi(next_cell.y - current.y)
			var step_cost: float = SQRT2 if distance == 2 else 1.0
			var tentative: float = float(costs[current]) + step_cost
			if costs.has(next_cell) and tentative >= float(costs[next_cell]) - 0.000001:
				continue
			costs[next_cell] = tentative
			came_from[next_cell] = current
			var h: float = _heuristic(next_cell, goal, diagonal)
			open[next_cell] = {"f": tentative + h, "h": h}

	return _result(false, [], "no_path", expanded)


func smooth_path(path: Array) -> Array:
	if path.size() < 3:
		return path.duplicate()
	var result: Array = [path[0]]
	var index: int = 1
	while index < path.size() - 1:
		var previous: Vector2i = result[result.size() - 1]
		var current: Vector2i = path[index]
		var next_cell: Vector2i = path[index + 1]
		if _same_direction(previous, current, next_cell):
			index += 1
			continue
		result.append(current)
		index += 1
	result.append(path[path.size() - 1])
	return result


func create_follower(source) -> PathFollower:
	if source is Dictionary:
		if not bool(source.get("ok", false)):
			return PathFollower.new()
		return PathFollower.new(source.get("path", []))
	if source is Array:
		return PathFollower.new(source)
	return PathFollower.new()


func drive_controller(controller, follower, options: Dictionary = {}) -> Dictionary:
	if not (follower is PathFollower):
		return {"ok": false, "reason": "invalid_follower", "moved": false, "finished": true, "cell": null, "state": ""}
	var next_cell: Variant = follower.peek_next()
	var arrived: bool = next_cell == null
	var state_machine: Variant = null
	if controller is Object:
		state_machine = controller.get("state_machine")
	var state: String = ""
	if state_machine != null and state_machine.has_method("transition_to"):
		var wanted: String = str(options.get("arrived_state", "idle")) if arrived else str(options.get("walk_state", "walk"))
		state_machine.transition_to(wanted)
	if state_machine != null and state_machine.has_method("get_state"):
		state = str(state_machine.get_state())
	var moved: Variant = null
	if not arrived and not bool(options.get("state_only", false)):
		moved = follower.advance()
	return {
		"ok": true,
		"reason": "arrived" if arrived else "step",
		"moved": moved != null,
		"finished": arrived,
		"cell": moved,
		"state": state,
	}


func cell_to_world(cell_value, cell_size: float = 1.0, plane_y: float = 0.0) -> Vector3:
	var cell: Variant = _as_cell(cell_value)
	if cell == null:
		return Vector3.ZERO
	return Vector3(float(cell.x) * cell_size, plane_y, float(cell.y) * cell_size)


func world_to_cell_2d(position: Vector2, cell_size: float = 1.0) -> Vector2i:
	if cell_size <= 0.0:
		return Vector2i.ZERO
	return Vector2i(roundi(position.x / cell_size), roundi(position.y / cell_size))


func world_to_cell_3d(position: Vector3, cell_size: float = 1.0) -> Vector2i:
	return world_to_cell_2d(Vector2(position.x, position.z), cell_size)


class PathFollower extends RefCounted:
	var path: Array = []
	var index: int = 0
	var last_cell: Variant = null

	func _init(p_path: Array = []) -> void:
		path = p_path.duplicate()
		if not path.is_empty():
			last_cell = path[0]

	func has_next() -> bool:
		return index < path.size()

	func is_finished() -> bool:
		return index >= path.size()

	func peek_next() -> Variant:
		return path[index] if has_next() else null

	func current_cell() -> Variant:
		return last_cell

	func advance() -> Variant:
		if not has_next():
			return null
		last_cell = path[index]
		index += 1
		return last_cell

	func remaining() -> int:
		return maxi(0, path.size() - index)


func _as_cell(value) -> Variant:
	if value is Vector2i:
		return value
	if value is Vector3i:
		return Vector2i(value.x, value.z)
	if value is Vector2:
		return Vector2i(roundi(value.x), roundi(value.y))
	if value is Vector3:
		return Vector2i(roundi(value.x), roundi(value.z))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	if value is Dictionary:
		if value.has("cell"):
			return _as_cell(value["cell"])
		var cell_x: Variant = value.get("x", value.get("col", null))
		var cell_y: Variant = value.get("y", value.get("z", value.get("row", null)))
		if cell_x != null and cell_y != null:
			return Vector2i(int(cell_x), int(cell_y))
	return null


func _neighbors(cell: Vector2i, diagonal: bool) -> Array:
	var result: Array = [
		cell + Vector2i(1, 0),
		cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(0, -1),
	]
	if diagonal:
		result.append(cell + Vector2i(1, 1))
		result.append(cell + Vector2i(1, -1))
		result.append(cell + Vector2i(-1, 1))
		result.append(cell + Vector2i(-1, -1))
	var walkable: Array = []
	for candidate in result:
		if not is_inside(candidate) or obstacles.has(candidate):
			continue
		if diagonal and candidate.x != cell.x and candidate.y != cell.y:
			if obstacles.has(Vector2i(candidate.x, cell.y)) or obstacles.has(Vector2i(cell.x, candidate.y)):
				continue
		walkable.append(candidate)
	return walkable


func _heuristic(from_cell: Vector2i, to_cell: Vector2i, diagonal: bool) -> float:
	var dx: int = absi(from_cell.x - to_cell.x)
	var dy: int = absi(from_cell.y - to_cell.y)
	if diagonal:
		return float(maxi(dx, dy)) + (SQRT2 - 1.0) * float(mini(dx, dy))
	return float(dx + dy)


func _pop_best(open: Dictionary) -> Vector2i:
	var best: Vector2i = open.keys()[0]
	var best_f: float = float(open[best]["f"])
	var best_h: float = float(open[best]["h"])
	for key in open.keys():
		var entry: Dictionary = open[key]
		var f: float = float(entry["f"])
		var h: float = float(entry["h"])
		if f < best_f or (is_equal_approx(f, best_f) and h < best_h):
			best = key
			best_f = f
			best_h = h
	open.erase(best)
	return best


func _reconstruct(came_from: Dictionary, end_cell: Vector2i) -> Array:
	var path: Array = []
	var cursor: Variant = end_cell
	while cursor != null:
		path.append(cursor)
		if not came_from.has(cursor):
			break
		cursor = came_from[cursor]
	path.reverse()
	return path


func _same_direction(previous: Vector2i, current: Vector2i, next_cell: Vector2i) -> bool:
	var first: Vector2i = current - previous
	var second: Vector2i = next_cell - current
	if first.x != 0 and second.x != 0 and signi(first.x) != signi(second.x):
		return false
	if first.y != 0 and second.y != 0 and signi(first.y) != signi(second.y):
		return false
	return (first.x == 0) == (second.x == 0) and (first.y == 0) == (second.y == 0)


func _result(ok: bool, path: Array, reason: String, expanded: int) -> Dictionary:
	return {"ok": ok, "path": path, "reason": reason, "expanded": expanded, "length": path.size()}
