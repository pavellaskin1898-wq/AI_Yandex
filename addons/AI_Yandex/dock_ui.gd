@tool
extends Control

var _config: RefCounted = null
var _http_server: Node = null

var _api_key_field: LineEdit
var _folder_id_field: LineEdit
var _connect_btn: Button
var _status_label: Label
var _log_view: RichTextLabel
var _prompt_field: TextEdit
var _send_btn: Button

func setup(config: RefCounted, http_server: Node) -> void:
	_config = config
	_http_server = http_server
	if _http_server != null and _http_server.has_signal("code_received"):
		_http_server.connect("code_received", Callable(self, "_on_code_received"))
	_refresh_connection_state()

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	if _api_key_field != null:
		return
	custom_minimum_size = Vector2(340, 480)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var title: Label = Label.new()
	title.text = "AI Yandex Assistant"
	root.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Not connected"
	root.add_child(_status_label)

	var key_label: Label = Label.new()
	key_label.text = "API Key:"
	root.add_child(key_label)

	_api_key_field = LineEdit.new()
	_api_key_field.placeholder_text = "Enter Yandex Cloud API Key"
	_api_key_field.secret = true
	root.add_child(_api_key_field)

	var folder_label: Label = Label.new()
	folder_label.text = "Folder ID (optional):"
	root.add_child(folder_label)

	_folder_id_field = LineEdit.new()
	_folder_id_field.placeholder_text = "Yandex Cloud Folder ID"
	root.add_child(_folder_id_field)

	_connect_btn = Button.new()
	_connect_btn.text = "Connect"
	_connect_btn.pressed.connect(Callable(self, "_on_connect_pressed"))
	root.add_child(_connect_btn)

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
	_send_btn.text = "Send to AI"
	_send_btn.pressed.connect(Callable(self, "_on_send_pressed"))
	root.add_child(_send_btn)

func _refresh_connection_state() -> void:
	if _config == null:
		return
	if _config.has_api_key():
		_status_label.text = "Connected ✓"
		_api_key_field.text = _config.api_key
		_connect_btn.text = "Disconnect"
	else:
		_status_label.text = "Not connected"
		_api_key_field.text = ""
		_connect_btn.text = "Connect"

func _on_connect_pressed() -> void:
	if _config == null:
		return
	if _config.has_api_key():
		_config.clear_api_key()
		_refresh_connection_state()
		_append_log("[color=yellow]Disconnected[/color]")
		return
	var api_key: String = _api_key_field.text.strip_edges()
	var folder_id: String = _folder_id_field.text.strip_edges()
	if api_key == "" or api_key.length() < 10:
		_append_log("[color=red]Invalid API Key[/color]")
		return
	_config.api_key = api_key
	_config.folder_id = folder_id
	_config.save_config()
	_refresh_connection_state()
	_append_log("[color=green]Connected with API Key[/color]")

func _on_send_pressed() -> void:
	var prompt: String = _prompt_field.text.strip_edges()
	if prompt == "":
		return
	if not _config.has_api_key():
		_append_log("[color=red]Please connect first[/color]")
		return
	_append_log("[b]You:[/b] %s" % prompt)
	_prompt_field.text = ""

func _on_code_received(code: String, file_path: String) -> void:
	_append_log("[color=green]Received code[/color] (%d chars) for %s" % [code.length(), file_path])

func _append_log(bb: String) -> void:
	if _log_view == null:
		return
	_log_view.append_text(bb + "\n")
