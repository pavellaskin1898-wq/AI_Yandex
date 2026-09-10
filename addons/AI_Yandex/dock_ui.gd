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

	if (
		_http_server != null
		and _http_server.has_signal("code_received")
	):
		var callback := Callable(
			self,
			"_on_code_received"
		)

		if not _http_server.is_connected(
			"code_received",
			callback
		):
			_http_server.connect(
				"code_received",
				callback
			)

	_refresh_connection_state


func _ready() -> void:
	_build_ui()

	_http_request = HTTPRequest.new()
	_http_request.name = "ChatHTTPRequest"
	_http_request.timeout = 65.0
	add_child(_http_request)

	_http_request.request_completed.connect(
		Callable(
			self,
			"_on_request_completed"
		)
	)

	_code_request = HTTPRequest.new()
	_code_request.name = "CodeHTTPRequest"
	_code_request.timeout = 10.0
	add_child(_code_request)

	_code_request.request_completed.connect(
		Callable(
			self,
			"_on_code_request_completed"
		)
	)


# ============================================================
# UI
# ============================================================

func _build_ui() -> void:
	if _api_key_field != null:
		return

	custom_minimum_size = Vector2(340, 480)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var title := Label.new()
	title.text = "AI Yandex Assistant"
	root.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Not connected"
	root.add_child(_status_label)

	var key_label := Label.new()
	key_label.text = "API Key:"
	root.add_child(key_label)

	_api_key_field = LineEdit.new()
	_api_key_field.placeholder_text = "Enter Yandex Cloud API Key"
	_api_key_field.secret = true
	root.add_child(_api_key_field)

	var folder_label := Label.new()
	folder_label.text = "Folder ID:"
	root.add_child(folder_label)

	_folder_id_field = LineEdit.new()
	_folder_id_field.placeholder_text = "Yandex Cloud Folder ID"
	root.add_child(_folder_id_field)

	_connect_btn = Button.new()
	_connect_btn.text = "Connect"
	_connect_btn.pressed.connect(
		Callable(
			self,
			"_on_connect_pressed"
		)
	)
	root.add_child(_connect_btn)

	var sep := HSeparator.new()
	root.add_child(sep)

	_log_view = RichTextLabel.new()
	_log_view.bbcode_enabled = true
	_log_view.scroll_following = true
	_log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_log_view)

	_prompt_field = TextEdit.new()
	_prompt_field.custom_minimum_size = Vector2(0, 80)
	_prompt_field.placeholder_text = (
		"Describe your game or code task..."
	)
	root.add_child(_prompt_field)

	_processing_label = Label.new()
	_processing_label.text = ""
	_processing_label.visible = false
	_processing_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	root.add_child(_processing_label)

	var btn_container := HBoxContainer.new()
	root.add_child(btn_container)

	_send_btn = Button.new()
	_send_btn.text = "Send to AI"
	_send_btn.pressed.connect(
		Callable(
			self,
			"_on_send_pressed"
		)
	)
	_send_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_container.add_child(_send_btn)

	_stop_btn = Button.new()
	_stop_btn.text = "🛑 Стоп"
	_stop_btn.disabled = true
	_stop_btn.pressed.connect(
		Callable(
			self,
			"_on_stop_pressed"
		)
	)
	btn_container.add_child(_stop_btn)


# ============================================================
# CONNECTION
# ============================================================

func _refresh_connection_state() -> void:
	if _config == null:
		return

	if _config.has_api_key():
		_status_label.text = "Connected ✓"

	_api_key_field.text = _config.api_key
	_folder_id_field.text = _config.folder_id

	_connect_btn.text = "Disconnect"
	else:
		_status_label.text = "Not connected"

	_api_key_field.text = ""
	_folder_id_field.text = ""

	_connect_btn.text = "Connect"


func _on_connect_pressed() -> void:
	if _config == null:
		return

	if _config.has_api_key():
		_config.clear_api_key()

		_refresh_connection_state()

		_append_log(
			"[color=yellow]Disconnected[/color]"
		)

		return

	var api_key: String = (
		_api_key_field.text.strip_edges()
	)

	var folder_id: String = (
		_folder_id_field.text.strip_edges()
	)

	if api_key == "" or api_key.length() < 10:
		_append_log(
			"[color=red]Invalid API Key[/color]"
		)
		return

	if folder_id == "":
		_append_log(
			"[color=red]Folder ID is required[/color]"
		)
		return

	_config.api_key = api_key
	_config.folder_id = folder_id

	_config.save_config()
	_refresh_connection_state()

	_append_log(
		"[color=green]API Key and Folder ID saved[/color]"
	)


# ============================================================
# CHAT
# ============================================================

func _on_send_pressed() -> void:
	if _is_processing:
		return

	var prompt: String = (
		_prompt_field.text.strip_edges()
	)

	if prompt == "":
		return

	if _config == null:
		_append_log(
			"[color=red]Configuration is not loaded[/color]"
		)
		return

	if not _config.has_api_key():
		_append_log(
			"[color=red]Please connect first[/color]"
		)
		return

	if _config.folder_id.strip_edges() == "":
		_append_log(
			"[color=red]Folder ID is required[/color]"
		)
		return

	_is_processing = true
	_update_ui_state()

	_append_log(
		"[b]You:[/b] %s" % prompt
	)

	_prompt_field.text = ""

	var json_body := JSON.stringify({
		"prompt": prompt,
		"api_key": _config.api_key,
		"folder_id": _config.folder_id,
		"model": _config.model,
		"temperature": _config.temperature
	})

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json"
	])

	var url: String = (
		_config.server_url.trim_suffix("/")
		+ "/chat"
	)

	print("[AI_Yandex] Sending request to: ", url)

	var err: Error = _http_request.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)

	if err != OK:
		_append_log(
			"[color=red]Failed to send request: %s[/color]"
			% error_string(err)
		)

		_reset_processing_state()


# ============================================================
# STOP
# ============================================================

func _on_stop_pressed() -> void:
	if _http_request == null:
		return

	if (
		_http_request.get_http_client_status()
		!= HTTPClient.STATUS_DISCONNECTED
	):
		_http_request.cancel_request()

		_append_log(
			"[color=yellow]Request cancelled by user[/color]"
		)

		_reset_processing_state()


func _reset_processing_state() -> void:
	_is_processing = false
	_update_ui_state()


func _update_ui_state() -> void:
	if _is_processing:
		_processing_label.text = (
			"⏳ Обработка запроса..."
		)
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


# ============================================================
# CHAT RESPONSE
# ============================================================

func _on_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_reset_processing_state()

	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg := (
			"Request failed with code: %d"
			% result
		)

		if body.size() > 0:
			error_msg += (
				" | Server response: "
				+ body.get_string_from_utf8()
			)

		_append_log(
			"[color=red]%s[/color]"
			% error_msg
		)

		print(
			"[AI_Yandex] HTTPRequest result: ",
			result
		)

		return

	if response_code != 200:
		var error_detail := (
			"HTTP Error: %d"
			% response_code
		)

		if body.size() > 0:
			error_detail += (
				" | "
				+ body.get_string_from_utf8()
			)

		_append_log(
			"[color=red]%s[/color]"
			% error_detail
		)

		return

	var json := JSON.new()

	var parse_err := json.parse(
		body.get_string_from_utf8()
	)

	if parse_err != OK:
		_append_log(
			"[color=red]JSON parse error: %s[/color]"
			% json.get_error_message()
		)
		return

	var data: Variant = json.data

	if not data is Dictionary:
		_append_log(
			"[color=red]Invalid server response[/color]"
		)
		return

	if data.has("response"):
		_append_log(
			"[color=green]AI Response:[/color] %s"
			% str(data["response"])
		)

	if data.has("code_blocks"):
		var code_blocks: Variant = data["code_blocks"]

		if code_blocks is Array:
			for code_block in code_blocks:
				var code: String = str(code_block)

				if code.strip_edges() == "":
					continue

				_append_log(
					"[color=cyan]Executing code...[/color]"
				)

				_send_code_to_godot(code)


# ============================================================
# SEND GENERATED CODE TO GODOT
# ============================================================

func _send_code_to_godot(code: String) -> void:
	if _config == null:
		return

	var json_body := JSON.stringify({
		"code": code,
		"file_path": "res://generated_script.gd"
	})

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json"
	])

	var url := (
		"http://127.0.0.1:%d/execute"
		% _config.godot_port
	)

	print(
		"[AI_Yandex] Sending generated code to: ",
		url
	)

	var err := _code_request.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)

	if err != OK:
		_append_log(
			"[color=red]Code request failed: %s[/color]"
			% error_string(err)
		)


func _on_code_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_append_log(
			"[color=red]Code HTTP request failed: %d[/color]"
			% result
		)
		return

	if response_code == 200:
		_append_log(
			"[color=green]Code queued successfully[/color]"
		)
	else:
		var message := (
			"Code execution failed with HTTP %d"
			% response_code
		)

		if body.size() > 0:
			message += (
				" | "
				+ body.get_string_from_utf8()
			)

		_append_log(
			"[color=red]%s[/color]"
			% message
		)


# ============================================================
# HTTP SERVER SIGNAL
# ============================================================

func _on_code_received(
	code: String,
	file_path: String
) -> void:
	_append_log(
		"[color=green]Received code[/color] "
		+ "(%d chars) for %s"
		% [code.length(), file_path]
	)


# ============================================================
# LOG
# ============================================================

func _append_log(bb: String) -> void:
	if _log_view == null:
		return

	_log_view.append_text(bb + "\n")
