@tool
extends RefCounted

const CONFIG_PATH := "user://ai_yandex_config.json"

var api_key: String = ""
var folder_id: String = ""
var server_url: String = "http://127.0.0.1:8000"
var godot_port: int = 9876
var model: String = "yandexgpt-lite"
var temperature: float = 0.7


func load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return

	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)

	if file == null:
		push_error("[AI_Yandex] Cannot open config file")
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_text)

	if err != OK:
		push_error("[AI_Yandex] Config parse error: " + json.get_error_message())
		return

	var data: Variant = json.data

	if not data is Dictionary:
		return

	var cfg: Dictionary = data

	api_key = str(cfg.get("api_key", ""))
	folder_id = str(cfg.get("folder_id", ""))
	server_url = str(cfg.get("server_url", "http://127.0.0.1:8000"))
	godot_port = int(cfg.get("godot_port", 9876))
	model = str(cfg.get("model", "yandexgpt-lite"))
	temperature = float(cfg.get("temperature", 0.7))


func save_config() -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)

	if file == null:
		push_error("[AI_Yandex] Cannot write config file")
		return

	var cfg := {
		"api_key": api_key,
		"folder_id": folder_id,
		"server_url": server_url,
		"godot_port": godot_port,
		"model": model,
		"temperature": temperature
	}

	file.store_string(JSON.stringify(cfg, "\t"))
	file.close()


func has_api_key() -> bool:
	return api_key.strip_edges() != "" and api_key.length() >= 10


func clear_api_key() -> void:
	api_key = ""
	folder_id = ""
	save_config()
