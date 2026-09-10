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

	var err: int = _server.listen(
		port,
		"127.0.0.1"
	)

	if err != OK:
		push_error(
			"[AI_Yandex] Failed to listen on port %d: %s"
			% [port, error_string(err)]
		)

		_server = null
		return

	_running = true

	print(
		"[AI_Yandex] HTTP server listening on "
		+ "127.0.0.1:%d"
		% port
	)


func stop() -> void:
	for client in _clients:
		var peer: StreamPeerTCP = client["peer"]

		if peer != null:
			peer.disconnect_from_host()

	_clients.clear()

	if _server != null:
		_server.stop()
		_server = null

	_running = false


func _process(_delta: float) -> void:
	if not _running or _server == null:
		return

	# ---------------------------------------------------------
	# Accept new clients
	# ---------------------------------------------------------

	while _server.is_connection_available():
		var peer: StreamPeerTCP = (
			_server.take_connection()
		)

		if peer != null:
			_clients.append({
				"peer": peer,
				"buf": PackedByteArray(),
				"deadline": Time.get_ticks_msec() + 10000
			})

	# ---------------------------------------------------------
	# Process clients
	# ---------------------------------------------------------

	var still_alive: Array = []

	for client in _clients:
		var peer: StreamPeerTCP = client["peer"]

		peer.poll()

		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue

		var available: int = (
			peer.get_available_bytes()
		)

		if available > 0:
			var chunk: Array = (
				peer.get_partial_data(available)
			)

			if chunk.size() >= 2 and chunk[0] == OK:
				var buf: PackedByteArray = client["buf"]

				buf.append_array(chunk[1])

				client["buf"] = buf

		var buffer: PackedByteArray = client["buf"]

		var header_end: int = (
			_find_header_end(buffer)
		)

		if header_end != -1:
			var parsed := _parse_http_request(buffer)

			if parsed["complete"]:
				_handle_request(
					peer,
					parsed["method"],
					parsed["path"],
					parsed["body"]
				)

				continue

		if Time.get_ticks_msec() > int(
			client["deadline"]
		):
			_send(
				peer,
				408,
				{"error": "request timeout"}
			)

			continue

		still_alive.append(client)

	_clients = still_alive


# ============================================================
# HTTP PARSER
# ============================================================

func _find_header_end(
	buffer: PackedByteArray
) -> int:
	if buffer.size() < 4:
		return -1

	for i in range(
		0,
		buffer.size() - 3
	):
		if (
			buffer[i] == 13
			and buffer[i + 1] == 10
			and buffer[i + 2] == 13
			and buffer[i + 3] == 10
		):
			return i

	return -1


func _parse_http_request(
	buffer: PackedByteArray
) -> Dictionary:
	var header_end: int = (
		_find_header_end(buffer)
	)

	if header_end == -1:
		return {
			"complete": false
		}

	var header_bytes: PackedByteArray = (
		buffer.slice(0, header_end)
	)

	var header_text: String = (
		header_bytes.get_string_from_utf8()
	)

	var lines: PackedStringArray = (
		header_text.split("\r\n")
	)

	if lines.is_empty():
		return {
			"complete": false
		}

	var request_line: PackedStringArray = (
		lines[0].split(" ")
	)

	if request_line.size() < 2:
		return {
			"complete": false
		}

	var content_length: int = 0

	for i in range(1, lines.size()):
		var line: String = lines[i]

		var colon: int = line.find(":")

		if colon == -1:
			continue

		var name: String = (
			line.substr(0, colon)
			.strip_edges()
			.to_lower()
		)

		var value: String = (
			line.substr(colon + 1)
			.strip_edges()
		)

		if name == "content-length":
			content_length = int(value)

	var body_start: int = header_end + 4
	var available_body: int = (
		buffer.size() - body_start
	)

	# Ждём весь body согласно Content-Length.
	if available_body < content_length:
		return {
			"complete": false
		}

	var body_bytes: PackedByteArray = (
		buffer.slice(
			body_start,
			body_start + content_length
		)
	)

	return {
		"complete": true,
		"method": request_line[0],
		"path": request_line[1],
		"body": body_bytes.get_string_from_utf8()
	}


# ============================================================
# REQUEST HANDLER
# ============================================================

func _handle_request(
	peer: StreamPeerTCP,
	method: String,
	path: String,
	body: String
) -> void:
	# ---------------------------------------------------------
	# GET /health
	# ---------------------------------------------------------

	if method == "GET" and path == "/health":
		_send(
			peer,
			200,
			{
				"status": "ok",
				"port": port
			}
		)
		return

	# ---------------------------------------------------------
	# POST /execute
	# ---------------------------------------------------------

	if method == "POST" and path == "/execute":
		var parsed: Variant = (
			JSON.parse_string(body)
		)

		if typeof(parsed) != TYPE_DICTIONARY:
			_send(
				peer,
				400,
				{"error": "invalid json"}
			)
			return

		var data: Dictionary = parsed

		var code: String = str(
			data.get("code", "")
		)

		var file_path: String = str(
			data.get("file_path", "")
		)

		if code.strip_edges() == "":
			_send(
				peer,
				400,
				{"error": "empty code"}
			)
			return

		code_received.emit(
			code,
			file_path
		)

		_send(
			peer,
			200,
			{
				"status": "queued",
				"len": code.length(),
				"file_path": file_path
			}
		)

		return

	# ---------------------------------------------------------
	# Not found
	# ---------------------------------------------------------

	_send(
		peer,
		404,
		{"error": "not found"}
	)


# ============================================================
# RESPONSE
# ============================================================

func _send(
	peer: StreamPeerTCP,
	status_code: int,
	payload: Dictionary
) -> void:
	var body: String = JSON.stringify(payload)

	var reason: String = "OK"

	match status_code:
		200:
			reason = "OK"
		400:
			reason = "Bad Request"
		404:
			reason = "Not Found"
		408:
			reason = "Request Timeout"
		500:
			reason = "Internal Server Error"

	var body_bytes: PackedByteArray = (
		body.to_utf8_buffer()
	)

	var response: String = (
		"HTTP/1.1 %d %s\r\n"
		+ "Content-Type: application/json; charset=utf-8\r\n"
		+ "Content-Length: %d\r\n"
		+ "Connection: close\r\n"
		+ "\r\n"
	) % [
		status_code,
		reason,
		body_bytes.size()
	]

	var response_bytes: PackedByteArray = (
		response.to_utf8_buffer()
	)

	response_bytes.append_array(body_bytes)

	peer.put_data(response_bytes)
	peer.disconnect_from_host()
