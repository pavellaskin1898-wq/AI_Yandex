# ===== addons/AI_Yandex/dock_ui.gd =====
@tool
extends Control

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
var yandex_client: Node = null
var http_server: Node = null
var config: AIYandexConfig = null

var is_authenticated: bool = false
var current_email: String = ""

func _ready():
_init_model_options()
_connect_signals()
_add_log("[AI Yandex] Dock UI initialized")

func setup(cfg: AIYandexConfig, server: Node) -> void:
config = cfg
http_server = server

# Инициализация клиента
yandex_client = HTTPRequest.new()
add_child(yandex_client)

_load_settings()
_update_auth_ui()

# Подключаем сигнал от сервера
if http_server != null and http_server.has_signal("code_received"):
http_server.connect("code_received", Callable(self, "_on_code_received"))

print("[AI_Yandex] Dock UI setup complete")

func _init_model_options():
model_option.clear()
model_option.add_item("yandexgpt-lite", 0)
model_option.add_item("yandexgpt", 1)

func _load_settings():
if config == null:
return
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

func _connect_signals():
send_button.pressed.connect(_on_send_pressed)
generate_game_button.pressed.connect(_on_generate_game_pressed)
clear_button.pressed.connect(_on_clear_pressed)
login_button.pressed.connect(_on_login_pressed)
logout_button.pressed.connect(_on_logout_pressed)
save_button.pressed.connect(_on_save_settings_pressed)
clear_log_button.pressed.connect(_on_clear_log_pressed)

func _update_auth_ui():
if config == null:
return
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
_add_log("Отправлен запрос к YandexGPT (требуется Python-бэкенд)")

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
_add_log("Запрошена генерация игры (требуется Python-бэкенд)")

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

# Отправляем запрос на Python-сервер
if config != null:
var url = "%s:%d/login" % [config.get_server_url(), config.get_python_port()]
var headers = ["Content-Type: application/json"]
var body = JSON.stringify({"email": email, "password": password})

if yandex_client != null and yandex_client.has_method("request"):
var err = yandex_client.request(url, headers, HTTPClient.METHOD_POST, body)
if err != OK:
_on_login_result(false, "", "Failed to send request: %s" % error_string(err))
else:
yandex_client.request_completed.connect(_on_login_request_completed)

func _on_login_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
var response_str = body.get_string_from_utf8()
var json = JSON.new()
var parse_err = json.parse(response_str)
var data = json.data if parse_err == OK else {}

if result != HTTPRequest.RESULT_SUCCESS or response_code >= 400:
_on_login_result(false, "", "Request failed")
return

if data.has("token") and data.has("email"):
if config != null:
config.set_email(data["email"])
config.set_oauth_token(data["token"])
_on_login_result(true, data["email"], "")
else:
_on_login_result(false, "", data.get("error", "Unknown error"))

func _on_login_result(success: bool, email: String, error: String):
login_button.disabled = false
if success:
is_authenticated = true
current_email = email
status_message.text = "Вошёл как: " + email
password_edit.text = ""
_update_auth_ui()
_add_log("Успешный вход: %s" % email)
else:
status_message.text = "Ошибка: " + error
_add_log("Ошибка входа: %s" % error)

func _on_logout_pressed():
if config != null:
config.clear_auth()
is_authenticated = false
current_email = ""
_update_auth_ui()
_add_log("Выход из аккаунта")

func _on_save_settings_pressed():
if config != null:
config.set_python_url(url_edit.text)
config.set_python_port(int(python_port_edit.value))
config.set_godot_port(int(godot_port_edit.value))
config.set_model(model_option.get_item_text(model_option.selected))
config.set_temperature(float(temperature_edit.value) / 10.0)
config.set_max_tokens(max_tokens_edit.value)
_add_log("Настройки сохранены")

func _on_clear_log_pressed():
log_text.text = ""

func _on_code_received(code: String, file_path: String):
_add_log("Получен код для выполнения, длина: %d" % code.length())
chat_log.text += "\n[color=#ffaa00][i]Код получен. Выполнение требует ручной проверки.[/i][/color]\n"

func _exit_tree():
if yandex_client != null:
yandex_client.queue_free()
