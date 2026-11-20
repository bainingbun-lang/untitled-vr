class_name VehicleDb
extends RefCounted

# Vehiculos: modelos reales (Kenney Car Kit, CC0) con ruedas separadas en el GLB.
const MODEL_DIR := "res://assets/models/vehicles/"

const VEHICLES: Dictionary = {
	"sedan": {
		"id": "sedan", "name": "Turismo", "kind": "turismo", "model": "sedan.glb",
		"mass": 1100.0, "max_speed": 38.0, "engine_force": 2600.0, "brake": 60.0, "health": 220.0,
	},
	"pickup": {
		"id": "pickup", "name": "Pickup", "kind": "pickup", "model": "truck.glb",
		"mass": 1700.0, "max_speed": 33.0, "engine_force": 3600.0, "brake": 70.0, "health": 320.0,
	},
	"sports": {
		"id": "sports", "name": "Deportivo", "kind": "deportivo", "model": "sedan-sports.glb",
		"mass": 1000.0, "max_speed": 55.0, "engine_force": 3600.0, "brake": 70.0, "health": 180.0,
	},
	"van": {
		"id": "van", "name": "Furgoneta", "kind": "furgoneta", "model": "delivery.glb",
		"mass": 2100.0, "max_speed": 28.0, "engine_force": 4200.0, "brake": 70.0, "health": 360.0,
	},
	"buggy": {
		"id": "buggy", "name": "Buggy", "kind": "buggy", "model": "kart-oobi.glb",
		"mass": 500.0, "max_speed": 30.0, "engine_force": 1500.0, "brake": 40.0, "health": 150.0,
	},
	"suv": {
		"id": "suv", "name": "Todoterreno", "kind": "suv", "model": "suv.glb",
		"mass": 1800.0, "max_speed": 34.0, "engine_force": 3800.0, "brake": 70.0, "health": 300.0,
	},
	"racer": {
		"id": "racer", "name": "Carreras", "kind": "carreras", "model": "race.glb",
		"mass": 800.0, "max_speed": 62.0, "engine_force": 3400.0, "brake": 70.0, "health": 140.0,
	},
}


static func all() -> Dictionary:
	var result: Dictionary = {}
	for id in VEHICLES.keys():
		var entry: Dictionary = (VEHICLES[id] as Dictionary).duplicate(true)
		entry["scene_builder"] = "glb"
		entry["model_path"] = MODEL_DIR + str(entry["model"])
		result[id] = entry
	return result


static func list_ids() -> Array:
	return VEHICLES.keys()


static func get_def(id: String) -> Dictionary:
	var entries := all()
	return (entries[id] as Dictionary) if entries.has(id) else {}
