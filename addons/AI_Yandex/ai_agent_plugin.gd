# ===== addons/AI_Yandex/ai_agent_plugin.gd =====
@tool
extends EditorPlugin

const DOCK_SCENE_PATH := "res://addons/AI_Yandex/dock_ui.tscn"

var dock_ui: Control = null
var http_server: Node = null
var config: AIYandexConfig = null

func _enter_tree() -> void:
# 1) Инициализация конфига
config = AIYandexConfig.get_instance()

# 2) Создаём HTTP-сервер для приёма команд от Python-бэкенда
var HTTPServerScript: GDScript = load("res://addons/AI_Yandex/http_server.gd")
http_server = HTTPServerScript.new()
http_server.name = "AIYandexHttpServer"
add_child(http_server)

# Запускаем сервер с портом из конфига
var godot_port: int = config.get_godot_port()
if http_server.has_method("start"):
http_server.call("start", godot_port)

# 3) Создаём и добавляем док-панель
var packed: PackedScene = load(DOCK_SCENE_PATH) as PackedScene
if packed == null:
push_error("[AI_Yandex] Не удалось загрузить dock_ui.tscn")
return

dock_ui = packed.instantiate() as Control
if dock_ui == null:
push_error("[AI_Yandex] dock_ui.tscn не является Control")
return

# Прокидываем зависимости в UI через метод setup
if dock_ui.has_method("setup"):
dock_ui.call("setup", config, http_server)

# Добавляем док в правую нижнюю часть редактора
add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock_ui)
print("[AI_Yandex] Plugin enabled, dock added, HTTP server on port %d" % godot_port)

func _exit_tree() -> void:
# Останавливаем HTTP сервер
if http_server != null:
if http_server.has_method("stop"):
http_server.call("stop")
http_server.queue_free()
http_server = null

# Удаляем док-панель
if dock_ui != null:
remove_control_from_docks(dock_ui)
dock_ui.queue_free()
dock_ui = null

# Сохраняем конфиг
if config != null:
config.save_config()
config = null

print("[AI_Yandex] Plugin disabled")
