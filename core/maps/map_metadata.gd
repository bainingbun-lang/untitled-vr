class_name MapMetadata
extends RefCounted

# Schema with default values for map metadata
var metadata: Dictionary = {
	"id": "",
	"version": "1.0.0",
	"author": "Unknown",
	"license": "",
	"scale": 1.0,
	"has_collisions": false,
	"has_navigation": false,
	"spawn_points": [],
	"forbidden_zones": [],
	"performance_profiles": {},
	"zones": [],
	"platforms": [],
	"tags": [],
	"players_min": 1,
	"players_max": 1
}

func _init(data: Dictionary = {}):
	for key in metadata.keys():
		if data.has(key):
			metadata[key] = data[key]

func get_value(key: String) -> Variant:
	return metadata.get(key, null)

func set_value(key: String, value: Variant) -> void:
	metadata[key] = value
