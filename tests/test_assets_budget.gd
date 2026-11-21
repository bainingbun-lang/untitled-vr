extends SceneTree

const ASSET_BUDGETS = {
	"total_mb": 85,
	"categories": {
		"characters_mb": 35,
		"weapons_mb": 6,
		"maps_mb": 25,
		"props_mb": 8,
		"vehicles_mb": 3,
		"hands_mb": 5,
		"textures_mb": 6,
		"hdri_mb": 6,
		"audio_mb": 5,
	}
}

var _failures: Array = []

func _dir_size_mb(path: String) -> float:
	var dir = DirAccess.open(path)
	if not dir:
		return 0.0
	var total_bytes = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var file_path = path.path_join(file_name)
		if dir.current_is_dir():
			total_bytes += _dir_size_mb(file_path) * 1024 * 1024
		else:
			total_bytes += FileAccess.get_file_as_bytes(file_path).size()
		file_name = dir.get_next()
	dir.list_dir_end()
	return total_bytes / (1024.0 * 1024.0)

func _assert(condition: bool, msg: String):
	if not condition:
		_failures.append(msg)
		print("FAIL: " + msg)
	else:
		print("PASS: " + msg)

func _collect_import_files(dir: DirAccess, result: Array):
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var file_path = dir.get_current_dir().path_join(file_name)
		if dir.current_is_dir():
			var subdir = DirAccess.open(file_path)
			if subdir:
				_collect_import_files(subdir, result)
		elif file_name.ends_with(".import"):
			result.append(file_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _init():
	print("=== Asset Budget Tests ===")
	
	var total_mb = _dir_size_mb("res://assets")
	_assert(total_mb <= ASSET_BUDGETS["total_mb"], 
		"Total assets size %.1f MB within budget %.1f MB" % [total_mb, ASSET_BUDGETS["total_mb"]])

	var mb = _dir_size_mb("res://assets/models/characters")
	_assert(mb <= ASSET_BUDGETS["categories"]["characters_mb"],
		"Characters %.1f MB within budget %.1f MB" % [mb, ASSET_BUDGETS["categories"]["characters_mb"]])

	mb = _dir_size_mb("res://assets/models/weapons")
	_assert(mb <= ASSET_BUDGETS["categories"]["weapons_mb"],
		"Weapons %.1f MB within budget %.1f MB" % [mb, ASSET_BUDGETS["categories"]["weapons_mb"]])

	mb = _dir_size_mb("res://assets/models/maps")
	_assert(mb <= ASSET_BUDGETS["categories"]["maps_mb"],
		"Maps %.1f MB within budget %.1f MB" % [mb, ASSET_BUDGETS["categories"]["maps_mb"]])

	mb = _dir_size_mb("res://assets/models/props")
	_assert(mb <= ASSET_BUDGETS["categories"]["props_mb"],
		"Props %.1f MB within budget %.1f MB" % [mb, ASSET_BUDGETS["categories"]["props_mb"]])

	mb = _dir_size_mb("res://assets/models/vehicles")
	_assert(mb <= ASSET_BUDGETS["categories"]["vehicles_mb"],
		"Vehicles %.1f MB within budget %.1f MB" % [mb, ASSET_BUDGETS["categories"]["vehicles_mb"]])

	mb = _dir_size_mb("res://assets/models/hands")
	_assert(mb <= ASSET_BUDGETS["categories"]["hands_mb"],
		"Hands %.1f MB within budget %.1f MB" % [mb, ASSET_BUDGETS["categories"]["hands_mb"]])

	mb = _dir_size_mb("res://assets/textures")
	_assert(mb <= ASSET_BUDGETS["categories"]["textures_mb"],
		"Textures %.1f MB within budget %.1f MB" % [mb, ASSET_BUDGETS["categories"]["textures_mb"]])

	mb = _dir_size_mb("res://assets/hdri")
	_assert(mb <= ASSET_BUDGETS["categories"]["hdri_mb"],
		"HDRI %.1f MB within budget %.1f MB" % [mb, ASSET_BUDGETS["categories"]["hdri_mb"]])

	mb = _dir_size_mb("res://assets/audio")
	_assert(mb <= ASSET_BUDGETS["categories"]["audio_mb"],
		"Audio %.1f MB within budget %.1f MB" % [mb, ASSET_BUDGETS["categories"]["audio_mb"]])

	var used_props = [
		"barrel_01", "barrel_03", "old_tyre", "wooden_crate_02",
		"cement_bag", "ammo_box", "trashbag", "security_light",
		"plastic_crate_02", "painted_wooden_bench"
	]
	var props_dir = DirAccess.open("res://assets/models/props")
	_assert(props_dir != null, "Props directory found")
	props_dir.list_dir_begin()
	var file_name = props_dir.get_next()
	while file_name != "":
		if props_dir.current_is_dir() and file_name not in used_props:
			_assert(false, "Unused prop folder found: %s" % file_name)
		file_name = props_dir.get_next()
	props_dir.list_dir_end()

	var import_files = []
	var assets_dir = DirAccess.open("res://assets")
	_collect_import_files(assets_dir, import_files)
	
	for import_path in import_files:
		var file = FileAccess.open(import_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			if 'importer="texture"' in content:
				_assert("size_limit=1024" in content,
					"Texture import has size_limit=1024: %s" % import_path)

	var preset_file = FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	_assert(preset_file != null, "export_presets.cfg found")
	var content = preset_file.get_as_text()
	preset_file.close()
	
	_assert("texture_format/etc2_astc=true" in content,
		"Quest VR preset has texture_format/etc2_astc=true for ASTC compression")
	_assert("quest_3_support=true" in content,
		"Quest VR preset targets Quest 3")

	print("=== Summary ===")
	if _failures.size() == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("FAILURES: %d" % _failures.size())
		for f in _failures:
			print("  - " + f)
		quit(1)