extends SceneTree

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const SessionScript = preload("res://core/game/game_session.gd")
const VrGameModeScript = preload("res://core/vr/vr_game_mode.gd")
const DbScript = preload("res://core/game/weapon_db.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _initialize() -> void:
	await process_frame
	await _test_platform_and_build()
	await _test_world_vr()
	await _test_start_menu()
	await _test_pc_world()
	_reset_state()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_platform_and_build() -> void:
	_case = "deteccion y construccion de modo"
	VrGameModeScript.xr_available_override = Callable()
	_expect(not VrGameModeScript.xr_available(), "sin OpenXR no se activa el modo VR")
	VrGameModeScript.xr_available_override = func() -> bool: return true
	_expect(VrGameModeScript.xr_available(), "la sonda XR fuerza disponibilidad para tests")

	var host := Node3D.new()
	host.name = "VrModeHost"
	root.add_child(host)
	await process_frame
	var player := VrGameModeScript.build(host, false)
	_expect(player != null and player.name == "Player", "sin VR se instancia Player")
	_expect(player != null and player.has_method("weapon_ids"), "Player conserva su interfaz")
	var rig := VrGameModeScript.build(host, true)
	_expect(rig != null and rig.has_method("is_active") and bool(rig.call("is_active")), "con VR se instancia VrRig activo")
	_expect(rig != null and not bool(rig.get("auto_process")), "VrRig no se autocorrige fuera del modo")
	host.free()
	await process_frame


func _test_world_vr() -> void:
	_case = "GameWorld en VR"
	SessionScript.platform_override = "vr"
	SessionScript.platform = "vr"
	SessionScript.vr_menu_confirmed = true
	VrGameModeScript.xr_available_override = func() -> bool: return true
	var meta: Dictionary = GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.18, "spawn_count": 4,
	})
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	world.setup(meta)
	await process_frame

	_expect(world.vr_active, "GameWorld marca modo VR activo")
	var rig = world.actor
	_expect(rig != null and rig.has_method("is_active") and bool(rig.call("is_active")), "el actor es VrRig activo")
	_expect(world.hud == null and world.hotbar == null and world.pause_menu == null, "no se crean HUD/hotbar/menus 2D en VR")
	_expect(world.vr_result.has("state") and world.vr_result.has("weapon_system"), "VrGameMode entrega estado y armas")
	var state = world.vr_state
	var hud = world.vr_result.get("hud", null)
	var menu = world.vr_result.get("menu", null)
	var ws = world.vr_result.get("weapon_system", null)
	_expect(state != null and hud != null and menu != null and ws != null, "HUD, menu, estado y WeaponSystem creados")
	_expect(rig.bag.items().size() == DbScript.list_ids().size(), "el bolso contiene todas las armas")
	_expect(rig.left_hand != null and rig.right_hand != null, "dos manos de arma conectadas")
	_expect(rig.right_hand.weapon_system == ws, "la mano derecha usa el WeaponSystem del modo")
	_expect(hud.weapon_ammo_label != null and hud.health_label != null, "contadores 3D del HUD construidos")
	_expect(menu.get_parent() == world and menu.buttons.size() == 4, "menu de pausa VR con cuatro botones")
	_expect(world.target_dummies().size() > 0 and world.target_dummies().size() <= 6, "dianas limitadas por el perfil VR")

	rig.bag.open(rig.bag.bag_center())
	_expect(rig.right_hand.try_take("pistol"), "se puede sacar una pistola del bolso")
	_expect(rig.right_hand.viewmodel != null and bool(rig.right_hand.viewmodel.call("has_model")),
		"el viewmodel 3D se crea en la mano VR")
	state.call("refresh_hud")
	_expect(hud.weapon_ammo_label.text.find("12/12") >= 0, "el HUD 3D muestra la municion del arma en mano")

	state.call("toggle_menu")
	_expect(bool(menu.is_open), "el boton de menu abre VrMenu")
	_expect(bool(rig.get("inputs_suspended")), "abrir menu suspende los controles del rig")
	menu.call("close_menu")
	_expect(not bool(rig.get("inputs_suspended")), "cerrar menu restaura los controles")
	state.call("tick", 0.016)
	_expect(true, "el tick del modo VR corre sin errores")
	world.free()
	await process_frame


func _test_start_menu() -> void:
	_case = "menu de inicio VR"
	SessionScript.platform_override = "vr"
	SessionScript.platform = "vr"
	SessionScript.vr_menu_confirmed = false
	SessionScript.start_override = Callable()
	VrGameModeScript.xr_available_override = func() -> bool: return true
	var meta: Dictionary = {"seed": 4242, "ok": true}
	var error: int = SessionScript.start(meta, self)
	_expect(error == OK, "GameSession.start en VR devuelve OK")
	var host = root.get_node_or_null("VrStartMenu")
	_expect(host != null, "se crea el panel de inicio 3D")
	var menu = host.get_node_or_null("VrStartMenuPanel") if host != null else null
	_expect(menu != null and menu.buttons.size() == 2, "menu 3D de inicio con dos opciones")
	_expect(SessionScript.vr_menu_confirmed, "el menu de inicio queda marcado como confirmado")
	if host != null:
		host.free()
	VrGameModeScript.last_start_menu = null
	await process_frame


func _test_pc_world() -> void:
	_case = "modo pantalla intacto"
	_reset_state()
	var meta: Dictionary = GeneratorScript.generate(4242, {
		"width": 24, "height": 18, "obstacle_density": 0.18, "spawn_count": 4,
	})
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	world.setup(meta)
	await process_frame
	_expect(not world.vr_active, "sin plataforma VR el mundo no activa el modo VR")
	_expect(world.actor != null and world.actor.has_method("weapon_ids"), "sin VR se mantiene Player")
	_expect(world.hud != null and world.hotbar != null, "sin VR se mantienen HUD y hotbar 2D")
	world.free()
	await process_frame


func _reset_state() -> void:
	SessionScript.platform_override = ""
	SessionScript.platform = ""
	SessionScript.vr_menu_confirmed = false
	SessionScript.start_override = Callable()
	VrGameModeScript.xr_available_override = Callable()
	VrGameModeScript.last_start_menu = null


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])
