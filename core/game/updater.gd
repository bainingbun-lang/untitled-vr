class_name GameUpdater
extends RefCounted

const GITHUB_API_URL: String = "https://api.github.com/repos/%s/releases/tags/vr-latest"
const CHECK_INTERVAL: float = 3600.0
const USER_AGENT: String = "UNTITLED-VR-Updater/1.0"

signal update_available(version: String, apk_url: String, size: int, sha256: String)
signal update_check_failed(reason: String)
signal download_progress(progress: float)
signal download_complete(apk_path: String)
signal download_failed(reason: String)
signal install_launched()

var _http_request: HTTPRequest = null
var _owner_repo: String = ""
var _current_version: String = ""
var _check_timer: float = 0.0
var _checking: bool = false
var _downloading: bool = false
var _apk_download_path: String = ""
var _expected_size: int = 0
var _expected_sha256: String = ""
var _download_bytes: int = 0

func _init() -> void:
	_owner_repo = _get_owner_repo_from_git()
	_current_version = _get_current_version()
	_setup_http_request()

func _setup_http_request() -> void:
	_http_request = HTTPRequest.new()
	_http_request.request_completed.connect(_on_request_completed)

func _get_owner_repo_from_git() -> String:
	return "bainingbun-lang/untitled-vr"

func _get_current_version() -> String:
	var version_file: String = ProjectSettings.globalize_path("user://version.txt")
	if FileAccess.file_exists(version_file):
		var file: FileAccess = FileAccess.open(version_file, FileAccess.READ)
		if file != null:
			var ver: String = file.get_line().strip_edges()
			file.close()
			if not ver.is_empty():
				return ver
	var proj_version: String = ProjectSettings.get_setting("application/config/version", "")
	if not proj_version.is_empty():
		return proj_version
	return "0.0.0"

func set_current_version(version: String) -> void:
	_current_version = version
	var version_file: String = ProjectSettings.globalize_path("user://version.txt")
	var file: FileAccess = FileAccess.open(version_file, FileAccess.WRITE)
	if file != null:
		file.store_line(version)
		file.close()

func check_for_updates_async() -> void:
	if _checking:
		return
	if _owner_repo.is_empty():
		update_check_failed.emit("No owner/repo configured")
		return
	_checking = true
	var url: String = GITHUB_API_URL % _owner_repo
	var headers: Array[String] = [
		"User-Agent: %s" % USER_AGENT,
		"Accept: application/vnd.github+json"
	]
	_http_request.request(url, headers, HTTPClient.METHOD_GET)

func _find_apk_asset(assets: Array) -> Dictionary:
	for asset in assets:
		if asset is Dictionary:
			var name: String = str(asset.get("name", ""))
			if name.to_lower().ends_with(".apk"):
				return asset
	return {}

func _version_equal(a: String, b: String) -> bool:
	var clean_a: String = a.trim_prefix("v").trim_prefix("V")
	var clean_b: String = b.trim_prefix("v").trim_prefix("V")
	return clean_a == clean_b

func download_apk(apk_url: String, size: int, sha256: String) -> void:
	if _downloading:
		return
	_downloading = true
	_expected_size = size
	_expected_sha256 = sha256
	_apk_download_path = ProjectSettings.globalize_path("user://untitled_vr_update.apk")
	_download_bytes = 0
	
	var existing_file: FileAccess = FileAccess.open(_apk_download_path, FileAccess.READ)
	if existing_file != null:
		existing_file.close()
		var dir: DirAccess = DirAccess.open(ProjectSettings.globalize_path("user://"))
		if dir != null:
			dir.remove("untitled_vr_update.apk")
	
	var headers: Array[String] = [
		"User-Agent: %s" % USER_AGENT
	]
	_http_request.request(apk_url, headers, HTTPClient.METHOD_GET)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if _downloading:
		_downloading = false
		if result != HTTPRequest.RESULT_SUCCESS:
			download_failed.emit("Download failed: %s" % _http_result_to_str(result))
			return
		if response_code != 200:
			download_failed.emit("HTTP %d" % response_code)
			return
		var file: FileAccess = FileAccess.open(_apk_download_path, FileAccess.WRITE)
		if file == null:
			download_failed.emit("Cannot write APK file")
			return
		file.store_buffer(body)
		file.close()
		if _expected_sha256 != "":
			var actual_sha256: String = _compute_sha256(_apk_download_path)
			if actual_sha256 != _expected_sha256:
				download_failed.emit("SHA256 mismatch: expected %s, got %s" % [_expected_sha256, actual_sha256])
				return
		download_complete.emit(_apk_download_path)
	else:
		_on_check_completed(result, response_code, headers, body)

func _on_check_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_checking = false
	if result != HTTPRequest.RESULT_SUCCESS:
		update_check_failed.emit("Request failed: %s" % _http_result_to_str(result))
		return
	if response_code != 200:
		if response_code == 404:
			update_check_failed.emit("Release 'vr-latest' not found")
		else:
			update_check_failed.emit("HTTP %d: %s" % [response_code, body.get_string_from_utf8()])
		return
	var json_text: String = body.get_string_from_utf8()
	var parse_result: Variant = JSON.parse_string(json_text)
	if parse_result is Dictionary and parse_result.has("error"):
		update_check_failed.emit("Invalid JSON response")
		return
	if not parse_result is Dictionary:
		update_check_failed.emit("Unexpected JSON format")
		return
	var release: Dictionary = parse_result
	if not release.has("tag_name") or not release.has("assets"):
		update_check_failed.emit("Release missing tag_name or assets")
		return
	var latest_version: String = str(release["tag_name"])
	if _version_equal(latest_version, _current_version):
		return
	var apk_asset: Dictionary = _find_apk_asset(release["assets"])
	if apk_asset == {} or apk_asset.is_empty():
		update_check_failed.emit("No APK asset found in release")
		return
	var apk_url: String = str(apk_asset.get("browser_download_url", ""))
	var apk_size: int = int(apk_asset.get("size", 0))
	var apk_sha256: String = str(apk_asset.get("sha256", ""))
	if apk_url.is_empty():
		update_check_failed.emit("APK asset missing download URL")
		return
	update_available.emit(latest_version, apk_url, apk_size, apk_sha256)

func _http_result_to_str(result: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS: return "SUCCESS"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: return "CHUNKED_BODY_SIZE_MISMATCH"
		HTTPRequest.RESULT_CANT_RESOLVE: return "CANT_RESOLVE"
		HTTPRequest.RESULT_CANT_CONNECT: return "CANT_CONNECT"
		HTTPRequest.RESULT_CONNECTION_ERROR: return "CONNECTION_ERROR"
		HTTPRequest.RESULT_NO_RESPONSE: return "NO_RESPONSE"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: return "BODY_SIZE_LIMIT_EXCEEDED"
		HTTPRequest.RESULT_REQUEST_FAILED: return "REQUEST_FAILED"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN: return "DOWNLOAD_FILE_CANT_OPEN"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR: return "DOWNLOAD_FILE_WRITE_ERROR"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: return "REDIRECT_LIMIT_REACHED"
		HTTPRequest.RESULT_TIMEOUT: return "TIMEOUT"
		_: return "UNKNOWN(%d)" % result

func _compute_sha256(file_path: String) -> String:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	var hash_ctx: HashingContext = HashingContext.new()
	hash_ctx.start(HashingContext.HASH_SHA256)
	var buffer: PackedByteArray = file.get_buffer(file.get_length())
	hash_ctx.update(buffer)
	file.close()
	return hash_ctx.finish().hex_encode()

func install_apk(apk_path: String) -> void:
	var platform: String = GameSession.detect_platform()
	if platform == "android":
		# On Android, use Intent to open the APK for installation
		# This requires the REQUEST_INSTALL_PACKAGES permission
		var intent = {
			"action": "android.intent.action.VIEW",
			"data": "file://%s" % apk_path,
			"type": "application/vnd.android.package-archive",
			"flags": 0x00000001 | 0x04000000  # FLAG_GRANT_READ_URI_PERMISSION | FLAG_ACTIVITY_NEW_TASK
		}
		# Note: Actual intent launch requires Android plugin or JNI
		push_warning("Android: APK downloaded to %s. Open with file manager to install." % apk_path)
	elif platform == "vr":
		push_warning("Quest detected: sideload the APK manually via ADB or SideQuest: %s" % apk_path)
	else:
		push_warning("PC/desktop: install the APK on your device manually: %s" % apk_path)
	install_launched.emit()

func get_current_version() -> String:
	return _current_version

func get_owner_repo() -> String:
	return _owner_repo

func set_owner_repo(owner_repo: String) -> void:
	_owner_repo = owner_repo

func is_checking() -> bool:
	return _checking

func is_downloading() -> bool:
	return _downloading