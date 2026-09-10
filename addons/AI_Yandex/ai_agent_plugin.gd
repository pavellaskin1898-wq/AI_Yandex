@tool
extends EditorPlugin

## AI Yandex Agent Plugin for Godot 4.6.3
## Main plugin script that manages the dock panel and HTTP server

var dock_panel: Control
var http_server: Node
const DOCK_UI_SCENE = preload("res://addons/AI_Yandex/dock_ui.tscn")
const HTTP_SERVER_SCRIPT = preload("res://addons/AI_Yandex/http_server.gd")

# Server configuration
const SERVER_HOST: String = "127.0.0.1"
const SERVER_PORT: int = 8765


func _enter_tree() -> void:
	"""Called when the plugin is enabled."""
	print("[AI Yandex] Plugin enabled")
	
	# Create and add the dock panel
	dock_panel = DOCK_UI_SCENE.instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock_panel)
	
	# Initialize reference to dock UI script
	if dock_panel.has_method("set_plugin"):
		dock_panel.set_plugin(self)
	
	# Create and start HTTP server
	http_server = HTTP_SERVER_SCRIPT.new()
	http_server.name = "AIHttpServer"
	add_child(http_server)
	
	if http_server.has_method("start_server"):
		http_server.start_server(SERVER_HOST, SERVER_PORT)
	
	# Pass server reference to dock panel
	if dock_panel.has_method("set_http_server"):
		dock_panel.set_http_server(http_server)


func _exit_tree() -> void:
	"""Called when the plugin is disabled."""
	print("[AI Yandex] Plugin disabled")
	
	# Stop HTTP server
	if http_server:
		if http_server.has_method("stop_server"):
			http_server.stop_server()
		http_server.queue_free()
		http_server = null
	
	# Remove dock panel
	if dock_panel:
		remove_control_from_docks(dock_panel)
		dock_panel.queue_free()
		dock_panel = null


func get_dock_panel() -> Control:
	"""Returns the dock panel control."""
	return dock_panel


func get_http_server() -> Node:
	"""Returns the HTTP server node."""
	return http_server


func log_message(message: String) -> void:
	"""Logs a message to the dock panel if available."""
	if dock_panel and dock_panel.has_method("add_log"):
		dock_panel.add_log(message)
