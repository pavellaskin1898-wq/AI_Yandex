# ===== addons/AI_Yandex/yandex_client.gd =====
@tool
extends Node
class_name YandexClient

const DEFAULT_TIMEOUT := 30.0

var http_request: HTTPRequest = null
var python_url: String = "http://127.0.0.1"
var python_port: int = 8000
var current_request_id: int = -1

signal login_completed(success: bool, email: String, error: String)
signal chat_completed(success: bool, response: Dictionary, error: String)
signal generate_game_completed(success: bool, files: Array, error: String)

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func set_server(url: String, port: int):
	python_url = url
	python_port = port

func _get_base_url() -> String:
	return "%s:%d" % [python_url, python_port]

func login(email: String, password: String) -> void:
	var url = "%s/login" % _get_base_url()
	var headers = ["Content-Type: application/json"]
	
	var body = {
		"email": email,
		"password": password
	}
	
	var json = JSON.stringify(body)
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, json)
	if err != OK:
		login_completed.emit(false, "", "Failed to send request: %s" % error_string(err))
		return
	
	current_request_id = -1  # Will be set by signal

func chat(prompt: String, context: Dictionary = {}, token: String = "") -> void:
	var url = "%s/chat" % _get_base_url()
	var headers = ["Content-Type: application/json"]
	
	var body = {
		"prompt": prompt,
		"context": context,
		"token": token
	}
	
	var json = JSON.stringify(body)
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, json)
	if err != OK:
		chat_completed.emit(false, {}, "Failed to send request: %s" % error_string(err))
		return

func generate_game(task: String, token: String = "") -> void:
	var url = "%s/generate_game" % _get_base_url()
	var headers = ["Content-Type: application/json"]
	
	var body = {
		"task": task,
		"token": token
	}
	
	var json = JSON.stringify(body)
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, json)
	if err != OK:
		generate_game_completed.emit(false, [], "Failed to send request: %s" % error_string(err))
		return

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var response_str = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_err = json.parse(response_str)
	var data = json.data if parse_err == OK else {}
	
	if result != HTTPRequest.RESULT_SUCCESS:
		login_completed.emit(false, "", "Request failed: %s" % error_string(result))
		chat_completed.emit(false, {}, "Request failed: %s" % error_string(result))
		generate_game_completed.emit(false, [], "Request failed: %s" % error_string(result))
		return
	
	if response_code >= 400:
		var error_msg = data.get("detail", data.get("error", "Unknown error")) if data is Dictionary else "HTTP %d" % response_code
		login_completed.emit(false, "", error_msg)
		chat_completed.emit(false, {}, {"error": error_msg})
		generate_game_completed.emit(false, [], error_msg)
		return
	
	# Определяем тип ответа по наличию полей
	if data.has("token") and data.has("email"):
		login_completed.emit(true, data.get("email", ""), "")
	elif data.has("response") or data.has("text"):
		chat_completed.emit(true, data, "")
	elif data.has("files"):
		generate_game_completed.emit(true, data.get("files", []), "")
	else:
		# Неизвестный формат, отправляем как chat response
		chat_completed.emit(true, data, "")
