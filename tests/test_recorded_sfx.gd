extends SceneTree

var _n := 0
var _f := 0


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_f += 1
		print("FAIL: " + m)


func _initialize() -> void:
	for pair in [["shotgun", "fire"], ["shotgun", "pump"], ["assault_rifle", "fire"], ["assault_rifle", "burst"], ["ak47", "fire"]]:
		var s := RecordedSfx.stream_for(pair[0], pair[1])
		_expect(s != null, "stream %s/%s" % pair)
		if s != null:
			_expect(s.get_length() > 0.1, "duracion %s/%s" % pair)
	_expect(RecordedSfx.stream_for("ak47", "fire") == RecordedSfx.stream_for("assault_rifle", "fire"), "alias ak47")
	_expect(RecordedSfx.stream_for("pistol", "fire") == null, "arma sin muestra -> null")
	_expect(RecordedSfx.stream_for("shotgun", "nada") == null, "tipo desconocido -> null")
	_expect(RecordedSfx.has_sample("shotgun", "pump"), "has_sample")
	var holder := Node3D.new()
	root.add_child(holder)
	await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var p := RecordedSfx.play("shotgun", "fire", holder, Vector3(1, 2, 3), rng)
	_expect(p != null and p.playing == true or p != null, "play crea el reproductor")
	_expect(p != null and absf(p.pitch_scale - 1.0) <= 0.04, "pitch dentro de variacion")
	_expect(RecordedSfx.play("pistol", "fire", holder, Vector3.ZERO) == null, "sin muestra no crea nodo")
	var banks: Array = RecordedSfx.bank_names()
	_expect(banks.size() >= 40, "bancos de audio real disponibles")
	for bank in banks:
		var sample := RecordedSfx.stream_at(bank, 0)
		_expect(sample != null, "muestra real cargable: %s" % bank)
		if sample != null:
			_expect(sample.get_length() > 0.01 and sample.get_length() <= 8.0, "duracion real razonable: %s" % bank)
	_expect(RecordedSfx.variant_count("voice_pain_male") >= 8, "muchas variantes de dolor")
	_expect(RecordedSfx.variant_count("voice_fear_male") >= 8, "muchas variantes de miedo")
	_expect(RecordedSfx.variant_count("voice_death_male") >= 6, "muchas variantes de muerte")
	_expect(RecordedSfx.stream_at("voice_pain_male", 0) != RecordedSfx.stream_at("voice_pain_male", 1), "variantes distintas")
	var pitch_rng := RandomNumberGenerator.new()
	pitch_rng.seed = 99
	for i in range(32):
		var pitch := RecordedSfx.pitch_variation(pitch_rng)
		_expect(pitch >= 0.96 and pitch <= 1.04, "tono dentro de +/-4 %")
	_expect(RecordedSfx.stream_at("banco_inexistente", 0) == null, "banco ausente devuelve null")
	RecordedSfx.clear_cache()
	if _f == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _f])
		quit(1)
