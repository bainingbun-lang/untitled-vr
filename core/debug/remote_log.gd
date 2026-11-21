extends RefCounted

const HOST := "192.168.1.5"
const PORT := 8765
static var retry_at_msec: int = 0


static func crumb(msg: String) -> void:
	send("crumb", "%s | mem=%dMB" % [msg, int(OS.get_static_memory_usage() / 1048576)])


static func send(tag: String, body: String) -> void:
	if Time.get_ticks_msec() < retry_at_msec or DisplayServer.get_name() == "headless":
		return
	var tcp := StreamPeerTCP.new()
	if tcp.connect_to_host(HOST, PORT) != OK:
		retry_at_msec = Time.get_ticks_msec() + 3000
		return
	var t := Time.get_ticks_msec()
	while tcp.get_status() == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() - t < 150:
		tcp.poll()
		OS.delay_msec(5)
	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		retry_at_msec = Time.get_ticks_msec() + 3000
		return
	var data := body.to_utf8_buffer()
	tcp.put_data(("POST /%s HTTP/1.0\r\nHost: x\r\nContent-Length: %d\r\n\r\n" % [tag, data.size()]).to_utf8_buffer())
	tcp.put_data(data)
	tcp.poll()
	OS.delay_msec(15)
	tcp.disconnect_from_host()


static func upload_previous_logs() -> void:
	var dir := DirAccess.open("user://logs")
	if dir == null:
		send("prevlog_none", "sin carpeta user://logs")
		return
	var files: Array = []
	for f in dir.get_files():
		if str(f) != "godot.log":
			files.append(f)
	files.sort()
	if files.is_empty():
		send("prevlog_none", "sin logs previos (solo godot.log)")
		return
	for i in range(maxi(0, files.size() - 2), files.size()):
		var path := "user://logs/" + str(files[i])
		var fa := FileAccess.open(path, FileAccess.READ)
		if fa == null:
			continue
		var len := fa.get_length()
		if len > 60000:
			fa.seek(len - 60000)
		send("prevlog_" + str(files[i]).replace(".", "_"), fa.get_as_text())
