class_name NPCLOD
extends RefCounted

const LOD_VISUAL_HIGH = 0
const LOD_VISUAL_MED = 1
const LOD_VISUAL_LOW = 2
const LOD_VISUAL_CULLED = 3

const LOD_ANIM_HIGH = 0
const LOD_ANIM_LOW = 1
const LOD_ANIM_DISABLED = 2

const LOD_AI_HIGH = 0
const LOD_AI_LOW = 1
const LOD_AI_SLEEP = 2

var last_update_time: float = 0.0
var current_visual_lod: int = LOD_VISUAL_HIGH
var current_anim_lod: int = LOD_ANIM_HIGH
var current_ai_lod: int = LOD_AI_HIGH
var last_distance: float = 0.0
var is_occluded: bool = false
var occlusion_check_time: float = 0.0
var occlusion_check_interval: float = 0.5

# Dynamic LOD bias from VR performance profile
var lod_bias: float = 1.0

func set_lod_bias(bias: float) -> void:
	lod_bias = clampf(bias, 0.5, 2.0)

func get_update_interval(distance: float) -> float:
	var biased_dist: float = distance * lod_bias
	if biased_dist < 10.0:
		return 0.0
	elif biased_dist < 25.0:
		return 0.5
	elif biased_dist < 50.0:
		return 1.0
	else:
		return 5.0

func get_visual_lod(distance: float, is_occluded: bool = false) -> int:
	var biased_dist: float = distance * lod_bias
	if is_occluded or biased_dist > 80.0:
		return LOD_VISUAL_CULLED
	elif biased_dist < 15.0:
		return LOD_VISUAL_HIGH
	elif biased_dist < 40.0:
		return LOD_VISUAL_MED
	else:
		return LOD_VISUAL_LOW

func get_anim_lod(distance: float) -> int:
	var biased_dist: float = distance * lod_bias
	if biased_dist < 20.0:
		return LOD_ANIM_HIGH
	elif biased_dist < 50.0:
		return LOD_ANIM_LOW
	else:
		return LOD_ANIM_DISABLED

func get_ai_lod(distance: float) -> int:
	var biased_dist: float = distance * lod_bias
	if biased_dist < 25.0:
		return LOD_AI_HIGH
	elif biased_dist < 60.0:
		return LOD_AI_LOW
	else:
		return LOD_AI_SLEEP

func should_update(current_time: float, distance: float) -> bool:
	var interval = get_update_interval(distance)
	if interval == 0.0:
		return true
	return (current_time - last_update_time) >= interval

func update_lods(current_time: float, distance: float, camera_frustum: Camera3D = null) -> Dictionary:
	last_distance = distance
	
	var new_visual_lod := get_visual_lod(distance, is_occluded)
	var new_anim_lod := get_anim_lod(distance)
	var new_ai_lod := get_ai_lod(distance)
	
	var visual_changed := new_visual_lod != current_visual_lod
	var anim_changed := new_anim_lod != current_anim_lod
	var ai_changed := new_ai_lod != current_ai_lod
	
	current_visual_lod = new_visual_lod
	current_anim_lod = new_anim_lod
	current_ai_lod = new_ai_lod
	
	last_update_time = current_time
	
	return {
		"visual_lod": current_visual_lod,
		"anim_lod": current_anim_lod,
		"ai_lod": current_ai_lod,
		"visual_changed": visual_changed,
		"anim_changed": anim_changed,
		"ai_changed": ai_changed,
		"distance": distance,
		"is_occluded": is_occluded,
	}

func check_occlusion(current_time: float, camera: Camera3D, global_position: Vector3, radius: float = 1.0) -> bool:
	if camera == null:
		return false
	if (current_time - occlusion_check_time) < occlusion_check_interval:
		return is_occluded
	
	occlusion_check_time = current_time
	
	var frustum: Array[Plane] = []
	if camera.has_method("get_frustum"):
		frustum = camera.get_frustum()
	
	var transform := camera.global_transform
	var local_pos := transform.affine_inverse() * global_position
	
	for plane in frustum:
		if plane.distance_to(local_pos) < -radius:
			is_occluded = true
			return true
	
	is_occluded = false
	return false

func mark_updated(current_time: float) -> void:
	last_update_time = current_time

func get_lod_state() -> Dictionary:
	return {
		"visual_lod": current_visual_lod,
		"anim_lod": current_anim_lod,
		"ai_lod": current_ai_lod,
		"last_distance": last_distance,
		"is_occluded": is_occluded,
	}

func apply_visual_lod(mesh_instance: MeshInstance3D, multimesh: MultiMesh = null) -> void:
	if mesh_instance == null:
		return
	match current_visual_lod:
		LOD_VISUAL_HIGH:
			mesh_instance.visible = true
			if multimesh != null:
				multimesh.visible_instance_count = multimesh.instance_count
		LOD_VISUAL_MED:
			mesh_instance.visible = true
			if multimesh != null:
				multimesh.visible_instance_count = maxi(1, multimesh.instance_count / 2)
		LOD_VISUAL_LOW:
			mesh_instance.visible = true
			if multimesh != null:
				multimesh.visible_instance_count = maxi(1, multimesh.instance_count / 4)
		LOD_VISUAL_CULLED:
			mesh_instance.visible = false
			if multimesh != null:
				multimesh.visible_instance_count = 0

func apply_anim_lod(animation_player: AnimationPlayer, animation_tree: AnimationTree = null) -> void:
	if animation_player == null:
		return
	match current_anim_lod:
		LOD_ANIM_HIGH:
			animation_player.process_mode = 0
		LOD_ANIM_LOW:
			animation_player.process_mode = 1
		LOD_ANIM_DISABLED:
			animation_player.stop(true)

func apply_ai_lod(ai_script: RefCounted) -> void:
	if ai_script == null or not ai_script.has_method("set_lod_level"):
		return
	ai_script.call("set_lod_level", current_ai_lod)