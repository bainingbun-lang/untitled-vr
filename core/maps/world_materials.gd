class_name WorldMaterials
extends RefCounted

const TEXTURE_DIR := "res://assets/textures/"
const SKY_PATH := "res://assets/hdri/qwantani_sunset_puresky_1k.exr"

const SURFACE_TEXTURES := {
	"ground": {
		"albedo": TEXTURE_DIR + "ground/ground_albedo.jpg",
		"normal": TEXTURE_DIR + "ground/ground_normal.jpg",
		"roughness": TEXTURE_DIR + "ground/ground_roughness.jpg",
		"scale": 0.32,
	},
	"asphalt": {
		"albedo": TEXTURE_DIR + "asphalt/asphalt_albedo.jpg",
		"normal": TEXTURE_DIR + "asphalt/asphalt_normal.jpg",
		"roughness": TEXTURE_DIR + "asphalt/asphalt_roughness.jpg",
		"scale": 0.28,
	},
	"concrete": {
		"albedo": TEXTURE_DIR + "concrete/concrete_albedo.jpg",
		"normal": TEXTURE_DIR + "concrete/concrete_normal.jpg",
		"roughness": TEXTURE_DIR + "concrete/concrete_roughness.jpg",
		"scale": 0.45,
	},
	"metal": {
		"albedo": TEXTURE_DIR + "metal/metal_albedo.jpg",
		"normal": TEXTURE_DIR + "metal/metal_normal.jpg",
		"roughness": TEXTURE_DIR + "metal/metal_roughness.jpg",
		"metalness": TEXTURE_DIR + "metal/metal_metalness.jpg",
		"scale": 0.55,
	},
	"wood": {
		"albedo": TEXTURE_DIR + "wood/wood_albedo.jpg",
		"normal": TEXTURE_DIR + "wood/wood_normal.jpg",
		"roughness": TEXTURE_DIR + "wood/wood_roughness.jpg",
		"scale": 0.40,
	},
	"brick": {
		"albedo": TEXTURE_DIR + "brick/brick_albedo.jpg",
		"normal": TEXTURE_DIR + "brick/brick_normal.jpg",
		"roughness": TEXTURE_DIR + "brick/brick_roughness.jpg",
		"scale": 0.38,
	},
	"glass": {
		"albedo": "",
		"normal": "",
		"roughness": "",
		"scale": 1.0,
	},
}

const PROP_KINDS := [
	"barrel_metal", "barrel_rust", "tyre", "wooden_crate", "cement_bag",
	"ammo_box", "trash_bag", "security_light", "plastic_crate",
	"street_light", "bench", "trash_can", "fence_section",
]

const PROPS := {
	"barrel_metal": {
		"path": "res://assets/models/props/barrel_01/model.gltf",
		"surface": "metal", "mass": 24.0, "height": 0.9,
		"shape": "cylinder", "collision": [0.58, 0.9, 0.58],
	},
	"barrel_rust": {
		"path": "res://assets/models/props/barrel_03/model.gltf",
		"surface": "metal", "mass": 22.0, "height": 0.9,
		"shape": "cylinder", "collision": [0.64, 0.9, 0.64],
	},
	"tyre": {
		"path": "res://assets/models/props/old_tyre/model.gltf",
		"surface": "concrete", "mass": 9.0, "height": 0.6,
		"shape": "cylinder", "collision": [0.6, 0.18, 0.6],
	},
	"wooden_crate": {
		"path": "res://assets/models/props/wooden_crate_02/model.gltf",
		"surface": "wood", "mass": 18.0, "height": 0.8,
		"shape": "box", "collision": [0.55, 0.8, 1.0],
	},
	"cement_bag": {
		"path": "res://assets/models/props/cement_bag/model.gltf",
		"surface": "dirt", "mass": 8.0, "height": 0.35,
		"shape": "box", "collision": [0.5, 0.35, 0.75],
	},
	"ammo_box": {
		"path": "res://assets/models/props/ammo_box/model.gltf",
		"surface": "metal", "mass": 7.0, "height": 0.36,
		"shape": "box", "collision": [0.4, 0.36, 0.55],
	},
	"trash_bag": {
		"path": "res://assets/models/props/trashbag/model.gltf",
		"surface": "dirt", "mass": 5.0, "height": 0.65,
		"shape": "box", "collision": [0.55, 0.65, 0.5],
	},
	"security_light": {
		"path": "res://assets/models/props/security_light/model.gltf",
		"surface": "metal", "mass": 6.0, "height": 1.4,
		"shape": "box", "collision": [0.45, 1.4, 0.45],
		"emissive": Color(1.0, 0.9, 0.7, 1.0),
		"light_range": 12.0,
		"light_energy": 2.5,
	},
	"plastic_crate": {
		"path": "res://assets/models/props/plastic_crate_02/model.gltf",
		"surface": "metal", "mass": 5.0, "height": 0.5,
		"shape": "box", "collision": [0.65, 0.5, 0.55],
	},
	"street_light": {
		"path": "res://assets/models/props/security_light/model.gltf",
		"surface": "metal", "mass": 0.0, "height": 6.0,
		"shape": "box", "collision": [0.3, 6.0, 0.3],
		"emissive": Color(1.0, 0.9, 0.7, 1.0),
		"light_range": 12.0,
		"light_energy": 2.5,
	},
	"bench": {
		"path": "res://assets/models/props/painted_wooden_bench/model.gltf",
		"surface": "wood", "mass": 0.0, "height": 0.9,
		"shape": "box", "collision": [1.5, 0.9, 0.5],
	},
	"trash_can": {
		"path": "res://assets/models/props/trashbag/model.gltf",
		"surface": "metal", "mass": 12.0, "height": 1.0,
		"shape": "cylinder", "collision": [0.4, 1.0, 0.4],
	},
	"fence_section": {
		"path": "res://assets/models/maps/nature/fence_simple.glb",
		"surface": "metal", "mass": 0.0, "height": 1.2,
		"shape": "box", "collision": [2.0, 1.2, 0.1],
	},
}

static var _textures: Dictionary = {}
static var _materials: Dictionary = {}
static var _scenes: Dictionary = {}
static var _mobile_materials: Dictionary = {}
static var _material_ref_counts: Dictionary = {}


static func surface_material(surface: String, mobile: bool = false) -> StandardMaterial3D:
	var key := surface.strip_edges().to_lower()
	if not SURFACE_TEXTURES.has(key):
		key = "concrete"
	
	var cache_key := key + (".mobile" if mobile else "")
	if _materials.has(cache_key):
		_material_ref_counts[cache_key] = _material_ref_counts.get(cache_key, 0) + 1
		return _materials[cache_key] as StandardMaterial3D

	var paths: Dictionary = SURFACE_TEXTURES[key]
	var material := StandardMaterial3D.new()
	var albedo := _texture(str(paths.get("albedo", "")))
	var normal := _texture(str(paths.get("normal", "")))
	var roughness := _texture(str(paths.get("roughness", "")))
	var metalness := _texture(str(paths.get("metalness", "")))
	if albedo != null:
		material.albedo_texture = albedo
	if normal != null:
		material.normal_texture = normal
	if roughness != null:
		material.roughness_texture = roughness
	if metalness != null:
		material.metallic_texture = metalness
	
	match key:
		"metal":
			material.roughness = 0.3
			material.metallic = 1.0
		"glass":
			material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color(0.2, 0.3, 0.5, 0.3)
			material.roughness = 0.05
			material.metallic = 0.9
			material.clearcoat = 1.0
			material.clearcoat_roughness = 0.05
			material.cull_mode = StandardMaterial3D.CULL_BACK
		"asphalt":
			material.roughness = 0.9
			material.metallic = 0.0
		"concrete":
			material.roughness = 0.8
			material.metallic = 0.0
		"brick":
			material.roughness = 0.85
			material.metallic = 0.0
		"wood":
			material.roughness = 0.6
			material.metallic = 0.0
		"ground":
			material.roughness = 0.95
			material.metallic = 0.0
		_:
			material.roughness = 0.7
			material.metallic = 0.0

	if mobile:
		material.uv1_triplanar = false
		material.uv1_world_triplanar = false
		material.render_priority = 1
		material.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
		material.flag_use_point_size = false
		material.flag_disable_ambient_light = true
		material.flag_disable_fog = true
	else:
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_triplanar_sharpness = 0.55
	
	var tile := float(paths.get("scale", 0.4))
	material.uv1_scale = Vector3(tile, tile, tile)

	_materials[cache_key] = material
	_material_ref_counts[cache_key] = 1
	return material


static func texture_for(surface: String, map_name: String) -> Texture2D:
	var paths: Dictionary = SURFACE_TEXTURES.get(
		surface.strip_edges().to_lower(), SURFACE_TEXTURES["concrete"]
	)
	return _texture(str(paths.get(map_name, "")))


static func sky_texture() -> Texture2D:
	return _texture(SKY_PATH)


static func make_environment(mobile: bool) -> Environment:
	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = sky_texture()
	sky.sky_material = panorama

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.5 if not mobile else 0.4
	environment.ambient_light_color = Color(0.15, 0.12, 0.1)

	environment.fog_enabled = true
	environment.fog_light_color = Color(0.55, 0.42, 0.32)
	environment.fog_density = 0.005 if not mobile else 0.0035
	environment.fog_sun_scatter = 0.2
	environment.fog_height = 0.0
	environment.fog_height_density = 0.02

	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.1
	environment.tonemap_white = 5.5
	environment.background_energy_multiplier = 0.85
	environment.glow_enabled = not mobile
	environment.glow_intensity = 0.12
	environment.glow_bloom = 0.035
	environment.glow_hdr_threshold = 1.0

	environment.ssao_enabled = not mobile
	environment.ssao_radius = 1.5
	environment.ssao_intensity = 0.6
	environment.ssil_enabled = not mobile
	environment.sdfgi_enabled = false
	environment.volumetric_fog_enabled = not mobile
	environment.volumetric_fog_emission = Color(0.05, 0.03, 0.01)
	environment.volumetric_fog_density = 0.02
	environment.volumetric_fog_albedo = Color(0.4, 0.3, 0.2)
	return environment


static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("vr")


static func prop_config(kind: String) -> Dictionary:
	var key := kind
	if not PROPS.has(key):
		key = str(PROP_KINDS[0])
	var result: Dictionary = (PROPS[key] as Dictionary).duplicate()
	result["kind"] = key
	return result


static func prop_scene(kind: String) -> PackedScene:
	var config := prop_config(kind)
	var path := str(config.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if _scenes.has(path):
		return _scenes[path] as PackedScene
	var scene := load(path) as PackedScene
	_scenes[path] = scene
	return scene


static func create_street_light(kind: String, position: Vector3, rotation: float = 0.0) -> Node3D:
	var config := prop_config(kind)
	var scene := prop_scene(kind)
	if scene == null:
		var root := Node3D.new()
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.9, 0.7)
		light.omni_range = float(config.get("light_range", 12.0))
		light.light_energy = float(config.get("light_energy", 2.5))
		light.light_shadow_enabled = false
		root.add_child(light)
		root.position = position
		root.rotation.y = rotation
		return root
	
	var instance := scene.instantiate() as Node3D
	instance.position = position
	instance.rotation.y = rotation
	
	var light := OmniLight3D.new()
	light.light_color = config.get("emissive", Color(1.0, 0.9, 0.7))
	light.omni_range = float(config.get("light_range", 12.0))
	light.light_energy = float(config.get("light_energy", 2.5))
	light.light_shadow_enabled = false
	instance.add_child(light)
	light.position = Vector3(0, 5.5, 0)
	
	return instance


static func prop_kind(index: int) -> String:
	if PROP_KINDS.is_empty():
		return ""
	var wrapped := wrapi(index, 0, PROP_KINDS.size())
	return str(PROP_KINDS[wrapped])


static func _texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if _textures.has(path):
		return _textures[path] as Texture2D
	var texture := load(path) as Texture2D
	_textures[path] = texture
	return texture


static func release_material(surface: String, mobile: bool = false) -> void:
	var cache_key := surface.strip_edges().to_lower() + (".mobile" if mobile else "")
	if _material_ref_counts.has(cache_key):
		_material_ref_counts[cache_key] -= 1
		if _material_ref_counts[cache_key] <= 0:
			_materials.erase(cache_key)
			_material_ref_counts.erase(cache_key)


static func get_material_stats() -> Dictionary:
	return {
		"material_count": _materials.size(),
		"texture_count": _textures.size(),
		"scene_count": _scenes.size(),
		"ref_counts": _material_ref_counts.duplicate(),
	}


static func clear_unused_materials() -> void:
	var to_erase: Array = []
	for key in _material_ref_counts.keys():
		if _material_ref_counts[key] <= 0:
			to_erase.append(key)
	for key in to_erase:
		_materials.erase(key)
		_material_ref_counts.erase(key)
