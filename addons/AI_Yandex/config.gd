@tool
extends RefCounted

const CONFIG_PATH := "user://ai_yandex_secure.dat"
const FILE_PASS := "AI_Yandex_v1_local_obfuscation"

signal config_changed()

var api_key: String = ""           # хранится зашифрованным
var folder_id: String = ""         # ID каталога Yandex Cloud (опционально)
var server_url: String = "http://127.0.0.1:8000"
var godot_port: int = 9876
var model: String = "yandexgpt-lite"
var temperature: float = 0.6

func load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var f: FileAccess = FileAccess.open_encrypted_with_pass(CONFIG_PATH, FileAccess.READ, FILE_PASS)
	if f == null:
		push_warning("[AI_Yandex] Cannot open config")
		return
	var txt: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	api_key = str(d.get("api_key", ""))
	folder_id = str(d.get("folder_id", ""))
	server_url = str(d.get("server_url", server_url))
	godot_port = int(d.get("godot_port", godot_port))
	model = str(d.get("model", model))
	temperature = float(d.get("temperature", temperature))

func save_config() -> void:
	var d: Dictionary = {
		"api_key": api_key,
		"folder_id": folder_id,
		"server_url": server_url,
		"godot_port": godot_port,
		"model": model,
		"temperature": temperature
	}
	var txt: String = JSON.stringify(d)
	var f: FileAccess = FileAccess.open_encrypted_with_pass(CONFIG_PATH, FileAccess.WRITE, FILE_PASS)
	if f == null:
		push_error("[AI_Yandex] Cannot write config")
		return
	f.store_string(txt)
	f.close()
	config_changed.emit()

func clear_api_key() -> void:
	api_key = ""
	save_config()

func has_api_key() -> bool:
	return api_key != "" and api_key.length() > 10
