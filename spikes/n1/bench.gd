extends SceneTree

const CELL := 25.0
const NEAR := 60.0
const MID := 180.0
const SEE := 30.0
const TICKS := 120

func _init() -> void:
	for n in [10, 50, 100, 250, 500, 1000, 2000, 4000, 8000]:
		var r := _run(n)
		print("N1 N=%d ms_per_tick=%.3f active_avg=%.1f mem_mb=%.2f" % [n, r.ms, r.active, r.mem])
		if r.ms > 16.7:
			print("N1 BUDGET_16_7MS_EXCEEDED_AT=%d" % n)
			break
	quit(0)

func _run(n: int) -> Dictionary:
	seed(42)
	var pos := PackedVector2Array(); pos.resize(n)
	var vel := PackedVector2Array(); vel.resize(n)
	var mood := PackedFloat32Array(); mood.resize(n)
	var pers := PackedFloat32Array(); pers.resize(n)
	var state := PackedInt32Array(); state.resize(n)
	var mem := PackedInt32Array(); mem.resize(n * 16)
	var memi := PackedInt32Array(); memi.resize(n)
	for i in n:
		pos[i] = Vector2(randf_range(-500, 500), randf_range(-500, 500))
		vel[i] = Vector2(randf_range(-1, 1), randf_range(-1, 1))
		pers[i] = randf()
		mood[i] = 0.5
	var grid := {}
	var active_sum := 0
	var mem_start := OS.get_static_memory_usage()
	var t0 := Time.get_ticks_usec()
	for t in TICKS:
		grid.clear()
		for i in n:
			var c := Vector2i(int(floor(pos[i].x / CELL)), int(floor(pos[i].y / CELL)))
			if not grid.has(c):
				grid[c] = []
			grid[c].append(i)
		for i in n:
			var d := pos[i].length()
			var lod := 0 if d < NEAR else (1 if d < MID else 2)
			if lod == 2 and (t + i) % 16 != 0:
				pos[i] += vel[i] * 0.5
				continue
			if lod == 1 and (t + i) % 4 != 0:
				pos[i] += vel[i]
				continue
			active_sum += 1
			var base := Vector2i(int(floor(pos[i].x / CELL)), int(floor(pos[i].y / CELL)))
			var seen := 0
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var c2 := base + Vector2i(dx, dy)
					if grid.has(c2):
						for j in grid[c2]:
							if j != i and pos[i].distance_squared_to(pos[j]) < SEE * SEE:
								seen += 1
								mem[i * 16 + (memi[i] % 16)] = j
								memi[i] += 1
			mood[i] = clampf(mood[i] + (0.02 * seen - 0.01) * (pers[i] - 0.5), 0.0, 1.0)
			state[i] = 1 if mood[i] > 0.7 else (2 if seen > 3 else 0)
			vel[i] = vel[i].rotated(randf_range(-0.1, 0.1))
			pos[i] += vel[i]
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / TICKS
	var mem_mb := (OS.get_static_memory_usage() - mem_start) / 1048576.0
	return {"ms": ms, "active": float(active_sum) / TICKS, "mem": mem_mb}
