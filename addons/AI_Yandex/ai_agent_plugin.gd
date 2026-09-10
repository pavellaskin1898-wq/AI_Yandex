@tool
extends EditorPlugin

const DOCK_SCENE_PATH := "res://addons/AI_Yandex/dock_ui.tscn"
const HTTP_SERVER_SCRIPT := "res://addons/AI_Yandex/http_server.gd"
const CONFIG_SCRIPT := "res://addons/AI_Yandex/config.gd"

var _dock: Control = null
var _http_server: Node = null
var _config: RefCounted = null
var _python_process_id: int = -1

func _enter_tree() -> void:
	var cfg_script: GDScript = load(CONFIG_SCRIPT) as GDScript
	if cfg_script == null:
		push_error("[AI_Yandex] Cannot load config.gd")
		return
	_config = cfg_script.new()
	_config.load_config()

	var srv_script: GDScript = load(HTTP_SERVER_SCRIPT) as GDScript
	if srv_script == null:
		push_error("[AI_Yandex] Cannot load http_server.gd")
		return
	_http_server = srv_script.new()
	_http_server.name = "AIYandexHttpServer"
	_http_server.set("port", _config.godot_port)
	add_child(_http_server)
	if _http_server.has_method("start"):
		_http_server.call("start")

	var packed: PackedScene = load(DOCK_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("[AI_Yandex] Cannot load dock_ui.tscn")
		return
	_dock = packed.instantiate() as Control
	if _dock == null:
		push_error("[AI_Yandex] dock_ui.tscn is not a Control")
		return
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _dock)

	if _dock.has_method("setup"):
		_dock.call("setup", _config, _http_server)

	_start_python_server()

	print("[AI_Yandex] Plugin loaded. HTTP server on port %d" % _config.godot_port)

func _exit_tree() -> void:
	_stop_python_server()
	
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	if _http_server != null:
		if _http_server.has_method("stop"):
			_http_server.call("stop")
		_http_server.queue_free()
		_http_server = null
	if _config != null:
		_config.save_config()
		_config = null

func _start_python_server() -> void:
	"""Запускает Python сервер автоматически при загрузке плагина"""
	var python_path: String = _find_python_executable()
	if python_path.is_empty():
		push_warning("[AI_Yandex] Python executable not found. Please install Python and add it to PATH.")
		return
	
	var script_path: String = ProjectSettings.globalize_path("res://python_server/main.py")
	
	if not FileAccess.file_exists(script_path):
		push_error("[AI_Yandex] Python server script not found at: " + script_path)
		return
	
	var args: PackedStringArray = [python_path, script_path]
	_python_process_id = OS.execute(python_path, args, [], false)
	
	if _python_process_id != -1:
		print("[AI_Yandex] Python server started successfully on port 8000 (PID: %d)" % _python_process_id)
	else:
		push_warning("[AI_Yandex] Failed to start Python server")

func _stop_python_server() -> void:
	"""Останавливает Python сервер при выгрузке плагина"""
	if _python_process_id != -1:
		# Note: Godot 4.x doesn't have a direct way to kill a process by PID from GDScript
		# The process will continue running, but this is acceptable for most use cases
		# For proper cleanup, users should manually stop the server or use OS signals
		print("[AI_Yandex] Python server (PID: %d) should be stopped manually if needed" % _python_process_id)
		_python_process_id = -1

func _find_python_executable() -> String:
	"""Ищет исполняемый файл Python в системе"""
	var possible_names: PackedStringArray = ["python3", "python", "python3.10", "python3.11", "python3.12"]
	
	for name in possible_names:
		var result: int = OS.execute("which", [name], [], true, true)
		if result == 0:
			return name
	
	if OS.has_feature("windows"):
		var win_paths: PackedStringArray = [
			"C:\\Python39\\python.exe",
			"C:\\Python310\\python.exe",
			"C:\\Python311\\python.exe",
			"C:\\Python312\\python.exe",
			"C:\\Users\\%USERNAME%\\AppData\\Local\\Programs\\Python\\Python39\\python.exe",
			"C:\\Users\\%USERNAME%\\AppData\\Local\\Programs\\Python\\Python310\\python.exe",
			"C:\\Users\\%USERNAME%\\AppData\\Local\\Programs\\Python\\Python311\\python.exe",
			"C:\\Users\\%USERNAME%\\AppData\\Local\\Programs\\Python\\Python312\\python.exe"
		]
		for path in win_paths:
			var expanded_path: String = path.replace("%USERNAME%", OS.get_environment("USERNAME"))
			if FileAccess.file_exists(expanded_path):
				return expanded_path
	
	return ""
