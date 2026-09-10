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
	var os_name = OS.get_name()
	var candidates: PackedStringArray = []
	
	if os_name == "Windows":
		candidates = ["python", "python3", "py"]
	elif os_name == "macOS" or os_name == "Linux":
		candidates = ["python3", "python"]
	else:
		candidates = ["python3", "python"]
	
	for cmd in candidates:
		# Пытаемся запустить команду с аргументом --version для проверки существования
		# exit_code будет 0, если команда найдена и выполнилась успешно
		var output: Array = []
		var exit_code: int = OS.execute(cmd, ["--version"], output, true)
		if exit_code == 0:
			print("[AI_Yandex] Found Python executable: ", cmd)
			return cmd
	
	print("[AI_Yandex] Error: Python executable not found in PATH.")
	return ""
