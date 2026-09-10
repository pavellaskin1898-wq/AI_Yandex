@tool
extends Node

signal code_received(code: String, file_path: String)

var port: int = 9876
var _server: TCPServer = null
var _clients: Array = []
var _running: bool = false

func _ready() -> void:
	set_process(true)

func start() -> void:
	if _running:
		return
	_server = TCPServer.new()
	var err: int = _server.listen(port, "127.0.0.1")
	if err != OK:
		push_error("[AI_Yandex] Failed to listen on port %d: %s" % [port, error_string(err)])
		_server = null
		return
	_running = true
	print("[AI_Yandex] HTTP server listening on 127.0.0.1:%d" % port)

func stop() -> void:
	for c in _clients:
		var p: StreamPeerTCP = c.get("peer", null)
		if p != null:
			p.disconnect_from_host()
	_clients.clear()
	if _server != null:
		_server.stop()
		_server = null
	_running = false

func _process(_delta: float) -> void:
	if not _running or _server == null:
		return
	while _server.is_connection_available():
		var peer: StreamPeerTCP = _server.take_connection()
		if peer != null:
			_clients.append({
				"peer": peer,
				"buf": PackedByteArray(),
				"deadline": Time.get_ticks_msec() + 5000
			})
	var still_alive: Array = []
	for c in _clients:
		var peer: StreamPeerTCP = c["peer"]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue
		var avail: int = peer.get_available_bytes()
		if avail > 0:
			var chunk: Array = peer.get_partial_data(avail)
			if chunk[0] == OK:
				var buf: PackedByteArray = c["buf"]
				buf.append_array(chunk[1])
				c["buf"] = buf
		var buf2: PackedByteArray = c["buf"]
		var text: String = buf2.get_string_from_utf8()
		var header_end: int = text.find("\r\n\r\n")
		if header_end != -1:
			_handle_request(peer, text)
			continue
		if Time.get_ticks_msec() > int(c["deadline"]):
			peer.disconnect_from_host()
			continue
		still_alive.append(c)
	_clients = still_alive

func _handle_request(peer: StreamPeerTCP, raw: String) -> void:
	var header_end: int = raw.find("\r\n\r\n")
	var head: String = raw.substr(0, header_end)
	var body: String = raw.substr(header_end + 4)
	var lines: PackedStringArray = head.split("\r\n")
	if lines.is_empty():
		_send(peer, 400, {"error": "bad request"})
		return
	var request_line: PackedStringArray = lines[0].split(" ")
	if request_line.size() < 2:
		_send(peer, 400, {"error": "bad request line"})
		return
	var method: String = request_line[0]
	var path: String = request_line[1]

	if method == "GET" and path == "/health":
		_send(peer, 200, {"status": "ok", "port": port})
		return

	if method == "POST" and path == "/execute":
		var parsed: Variant = JSON.parse_string(body)
		if typeof(parsed) != TYPE_DICTIONARY:
			_send(peer, 400, {"error": "invalid json"})
			return
		var d: Dictionary = parsed
		var code: String = str(d.get("code", ""))
		var file_path: String = str(d.get("file_path", ""))
		code_received.emit(code, file_path)
		_send(peer, 200, {"status": "queued", "len": code.length()})
		return

	_send(peer, 404, {"error": "not found"})

func _send(peer: StreamPeerTCP, code: int, payload: Dictionary) -> void:
	var body: String = JSON.stringify(payload)
	var reason: String = "OK"
	if code == 400:
		reason = "Bad Request"
	elif code == 404:
		reason = "Not Found"
	var resp: String = "HTTP/1.1 %d %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [code, reason, body.length(), body]
	var bytes: PackedByteArray = resp.to_utf8_buffer()
	peer.put_data(bytes)
	peer.disconnect_from_host()
