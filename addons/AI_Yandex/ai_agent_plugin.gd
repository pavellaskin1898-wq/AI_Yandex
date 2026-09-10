# ===== addons/AI_Yandex/ai_agent_plugin.gd =====
@tool
extends EditorPlugin

const DOCK_SCENE_PATH := "res://addons/AI_Yandex/dock_ui.tscn"

var dock_ui: Control = null
var http_server: AIHttpServer = null

func _enter_tree():
	# Инициализация HTTP сервера для приёма команд от Python-бэкенда
	http_server = AIHttpServer.new()
	add_child(http_server)
	
	# Загружаем конфиг для получения порта
	var config = YandexConfig.get_instance()
	var godot_port = config.get_godot_port()
	http_server.start(godot_port)
	
	# Создаём и добавляем док-панель
	var scene = load(DOCK_SCENE_PATH)
	if scene:
		dock_ui = scene.instantiate()
		if dock_ui:
			# Добавляем док в правую нижнюю часть редактора
			add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock_ui)
			print("[AI Yandex] Plugin enabled, dock added")
	else:
		push_error("Failed to load dock scene: %s" % DOCK_SCENE_PATH)

func _exit_tree():
	# Останавливаем HTTP сервер
	if http_server:
		http_server.stop()
		http_server.queue_free()
		http_server = null
	
	# Удаляем док-панель
	if dock_ui:
		remove_control_from_docks(dock_ui)
		dock_ui.queue_free()
		dock_ui = null
	
	print("[AI Yandex] Plugin disabled")
