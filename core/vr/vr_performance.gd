class_name VrPerformance
extends Node

const MODE_72 := "quest_72"
const MODE_90 := "quest_90"

const DEFAULT_PROFILES := {
	MODE_72: {
		"mode": MODE_72,
		"refresh_hz": 72.0,
		"frame_budget_ms": 13.888,
		"msaa": 2,
		"foveation": 1,
		"render_scale": 1.0,
		"shadow_distance": 18.0,
		"particles": 120,
		"npcs": 12,
		"decals": 48,
		"culling_distance": 80.0,
		"lod_bias": 1.0,
		"max_draw_calls": 120,
		"max_triangles": 150000,
	},
	MODE_90: {
		"mode": MODE_90,
		"refresh_hz": 90.0,
		"frame_budget_ms": 11.111,
		"msaa": 2,
		"foveation": 1,
		"render_scale": 1.0,
		"shadow_distance": 16.0,
		"particles": 96,
		"npcs": 10,
		"decals": 40,
		"culling_distance": 70.0,
		"lod_bias": 1.2,
		"max_draw_calls": 100,
		"max_triangles": 120000,
	},
}

const MIN_SETTINGS := {
	"msaa": 0,
	"foveation": 0,
	"render_scale": 0.7,
	"shadow_distance": 6.0,
	"particles": 24,
	"npcs": 4,
	"decals": 8,
	"culling_distance": 40.0,
	"lod_bias": 2.0,
	"max_draw_calls": 50,
	"max_triangles": 50000,
}

const MAX_SETTINGS := {
	"msaa": 4,
	"foveation": 4,
	"render_scale": 1.0,
	"shadow_distance": 24.0,
	"particles": 160,
	"npcs": 16,
	"decals": 64,
	"culling_distance": 100.0,
	"lod_bias": 0.8,
	"max_draw_calls": 200,
	"max_triangles": 200000,
}

var target_mode: String = MODE_72
var profile: Dictionary = {}
var degrade_level: int = 0
var max_degrade_level: int = 4
var below_budget_frames: int = 0
var above_budget_frames: int = 0
var downshift_frames: int = 8
var upshift_frames: int = 24
var downshift_margin_ms: float = 1.0
var upshift_margin_ms: float = 1.5
var xr_available: bool = false
var _built: bool = false

var culling_camera: Camera3D = null
var frustum_planes: Array[Plane] = []
var last_frustum_update: float = 0.0
var frustum_update_interval: float = 0.1
var occlusion_queries: Dictionary = {}
var draw_call_count: int = 0
var triangle_count: int = 0
var last_gpu_time: float = 0.0


func _init(mode: String = MODE_72) -> void:
	set_target_mode(mode)


func build() -> bool:
	_built = true
	xr_available = detect_openxr_available()
	return true


func is_built() -> bool:
	return _built


func set_target_mode(mode: String) -> void:
	if not DEFAULT_PROFILES.has(mode):
		mode = MODE_72
	target_mode = mode
	profile = profile_for_mode(mode, degrade_level)
	below_budget_frames = 0
	above_budget_frames = 0


func current_profile() -> Dictionary:
	return profile.duplicate(true)


func observe_frame(frame_ms: float, delta_s: float = -1.0) -> Dictionary:
	var budget: float = float(profile.get("frame_budget_ms", profile_for_mode(target_mode, 0).get("frame_budget_ms", 13.888)))
	var sample_ms: float = frame_ms
	if sample_ms <= 0.0 and delta_s > 0.0:
		sample_ms = delta_s * 1000.0
	var over_limit: bool = sample_ms > budget + downshift_margin_ms
	var under_limit: bool = sample_ms < budget - upshift_margin_ms
	var changed := false
	if over_limit:
		below_budget_frames += 1
		above_budget_frames = 0
	elif under_limit:
		above_budget_frames += 1
		below_budget_frames = 0
	else:
		below_budget_frames = 0
		above_budget_frames = 0

	if below_budget_frames >= downshift_frames and degrade_level < max_degrade_level:
		degrade_level += 1
		below_budget_frames = 0
		changed = true
	elif above_budget_frames >= upshift_frames and degrade_level > 0:
		degrade_level -= 1
		above_budget_frames = 0
		changed = true

	if changed:
		profile = profile_for_mode(target_mode, degrade_level)

	return {
		"mode": target_mode,
		"degrade_level": degrade_level,
		"changed": changed,
		"frame_ms": sample_ms,
		"budget_ms": budget,
		"profile": profile.duplicate(true),
		"below_72fps": is_below_72fps(sample_ms),
	}


static func profile_for_mode(mode: String, level: int = 0) -> Dictionary:
	var base_mode := mode if DEFAULT_PROFILES.has(mode) else MODE_72
	var base: Dictionary = (DEFAULT_PROFILES[base_mode] as Dictionary).duplicate(true)
	return apply_degrade_level(base, level)


static func apply_degrade_level(base: Dictionary, level: int) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	var steps := clampi(level, 0, 8)
	for i in range(steps):
		out["render_scale"] = maxf(float(out.get("render_scale", 1.0)) - 0.08, float(MIN_SETTINGS["render_scale"]))
		out["shadow_distance"] = maxf(float(out.get("shadow_distance", 12.0)) - 3.0, float(MIN_SETTINGS["shadow_distance"]))
		out["particles"] = maxi(int(round(float(out.get("particles", 64)) * 0.72)), int(MIN_SETTINGS["particles"]))
		out["npcs"] = maxi(int(out.get("npcs", 8)) - 2, int(MIN_SETTINGS["npcs"]))
		out["decals"] = maxi(int(round(float(out.get("decals", 32)) * 0.7)), int(MIN_SETTINGS["decals"]))
		if i >= 1:
			out["msaa"] = maxi(int(out.get("msaa", 2)) - 2, int(MIN_SETTINGS["msaa"]))
		if i >= 2:
			out["foveation"] = mini(int(out.get("foveation", 1)) + 1, int(MAX_SETTINGS["foveation"]))
	out["render_scale"] = clampf(float(out.get("render_scale", 1.0)), float(MIN_SETTINGS["render_scale"]), float(MAX_SETTINGS["render_scale"]))
	out["shadow_distance"] = clampf(float(out.get("shadow_distance", 12.0)), float(MIN_SETTINGS["shadow_distance"]), float(MAX_SETTINGS["shadow_distance"]))
	out["particles"] = clampi(int(out.get("particles", 64)), int(MIN_SETTINGS["particles"]), int(MAX_SETTINGS["particles"]))
	out["npcs"] = clampi(int(out.get("npcs", 8)), int(MIN_SETTINGS["npcs"]), int(MAX_SETTINGS["npcs"]))
	out["decals"] = clampi(int(out.get("decals", 32)), int(MIN_SETTINGS["decals"]), int(MAX_SETTINGS["decals"]))
	out["msaa"] = clampi(int(out.get("msaa", 2)), int(MIN_SETTINGS["msaa"]), int(MAX_SETTINGS["msaa"]))
	out["foveation"] = clampi(int(out.get("foveation", 1)), int(MIN_SETTINGS["foveation"]), int(MAX_SETTINGS["foveation"]))
	out["degrade_level"] = steps
	return out


static func is_below_72fps(frame_ms: float) -> bool:
	return frame_ms > 13.888


static func detect_openxr_available() -> bool:
	if not ClassDB.class_exists("XRServer"):
		return false
	if not ClassDB.class_exists("OpenXRInterface"):
		return false
	var iface = XRServer.find_interface("OpenXR")
	if iface == null:
		return false
	if iface.has_method("is_initialized"):
		return bool(iface.call("is_initialized"))
	return true


func set_culling_camera(camera: Camera3D) -> void:
	culling_camera = camera
	update_frustum()


func update_frustum() -> void:
	if culling_camera == null:
		return
	var current_time := Time.get_ticks_msec() / 1000.0
	if (current_time - last_frustum_update) < frustum_update_interval:
		return
	last_frustum_update = current_time
	if culling_camera.has_method("get_frustum"):
		frustum_planes = culling_camera.get_frustum()
	else:
		frustum_planes = []
	
	# Pre-compute plane distances for faster culling checks
	# We'll store plane normal and distance for quick dot product checks


func is_visible(aabb: AABB) -> bool:
	if frustum_planes.is_empty():
		return true
	for plane in frustum_planes:
		if plane.distance_to(aabb.position) + plane.normal.dot(aabb.size.abs()) < 0.0:
			return false
	return true


func is_visible_fast(min_pos: Vector3, max_pos: Vector3) -> bool:
	if frustum_planes.is_empty():
		return true
	var center: Vector3 = (min_pos + max_pos) * 0.5
	var half_size: Vector3 = (max_pos - min_pos).abs() * 0.5
	for plane in frustum_planes:
		if plane.distance_to(center) + plane.normal.dot(half_size) < 0.0:
			return false
	return true


func cull_multi_mesh_instances(node: MultiMeshInstance3D, camera_pos: Vector3) -> int:
	var multimesh: MultiMesh = node.multimesh
	if multimesh == null:
		return 0
	var cull_dist: float = node.get_meta("cull_distance", get_culling_distance())
	var cull_aabb: AABB = node.get_meta("cull_aabb", AABB())
	
	if not is_visible_fast(cull_aabb.position, cull_aabb.end):
		node.visible_instance_count = 0
		return 0
	
	var dist_sq: float = camera_pos.distance_squared_to(cull_aabb.get_center())
	if dist_sq > cull_dist * cull_dist:
		node.visible_instance_count = 0
		return 0
	
	return multimesh.instance_count


func is_visible_sphere(position: Vector3, radius: float) -> bool:
	if frustum_planes.is_empty():
		return true
	for plane in frustum_planes:
		if plane.distance_to(position) < -radius:
			return false
	return true


func get_culling_distance() -> float:
	return float(profile.get("culling_distance", 80.0))


func get_lod_bias() -> float:
	return float(profile.get("lod_bias", 1.0))


func get_max_draw_calls() -> int:
	return int(profile.get("max_draw_calls", 120))


func get_max_triangles() -> int:
	return int(profile.get("max_triangles", 150000))


func record_frame_stats(draw_calls: int, triangles: int, gpu_time_ms: float) -> void:
	draw_call_count = draw_calls
	triangle_count = triangles
	last_gpu_time = gpu_time_ms


func get_frame_stats() -> Dictionary:
	return {
		"draw_calls": draw_call_count,
		"triangles": triangle_count,
		"gpu_time_ms": last_gpu_time,
		"budget_draw_calls": get_max_draw_calls(),
		"budget_triangles": get_max_triangles(),
		"over_budget_draw_calls": draw_call_count > get_max_draw_calls(),
		"over_budget_triangles": triangle_count > get_max_triangles(),
	}


func apply_profile_to_rendering() -> void:
	if not xr_available:
		return
	var iface = XRServer.find_interface("OpenXR")
	if iface == null:
		return
	
	iface.set_render_target_size_multiplier(float(profile.get("render_scale", 1.0)))
	
	if iface.has_method("set_foveation_level"):
		iface.call("set_foveation_level", int(profile.get("foveation", 1)))
	
	if iface.has_method("set_msaa"):
		iface.call("set_msaa", int(profile.get("msaa", 2)))
	
	# Shadow atlas quadrant subdivision not available in Godot 4.7 headless
	# if RenderingServer.has_method("shadow_atlas_set_quadrant_subdivision"):
	# 	RenderingServer.shadow_atlas_set_quadrant_subdivision(0, int(profile.get("shadow_distance", 18.0)) / 4.0)


func _apply_profile_recursive(node: Node3D, cull_dist: float) -> void:
	if node is MultiMeshInstance3D:
		node.visibility_range_end = cull_dist
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	elif node is MeshInstance3D:
		node.visibility_range_end = cull_dist
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	
	for child in node.get_children():
		if child is Node3D:
			_apply_profile_recursive(child, cull_dist)

func apply_profile_to_scene(root: Node3D) -> void:
	var cull_dist := get_culling_distance()
	var lod_bias := get_lod_bias()
	
	_apply_profile_recursive(root, cull_dist)

func update_visibility_per_frame(root: Node3D, camera_pos: Vector3) -> int:
	var visible_count: int = 0
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MultiMeshInstance3D:
			var count: int = cull_multi_mesh_instances(node, camera_pos)
			visible_count += count
		for child in node.get_children():
			if child is Node3D:
				stack.append(child)
	return visible_count
