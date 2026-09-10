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

	# ---------------------------------------------------------
	# Локальный HTTP-сервер Godot
	# ---------------------------------------------------------
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

	# ---------------------------------------------------------
	# Dock
	# ---------------------------------------------------------
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

	# ---------------------------------------------------------
	# Python backend
	# ---------------------------------------------------------
	_start_python_server()

	print(
		"[AI_Yandex] Plugin loaded. Godot HTTP server: 127.0.0.1:%d"
		% _config.godot_port
	)


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


# ============================================================
# PYTHON SERVER
# ============================================================

func _start_python_server() -> void:
	print("[AI_Yandex] Starting Python backend...")

	var python_path: String = _find_python_executable()

	if python_path.is_empty():
		push_error(
			"[AI_Yandex] Python executable not found. "
			+ "Install Python 3.9+ and make sure it is available."
		)
		return

	var script_path: String = ProjectSettings.globalize_path(
		"res://python_server/main.py"
	)

	if not FileAccess.file_exists(script_path):
		push_error(
			"[AI_Yandex] Python server script not found: "
			+ script_path
		)
		return

	print("[AI_Yandex] Python executable: ", python_path)
	print("[AI_Yandex] Python script: ", script_path)

	var args: PackedStringArray = [
		script_path,
		"--host",
		"127.0.0.1",
		"--port",
		"8000"
	]

	# ВАЖНО:
	# OS.execute() здесь НЕ используем.
	# create_process() запускает Python независимо
	# и возвращает настоящий PID.
	_python_process_id = OS.create_process(
		python_path,
		args,
		true
	)

	if _python_process_id == -1:
		push_error(
			"[AI_Yandex] Failed to create Python process."
		)
		return

	print(
		"[AI_Yandex] Python backend process created. PID: %d"
		% _python_process_id
	)


func _stop_python_server() -> void:
	if _python_process_id == -1:
		return

	if OS.is_process_running(_python_process_id):
		print(
			"[AI_Yandex] Stopping Python backend. PID: %d"
			% _python_process_id
		)

		OS.kill(_python_process_id)

	_python_process_id = -1


# ============================================================
# FIND PYTHON
# ============================================================

func _find_python_executable() -> String:
	var project_path: String = ProjectSettings.globalize_path("res://")

	var candidates: PackedStringArray = []

	if OS.get_name() == "Windows":
		candidates = [
			project_path.path_join("python_server/venv/Scripts/python.exe"),
			project_path.path_join("venv/Scripts/python.exe")
		]
	else:
		candidates = [
			project_path.path_join("python_server/venv/bin/python3"),
			project_path.path_join("python_server/venv/bin/python"),
			project_path.path_join("venv/bin/python3"),
			project_path.path_join("venv/bin/python")
		]

	# Сначала ищем Python из virtualenv.
	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			print("[AI_Yandex] Found virtualenv Python: ", candidate)
			return candidate

	# ---------------------------------------------------------
	# Системный Python
	# ---------------------------------------------------------

	if OS.get_name() == "Windows":
		var output: Array = []
		var exit_code: int = OS.execute(
			"where.exe",
			["python"],
			output,
			true
		)

		if exit_code == 0 and not output.is_empty():
			var text: String = str(output[0])

			for line in text.split("\n"):
				var path: String = line.strip_edges()

				if path.ends_with(".exe") and FileAccess.file_exists(path):
					print("[AI_Yandex] Found system Python: ", path)
					return path

		# Python Launcher
		var py_output: Array = []
		var py_exit_code: int = OS.execute(
			"where.exe",
			["py"],
			py_output,
			true
		)

		if py_exit_code == 0 and not py_output.is_empty():
			var py_path: String = str(py_output[0]).strip_edges()

			if FileAccess.file_exists(py_path):
				print("[AI_Yandex] Found Python launcher: ", py_path)
				return py_path

	else:
		var output: Array = []
		var exit_code: int = OS.execute(
			"which",
			["python3"],
			output,
			true
		)

		if exit_code == 0 and not output.is_empty():
			var path: String = str(output[0]).strip_edges()

			if FileAccess.file_exists(path):
				print("[AI_Yandex] Found system Python: ", path)
				return path

		var python_output: Array = []
		var python_exit_code: int = OS.execute(
			"which",
			["python"],
			python_output,
			true
		)

		if python_exit_code == 0 and not python_output.is_empty():
			var python_path: String = str(
				python_output[0]
			).strip_edges()

			if FileAccess.file_exists(python_path):
				print(
					"[AI_Yandex] Found system Python: ",
					python_path
				)
				return python_path

	push_error(
		"[AI_Yandex] Python executable was not found."
	)

	return ""
