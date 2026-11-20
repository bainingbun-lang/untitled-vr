extends SceneTree
func _initialize() -> void:
	var bad := 0
	for p in ["res://scenes/world/game_world.tscn", "res://scenes/vr/vr_boot.tscn", "res://scenes/player/player.tscn"]:
		if load(p) == null: bad += 1; print("NO CARGA: ", p)
	for p in ["res://core/game/game_world.gd", "res://core/game/armed_npc.gd", "res://core/vr/vr_game_mode.gd", "res://core/vr/vr_bootstrap.gd", "res://core/game/player.gd", "res://core/game/vehicle.gd"]:
		var s = load(p)
		if s == null or not s.can_instantiate(): bad += 1; print("NO COMPILA: ", p)
	print("RESULTADO bad=", bad)
	quit(0 if bad == 0 else 1)
