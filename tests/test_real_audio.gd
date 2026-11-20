extends SceneTree

func _initialize() -> void:
	for cls in [AudioEffectLimiter, AudioEffectLowPassFilter, AudioEffectReverb]:
		var e = cls.new()
		print("== ", cls, " ==")
		for p in e.get_property_list():
			if (p.usage & PROPERTY_USAGE_EDITOR) != 0 or (p.usage & PROPERTY_USAGE_STORAGE) != 0:
				print(String(p.name), " : ", p.type, " = ", str(e.get(p.name)))
		e.free()
	quit(0)
