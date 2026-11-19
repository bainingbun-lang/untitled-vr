class_name ModCapabilities
extends RefCounted

const VALID_STATUSES := [
	"ALLOWED",
	"ALLOWED_AFTER_RESTART",
	"NEEDS_PERMISSION",
	"REQUIRES_RECOMPILE",
	"IMPOSSIBLE_ON_PLATFORM",
	"UNVERIFIED",
	"UNKNOWN_INPUT",
]


static func describe(kind: String, platform: String) -> Dictionary:
	if not all_kinds().has(kind) or not all_platforms().has(platform):
		return {
			"status": "UNKNOWN_INPUT",
			"flags": [],
			"note": "kind o platform desconocido: kind='%s', platform='%s'" % [kind, platform],
		}

	if kind == "native_extension":
		if platform == "pc":
			return {
				"status": "REQUIRES_RECOMPILE",
				"flags": ["NEEDS_PERMISSION", "RISK_NATIVE_CODE"],
				"note": "NO PROBADO",
			}
		return {
			"status": "UNVERIFIED",
			"flags": ["RISK_NATIVE_CODE"],
			"note": "no probado en esta plataforma",
		}

	if platform == "pc":
		match kind:
			"config":
				return {"status": "ALLOWED", "flags": [], "note": ""}
			"resource":
				return {
					"status": "ALLOWED",
					"flags": [],
					"note": "verificado: M1, carga de PCK con recursos",
				}
			"script":
				return {
					"status": "ALLOWED",
					"flags": ["RISK_NO_SANDBOX"],
					"note": "verificado: scripts de PCK ejecutados en M1",
				}
			"core_script":
				return {
					"status": "ALLOWED_AFTER_RESTART",
					"flags": ["STABILITY_WARNING"],
					"note": (
						"verificado M3: el script sustituido se usa solo si se resuelve tras "
						+ "cargar el pack o al reiniciar"
					),
				}
			"autoload":
				return {
					"status": "ALLOWED_AFTER_RESTART",
					"flags": ["STABILITY_WARNING"],
					"note": "verificado M3: instancia existente no cambia",
				}
			"loader":
				return {
					"status": "ALLOWED_AFTER_RESTART",
					"flags": ["STABILITY_WARNING"],
					"note": (
						"el cargador de mods ya está en uso al arrancar; su sustitución efectiva "
						+ "requiere reemplazarlo antes del arranque"
					),
				}
			"system":
				return {
					"status": "UNVERIFIED",
					"flags": [],
					"note": "sin prueba registrada en spikes/RESULTS.md",
				}
			_:
				return {"status": "UNVERIFIED", "flags": [], "note": "no verificado"}

	return {
		"status": "UNVERIFIED",
		"flags": [],
		"note": "no probado en esta plataforma",
	}


static func all_kinds() -> Array:
	return [
		"config",
		"resource",
		"script",
		"system",
		"core_script",
		"autoload",
		"loader",
		"native_extension",
	]


static func all_platforms() -> Array:
	return ["pc", "android", "vr"]
