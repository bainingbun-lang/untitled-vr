extends SceneTree

const NPCNavigation = preload("res://core/npc/npc_navigation.gd")
const NPCStateMachine = preload("res://core/npc/npc_state_machine.gd")
const NPCPersonality = preload("res://core/npc/npc_personality.gd")
const NPCNeeds = preload("res://core/npc/npc_needs.gd")
const NPCMemory = preload("res://core/npc/npc_memory.gd")
const NPCRoutine = preload("res://core/npc/npc_routine.gd")
const NPCController = preload("res://core/npc/npc_controller.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _init():
	_case = "ruta libre"
	var nav = NPCNavigation.new(8, 8)
	var result: Dictionary = nav.find_path(Vector2i(0, 0), Vector2i(4, 3))
	_check("ruta libre encontrada", result["ok"] == true and result["reason"] == "ok", str(result))
	var path: Array = result["path"]
	_check("ruta libre empieza y termina en los extremos", path.size() >= 2 and path[0] == Vector2i(0, 0) and path[path.size() - 1] == Vector2i(4, 3), str(path))
	_check("ruta libre contigua y dentro de la rejilla", _contiguous(path) and _inside(path, 8, 8), str(path))
	_check("ruta libre reporta expansion", int(result["expanded"]) > 0, str(result))

	_case = "rodeo de obstaculos"
	var wall: Array = []
	for y in range(5):
		wall.append(Vector2i(2, y))
	var detour_nav = NPCNavigation.new(6, 6, wall)
	var detour: Dictionary = detour_nav.find_path(Vector2i(0, 0), Vector2i(4, 0))
	_check("rodeo encontrado", detour["ok"] == true, str(detour))
	var detour_path: Array = detour["path"]
	_check("rodeo evita obstaculos", _clear_of(detour_path, wall), str(detour_path))
	_check("rodeo contiguo", _contiguous(detour_path), str(detour_path))
	_check("rodeo es mas largo que la linea recta", detour_path.size() > 5, str(detour_path.size()))

	_case = "ruta bloqueada"
	var full_wall: Array = []
	for y in range(6):
		full_wall.append(Vector2i(2, y))
	var blocked_nav = NPCNavigation.new(6, 6, full_wall)
	var blocked: Dictionary = blocked_nav.find_path(Vector2i(0, 0), Vector2i(4, 0))
	_check("ruta imposible es controlada", blocked["ok"] == false and blocked["reason"] == "no_path" and (blocked["path"] as Array).is_empty(), str(blocked))
	_check("ruta imposible agota la rejilla sin excederla", int(blocked["expanded"]) <= 36, str(blocked))
	var blocked_follower = blocked_nav.create_follower(blocked)
	_check("seguidor de ruta imposible queda vacio", blocked_follower.is_finished() == true, str(blocked_follower.path))

	_case = "limite de nodos"
	var limited: Dictionary = nav.find_path(Vector2i(0, 0), Vector2i(7, 7), {"max_expansions": 1})
	_check("limite de expansion detectado", limited["ok"] == false and limited["reason"] == "node_limit" and int(limited["expanded"]) == 1, str(limited))
	var enough: Dictionary = nav.find_path(Vector2i(0, 0), Vector2i(7, 7), {"max_expansions": 4096})
	_check("mismo caso con presupuesto suficiente", enough["ok"] == true, str(enough))

	_case = "origen igual a destino"
	var same: Dictionary = nav.find_path(Vector2i(2, 2), Vector2i(2, 2))
	_check("origen=destino resuelto", same["ok"] == true and (same["path"] as Array) == [Vector2i(2, 2)], str(same))
	_check("origen=destino sin expansion", int(same["expanded"]) == 0, str(same))
	var blocked_same: Dictionary = detour_nav.find_path(Vector2i(2, 0), Vector2i(2, 0))
	_check("celda origen bloqueada se reporta", blocked_same["ok"] == false and blocked_same["reason"] == "blocked_start", str(blocked_same))
	var goal_blocked: Dictionary = detour_nav.find_path(Vector2i(0, 0), Vector2i(2, 0))
	_check("celda destino bloqueada se reporta", goal_blocked["ok"] == false and goal_blocked["reason"] == "blocked_goal", str(goal_blocked))

	_case = "fuera de rejilla"
	var outside_start: Dictionary = nav.find_path(Vector2i(-1, 0), Vector2i(1, 1))
	var outside_goal: Dictionary = nav.find_path(Vector2i(0, 0), Vector2i(8, 8))
	_check("origen fuera de rejilla", outside_start["ok"] == false and outside_start["reason"] == "out_of_bounds", str(outside_start))
	_check("destino fuera de rejilla", outside_goal["ok"] == false and outside_goal["reason"] == "out_of_bounds", str(outside_goal))

	_case = "suavizado opcional"
	var straight: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	var smoothed: Array = nav.smooth_path(straight)
	_check("suavizado elimina puntos colineales", smoothed == [Vector2i(0, 0), Vector2i(3, 0)], str(smoothed))
	var raw_path: Array = nav.find_path(Vector2i(0, 0), Vector2i(5, 0))["path"]
	var smooth_result: Dictionary = nav.find_path(Vector2i(0, 0), Vector2i(5, 0), {"smooth": true})
	_check("suavizado conserva extremos y reduce puntos", smooth_result["ok"] == true and (smooth_result["path"] as Array).size() < raw_path.size() and (smooth_result["path"] as Array)[0] == Vector2i(0, 0) and (smooth_result["path"] as Array)[-1] == Vector2i(5, 0), str(smooth_result))

	_case = "diagonal opcional"
	var diagonal_nav = NPCNavigation.new(4, 4)
	var straight_only: Dictionary = diagonal_nav.find_path(Vector2i(0, 0), Vector2i(3, 3))
	var diagonal_result: Dictionary = diagonal_nav.find_path(Vector2i(0, 0), Vector2i(3, 3), {"allow_diagonal": true})
	_check("diagonal acorta la ruta", (diagonal_result["path"] as Array).size() < (straight_only["path"] as Array).size(), str([straight_only["length"], diagonal_result["length"]]))
	_check("diagonal contigua", _contiguous(diagonal_result["path"]), str(diagonal_result["path"]))

	_case = "seguimiento y adaptador de controlador"
	var follower = nav.create_follower(result)
	_check("seguidor arranca en el origen", follower.has_next() == true and follower.current_cell() == Vector2i(0, 0) and follower.remaining() == path.size(), str(path.size()))
	var controller = NPCController.new(NPCStateMachine.new(), NPCPersonality.new(), NPCNeeds.new(), NPCMemory.new(), NPCRoutine.new())
	var first_step: Dictionary = nav.drive_controller(controller, follower)
	_check("primer paso mueve y pone a caminar", first_step["ok"] == true and first_step["moved"] == true and first_step["state"] == "walk" and follower.current_cell() == Vector2i(0, 0), str(first_step))
	while follower.has_next():
		nav.drive_controller(controller, follower)
	_check("seguidor consume toda la ruta", follower.is_finished() == true and follower.remaining() == 0 and follower.current_cell() == Vector2i(4, 3), str(follower.current_cell()))
	var arrival: Dictionary = nav.drive_controller(controller, follower)
	_check("al llegar el controlador vuelve a idle sin forzar movimiento", arrival["reason"] == "arrived" and arrival["moved"] == false and arrival["state"] == "idle" and controller.state_machine.get_state() == "idle", str(arrival))

	_case = "conversion 2D/3D"
	var world: Vector3 = nav.cell_to_world(Vector2i(2, 3), 2.0, 1.5)
	_check("celda a mundo 3D", world == Vector3(4.0, 1.5, 6.0), str(world))
	_check("mundo 3D a celda", nav.world_to_cell_3d(Vector3(4.4, 9.0, 5.6), 2.0) == Vector2i(2, 3), str(nav.world_to_cell_3d(Vector3(4.4, 9.0, 5.6), 2.0)))
	_check("mundo 2D a celda", nav.world_to_cell_2d(Vector2(-2.4, 3.4), 2.0) == Vector2i(-1, 2), str(nav.world_to_cell_2d(Vector2(-2.4, 3.4), 2.0)))

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _check(name: String, condition: bool, detail: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s -> %s" % [_case, name, detail])


func _contiguous(path: Array) -> bool:
	if path.is_empty():
		return false
	for i in range(1, path.size()):
		var delta: Vector2i = path[i] - path[i - 1]
		if absi(delta.x) + absi(delta.y) != 1 and absi(delta.x) != 1 and absi(delta.y) != 1:
			return false
	return true


func _inside(path: Array, p_width: int, p_height: int) -> bool:
	for cell in path:
		if cell.x < 0 or cell.y < 0 or cell.x >= p_width or cell.y >= p_height:
			return false
	return true


func _clear_of(path: Array, obstacles: Array) -> bool:
	for cell in path:
		if cell in obstacles:
			return false
	return true
