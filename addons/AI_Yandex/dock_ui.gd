# ===== addons/AI_Yandex/dock_ui.gd =====
@tool
extends Control
class_name AIDockUI

# UI элементы
@onready var tab_container: TabContainer = $VBoxContainer/TabContainer
@onready var chat_log: RichTextLabel = $VBoxContainer/TabContainer/Agent/VBoxContainer/ChatLog
@onready var prompt_edit: TextEdit = $VBoxContainer/TabContainer/Agent/VBoxContainer/PromptContainer/PromptEdit
@onready var send_button: Button = $VBoxContainer/TabContainer/Agent/VBoxContainer/PromptContainer/ButtonContainer/SendButton
@onready var generate_game_button: Button = $VBoxContainer/TabContainer/Agent/VBoxContainer/PromptContainer/ButtonContainer/GenerateGameButton
@onready var clear_button: Button = $VBoxContainer/TabContainer/Agent/VBoxContainer/PromptContainer/ButtonContainer/ClearButton

@onready var email_edit: LineEdit = $VBoxContainer/TabContainer/Auth/VBoxContainer/EmailEdit
@onready var password_edit: LineEdit = $VBoxContainer/TabContainer/Auth/VBoxContainer/PasswordEdit
@onready var remember_checkbox: CheckBox = $VBoxContainer/TabContainer/Auth/VBoxContainer/RememberCheckbox
@onready var login_button: Button = $VBoxContainer/TabContainer/Auth/VBoxContainer/LoginButton
@onready var logout_button: Button = $VBoxContainer/TabContainer/Auth/VBoxContainer/LogoutButton
@onready var status_message: Label = $VBoxContainer/TabContainer/Auth/VBoxContainer/StatusMessage

@onready var url_edit: LineEdit = $VBoxContainer/TabContainer/Settings/GridContainer/URLEdit
@onready var python_port_edit: SpinBox = $VBoxContainer/TabContainer/Settings/GridContainer/PythonPortEdit
@onready var godot_port_edit: SpinBox = $VBoxContainer/TabContainer/Settings/GridContainer/GodotPortEdit
@onready var model_option: OptionButton = $VBoxContainer/TabContainer/Settings/GridContainer/ModelOptionButton
@onready var temperature_edit: SpinBox = $VBoxContainer/TabContainer/Settings/GridContainer/TemperatureEdit
@onready var max_tokens_edit: SpinBox = $VBoxContainer/TabContainer/Settings/GridContainer/MaxTokensEdit
@onready var save_button: Button = $VBoxContainer/TabContainer/Settings/GridContainer/SaveButton

@onready var log_text: TextEdit = $VBoxContainer/TabContainer/Logs/VBoxContainer/LogText
@onready var clear_log_button: Button = $VBoxContainer/TabContainer/Logs/VBoxContainer/ClearLogButton

@onready var connection_indicator: ColorRect = $VBoxContainer/StatusBar/ConnectionIndicator
@onready var connection_label: Label = $VBoxContainer/StatusBar/ConnectionLabel
@onready var user_label: Label = $VBoxContainer/StatusBar/UserLabel

# Компоненты
var yandex_client: YandexClient = null
var http_server: AIHttpServer = null
var config: YandexConfig = null

var is_authenticated: bool = false
var current_email: String = ""

func _ready():
	_init_config()
	_init_client()
	_init_server()
	_init_model_options()
	_load_settings()
	_update_auth_ui()
	_connect_signals()
	_add_log("[AI Yandex] Dock UI initialized")

func _init_config():
	config = YandexConfig.get_instance()

func _init_client():
	yandex_client = YandexClient.new()
	add_child(yandex_client)
	yandex_client.login_completed.connect(_on_login_completed)
	yandex_client.chat_completed.connect(_on_chat_completed)
	yandex_client.generate_game_completed.connect(_on_generate_game_completed)

func _init_server():
	http_server = AIHttpServer.new()
	add_child(http_server)
	var godot_port = config.get_godot_port()
	http_server.start(godot_port)

func _init_model_options():
	model_option.clear()
	model_option.add_item("yandexgpt-lite", 0)
	model_option.add_item("yandexgpt", 1)
	model_option.add_item("yandexgpt-pro", 2)

func _load_settings():
	url_edit.text = config.get_python_url()
	python_port_edit.value = config.get_python_port()
	godot_port_edit.value = config.get_godot_port()
	
	var model = config.get_model()
	for i in range(model_option.item_count):
		if model_option.get_item_text(i) == model:
			model_option.selected = i
			break
	
	temperature_edit.value = int(config.get_temperature() * 10)
	max_tokens_edit.value = config.get_max_tokens()
	
	yandex_client.set_server(config.get_python_url(), config.get_python_port())

func _connect_signals():
	send_button.pressed.connect(_on_send_pressed)
	generate_game_button.pressed.connect(_on_generate_game_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	login_button.pressed.connect(_on_login_pressed)
	logout_button.pressed.connect(_on_logout_pressed)
	save_button.pressed.connect(_on_save_settings_pressed)
	clear_log_button.pressed.connect(_on_clear_log_pressed)

func _update_auth_ui():
	if config.is_authenticated():
		is_authenticated = true
		current_email = config.get_email()
		login_button.visible = false
		logout_button.visible = true
		password_edit.editable = false
		status_message.text = "Авторизован"
		user_label.text = current_email
		connection_indicator.color = Color(0, 1, 0, 1)
		connection_label.text = "Подключено"
		_add_log("Авторизован как: %s" % current_email)
	else:
		is_authenticated = false
		current_email = ""
		login_button.visible = true
		logout_button.visible = false
		password_edit.editable = true
		status_message.text = ""
		user_label.text = ""
		connection_indicator.color = Color(1, 0, 0, 1)
		connection_label.text = "Не подключено"

func _add_log(message: String):
	var timestamp = Time.get_datetime_string_from_system()
	log_text.text += "[%s] %s\n" % [timestamp, message]
	log_text.scroll_vertical = log_text.get_line_count()

func _add_chat_message(message: String, is_user: bool = false):
	if is_user:
		chat_log.text += "\n[color=#4488ff][b]Вы:[/b][/color]\n%s" % message
	else:
		chat_log.text += "\n[color=#44ff88][b]AI:[/b][/color]\n%s" % message
	chat_log.scroll_vertical = chat_log.get_line_count()

func _on_send_pressed():
	var prompt = prompt_edit.text.strip_edges()
	if prompt.is_empty():
		return
	
	if not is_authenticated:
		_add_log("Ошибка: сначала авторизуйтесь")
		_add_chat_message("Сначала необходимо авторизоваться в Яндексе.", false)
		return
	
	_add_chat_message(prompt, true)
	prompt_edit.text = ""
	
	var context = {
		"model": model_option.get_item_text(model_option.selected),
		"temperature": float(temperature_edit.value) / 10.0,
		"max_tokens": max_tokens_edit.value
	}
	
	yandex_client.chat(prompt, context, config.get_oauth_token())
	_add_log("Отправлен запрос к YandexGPT")

func _on_generate_game_pressed():
	var prompt = prompt_edit.text.strip_edges()
	if prompt.is_empty():
		prompt = "Создай простую игру: арканоид с управлением мышью"
	
	if not is_authenticated:
		_add_log("Ошибка: сначала авторизуйтесь")
		_add_chat_message("Сначала необходимо авторизоваться в Яндексе.", false)
		return
	
	_add_chat_message("Генерация игры: " + prompt, true)
	prompt_edit.text = ""
	
	yandex_client.generate_game(prompt, config.get_oauth_token())
	_add_log("Запрошена генерация игры")

func _on_clear_pressed():
	chat_log.text = "[color=#888888]Чат очищен[/color]"

func _on_login_pressed():
	var email = email_edit.text.strip_edges()
	var password = password_edit.text
	
	if email.is_empty() or password.is_empty():
		status_message.text = "Введите email и пароль"
		return
	
	login_button.disabled = true
	status_message.text = "Выполняется вход..."
	_add_log("Попытка входа: %s" % email)
	
	yandex_client.login(email, password)

func _on_logout_pressed():
	config.clear_auth()
	is_authenticated = false
	current_email = ""
	_update_auth_ui()
	_add_log("Выход из аккаунта")

func _on_save_settings_pressed():
	config.set_python_url(url_edit.text)
	config.set_python_port(int(python_port_edit.value))
	config.set_godot_port(int(godot_port_edit.value))
	config.set_model(model_option.get_item_text(model_option.selected))
	config.set_temperature(float(temperature_edit.value) / 10.0)
	config.set_max_tokens(max_tokens_edit.value)
	
	yandex_client.set_server(config.get_python_url(), config.get_python_port())
	
	# Перезапускаем HTTP сервер с новым портом
	http_server.stop()
	http_server.start(config.get_godot_port())
	
	_add_log("Настройки сохранены")

func _on_clear_log_pressed():
	log_text.text = ""

func _on_login_completed(success: bool, email: String, error: String):
	login_button.disabled = false
	
	if success:
		config.set_email(email)
		if remember_checkbox.button_pressed:
			# Сохраняем только токен, не пароль
			pass
		is_authenticated = true
		current_email = email
		status_message.text = "Вошёл как: " + email
		password_edit.text = ""
		_update_auth_ui()
		_add_log("Успешный вход: %s" % email)
	else:
		status_message.text = "Ошибка: " + error
		_add_log("Ошибка входа: %s" % error)

func _on_chat_completed(success: bool, response: Dictionary, error: String):
	if success:
		var text = response.get("text", response.get("response", str(response)))
		_add_chat_message(text, false)
		
		# Проверяем наличие кода для выполнения
		if response.has("code"):
			var code = response["code"]
			_add_log("Получен код для выполнения, длина: %d" % code.length())
			_execute_code_in_editor(code)
	else:
		_add_chat_message("Ошибка: " + error, false)
		_add_log("Ошибка чата: %s" % error)

func _on_generate_game_completed(success: bool, files: Array, error: String):
	if success:
		_add_chat_message("Игра сгенерирована! Создано файлов: %d" % files.size(), false)
		for file_info in files:
			if file_info is Dictionary:
				var path = file_info.get("path", "unknown")
				var content = file_info.get("content", "")
				_create_file(path, content)
				_add_log("Создан файл: %s" % path)
	else:
		_add_chat_message("Ошибка генерации: " + error, false)
		_add_log("Ошибка генерации игры: %s" % error)

func _execute_code_in_editor(code: String):
	# Отправляем код на выполнение через HTTP сервер
	# В реальном проекте здесь будет более сложная логика
	_add_log("Код готов к выполнению (требуется ручное применение)")
	chat_log.text += "\n[color=#ffaa00][i]Код сгенерирован. Используйте кнопку 'Применить код' или скопируйте вручную.[/i][/color]\n"

func _create_file(path: String, content: String):
	var full_path = path if path.begins_with("res://") else "res://" + path
	
	# Создаём директорию если нужно
	var dir = DirAccess.open("res://")
	if dir:
		var path_parts = full_path.split("/")
		if path_parts.size() > 2:
			var dir_path = "/".join(path_parts.slice(0, path_parts.size() - 1))
			dir.make_dir_recursive(dir_path.replace("res://", ""))
	
	var file = FileAccess.open(full_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		EditorInterface.get_resource_filesystem().scan()
		_add_log("Файл создан: %s" % full_path)
	else:
		_add_log("Ошибка создания файла: %s" % full_path)

func _exit_tree():
	if http_server:
		http_server.stop()
	if yandex_client:
		yandex_client.queue_free()
