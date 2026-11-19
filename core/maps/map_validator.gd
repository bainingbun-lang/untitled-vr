class_name MapValidator
extends RefCounted

enum Status {
	COMPATIBLE,
	COMPATIBLE_WITH_WARNINGS,
	REQUIRES_ADAPTATION,
	INCOMPATIBLE
}

const ALLOWED_PLATFORMS: Array = ["android", "pc", "vr"]

func validate(data: Dictionary) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var status: int = Status.COMPATIBLE

	# Mandatory: Unique ID
	if not data.has("id") or data["id"] == "":
		errors.append("Missing mandatory unique identifier (id)")
		status = Status.INCOMPATIBLE

	# Mandatory: License
	if not data.has("license") or data["license"] == "":
		errors.append("Missing mandatory license")
		status = Status.INCOMPATIBLE
	elif not _is_license_valid(data["license"]):
		warnings.append("Unknown license: " + str(data["license"]))
		if status == Status.COMPATIBLE:
			status = Status.COMPATIBLE_WITH_WARNINGS

	# Mandatory: Spawn Points
	if not data.has("spawn_points") or data["spawn_points"].size() == 0:
		errors.append("At least one spawn point is required")
		if status < Status.REQUIRES_ADAPTATION:
			status = Status.REQUIRES_ADAPTATION

	# Mandatory: Navigation
	if not data.has("has_navigation") or data["has_navigation"] == false:
		errors.append("Navigation mesh is missing or disabled")
		if status < Status.REQUIRES_ADAPTATION:
			status = Status.REQUIRES_ADAPTATION

	# Mandatory: Collisions
	if not data.has("has_collisions") or data["has_collisions"] == false:
		errors.append("Collision shapes are missing")
		if status < Status.REQUIRES_ADAPTATION:
			status = Status.REQUIRES_ADAPTATION

	# Optional (A6): platforms, tags and player-count bounds.
	var platforms_valid := _validate_platforms(data, errors)
	var tags_valid := _validate_tags(data, errors)
	var players_valid := _validate_players(data, errors)
	if not (platforms_valid and tags_valid and players_valid):
		if status < Status.REQUIRES_ADAPTATION:
			status = Status.REQUIRES_ADAPTATION

	return {
		"status": status,
		"errors": errors,
		"warnings": warnings
	}

func _validate_platforms(data: Dictionary, errors: Array) -> bool:
	if not data.has("platforms") or data["platforms"] == null:
		return true
	var value = data["platforms"]
	if not (value is Array):
		errors.append("'platforms' debe ser una lista de android/pc/vr")
		return false
	var valid := true
	for item in value:
		if not (item is String) or not ALLOWED_PLATFORMS.has(str(item).strip_edges().to_lower()):
			errors.append("'platforms' contiene una plataforma no valida: '%s'" % str(item))
			valid = false
	return valid

func _validate_tags(data: Dictionary, errors: Array) -> bool:
	if not data.has("tags") or data["tags"] == null:
		return true
	var value = data["tags"]
	if not (value is Array):
		errors.append("'tags' debe ser una lista de strings")
		return false
	var valid := true
	for item in value:
		if not (item is String):
			errors.append("'tags' contiene un valor no string: '%s'" % str(item))
			valid = false
	return valid

func _validate_players(data: Dictionary, errors: Array) -> bool:
	var has_min := data.has("players_min") and data["players_min"] != null
	var has_max := data.has("players_max") and data["players_max"] != null
	if not has_min and not has_max:
		return true

	var valid := true
	var min_value: int = -1
	var max_value: int = -1
	if has_min:
		if not _is_integer_value(data["players_min"]):
			errors.append("'players_min' debe ser un entero >= 1")
			valid = false
		else:
			min_value = int(data["players_min"])
			if min_value < 1:
				errors.append("'players_min' debe ser >= 1")
				valid = false
	if has_max:
		if not _is_integer_value(data["players_max"]):
			errors.append("'players_max' debe ser un entero >= 1")
			valid = false
		else:
			max_value = int(data["players_max"])
			if max_value < 1:
				errors.append("'players_max' debe ser >= 1")
				valid = false
	if has_min and has_max and min_value >= 1 and max_value >= 1 and min_value > max_value:
		errors.append("'players_min' no puede superar 'players_max' (%d > %d)" % [min_value, max_value])
		valid = false
	return valid

func _is_integer_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			var number: float = value
			return floor(number) == number
		_:
			return false

func _is_license_valid(license: String) -> bool:
	var valid_licenses: Array = ["MIT", "Apache-2.0", "GPL-3.0", "Project-Standard"]
	return license in valid_licenses
