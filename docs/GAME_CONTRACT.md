# GAME_CONTRACT — interfaces compartidas del juego jugable (ciclo 4)
Todos los agentes respetan estas firmas. Cada agente SOLO crea los archivos de su brief; si necesita algo de otro modulo, lo usa por estas firmas (con `ResourceLoader.exists`/`ClassDB`-style guardas, tolerando que aun no exista).

## Flujo
`scenes/menu/main_menu.tscn` (Play) -> seleccion/generacion de mapa -> `GameSession.start(map_meta)` -> cambia a `res://scenes/world/game_world.tscn`.

## GameSession (core/game/game_session.gd, class_name GameSession, TODO estatico)
- `static var map_meta: Dictionary`, `static var platform: String` ("android"|"pc"|"vr", detectado), `static var gore_enabled: bool = true`, `static var seed: int`
- `static func detect_platform() -> String`
- `static func start(meta: Dictionary, tree: SceneTree) -> Error` (guarda meta y hace change_scene_to_file a game_world.tscn)

## GameWorld (scenes/world/game_world.tscn, script core/game/game_world.gd, class_name GameWorld, extends Node3D)
- `func setup(meta: Dictionary) -> void` construye suelo, obstaculos, luz, cielo, spawn points (MapWorldBuilder) y al terminar anade el jugador (`res://scenes/player/player.tscn` si existe) en el primer spawn point.
- grupos: nodos de props fisicos en grupo "physics_props"; NPC/objetivos danables en grupo "damageable".
- `func spawn_point_positions() -> Array` (Vector3)

## MapWorldBuilder (core/maps/map_world_builder.gd, class_name MapWorldBuilder)
- `static func build(meta: Dictionary, parent: Node3D) -> Dictionary` -> {ok, spawn_points: Array[Vector3], bounds: AABB, errors: Array}. Debe funcionar con mapas del MapGenerator (core/maps/map_generator.gd) y con mapas validos del estandar. Limites de geometria para movil (max nodos).

## Player (scenes/player/player.tscn, script core/game/player.gd, class_name Player, extends CharacterBody3D)
- `var inventory: Inventory`, `var health: float`, `signal died`, `signal weapon_changed(item_id)`
- `func equip(item_id: String) -> bool`, `func fire() -> void`, `func enter_vehicle(v: Node3D) -> void`, `func exit_vehicle() -> void`
- Controles: teclado/raton en PC, joystick virtual + zona de mirar + botones en Android (TouchControls), mandos en VR (no bloquear: en VR basta con exponer las acciones).

## TouchControls (scenes/ui/touch_controls.tscn, script core/game/touch_controls.gd)
- señales `move(vec: Vector2)`, `look(delta: Vector2)`, `jump_pressed`, `fire_pressed`, `fire_released`, `interact_pressed`, `menu_pressed`, `hotbar_select(index:int)`

## Armas, dano, gore
- `WeaponDb` (core/game/weapon_db.gd): `static func all() -> Dictionary` (id -> def {id,name,damage,fire_rate,range,mag,auto,spread,pellets,tags}); `static func register_items(item_db: ItemDb) -> void` registra cada arma como item (tag "weapon").
- `Damageable` (core/game/damageable.gd, extends Node): `var health: float`, `func take_damage(amount: float, point: Vector3, normal: Vector3, source: Node = null) -> void`, `signal damaged(amount, point, normal)`, `signal died`
- `WeaponSystem` (core/game/weapon_system.gd, class_name WeaponSystem, extends Node): `func fire(weapon_id: String, origin: Vector3, direction: Vector3, space: PhysicsDirectSpaceState3D, exclude: Array) -> Dictionary` hitscan que aplica dano a Damageable, impulso a RigidBody3D, devuelve {hit, position, normal, collider}.
- `GoreFx` (core/game/gore_fx.gd, class_name GoreFx): `static func blood_hit(parent: Node, pos: Vector3, normal: Vector3, amount: float) -> void`, `static func on_death(parent: Node, pos: Vector3, size: float) -> void`; respeta `GameSession.gore_enabled` y un limite global de particulas/decales (movil).

## Vehiculos
- `VehicleDb` (core/game/vehicle_db.gd): `static func all() -> Dictionary` (id -> {id,name,scene_builder,max_speed,mass}), `static func list_ids() -> Array`
- `VehicleSpawner` (core/game/vehicle_spawner.gd): `static func spawn(vehicle_id: String, xform: Transform3D, parent: Node) -> Node3D` (VehicleBody3D construido por codigo, sin assets externos), rechazo controlado de id desconocido; limite de vehiculos vivos.
- Vehiculo: `func enter(driver: Node3D) -> bool`, `func exit() -> Node3D`, entradas `set_drive_input(throttle: float, steer: float, brake: float)`.
- `SpawnMenu` (scenes/ui/spawn_menu.tscn, script core/game/spawn_menu.gd): lista de vehiculos, boton Aparecer -> señal `spawn_requested(vehicle_id: String)`.

## Inventario inicial / VR
- `Loadout` (core/game/loadout.gd): `static func give_starting_kit(inventory: Inventory, item_db: ItemDb) -> Dictionary` mete TODAS las armas en el inventario (ya en inventario al entrar), devuelve {ok, given}.
- `Hotbar` (scenes/ui/hotbar.tscn, script core/game/hotbar.gd): muestra armas del inventario, señal `selected(item_id)`.
- `VrBag` (core/vr/vr_bag.gd, class_name VrBag): en VR las armas NO estan en la mano: `func open(hand_position: Vector3) -> bool` (se abre si la mano esta en la zona del bolso: detras del hombro/cadera respecto a la cabeza), `func items() -> Array`, `func take(item_id: String) -> bool` (saca el arma a la mano), `func stow() -> void`. Logica pura testeable sin XRServer.
