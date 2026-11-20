extends SceneTree

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const MapBuilderScript = preload("res://core/maps/map_world_builder.gd")
const MuzzleFxScript = preload("res://core/game/muzzle_fx.gd")
const ImpactFxScript = preload("res://core/game/impact_fx.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const ItemDbScript = preload("res://core/game/item_db.gd")
const InventoryScript = preload("res://core/game/inventory.gd")
const LoadoutScript = preload("res://core/game/loadout.gd")
const HotbarScript = preload("res://core/game/hotbar.gd")
const TouchScene = preload("res://scenes/ui/touch_controls.tscn")

var _checks := 0
var _failures: Array = []


func _initialize() -> void:
	await _run()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	await _check_muzzle_and_impact()
	await _check_gore()
	await _check_map_environment_and_props()
	await _check_ui()


func _merged_global_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var instance := item as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		var box: AABB = instance.get_global_transform() * instance.mesh.get_aabb()
		if found:
			result = result.merge(box)
		else:
			result = box
			found = true
	return result


func _make_floor(parent: Node3D) -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.name = "TestFloor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.5, 30.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	floor_body.position = Vector3(0.0, -0.25, 0.0)
	parent.add_child(floor_body)
	return floor_body


func _check_muzzle_and_impact() -> void:
	var holder := Node3D.new()
	holder.name = "FxHolder"
	root.add_child(holder)
	await process_frame
	_make_floor(holder)
	await physics_frame

	var muzzle := MuzzleFxScript.new()
	muzzle.name = "MuzzleFx"
	holder.add_child(muzzle)
	muzzle.fire(1.0, Vector3.FORWARD, Vector3.RIGHT)
	await process_frame

	_expect(MuzzleFxScript.FLASH_LIFE <= 0.12, "fogonazo con vida corta (<=120 ms)")
	var flashes := muzzle.find_children("MuzzleFlash", "Node3D", true, false)
	_expect(flashes.size() > 0, "fogonazo instanciado")
	if not flashes.is_empty():
		var flash_node := flashes[0] as Node3D
		_expect(flash_node.get_node_or_null("FlashSprite") is Sprite3D, "fogonazo usa Sprite3D billboard")
		_expect(flash_node.get_node_or_null("FlashSparks") == null, "sin chispas QuadMesh grises")
		var sprite := flash_node.get_node_or_null("FlashSprite") as Sprite3D
		if sprite != null:
			_expect(sprite.texture is GradientTexture2D, "fogonazo usa textura radial procedural")
			var diameter: float = sprite.pixel_size * float(MuzzleFxScript.SPRITE_RES)
			_expect(diameter >= 0.08 and diameter <= 0.30, "fogonazo mide decenas de cm")
			var material := sprite.material_override as StandardMaterial3D
			_expect(material != null and material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD,
				"fogonazo con mezcla aditiva")
	var smokes := muzzle.find_children("MuzzleSmoke", "Node3D", true, false)
	_expect(smokes.size() > 0, "humo de boca instanciado")
	if not smokes.is_empty():
		var smoke_sprite := (smokes[0] as Node3D).get_node_or_null("SmokePuff0") as Sprite3D
		_expect(smoke_sprite != null and smoke_sprite.texture is GradientTexture2D,
			"humo usa textura radial con alpha")
	var casings := muzzle.find_children("MuzzleCasing", "RigidBody3D", true, false)
	_expect(casings.size() > 0, "casquillo expulsado")
	if not casings.is_empty():
		var casing := casings[0] as RigidBody3D
		var collision_node := casing.get_child(0) as CollisionShape3D
		_expect(collision_node != null and collision_node.shape is CylinderShape3D,
			"colision de casquillo cilindrica")
		var visual := casing.get_node_or_null("Brass") as MeshInstance3D
		_expect(visual != null and visual.mesh is CylinderMesh, "malla de casquillo cilindrica")

	ImpactFxScript.spawn(holder, 1, Vector3(0.0, 0.05, 0.0), Vector3.UP, 60.0, Vector3.FORWARD)
	await process_frame
	var impacts := holder.find_children("ImpactFx", "Node3D", true, false)
	_expect(impacts.size() > 0, "impacto instanciado")
	if not impacts.is_empty():
		var particles := (impacts[0] as Node3D).get_child(0) as CPUParticles3D
		if particles != null:
			var box := particles.mesh as BoxMesh
			var sphere := particles.mesh as SphereMesh
			var largest := 0.0
			if box != null:
				largest = box.size.x
			elif sphere != null:
				largest = sphere.height
			_expect(largest <= 0.1, "particulas de impacto pequenas")
	var decals := holder.find_children("ImpactHole", "MeshInstance3D", true, false)
	_expect(decals.size() > 0, "decal de impacto instanciado")
	if not decals.is_empty():
		var plane := (decals[0] as MeshInstance3D).mesh as PlaneMesh
		_expect(plane != null and maxf(plane.size.x, plane.size.y) <= 0.35,
			"decal de impacto acotado")
		var material := (decals[0] as MeshInstance3D).material_override as StandardMaterial3D
		_expect(material != null and material.albedo_texture is GradientTexture2D,
			"decal con alpha radial")
	holder.queue_free()
	await process_frame


func _check_gore() -> void:
	GoreFxScript.set_gore_enabled(true)
	var holder := Node3D.new()
	holder.name = "GoreHolder"
	root.add_child(holder)
	await process_frame
	_make_floor(holder)
	await physics_frame

	var puddle := GoreFxScript.puddle(holder, Vector3(2.0, 3.0, 1.0), Vector3.UP, 0.9)
	_expect(puddle != null, "charco de sangre creado")
	if puddle != null:
		_expect(puddle.mesh is ArrayMesh, "charco es malla irregular plana")
		var aabb: AABB = puddle.mesh.get_aabb()
		_expect(aabb.size.y <= 0.02, "charco no tiene volumen")
		_expect(absf(puddle.global_position.y - 0.004) <= 0.02,
			"charco proyectado sobre el suelo y=0")
	var parts: Array = GoreFxScript.dismember(holder, Vector3(0.0, 1.5, 0.0), 1.0, "brazo", 3)
	_expect(parts.size() == 3, "partes organicas generadas")
	if not parts.is_empty():
		var body := parts[0] as RigidBody3D
		var visual := body.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		_expect(visual != null and not (visual.mesh is BoxMesh), "sin restos cubicos en gore")
		_expect(visual != null and (visual.mesh is SphereMesh or visual.mesh is CapsuleMesh),
			"restos organicos redondeados")
	GoreFxScript.clear()
	holder.queue_free()
	await process_frame


func _check_map_environment_and_props() -> void:
	var meta: Dictionary = GeneratorScript.generate(9182, {
		"width": 24, "height": 18, "obstacle_density": 0.16, "spawn_count": 4,
	})
	_expect(bool(meta.get("ok", false)), "meta de mapa para regression visual")
	var parent := Node3D.new()
	parent.name = "MapParent"
	root.add_child(parent)
	var report: Dictionary = MapBuilderScript.build(meta, parent)
	await physics_frame
	_expect(bool(report.get("ok", false)), "mapa construido")
	var world_environment := parent.find_children("WorldEnvironment", "WorldEnvironment", true, false)[0] as WorldEnvironment
	_expect(world_environment != null, "WorldEnvironment creado")
	if world_environment != null:
		var environment: Environment = world_environment.environment
		_expect(environment != null and environment.background_mode == Environment.BG_SKY,
			"fondo de cielo activo")
		_expect(environment != null and environment.fog_enabled, "niebla activa")
		if environment != null:
			_expect(environment.fog_density <= 0.003, "niebla sutil (<=0.003)")
			var fog := environment.fog_light_color
			var saturation: float = maxf(fog.r, maxf(fog.g, fog.b)) - minf(fog.r, minf(fog.g, fog.b))
			_expect(saturation <= 0.15 and fog.r >= 0.6, "niebla neutral, no marron")
		var sky: Sky = environment.sky if environment != null else null
		var panorama := sky.sky_material as PanoramaSkyMaterial if sky != null and sky.sky_material is PanoramaSkyMaterial else null
		_expect(panorama != null and panorama.panorama != null, "HDRI panoramico cargado en el cielo")
	var props: Array = report.get("props", [])
	_expect(props.size() > 0, "props fisicos presentes")
	for item in props:
		var prop := item as RigidBody3D
		if prop == null:
			continue
		_expect(prop.sleeping, "prop asentado y dormido al construir")
		_expect(absf(prop.rotation.x) <= 0.01 and absf(prop.rotation.z) <= 0.01,
			"prop sin inclinacion inicial")
		_expect(prop.global_position.y > 0.0, "prop no flota bajo el suelo")
		var collision_node := prop.find_children("*", "CollisionShape3D", true, false)[0] as CollisionShape3D
		if collision_node != null:
			var shape_height := 0.8
			if collision_node.shape is BoxShape3D:
				shape_height = (collision_node.shape as BoxShape3D).size.y
			elif collision_node.shape is CylinderShape3D:
				shape_height = (collision_node.shape as CylinderShape3D).height
			var visual_list := prop.find_children("*", "MeshInstance3D", true, false)
			if not visual_list.is_empty():
				var visual_aabb := _merged_global_aabb(prop)
				_expect(absf(visual_aabb.position.y - (prop.global_position.y - shape_height * 0.5)) <= 0.08,
					"malla del prop apoya en la base del collider")
	parent.queue_free()
	await process_frame


func _check_ui() -> void:
	var touch := TouchScene.instantiate()
	touch.name = "TouchControls"
	root.add_child(touch)
	await process_frame
	var fire := touch.get_node_or_null("FireButton") as Button
	var hotbar_slot := touch.get_node_or_null("HotbarSlot") as Button
	_expect(fire != null and fire.get_theme_font_size("font_size") >= 30,
		"boton de disparo con tipografia legible")
	_expect(hotbar_slot != null and hotbar_slot.get_theme_font_size("font_size") >= 30,
		"hotbar tactil con tipografia legible")
	_expect(touch.find_children("MovePadLabel", "Label", true, false).size() > 0,
		"pad de movimiento con etiqueta e icono")
	if fire != null:
		var style := fire.get_theme_stylebox("normal") as StyleBoxFlat
		_expect(style != null and style.bg_color.a >= 0.85, "boton con fondo opaco de contraste")
		_expect(fire.get_theme_color("font_color") == Color.WHITE, "texto blanco de alto contraste")
	touch.queue_free()

	var item_db := ItemDbScript.new()
	var inventory := InventoryScript.new(item_db, 24)
	LoadoutScript.give_starting_kit(inventory, item_db)
	var hotbar := HotbarScript.new()
	hotbar.name = "Hotbar"
	root.add_child(hotbar)
	hotbar.setup(inventory, item_db)
	await process_frame
	var slots: Array = hotbar.slot_buttons()
	_expect(slots.size() > 0, "hotbar con ranuras")
	if not slots.is_empty():
		var button := slots[0] as Button
		_expect(button.get_theme_font_size("font_size") >= 30, "ranura de hotbar con fuente 30+")
		_expect(button.custom_minimum_size.x >= 110.0 and button.custom_minimum_size.y >= 90.0,
			"ranura de hotbar lo suficientemente grande")
	hotbar.queue_free()
	await process_frame
