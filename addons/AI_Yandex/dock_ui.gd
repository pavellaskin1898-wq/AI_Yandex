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
var _stop_btn: Button
var _processing_label: Label
var _http_request: HTTPRequest
var _code_request: HTTPRequest
var _is_processing: bool = false

func setup(config: RefCounted, http_server: Node) -> void:
	_config = config
	_http_server = http_server
	if _http_server != null and _http_server.has_signal("code_received"):
		_http_server.connect("code_received", Callable(self, "_on_code_received"))
	_refresh_connection_state()

func _ready() -> void:
	_build_ui()
	_http_request = HTTPRequest.new()
	_http_request.name = "ChatHTTPRequest"
	add_child(_http_request)
	_http_request.request_completed.connect(Callable(self, "_on_request_completed"))
	
	_code_request = HTTPRequest.new()
	_code_request.name = "CodeHTTPRequest"
	add_child(_code_request)
	_code_request.request_completed.connect(Callable(self, "_on_code_request_completed"))

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

	# Индикатор процесса
	_processing_label = Label.new()
	_processing_label.text = ""
	_processing_label.visible = false
	_processing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_processing_label)

	# Контейнер для кнопок
	var btn_container: HBoxContainer = HBoxContainer.new()
	root.add_child(btn_container)

	_send_btn = Button.new()
	_send_btn.text = "Send to AI"
	_send_btn.pressed.connect(Callable(self, "_on_send_pressed"))
	btn_container.add_child(_send_btn)
	_send_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_stop_btn = Button.new()
	_stop_btn.text = "🛑 Стоп"
	_stop_btn.disabled = true
	_stop_btn.pressed.connect(Callable(self, "_on_stop_pressed"))
	btn_container.add_child(_stop_btn)

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
	if _is_processing:
		return
	
	var prompt: String = _prompt_field.text.strip_edges()
	if prompt == "":
		return
	if not _config.has_api_key():
		_append_log("[color=red]Please connect first[/color]")
		return
	
	_is_processing = true
	_update_ui_state()
	
	_append_log("[b]You:[/b] %s" % prompt)
	_prompt_field.text = ""
	
	# Отправляем запрос на Python сервер
	var api_key: String = _config.api_key
	var folder_id: String = _config.folder_id
	
	var json_body = JSON.stringify({
		"prompt": prompt,
		"api_key": api_key,
		"folder_id": folder_id,
		"model": "yandexgpt-lite",
		"temperature": 0.6
	})
	
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Accept: application/json"
	]
	
	var err: Error = _http_request.request(
		"http://127.0.0.1:8000/chat",
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)
	
	if err != OK:
		_append_log("[color=red]Failed to send request: %s[/color]" % error_string(err))
		_reset_processing_state()

func _on_stop_pressed() -> void:
	if _http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http_request.cancel_request()
		_append_log("[color=yellow]Request cancelled by user[/color]")
		_reset_processing_state()

func _reset_processing_state() -> void:
	_is_processing = false
	_update_ui_state()

func _update_ui_state() -> void:
	if _is_processing:
		_processing_label.text = "⏳ Обработка запроса... Пожалуйста, подождите."
		_processing_label.visible = true
		_send_btn.disabled = true
		_stop_btn.disabled = false
		_prompt_field.editable = false
	else:
		_processing_label.text = ""
		_processing_label.visible = false
		_send_btn.disabled = false
		_stop_btn.disabled = true
		_prompt_field.editable = true

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_reset_processing_state()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg := "Request failed with code: %d" % result
		if body.size() > 0:
			var error_body := body.get_string_from_utf8()
			error_msg += " | Server response: " + error_body
		_append_log("[color=red]%s[/color]" % error_msg)
		return
	
	if response_code == 200:
		var json = JSON.new()
		var parse_err = json.parse(body.get_string_from_utf8())
		if parse_err == OK:
			var data = json.data
			if data is Dictionary and data.has("response"):
				_append_log("[color=green]AI Response:[/color] %s" % str(data["response"]))
				
				# Если есть код, отправляем его в Godot
				if data.has("code_blocks") and data["code_blocks"].size() > 0:
					for code_block in data["code_blocks"]:
						_append_log("[color=cyan]Executing code...[/color]")
						# Отправляем код на локальный HTTP сервер Godot для выполнения
						_send_code_to_godot(code_block)
			else:
				_append_log("[color=yellow]Invalid response format[/color]")
		else:
			_append_log("[color=red]JSON parse error: %s[/color]" % json.get_error_message())
	else:
		var error_detail := "HTTP Error: %d" % response_code
		if body.size() > 0:
			var error_body := body.get_string_from_utf8()
			error_detail += " | " + error_body
		_append_log("[color=red]%s[/color]" % error_detail)

func _send_code_to_godot(code: String) -> void:
	# Отправляем код на встроенный HTTP сервер Godot (порт 9876)
	var json_body = JSON.stringify({
		"code": code,
		"file_path": "res://generated_script.gd"
	})
	
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Accept: application/json"
	]
	
	_code_request.request(
		"http://127.0.0.1:9876/execute",
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)

func _on_code_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		_append_log("[color=green]Code executed successfully[/color]")
	else:
		_append_log("[color=red]Code execution failed with code: %d[/color]" % response_code)

func _on_code_received(code: String, file_path: String) -> void:
	_append_log("[color=green]Received code[/color] (%d chars) for %s" % [code.length(), file_path])

func _append_log(bb: String) -> void:
	if _log_view == null:
		return
	_log_view.append_text(bb + "\n")
