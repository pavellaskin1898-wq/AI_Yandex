@tool
extends Control

## Dock UI for AI Yandex Agent Plugin
## Handles user interaction with the plugin

var http_server: Node = null
var plugin: EditorPlugin = null
var is_authenticated: bool = false
var current_username: String = ""

# Python server configuration
const PYTHON_SERVER_URL: String = "http://127.0.0.1:8000"

# UI Elements (auto-loaded from scene)
@onready var login_line_edit: LineEdit = $VBoxContainer/AuthVBox/LoginLineEdit
@onready var password_line_edit: LineEdit = $VBoxContainer/AuthVBox/PasswordLineEdit
@onready var login_button: Button = $VBoxContainer/AuthVBox/LoginButton
@onready var status_label: Label = $VBoxContainer/AuthVBox/StatusLabel
@onready var prompt_text_edit: TextEdit = $VBoxContainer/ActionsVBox/PromptTextEdit
@onready var generate_button: Button = $VBoxContainer/ActionsVBox/GenerateButton
@onready var execute_code_button: Button = $VBoxContainer/ActionsVBox/ExecuteCodeButton
@onready var log_text_edit: TextEdit = $VBoxContainer/LogTextEdit
@onready var clear_log_button: Button = $VBoxContainer/ClearLogButton


func _ready() -> void:
	"""Initialize the dock UI."""
	print("[AI DockUI] Ready")
	
	# Connect button signals
	login_button.pressed.connect(_on_login_pressed)
	generate_button.pressed.connect(_on_generate_pressed)
	execute_code_button.pressed.connect(_on_execute_code_pressed)
	clear_log_button.pressed.connect(_on_clear_log_pressed)
	
	# Set initial state
	_update_ui_state()
	
	add_log("AI Yandex Agent initialized")
	add_log("Python server URL: %s" % PYTHON_SERVER_URL)


func set_plugin(editor_plugin: EditorPlugin) -> void:
	"""Set the plugin reference."""
	plugin = editor_plugin
	print("[AI DockUI] Plugin reference set")


func set_http_server(server: Node) -> void:
	"""Set the HTTP server reference."""
	http_server = server
	print("[AI DockUI] HTTP server reference set")


func add_log(message: String) -> void:
	"""Add a message to the log."""
	var timestamp: String = Time.get_datetime_string_from_system(false, true).substr(0, 12)
	log_text_edit.text += "[%s] %s\n" % [timestamp, message]
	log_text_edit.scroll_vertical = log_text_edit.get_line_count()


func _update_ui_state() -> void:
	"""Update UI based on authentication state."""
	if is_authenticated:
		status_label.text = "Вошёл как: %s" % current_username
		status_label.add_theme_color_override("font_color", Color.GREEN)
		login_button.text = "Выйти"
		login_line_edit.editable = false
		password_line_edit.editable = false
	else:
		status_label.text = "Not logged in"
		status_label.remove_theme_color_override("font_color")
		login_button.text = "Войти"
		login_line_edit.editable = true
		password_line_edit.editable = true


func _on_login_pressed() -> void:
	"""Handle login button press."""
	if is_authenticated:
		# Logout
		is_authenticated = false
		current_username = ""
		add_log("Logged out")
		_update_ui_state()
		return
	
	# Login
	var username: String = login_line_edit.text.strip_edges()
	var password: String = password_line_edit.text.strip_edges()
	
	if username.is_empty() or password.is_empty():
		add_log("Error: Please enter both login and password")
		return
	
	add_log("Attempting to login as: %s" % username)
	
	# Send authentication request to Python server
	await _send_auth_request(username, password)


func _on_generate_pressed() -> void:
	"""Handle generate game button press."""
	if not is_authenticated:
		add_log("Error: Please login first")
		return
	
	var prompt: String = prompt_text_edit.text.strip_edges()
	if prompt.is_empty():
		add_log("Error: Please enter a game generation prompt")
		return
	
	add_log("Sending generation request...")
	add_log("Prompt: %s" % prompt)
	
	# Send generation request to Python server
	await _send_generation_request(prompt)


func _on_execute_code_pressed() -> void:
	"""Handle execute code button press."""
	add_log("Execute code requested - waiting for code from Python server")
	# This button is mainly for demonstration
	# Actual code execution happens when Python server sends code


func _on_clear_log_pressed() -> void:
	"""Clear the log."""
	log_text_edit.text = ""
	add_log("Log cleared")


func _send_auth_request(username: String, password: String) -> void:
	"""Send authentication request to Python server."""
	var http_request: HTTPRequest = HTTPRequest.new()
	add_child(http_request)
	
	var url: String = "%s/auth" % PYTHON_SERVER_URL
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var body: Dictionary = {
		"username": username,
		"password": password
	}
	
	var json = JSON.new()
	var body_str: String = json.stringify(body)
	
	var err: Error = http_request.request(url, headers, HTTPClient.METHOD_POST, body_str)
	if err != OK:
		add_log("Error sending auth request: %d" % err)
		http_request.queue_free()
		return
	
	# Wait for response
	var result = await http_request.request_completed
	http_request.queue_free()
	
	if result[1] == 200:
		is_authenticated = true
		current_username = username
		add_log("Successfully authenticated as: %s" % username)
		_update_ui_state()
	else:
		add_log("Authentication failed: HTTP %d" % result[1])


func _send_generation_request(prompt: String) -> void:
	"""Send game generation request to Python server."""
	var http_request: HTTPRequest = HTTPRequest.new()
	add_child(http_request)
	
	var url: String = "%s/generate" % PYTHON_SERVER_URL
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var body: Dictionary = {
		"prompt": prompt,
		"username": current_username
	}
	
	var json = JSON.new()
	var body_str: String = json.stringify(body)
	
	var err: Error = http_request.request(url, headers, HTTPClient.METHOD_POST, body_str)
	if err != OK:
		add_log("Error sending generation request: %d" % err)
		http_request.queue_free()
		return
	
	# Wait for response
	var result = await http_request.request_completed
	http_request.queue_free()
	
	if result[1] == 200:
		add_log("Generation request sent successfully")
		# Parse response if needed
		var json = JSON.new()
		var parse_result: Error = json.parse(result[3].get_string_from_utf8())
		if parse_result == OK:
			var response_data: Dictionary = json.data
			if response_data.has("message"):
				add_log("Response: %s" % response_data["message"])
	else:
		add_log("Generation request failed: HTTP %d" % result[1])


func _send_code_to_python(code: String) -> void:
	"""Send GDScript code to Python server (for future use)."""
	var http_request: HTTPRequest = HTTPRequest.new()
	add_child(http_request)
	
	var url: String = "%s/code" % PYTHON_SERVER_URL
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var body: Dictionary = {
		"code": code,
		"username": current_username
	}
	
	var json = JSON.new()
	var body_str: String = json.stringify(body)
	
	var err: Error = http_request.request(url, headers, HTTPClient.METHOD_POST, body_str)
	if err != OK:
		add_log("Error sending code: %d" % err)
		http_request.queue_free()
		return
	
	var result = await http_request.request_completed
	http_request.queue_free()
	
	if result[1] == 200:
		add_log("Code sent to Python server")
	else:
		add_log("Failed to send code: HTTP %d" % result[1])
