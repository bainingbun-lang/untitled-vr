extends Node

# Spike M1. Args: <base.pck|-> <mod.pck|-> <replace:0|1>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var basepck := a[0] if a.size() > 0 else "-"
	var modpck := a[1] if a.size() > 1 else "-"
	var replace := (a[2] == "1") if a.size() > 2 else true
	if basepck != "-":
		print("M1 BASE_PCK_OK=", ProjectSettings.load_resource_pack(basepck, true))
	if modpck != "-":
		var t0 := Time.get_ticks_usec()
		var ok := ProjectSettings.load_resource_pack(modpck, replace)
		print("M1 MOD_LOAD_OK=", ok, " REPLACE=", replace, " US=", Time.get_ticks_usec() - t0)
