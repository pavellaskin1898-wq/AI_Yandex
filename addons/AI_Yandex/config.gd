# ===== addons/AI_Yandex/config.gd =====
@tool
extends RefCounted
class_name YandexConfig

const CONFIG_PATH := "user://ai_yandex.cfg"
const ENCRYPTION_KEY := "ai_yandex_secret_key_32bytes!!"

static var _instance: YandexConfig = null
static var _crypto: Crypto = null
static var _key: PackedByteArray = []

static func get_instance() -> YandexConfig:
	if _instance == null:
		_instance = YandexConfig.new()
		_crypto = Crypto.new()
		_key = _hash_key(ENCRYPTION_KEY)
	return _instance

static func _hash_key(key: String) -> PackedByteArray:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(key.to_utf8_buffer())
	return ctx.finish()

var config_file: ConfigFile

func _init():
	config_file = ConfigFile.new()
	var err = config_file.load(CONFIG_PATH)
	if err != OK:
		# Создаём новый конфиг
		config_file.set_value("auth", "email", "")
		config_file.set_value("auth", "oauth_token", "")
		config_file.set_value("auth", "iam_token", "")
		config_file.set_value("settings", "python_url", "http://127.0.0.1")
		config_file.set_value("settings", "python_port", 8000)
		config_file.set_value("settings", "godot_port", 9876)
		config_file.set_value("settings", "model", "yandexgpt-lite")
		config_file.set_value("settings", "temperature", 0.7)
		config_file.set_value("settings", "max_tokens", 2000)
		save()

func save() -> Error:
	return config_file.save(CONFIG_PATH)

func get_email() -> String:
	return config_file.get_value("auth", "email", "")

func set_email(email: String):
	config_file.set_value("auth", "email", email)
	save()

func get_oauth_token() -> String:
	return config_file.get_value("auth", "oauth_token", "")

func set_oauth_token(token: String):
	config_file.set_value("auth", "oauth_token", _encrypt(token))
	save()

func get_iam_token() -> String:
	return config_file.get_value("auth", "iam_token", "")

func set_iam_token(token: String):
	config_file.set_value("auth", "iam_token", _encrypt(token))
	save()

func get_python_url() -> String:
	return config_file.get_value("settings", "python_url", "http://127.0.0.1")

func set_python_url(url: String):
	config_file.set_value("settings", "python_url", url)
	save()

func get_python_port() -> int:
	return config_file.get_value("settings", "python_port", 8000)

func set_python_port(port: int):
	config_file.set_value("settings", "python_port", port)
	save()

func get_godot_port() -> int:
	return config_file.get_value("settings", "godot_port", 9876)

func set_godot_port(port: int):
	config_file.set_value("settings", "godot_port", port)
	save()

func get_model() -> String:
	return config_file.get_value("settings", "model", "yandexgpt-lite")

func set_model(model: String):
	config_file.set_value("settings", "model", model)
	save()

func get_temperature() -> float:
	return config_file.get_value("settings", "temperature", 0.7)

func set_temperature(temp: float):
	config_file.set_value("settings", "temperature", temp)
	save()

func get_max_tokens() -> int:
	return config_file.get_value("settings", "max_tokens", 2000)

func set_max_tokens(tokens: int):
	config_file.set_value("settings", "max_tokens", tokens)
	save()

func _encrypt(data: String) -> String:
	if _crypto == null or _key.is_empty():
		return data
	var encrypted = _crypto.encrypt(_key, [], data.to_utf8_buffer())
	if encrypted:
		return encrypted.hex_encode()
	return data

func _decrypt(data: String) -> String:
	if _crypto == null or _key.is_empty():
		return data
	var decoded = Marshalls.hex_to_bytes(data)
	var decrypted = _crypto.decrypt(_key, [], decoded)
	if decrypted:
		return decrypted.get_string_from_utf8()
	return ""

func is_authenticated() -> bool:
	return not get_oauth_token().is_empty()

func clear_auth():
	config_file.set_value("auth", "email", "")
	config_file.set_value("auth", "oauth_token", "")
	config_file.set_value("auth", "iam_token", "")
	save()
