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
}

const PROP_KINDS := [
	"barrel_metal", "barrel_rust", "tyre", "wooden_crate", "cement_bag",
	"ammo_box", "trash_bag", "security_light", "plastic_crate",
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
	},
	"plastic_crate": {
		"path": "res://assets/models/props/plastic_crate_02/model.gltf",
		"surface": "metal", "mass": 5.0, "height": 0.5,
		"shape": "box", "collision": [0.65, 0.5, 0.55],
	},
}

static var _textures: Dictionary = {}
static var _materials: Dictionary = {}
static var _scenes: Dictionary = {}


static func surface_material(surface: String) -> StandardMaterial3D:
	var key := surface.strip_edges().to_lower()
	if not SURFACE_TEXTURES.has(key):
		key = "concrete"
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D

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
	material.roughness = 1.0
	material.metallic = 1.0 if key == "metal" else 0.0

	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_triplanar_sharpness = 0.55
	var tile := float(paths.get("scale", 0.4))
	material.uv1_scale = Vector3(tile, tile, tile)

	_materials[key] = material
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
	environment.ambient_light_energy = 0.45 if not mobile else 0.38

	environment.fog_enabled = true
	environment.fog_light_color = Color(0.64, 0.49, 0.38)
	environment.fog_density = 0.006 if not mobile else 0.004
	environment.fog_sun_scatter = 0.18

	environment.glow_enabled = true
	environment.glow_intensity = 0.16 if mobile else 0.22
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.05

	environment.ssao_enabled = false
	environment.ssil_enabled = false
	environment.sdfgi_enabled = false
	environment.volumetric_fog_enabled = false
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
