# ===== addons/AI_Yandex/config.gd =====
@tool
class_name AIYandexConfig
extends RefCounted

const CONFIG_PATH := "user://ai_yandex_secure.dat"

# Ключ для симметричного шифрования файла
const FILE_PASS := "AI_Yandex_v1_7f3a9c2e_local_obfuscation"

signal config_changed()

var email: String = ""
var oauth_token: String = ""
var server_url: String = "http://127.0.0.1"
var python_port: int = 8000
var godot_port: int = 9876
var model: String = "yandexgpt-lite"
var temperature: float = 0.6
var max_tokens: int = 2000
var remember_me: bool = true

static var _instance: AIYandexConfig = null

static func get_instance() -> AIYandexConfig:
if _instance == null:
_instance = AIYandexConfig.new()
_instance.load_config()
return _instance

func load_config() -> void:
if not FileAccess.file_exists(CONFIG_PATH):
return
var f := FileAccess.open_encrypted_with_pass(CONFIG_PATH, FileAccess.READ, FILE_PASS)
if f == null:
push_warning("[AI_Yandex] Не удалось открыть зашифрованный конфиг: %s" % error_string(FileAccess.get_open_error()))
return
var txt := f.get_as_text()
f.close()
var parsed: Variant = JSON.parse_string(txt)
if typeof(parsed) != TYPE_DICTIONARY:
push_warning("[AI_Yandex] Конфиг повреждён, игнорирую.")
return
var d: Dictionary = parsed
email = str(d.get("email", ""))
oauth_token = str(d.get("oauth_token", ""))
server_url = str(d.get("server_url", server_url))
python_port = int(d.get("python_port", python_port))
godot_port = int(d.get("godot_port", godot_port))
model = str(d.get("model", model))
temperature = float(d.get("temperature", temperature))
max_tokens = int(d.get("max_tokens", max_tokens))
remember_me = bool(d.get("remember_me", remember_me))

func save_config() -> void:
var d := {
"email": email,
"oauth_token": oauth_token if remember_me else "",
"server_url": server_url,
"python_port": python_port,
"godot_port": godot_port,
"model": model,
"temperature": temperature,
"max_tokens": max_tokens,
"remember_me": remember_me,
}
var txt := JSON.stringify(d)
var f := FileAccess.open_encrypted_with_pass(CONFIG_PATH, FileAccess.WRITE, FILE_PASS)
if f == null:
push_error("[AI_Yandex] Не удалось записать конфиг: %s" % error_string(FileAccess.get_open_error()))
return
f.store_string(txt)
f.close()
config_changed.emit()

func clear_auth() -> void:
email = ""
oauth_token = ""
save_config()

func set_email(val: String) -> void:
email = val
save_config()

func set_oauth_token(val: String) -> void:
oauth_token = val
save_config()

func set_python_url(val: String) -> void:
server_url = val
save_config()

func set_python_port(val: int) -> void:
python_port = val
save_config()

func set_godot_port(val: int) -> void:
godot_port = val
save_config()

func set_model(val: String) -> void:
model = val
save_config()

func set_temperature(val: float) -> void:
temperature = val
save_config()

func set_max_tokens(val: int) -> void:
max_tokens = val
save_config()

func get_email() -> String:
return email

func get_oauth_token() -> String:
return oauth_token

func get_server_url() -> String:
return server_url

func get_python_url() -> String:
return server_url

func get_python_port() -> int:
return python_port

func get_godot_port() -> int:
return godot_port

func get_model() -> String:
return model

func get_temperature() -> float:
return temperature

func get_max_tokens() -> int:
return max_tokens

func is_authenticated() -> bool:
return oauth_token != "" and email != ""

func has_token() -> bool:
return oauth_token != ""
