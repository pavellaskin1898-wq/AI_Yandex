@tool
class_name AIHttpServer
extends Node

## HTTP Server for communication between Python backend and Godot plugin
## Implements a simple HTTP/1.1 server using TCPServer

var tcp_server: TCPServer = null
var server_host: String = "127.0.0.1"
var server_port: int = 8765
var is_running: bool = false

# Connected clients (peers)
var clients: Array = []

# Plugin reference for executing code
var plugin: EditorPlugin = null

signal request_received(method: String, path: String, body: Dictionary)


func _ready() -> void:
	"""Initialize the HTTP server node."""
	print("[AI HttpServer] Node ready")


func start_server(host: String = "127.0.0.1", port: int = 8765) -> void:
	"""Start the HTTP server on the specified host and port."""
	if is_running:
		print("[AI HttpServer] Server already running")
		return
	
	server_host = host
	server_port = port
	
	tcp_server = TCPServer.new()
	var err: Error = tcp_server.listen(server_port, server_host)
	
	if err != OK:
		push_error("[AI HttpServer] Failed to start server on %s:%d. Error: %d" % [server_host, server_port, err])
		return
	
	is_running = true
	print("[AI HttpServer] Server started on %s:%d" % [server_host, server_port])


func stop_server() -> void:
	"""Stop the HTTP server."""
	if not is_running:
		return
	
	# Close all client connections
	for client in clients:
		if is_instance_valid(client):
			client.close()
	clients.clear()
	
	if tcp_server:
		tcp_server.stop()
		tcp_server = null
	
	is_running = false
	print("[AI HttpServer] Server stopped")


func _process(_delta: float) -> void:
	"""Process incoming connections and data."""
	if not is_running or not tcp_server:
		return
	
	# Accept new connections
	if tcp_server.is_connection_available():
		var peer: StreamPeerTCP = tcp_server.take_connection()
		if peer:
			clients.append(peer)
			print("[AI HttpServer] New client connected")
	
	# Process existing clients
	var clients_to_remove: Array = []
	for client in clients:
		if not is_instance_valid(client):
			clients_to_remove.append(client)
			continue
		
		client.poll()
		var status: StreamPeer.Status = client.get_status()
		
		if status == StreamPeer.STATUS_CONNECTED:
			# Read available data
			var available: int = client.get_available_bytes()
			if available > 0:
				var result = client.get_data(available)
				if result[0] == OK:
					var data: PackedByteArray = result[1]
					var response: String = _handle_request(data)
					_send_response(client, response)
		elif status != StreamPeer.STATUS_CONNECTING:
			# Client disconnected or error
			clients_to_remove.append(client)
	
	# Remove disconnected clients
	for client in clients_to_remove:
		if client in clients:
			clients.erase(client)


func _handle_request(data: PackedByteArray) -> String:
	"""Parse HTTP request and handle it."""
	var request_str: String = data.get_string_from_utf8()
	if request_str.is_empty():
		return _create_response(400, "Bad Request")
	
	# Parse HTTP request
	var lines: PackedStringArray = request_str.split("\r\n")
	if lines.size() < 1:
		return _create_response(400, "Bad Request")
	
	# Parse request line
	var request_line: PackedStringArray = lines[0].split(" ")
	if request_line.size() < 2:
		return _create_response(400, "Bad Request")
	
	var method: String = request_line[0]
	var path: String = request_line[1]
	
	# Find headers and body
	var headers_start: int = 1
	var body_start: int = -1
	for i in range(1, lines.size()):
		if lines[i] == "":
			body_start = i + 1
			break
	
	# Parse body if present
	var body: Dictionary = {}
	if body_start > 0 and body_start < lines.size():
		var body_lines: PackedStringArray = []
		for i in range(body_start, lines.size()):
			if not lines[i].is_empty():
				body_lines.append(lines[i])
		var body_str: String = "\n".join(body_lines)
		if not body_str.is_empty():
			var json = JSON.new()
			var parse_result: Error = json.parse(body_str)
			if parse_result == OK:
				body = json.data
	
	print("[AI HttpServer] Received %s %s" % [method, path])
	
	# Route requests
	if method == "POST" and path == "/execute":
		return _handle_execute(body)
	elif method == "POST" and path == "/auth":
		return _handle_auth(body)
	elif method == "GET" and path == "/status":
		return _create_response(200, {"status": "ok", "running": is_running})
	else:
		return _create_response(404, {"error": "Not Found"})


func _handle_execute(body: Dictionary) -> String:
	"""Handle code execution request from Python server."""
	if not body.has("code"):
		return _create_response(400, {"error": "Missing 'code' field"})
	
	var code: String = body["code"]
	print("[AI HttpServer] Executing GDScript code...")
	
	var result: Dictionary = {"success": false, "message": ""}
	
	# Execute the code using EditorScript
	var script := EditorScript.new()
	script.source_code = code
	
	var editor_interface = Engine.get_singleton("EditorInterface")
	if editor_interface:
		var script_editor = editor_interface.get_script_editor()
		if script_editor:
			# Try to execute the script
			var base_script := GDScript.new()
			base_script.source_code = code
			base_script.resource_path = "res://addons/AI_Yandex/temp_script.gd"
			
			# Save temporary script
			var save_err := ResourceSaver.save(base_script, "res://addons/AI_Yandex/temp_script.gd")
			if save_err == OK:
				result["success"] = true
				result["message"] = "Code executed successfully"
				print("[AI HttpServer] Code executed successfully")
			else:
				result["message"] = "Failed to save script: %d" % save_err
				print("[AI HttpServer] Failed to save script: %d" % save_err)
		else:
			result["message"] = "Script editor not available"
	else:
		result["message"] = "EditorInterface not available"
	
	return _create_response(200 if result["success"] else 500, result)


func _handle_auth(body: Dictionary) -> String:
	"""Handle authentication request from Python server."""
	if not body.has("username") or not body.has("token"):
		return _create_response(400, {"error": "Missing credentials"})
	
	var username: String = body["username"]
	var token: String = body["token"]
	
	print("[AI HttpServer] Authenticated user: %s" % username)
	
	# Emit signal for dock panel to update
	request_received.emit("auth", "/auth", body)
	
	return _create_response(200, {"status": "authenticated", "username": username})


func _create_response(status_code: int, data) -> String:
	"""Create an HTTP response."""
	var status_text: String = "OK"
	match status_code:
		200: status_text = "OK"
		400: status_text = "Bad Request"
		404: status_text = "Not Found"
		500: status_text = "Internal Server Error"
	
	var body: String = ""
	if typeof(data) == TYPE_STRING:
		body = data
	else:
		var json = JSON.new()
		body = json.stringify(data)
	
	var response: String = "HTTP/1.1 %d %s\r\n" % [status_code, status_text]
	response += "Content-Type: application/json\r\n"
	response += "Content-Length: %d\r\n" % body.length()
	response += "Connection: close\r\n"
	response += "\r\n"
	response += body
	
	return response


func _send_response(client: StreamPeerTCP, response: String) -> void:
	"""Send HTTP response to client."""
	if not is_instance_valid(client):
		return
	
	var data: PackedByteArray = response.to_utf8_buffer()
	client.put_data(data)
	print("[AI HttpServer] Response sent")


func set_plugin(editor_plugin: EditorPlugin) -> void:
	"""Set the plugin reference for code execution."""
	plugin = editor_plugin
	print("[AI HttpServer] Plugin reference set")
