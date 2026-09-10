@tool
extends EditorPlugin

const DOCK_SCENE_PATH := "res://addons/AI_Yandex/dock_ui.tscn"
const HTTP_SERVER_SCRIPT := "res://addons/AI_Yandex/http_server.gd"
const CONFIG_SCRIPT := "res://addons/AI_Yandex/config.gd"

var _dock: Control = null
var _http_server: Node = null
var _config: RefCounted = null

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

	print("[AI_Yandex] Plugin loaded. HTTP server on port %d" % _config.godot_port)

func _exit_tree() -> void:
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
