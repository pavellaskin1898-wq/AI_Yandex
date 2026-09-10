# ===== addons/AI_Yandex/http_server.gd =====
@tool
extends Node
class_name AIHttpServer

signal request_received(method: String, path: String, body: Dictionary)

const DEFAULT_PORT := 9876

var tcp_server: TCPServer = null
var port: int = DEFAULT_PORT
var is_running: bool = false
var _clients: Array[StreamPeerTCP] = []
var _buffers: Dictionary = {}

var editor_interface: EditorInterface = null

func _ready():
	editor_interface = Engine.get_singleton("EditorInterface")

func start(server_port: int = DEFAULT_PORT) -> Error:
	if is_running:
		push_warning("AIHttpServer already running")
		return OK
	
	port = server_port
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(port, "127.0.0.1")
	if err != OK:
		push_error("Failed to start HTTP server on port %d: %s" % [port, error_string(err)])
		return err
	
	is_running = true
	print("[AI Yandex] HTTP server started on 127.0.0.1:%d" % port)
	return OK

func stop():
	is_running = false
	for client in _clients:
		client.disconnect_from_host()
	_clients.clear()
	_buffers.clear()
	if tcp_server:
		tcp_server.stop()
		tcp_server = null
	print("[AI Yandex] HTTP server stopped")

func _exit_tree():
	stop()

func _process(_delta: float):
	if not is_running or tcp_server == null:
		return
	
	# Принимаем новые подключения
	if tcp_server.is_connection_available():
		var client: StreamPeerTCP = tcp_server.take_connection()
		if client:
			client.set_no_delay(true)
			_clients.append(client)
			_buffers[client] = PackedByteArray()
	
	# Обрабатываем существующие подключения
	var clients_to_remove: Array[StreamPeerTCP] = []
	for client in _clients:
		var status = client.get_status()
		if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			clients_to_remove.append(client)
			continue
		
		# Читаем данные
		var available = client.get_available_bytes()
		if available > 0:
			var data = client.get_data(available)
			if data[0] == OK and data[1].size() > 0:
				_buffers[client] += data[1]
				
				# Проверяем полный HTTP запрос (двойной CRLF)
				var buffer = _buffers[client]
				var buffer_str = buffer.get_string_from_utf8()
				if "\r\n\r\n" in buffer_str:
					_parse_request(client, buffer_str)
					_buffers[client] = PackedByteArray()
		
		# Проверяем завершение соединения
		if status == StreamPeerTCP.STATUS_NONE:
			clients_to_remove.append(client)
	
	# Удаляем отключённых клиентов
	for client in clients_to_remove:
		if _buffers.has(client):
			_buffers.erase(client)
		client.disconnect_from_host()
		_clients.erase(client)

func _parse_request(client: StreamPeerTCP, raw_request: String):
	var lines = raw_request.split("\r\n")
	if lines.is_empty():
		return
	
	# Парсим первую строку: METHOD /path HTTP/1.1
	var first_line = lines[0].split(" ")
	if first_line.size() < 2:
		return
	
	var method = first_line[0]
	var path = first_line[1]
	
	# Находим заголовок Content-Length
	var content_length = 0
	var body_start = -1
	for i in range(1, lines.size()):
		var line = lines[i]
		if line.is_empty():
			body_start = i + 1
			break
		if line.begins_with("Content-Length:"):
			content_length = int(line.split(":")[1].strip_edges())
	
	# Извлекаем тело
	var body_str = ""
	if body_start > 0 and content_length > 0:
		var body_lines = lines.slice(body_start)
		body_str = "\r\n".join(body_lines)
	
	# Парсим JSON тело
	var body_dict = {}
	if not body_str.is_empty():
		var json = JSON.new()
		var parse_err = json.parse(body_str)
		if parse_err == OK:
			body_dict = json.data
	
	# Обрабатываем запрос
	var response_body = ""
	var status_code = 200
	
	match path:
		"/execute":
			if method == "POST" and body_dict.has("code"):
				response_body = _execute_code(body_dict["code"])
			else:
				status_code = 400
				response_body = '{"error": "Invalid request"}'
		"/create_file":
			if method == "POST" and body_dict.has("path") and body_dict.has("content"):
				response_body = _create_file(body_dict["path"], body_dict["content"])
			else:
				status_code = 400
				response_body = '{"error": "Invalid request"}'
		"/health":
			response_body = '{"status": "ok", "running": true}'
		_:
			status_code = 404
			response_body = '{"error": "Not found"}'
	
	# Отправляем ответ
	var response = "HTTP/1.1 %d OK\r\n" % status_code
	response += "Content-Type: application/json\r\n"
	response += "Content-Length: %d\r\n" % response_body.length()
	response += "Access-Control-Allow-Origin: *\r\n"
	response += "Connection: close\r\n"
	response += "\r\n"
	response += response_body
	
	var response_bytes = response.to_utf8_buffer()
	client.put_data(response_bytes)
	client.disconnect_from_host()

func _execute_code(code: String) -> String:
	if editor_interface == null:
		return '{"error": "EditorInterface not available", "status": "error"}'
	
	var output = ""
	var success = true
	
	# Создаём временный скрипт для выполнения
	var script = EditorScript.new()
	script.source_code = code
	
	# Пытаемся выполнить код
	var base_script = GDScript.new()
	base_script.source_code = code
	
	var err = base_script.reload()
	if err != OK:
		output = "Script compilation error: %s" % error_string(err)
		success = false
	else:
		# Пробуем создать экземпляр и вызвать _ready если есть
		var instance = base_script.new()
		if instance and instance.has_method("_run"):
			var result = instance._run()
			if result != null:
				output = str(result)
		else:
			output = "Code executed successfully (no _run method found)"
		instance.free()
	
	return '{"status": "%s", "output": "%s"}' % ["ok" if success else "error", _escape_json(output)]

func _create_file(file_path: String, content: String) -> String:
	var full_path = file_path if file_path.begins_with("res://") else "res://" + file_path
	
	# Создаём директорию если нужно
	var dir = DirAccess.open("res://")
	if dir == null:
		return '{"error": "Cannot open res:// directory", "status": "error"}'
	
	var path_parts = full_path.split("/")
	if path_parts.size() > 2:
		var dir_path = "/".join(path_parts.slice(0, path_parts.size() - 1))
		dir.make_dir_recursive(dir_path.replace("res://", ""))
	
	# Записываем файл
	var file = FileAccess.open(full_path, FileAccess.WRITE)
	if file == null:
		return '{"error": "Cannot create file: %s", "status": "error"}' % full_path
	
	file.store_string(content)
	file.close()
	
	# Обновляем файловую систему
	EditorInterface.get_resource_filesystem().scan()
	
	return '{"status": "ok", "path": "%s"}' % full_path

func _escape_json(text: String) -> String:
	text = text.replace("\\", "\\\\")
	text = text.replace("\"", "\\\"")
	text = text.replace("\n", "\\n")
	text = text.replace("\r", "\\r")
	text = text.replace("\t", "\\t")
	return text
