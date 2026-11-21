extends SceneTree

const WeaponDbScript = preload("res://core/game/weapon_db.gd")
const ItemDbScript = preload("res://core/game/item_db.gd")
const ContentRegistryScript = preload("res://core/game/content_registry.gd")

var _failures: Array = []
var _checks := 0
var _case := ""

func _initialize() -> void:
	_case = "weapon_db.definiciones_minimas"
	var weapons := WeaponDbScript.all()
	_expect(weapons.size() >= 6, "al menos 6 armas en la base de datos")
	for id in ["pistol", "submachine_gun", "assault_rifle", "shotgun", "sniper_rifle", "bat"]:
		_expect(weapons.has(id), "arma presente: %s" % id)
		var def := WeaponDbScript.get_def(id)
		_expect(not def.is_empty(), "definicion no vacia para %s" % id)
		for key in ["id", "name", "damage", "fire_rate", "range", "mag", "tags"]:
			_expect(def.has(key), "campo %s en %s" % [key, id])
		_expect(str(def.get("id", "")) == id, "id coherente: %s" % id)

	_case = "weapon_db.diferenciacion_entre_armas"
	var shotgun := WeaponDbScript.get_def("shotgun")
	var pistol := WeaponDbScript.get_def("pistol")
	var sniper := WeaponDbScript.get_def("sniper_rifle")
	_expect(int(shotgun.get("pellets", 1)) >= 4, "escopeta tiene multiples pellets")
	_expect(float(sniper.get("damage", 0)) > float(pistol.get("damage", 0)), "francotirador mas danino que pistola")
	_expect(float(WeaponDbScript.get_def("bat").get("range", 999)) < 5.0, "arma cuerpo a cuerpo con alcance corto")
	_expect(WeaponDbScript.get_def("nonexistent").is_empty(), "arma desconocida devuelve vacio")

	_case = "weapon_db.list_ids_coherente"
	var ids := WeaponDbScript.list_ids()
	_expect(ids.size() >= 6, "al menos 6 ids listados")
	for id in ["pistol", "shotgun", "bat"]:
		_expect(ids.has(id), "id listado: %s" % id)

	_case = "weapon_db.registro_en_item_db"
	var item_db := ItemDbScript.new()
	WeaponDbScript.register_items(item_db)
	for id in WeaponDbScript.list_ids():
		_expect(bool(item_db.has(id)), "arma registrada como item: %s" % id)
		var item_def := item_db.get_def(id)
		var tags := item_def.get("tags", []) as Array
		_expect(bool(tags.has("weapon")), "tag weapon en item: %s" % id)
		_expect(not bool(item_def.get("apilable", true)), "arma no apilable: %s" % id)
	WeaponDbScript.register_items(null)
	_expect(true, "registro con item_db nulo no falla")

	_case = "weapon_db.integracion_con_content_registry"
	var registry := ContentRegistryScript.instance()
	for id in WeaponDbScript.list_ids():
		var reg_def := registry.definition("weapon", id)
		var db_def := WeaponDbScript.get_def(id)
		_expect(not reg_def.is_empty(), "registro tiene definicion para %s" % id)
		_expect(str(reg_def.get("id", "")) == str(db_def.get("id", "")), "id coincide entre registro y DB para %s" % id)

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for f in _failures:
			print("FAIL: " + f)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _expect(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures.append("[%s] %s" % [_case, msg])
