extends Node

# Spike M3: one process per case, selected with user args:
#   -- --case=A --pack=/abs/path/mod.pck

var _case := ""
var _pack := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--case="):
			_case = a.trim_prefix("--case=")
		elif a.begins_with("--pack="):
			_pack = a.trim_prefix("--pack=")

	match _case:
		"A":
			_case_a()
		"B":
			_case_b()
		"C":
			_case_c()
		"D":
			_case_d()
		"E":
			_case_e()
		"F_antes":
			_case_f_antes()
		"F_despues":
			_case_f_despues()
		"G":
			_case_g()
		"H":
			_case_h()
		_:
			print("M3 ", _case, "=CASO_DESCONOCIDO")

	get_tree().quit(0)


func _load_pack() -> bool:
	if _pack == "":
		return false
	return ProjectSettings.load_resource_pack(_pack, true)


func _case_a() -> void:
	var inst = load("res://core_demo.gd").new()
	print("M3 A=", inst.value())


func _case_b() -> void:
	var pre = load("res://core_demo.gd").new()
	var pre_value: String = pre.value()
	var ok := _load_pack()
	if not ok:
		print("M3 B=PACK_FALLO")
		return
	var post = load("res://core_demo.gd").new()
	print("M3 B=", post.value(), " (previa=", pre_value, ")")


func _case_c() -> void:
	var ok := _load_pack()
	if not ok:
		print("M3 C=PACK_FALLO")
		return
	var inst = load("res://core_demo.gd").new()
	print("M3 C=", inst.value())


func _case_d() -> void:
	var ok := _load_pack()
	if not ok:
		print("M3 D=PACK_FALLO")
		return
	var scr = ResourceLoader.load("res://core_demo.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	if scr == null:
		print("M3 D=LOAD_NULL")
		return
	print("M3 D=", scr.new().value())


func _case_e() -> void:
	var pre = load("res://core_demo.gd").new()
	var pre_value: String = pre.value()
	var ok := _load_pack()
	if not ok:
		print("M3 E=PACK_FALLO")
		return
	print("M3 E=", pre.value(), " (previa=", pre_value, ")")


func _case_f_antes() -> void:
	var before := _eval_core()
	var ok := _load_pack()
	if not ok:
		print("M3 F_antes=PACK_FALLO")
		return
	var after := _eval_core()
	print("M3 F_antes=", before, " -> ", after)


func _case_f_despues() -> void:
	var ok := _load_pack()
	if not ok:
		print("M3 F_despues=PACK_FALLO")
		return
	print("M3 F_despues=", _eval_core())


func _case_g() -> void:
	var auto := get_node_or_null("/root/AutoloadDemo")
	if auto == null:
		print("M3 G=SIN_AUTOLOAD")
		return
	var before: String = auto.value()
	var ok := _load_pack()
	if not ok:
		print("M3 G=PACK_FALLO")
		return
	var existing: String = auto.value()
	var fresh_scr = ResourceLoader.load("res://autoload_demo.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	var fresh := "LOAD_NULL"
	if fresh_scr != null:
		fresh = fresh_scr.new().value()
	print("M3 G=existente:", before, " -> ", existing, "; nueva_load=", fresh)


func _case_h() -> void:
	var t0 := Time.get_ticks_usec()
	var ok := _load_pack()
	var us := Time.get_ticks_usec() - t0
	if not ok:
		print("M3 H=PACK_FALLO")
		return
	print("M3 H=", "%.3f" % (float(us) / 1000.0), " ms")


func _eval_core() -> String:
	var gd := GDScript.new()
	gd.source_code = "func v() -> String:\n\treturn CoreDemo.new().value()\n"
	var err := gd.reload()
	if err != OK:
		return "RELOAD_ERR:" + str(err)
	var probe = gd.new()
	if probe == null:
		return "NEW_NULL"
	return str(probe.v())
