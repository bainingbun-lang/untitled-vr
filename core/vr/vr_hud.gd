class_name VrHud
extends Node3D

const AMMO_EMPTY_TEXT := "--"
const HEALTH_EMPTY_TEXT := "0"

var health_ratio_value: float = 1.0
var ammo_loaded: int = 0
var ammo_mag_size: int = 0
var ammo_reserve: int = 0
var ammo_infinite: bool = false
var reloading: bool = false
var reload_progress: float = 0.0
var damage_vignette: float = 0.0
var damage_angle: float = 0.0
var heartbeat_phase: float = 0.0
var laser_enabled: bool = false

var _built: bool = false
var weapon_ammo_label: Label3D = null
var magazine_ammo_label: Label3D = null
var health_label: Label3D = null
var health_bar: MeshInstance3D = null
var reload_label: Label3D = null
var laser_beam: MeshInstance3D = null


func build() -> bool:
	if _built:
		return true
	_built = true
	weapon_ammo_label = Label3D.new()
	weapon_ammo_label.name = "WeaponAmmoLabel"
	weapon_ammo_label.text = format_weapon_ammo(ammo_loaded, ammo_mag_size)
	weapon_ammo_label.pixel_size = 0.002
	add_child(weapon_ammo_label)

	magazine_ammo_label = Label3D.new()
	magazine_ammo_label.name = "MagazineAmmoLabel"
	magazine_ammo_label.text = format_magazine_ammo(ammo_loaded)
	magazine_ammo_label.pixel_size = 0.0018
	magazine_ammo_label.position = Vector3(0.0, -0.03, 0.0)
	add_child(magazine_ammo_label)

	health_label = Label3D.new()
	health_label.name = "HealthLabel"
	health_label.text = format_health(health_ratio_value * 100.0, 100.0)
	health_label.pixel_size = 0.002
	health_label.position = Vector3(0.0, 0.0, 0.0)
	add_child(health_label)

	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.08, 0.01, 0.002)
	health_bar = MeshInstance3D.new()
	health_bar.name = "HealthBar"
	health_bar.mesh = bar_mesh
	health_bar.position = Vector3(0.0, -0.02, 0.0)
	add_child(health_bar)

	reload_label = Label3D.new()
	reload_label.name = "ReloadLabel"
	reload_label.text = format_reload(reload_progress, reloading)
	reload_label.pixel_size = 0.0016
	reload_label.position = Vector3(0.0, -0.05, 0.0)
	add_child(reload_label)

	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.001
	beam_mesh.bottom_radius = 0.001
	beam_mesh.height = 1.0
	laser_beam = MeshInstance3D.new()
	laser_beam.name = "LaserBeam"
	laser_beam.mesh = beam_mesh
	laser_beam.visible = laser_enabled
	laser_beam.rotation.x = PI * 0.5
	laser_beam.position = Vector3(0.0, 0.0, -0.5)
	add_child(laser_beam)

	_refresh_visuals()
	return true


func is_built() -> bool:
	return _built


func set_ammo(loaded: int, mag_size: int, reserve_count: int = 0, infinite: bool = false) -> void:
	ammo_loaded = maxi(loaded, 0)
	ammo_mag_size = maxi(mag_size, 0)
	ammo_reserve = maxi(reserve_count, 0)
	ammo_infinite = infinite
	_refresh_visuals()


func set_health(current: float, maximum: float = 100.0) -> void:
	health_ratio_value = compute_health_ratio(current, maximum)
	_refresh_visuals()


func set_reload(active: bool, progress: float = 0.0) -> void:
	reloading = active
	reload_progress = clampf(progress, 0.0, 1.0)
	_refresh_visuals()


func register_damage(forward: Vector3, right: Vector3, world_position: Vector3, impact_point: Vector3, amount: float = 1.0) -> float:
	damage_angle = compute_damage_angle(forward, right, world_position, impact_point)
	damage_vignette = clampf(damage_vignette + maxf(amount, 0.0) * 0.08, 0.0, 1.0)
	_refresh_visuals()
	return damage_angle


func decay_vignette(delta: float, speed: float = 1.5) -> float:
	damage_vignette = maxf(damage_vignette - maxf(delta, 0.0) * maxf(speed, 0.0), 0.0)
	return damage_vignette


func set_laser_enabled(enabled: bool) -> void:
	laser_enabled = enabled
	if laser_beam != null:
		laser_beam.visible = enabled


func _refresh_visuals() -> void:
	if weapon_ammo_label != null:
		weapon_ammo_label.text = format_weapon_ammo(ammo_loaded, ammo_mag_size, ammo_reserve, ammo_infinite)
	if magazine_ammo_label != null:
		magazine_ammo_label.text = format_magazine_ammo(ammo_loaded, ammo_infinite)
	if health_label != null:
		health_label.text = format_health(health_ratio_value * 100.0, 100.0)
	if reload_label != null:
		reload_label.text = format_reload(reload_progress, reloading)
	if health_bar != null:
		var ratio: float = clampf(health_ratio_value, 0.0, 1.0)
		health_bar.scale = Vector3(maxf(ratio, 0.001), 1.0, 1.0)
		health_bar.position.x = -0.04 * (1.0 - ratio)
	if laser_beam != null:
		laser_beam.visible = laser_enabled


static func format_weapon_ammo(loaded: int, mag_size: int, reserve: int = -1, infinite: bool = false) -> String:
	var left := AMMO_EMPTY_TEXT if infinite else str(maxi(loaded, 0))
	var right := "INF" if infinite else str(maxi(mag_size, 0))
	if reserve >= 0 and not infinite:
		return "%s/%s | %d" % [left, right, maxi(reserve, 0)]
	return "%s/%s" % [left, right]


static func format_magazine_ammo(loaded: int, infinite: bool = false) -> String:
	return "INF" if infinite else str(maxi(loaded, 0))


static func format_health(current: float, maximum: float = 100.0) -> String:
	var ratio := compute_health_ratio(current, maximum)
	var value := int(round(ratio * maxf(maximum, 0.0))) if maximum > 0.0 else 0
	return str(maxi(value, 0))


static func compute_health_ratio(current: float, maximum: float = 100.0) -> float:
	if maximum <= 0.0:
		return 0.0
	return clampf(current / maximum, 0.0, 1.0)


static func format_reload(progress: float, active: bool) -> String:
	if not active:
		return ""
	var pct := int(round(clampf(progress, 0.0, 1.0) * 100.0))
	return "RELOAD %d%%" % pct


static func compute_damage_angle(forward: Vector3, right: Vector3, player_position: Vector3, damage_origin: Vector3) -> float:
	var flat_forward := Vector3(forward.x, 0.0, forward.z)
	var flat_right := Vector3(right.x, 0.0, right.z)
	if flat_forward.length_squared() <= 0.000001:
		flat_forward = Vector3.FORWARD
	if flat_right.length_squared() <= 0.000001:
		flat_right = flat_forward.cross(Vector3.UP)
		if flat_right.length_squared() <= 0.000001:
			flat_right = Vector3.RIGHT
	flat_forward = flat_forward.normalized()
	flat_right = flat_right.normalized()
	var to_damage := damage_origin - player_position
	to_damage.y = 0.0
	if to_damage.length_squared() <= 0.000001:
		return 0.0
	to_damage = to_damage.normalized()
	return atan2(flat_right.dot(to_damage), flat_forward.dot(to_damage))


static func heartbeat_period_seconds(health_ratio: float) -> float:
	var ratio: float = clampf(health_ratio, 0.0, 1.0)
	return lerpf(0.35, 1.2, ratio)


static func vignette_alpha(base_strength: float, pulse: float = 0.0) -> float:
	return clampf(base_strength + pulse * 0.15, 0.0, 1.0)
