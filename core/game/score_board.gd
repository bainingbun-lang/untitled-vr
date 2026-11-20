class_name ScoreBoard
extends Node

const SaveSystemScript = preload("res://core/game/save_system.gd")

signal score_changed(new_score: int)
signal combo_changed(combo: int)
signal wave_completed(wave: int, wave_score: int)
signal high_score_updated(map_name: String, score: int)

var _total_score: int = 0
var _wave_scores: Dictionary = {}
var _current_wave: int = 0
var _wave_start_score: int = 0
var _combo: int = 0
var _max_combo: int = 0
var _combo_timer: float = 0.0
var _combo_timeout: float = 3.0
var _kills: int = 0
var _headshots: int = 0
var _bodyshots: int = 0
var _shots_fired: int = 0
var _shots_hit: int = 0
var _deaths: int = 0
var _time_survived: float = 0.0
var _ammo_pickups: int = 0
var _health_pickups: int = 0
var _armor_pickups: int = 0
var _weapon_pickups: int = 0
var _objectives_completed: int = 0
var _map_name: String = "default"
var _session_start_time: int = 0
var _wrist_display: Node3D = null
var _display_update_timer: float = 0.0

func _init() -> void:
	_session_start_time = Time.get_ticks_msec()

func setup(p_player: Node3D = null, p_map_name: String = "default") -> void:
	_map_name = p_map_name
	_load_high_score()
	if p_player:
		_setup_wrist_display(p_player)

func _setup_wrist_display(player: Node3D) -> void:
	var left_hand = player.get_node_or_null("LeftHand") or player.get_node_or_null("Left_Hand")
	var right_hand = player.get_node_or_null("RightHand") or player.get_node_or_null("Right_Hand")
	var hand = left_hand if left_hand else right_hand
	
	if not hand:
		return
	
	_wrist_display = Node3D.new()
	_wrist_display.name = "ScoreWristDisplay"
	hand.add_child(_wrist_display)
	_wrist_display.position = Vector3(0.05, -0.05, 0.05)
	_wrist_display.rotation = Vector3(0, PI, 0)
	
	var canvas = CanvasLayer.new()
	canvas.layer = 20
	_wrist_display.add_child(canvas)
	
	var panel = Panel.new()
	panel.name = "ScorePanel"
	canvas.add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.add_theme_constant_override("separation", 4)
	
	var score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "PUNTUACION: 0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_color_override("font_color", Color(1, 1, 0.2))
	vbox.add_child(score_label)
	
	var wave_label = Label.new()
	wave_label.name = "WaveLabel"
	wave_label.text = "OLEADA: 0"
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.add_theme_font_size_override("font_size", 20)
	wave_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1))
	vbox.add_child(wave_label)
	
	var combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.text = "COMBO: x0"
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 22)
	combo_label.add_theme_color_override("font_color", Color(1, 0.5, 0))
	vbox.add_child(combo_label)
	
	var stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.text = "K:0 HS:0 ACC:0%"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.add_theme_color_override("font_color", Color(0.7, 1, 0.7))
	vbox.add_child(stats_label)
	
	var time_label = Label.new()
	time_label.name = "TimeLabel"
	time_label.text = "TIEMPO: 0:00"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 18)
	time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1))
	vbox.add_child(time_label)
	
	var hs_label = Label.new()
	hs_label.name = "HighScoreLabel"
	hs_label.text = "MEJOR: %d" % _get_high_score()
	hs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hs_label.add_theme_font_size_override("font_size", 16)
	hs_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	vbox.add_child(hs_label)

func _load_high_score() -> void:
	var save = SaveSystemScript.load("scoreboard_%s" % _map_name)
	if save and save.has("high_score"):
		_save_high_score = int(save["high_score"])
	else:
		_save_high_score = 0

var _save_high_score: int = 0

func _get_high_score() -> int:
	return _save_high_score

func _save_high_score_to_disk() -> void:
	SaveSystemScript.save("scoreboard_%s" % _map_name, {"high_score": _save_high_score})

func tick(delta: float) -> void:
	_time_survived += delta
	
	if _combo > 0:
		_combo_timer += delta
		if _combo_timer >= _combo_timeout:
			_combo = 0
			_combo_timer = 0.0
			combo_changed.emit(0)
	
	_display_update_timer += delta
	if _display_update_timer >= 0.5:
		_display_update_timer = 0.0
		_update_wrist_display()

func _update_wrist_display() -> void:
	if not _wrist_display:
		return
	
	var canvas = _wrist_display.get_node_or_null("CanvasLayer")
	if not canvas:
		return
	
	var panel = canvas.get_node_or_null("ScorePanel")
	if not panel:
		return
	
	var vbox = panel.get_node_or_null("VBoxContainer")
	if not vbox:
		return
	
	var score_label = vbox.get_node_or_null("ScoreLabel")
	if score_label:
		score_label.text = "PUNTUACION: %d" % _total_score
	
	var wave_label = vbox.get_node_or_null("WaveLabel")
	if wave_label:
		wave_label.text = "OLEADA: %d" % _current_wave
	
	var combo_label = vbox.get_node_or_null("ComboLabel")
	if combo_label:
		combo_label.text = "COMBO: x%d" % _combo
		if _combo >= 5:
			combo_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
		elif _combo >= 3:
			combo_label.add_theme_color_override("font_color", Color(1, 0.5, 0))
		else:
			combo_label.add_theme_color_override("font_color", Color(1, 1, 0.2))
	
	var stats_label = vbox.get_node_or_null("StatsLabel")
	if stats_label:
		var acc = _shots_fired > 0 ? (_shots_hit * 100 / _shots_fired) : 0
		stats_label.text = "K:%d HS:%d ACC:%d%%" % [_kills, _headshots, int(acc)]
	
	var time_label = vbox.get_node_or_null("TimeLabel")
	if time_label:
		var minutes = int(_time_survived / 60)
		var seconds = int(_time_survived) % 60
		time_label.text = "TIEMPO: %d:%02d" % [minutes, seconds]
	
	var hs_label = vbox.get_node_or_null("HighScoreLabel")
	if hs_label:
		hs_label.text = "MEJOR: %d" % _save_high_score

func add_kill(is_zombie: bool = false, is_boss: bool = false) -> void:
	var base_points = is_zombie ? 150 : 100
	if is_boss:
		base_points = 500
	
	var combo_bonus = _combo * 10
	var points = base_points + combo_bonus
	
	_total_score += points
	_kills += 1
	_combo += 1
	_combo_timer = 0.0
	
	if _combo > _max_combo:
		_max_combo = _combo
	
	score_changed.emit(_total_score)
	combo_changed.emit(_combo)

func register_hit(point: Vector3, normal: Vector3, damage: float) -> void:
	_shots_hit += 1
	
	var is_headshot = point.y > 1.5
	if is_headshot:
		_headshots += 1
		_total_score += 50
		score_changed.emit(_total_score)

func register_shot() -> void:
	_shots_fired += 1

func add_ammo_pickup(ammo_type: String, amount: int) -> void:
	_ammo_pickups += 1
	_total_score += 10
	score_changed.emit(_total_score)

func add_health_pickup(amount: float) -> void:
	_health_pickups += 1
	_total_score += 5
	score_changed.emit(_total_score)

func add_armor_pickup(amount: float) -> void:
	_armor_pickups += 1
	_total_score += 5
	score_changed.emit(_total_score)

func add_weapon_pickup(weapon_id: String) -> void:
	_weapon_pickups += 1
	_total_score += 50
	score_changed.emit(_total_score)

func add_objective_completed() -> void:
	_objectives_completed += 1
	_total_score += 200
	score_changed.emit(_total_score)

func start_wave(wave: int) -> void:
	_current_wave = wave
	_wave_start_score = _total_score

func end_wave(wave: int) -> void:
	var wave_score = _total_score - _wave_start_score
	_wave_scores[str(wave)] = wave_score
	wave_completed.emit(wave, wave_score)
	
	if _total_score > _save_high_score:
		_save_high_score = _total_score
		_save_high_score_to_disk()
		high_score_updated.emit(_map_name, _save_high_score)

func get_total_score() -> int:
	return _total_score

func get_wave_score(wave: int) -> int:
	return _wave_scores.get(str(wave), 0)

func get_current_wave() -> int:
	return _current_wave

func get_combo() -> int:
	return _combo

func get_max_combo() -> int:
	return _max_combo

func get_kills() -> int:
	return _kills

func get_headshots() -> int:
	return _headshots

func get_accuracy() -> float:
	return _shots_fired > 0 ? _shots_hit / _shots_fired : 0.0

func get_time_survived() -> float:
	return _time_survived

func get_deaths() -> int:
	return _deaths

func get_stats() -> Dictionary:
	var acc = get_accuracy()
	return {
		"total_score": _total_score,
		"wave": _current_wave,
		"kills": _kills,
		"headshots": _headshots,
		"accuracy": acc,
		"time_survived": _time_survived,
		"deaths": _deaths,
		"max_combo": _max_combo,
		"ammo_pickups": _ammo_pickups,
		"health_pickups": _health_pickups,
		"armor_pickups": _armor_pickups,
		"weapon_pickups": _weapon_pickups,
		"objectives_completed": _objectives_completed,
		"high_score": _save_high_score,
		"map_name": _map_name,
		"wave_scores": _wave_scores.duplicate(),
	}

func reset() -> void:
	_total_score = 0
	_wave_scores.clear()
	_current_wave = 0
	_wave_start_score = 0
	_combo = 0
	_max_combo = 0
	_combo_timer = 0.0
	_kills = 0
	_headshots = 0
	_bodyshots = 0
	_shots_fired = 0
	_shots_hit = 0
	_deaths = 0
	_time_survived = 0.0
	_ammo_pickups = 0
	_health_pickups = 0
	_armor_pickups = 0
	_weapon_pickups = 0
	_objectives_completed = 0
	_session_start_time = Time.get_ticks_msec()
	_update_wrist_display()

func set(key: String, value: Variant) -> void:
	match key:
		"deaths":
			_deaths = int(value)
		"kills":
			_kills = int(value)
		"headshots":
			_headshots = int(value)
		"shots_fired":
			_shots_fired = int(value)
		"shots_hit":
			_shots_hit = int(value)
		"time_survived":
			_time_survived = float(value)
		"total_score":
			_total_score = int(value)
		"current_wave":
			_current_wave = int(value)
		"combo":
			_combo = int(value)
			combo_changed.emit(_combo)
		"max_combo":
			_max_combo = int(value)
		"objectives_completed":
			_objectives_completed = int(value)
		"ammo_pickups":
			_ammo_pickups = int(value)
		"health_pickups":
			_health_pickups = int(value)
		"armor_pickups":
			_armor_pickups = int(value)
		"weapon_pickups":
			_weapon_pickups = int(value)
		"map_name":
			_map_name = str(value)
			_load_high_score()

func get(key: String) -> Variant:
	match key:
		"deaths": return _deaths
		"kills": return _kills
		"headshots": return _headshots
		"shots_fired": return _shots_fired
		"shots_hit": return _shots_hit
		"time_survived": return _time_survived
		"total_score": return _total_score
		"current_wave": return _current_wave
		"combo": return _combo
		"max_combo": return _max_combo
		"objectives_completed": return _objectives_completed
		"ammo_pickups": return _ammo_pickups
		"health_pickups": return _health_pickups
		"armor_pickups": return _armor_pickups
		"weapon_pickups": return _weapon_pickups
		"map_name": return _map_name
		"high_score": return _save_high_score
		_: return null

func has_method(method: String) -> bool:
	return true