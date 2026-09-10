@tool
extends Control

var _config: RefCounted = null
var _http_server: Node = null

var _login_field: LineEdit
var _pass_field: LineEdit
var _remember_check: CheckBox
var _login_btn: Button
var _status_label: Label
var _log_view: RichTextLabel
var _prompt_field: TextEdit
var _send_btn: Button

func setup(config: RefCounted, http_server: Node) -> void:
	_config = config
	_http_server = http_server
	if _http_server != null and _http_server.has_signal("code_received"):
		_http_server.connect("code_received", Callable(self, "_on_code_received"))
	_refresh_login_state()

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	if _login_field != null:
		return
	custom_minimum_size = Vector2(340, 480)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var title: Label = Label.new()
	title.text = "AI Yandex Assistant"
	root.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Not logged in"
	root.add_child(_status_label)

	_login_field = LineEdit.new()
	_login_field.placeholder_text = "Yandex login (email)"
	root.add_child(_login_field)

	_pass_field = LineEdit.new()
	_pass_field.placeholder_text = "Password"
	_pass_field.secret = true
	root.add_child(_pass_field)

	_remember_check = CheckBox.new()
	_remember_check.text = "Remember me"
	_remember_check.button_pressed = true
	root.add_child(_remember_check)

	_login_btn = Button.new()
	_login_btn.text = "Sign in"
	_login_btn.pressed.connect(Callable(self, "_on_login_pressed"))
	root.add_child(_login_btn)

	var sep: HSeparator = HSeparator.new()
	root.add_child(sep)

	_log_view = RichTextLabel.new()
	_log_view.bbcode_enabled = true
	_log_view.scroll_following = true
	_log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_log_view)

	_prompt_field = TextEdit.new()
	_prompt_field.custom_minimum_size = Vector2(0, 80)
	_prompt_field.placeholder_text = "Describe your game or code task..."
	root.add_child(_prompt_field)

	_send_btn = Button.new()
	_send_btn.text = "Send"
	_send_btn.pressed.connect(Callable(self, "_on_send_pressed"))
	root.add_child(_send_btn)

func _refresh_login_state() -> void:
	if _config == null:
		return
	if _config.has_token():
		_status_label.text = "Logged in as: %s" % _config.email
		_login_field.text = _config.email
		_login_btn.text = "Sign out"
	else:
		_status_label.text = "Not logged in"
		_login_btn.text = "Sign in"

func _on_login_pressed() -> void:
	if _config == null:
		return
	if _config.has_token():
		_config.clear_token()
		_refresh_login_state()
		_append_log("[color=yellow]Signed out[/color]")
		return
	var login: String = _login_field.text.strip_edges()
	var password: String = _pass_field.text
	if login == "" or password == "":
		_append_log("[color=red]Login and password required[/color]")
		return
	_append_log("[color=cyan]Sending login request to %s[/color]" % _config.server_url)

func _on_send_pressed() -> void:
	var prompt: String = _prompt_field.text.strip_edges()
	if prompt == "":
		return
	_append_log("[b]You:[/b] %s" % prompt)
	_prompt_field.text = ""

func _on_code_received(code: String, file_path: String) -> void:
	_append_log("[color=green]Received code[/color] (%d chars) for %s" % [code.length(), file_path])

func _append_log(bb: String) -> void:
	if _log_view == null:
		return
	_log_view.append_text(bb + "\n")
