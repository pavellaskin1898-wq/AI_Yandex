# ===== python_server/godot_bridge.py =====
"""
Мост для связи с Godot Editor
Отправляет код и команды в Godot через локальный HTTP сервер
"""

import asyncio
import httpx
from typing import Optional, Dict, Any


class GodotBridge:
    """Класс для отправки команд в Godot Editor"""
    
    def __init__(self):
        self.godot_host = "127.0.0.1"
        self.godot_port = 9876
        self.timeout = 10.0
    
    def set_godot_port(self, port: int):
        """Установка порта Godot сервера"""
        self.godot_port = port
    
    def set_godot_host(self, host: str):
        """Установка хоста Godot сервера"""
        self.godot_host = host
    
    async def check_connection(self) -> bool:
        """Проверка подключения к Godot"""
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(
                    f"http://{self.godot_host}:{self.godot_port}/health"
                )
                return response.status_code == 200
        except:
            return False
    
    async def execute_code(self, code: str) -> Dict[str, Any]:
        """
        Отправка GDScript кода на выполнение в Godot
        
        Args:
            code: Исходный код GDScript
        
        Returns:
            Результат выполнения
        """
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    f"http://{self.godot_host}:{self.godot_port}/execute",
                    json={"code": code},
                    headers={"Content-Type": "application/json"}
                )
                
                if response.status_code == 200:
                    return response.json()
                else:
                    return {
                        "status": "error",
                        "output": f"HTTP {response.status_code}: {response.text[:100]}"
                    }
        
        except httpx.TimeoutException:
            return {
                "status": "error",
                "output": "Timeout connecting to Godot"
            }
        except httpx.ConnectError:
            return {
                "status": "error",
                "output": f"Cannot connect to Godot on port {self.godot_port}"
            }
        except Exception as e:
            return {
                "status": "error",
                "output": f"Error: {str(e)}"
            }
    
    async def create_file(self, path: str, content: str) -> Dict[str, Any]:
        """
        Создание файла в проекте Godot
        
        Args:
            path: Путь к файлу (res://...)
            content: Содержимое файла
        
        Returns:
            Результат создания
        """
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    f"http://{self.godot_host}:{self.godot_port}/create_file",
                    json={"path": path, "content": content},
                    headers={"Content-Type": "application/json"}
                )
                
                if response.status_code == 200:
                    return response.json()
                else:
                    return {
                        "status": "error",
                        "path": path,
                        "error": f"HTTP {response.status_code}"
                    }
        
        except httpx.TimeoutException:
            return {
                "status": "error",
                "path": path,
                "error": "Timeout"
            }
        except httpx.ConnectError:
            return {
                "status": "error",
                "path": path,
                "error": f"Cannot connect to Godot on port {self.godot_port}"
            }
        except Exception as e:
            return {
                "status": "error",
                "path": path,
                "error": str(e)
            }
    
    async def send_notification(self, message: str, level: str = "info") -> Dict[str, Any]:
        """
        Отправка уведомления в Godot Editor
        
        Args:
            message: Текст уведомления
            level: Уровень (info, warning, error)
        
        Returns:
            Результат
        """
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    f"http://{self.godot_host}:{self.godot_port}/notify",
                    json={"message": message, "level": level},
                    headers={"Content-Type": "application/json"}
                )
                
                return {"status": "ok", "message": message}
        
        except:
            return {"status": "error", "message": "Failed to send notification"}
    
    async def reload_scene(self) -> Dict[str, Any]:
        """Перезагрузка текущей сцены в Godot"""
        code = """
extends EditorScript

func _run():
    var editor_interface = Engine.get_singleton("EditorInterface")
    var scene = editor_interface.get_edited_scene_root()
    if scene:
        var path = scene.scene_file_path
        if path:
            editor_interface.open_scene_from_path(path)
            return "Scene reloaded: " + path
    return "No scene to reload"
"""
        return await self.execute_code(code)
    
    async def refresh_filesystem(self) -> Dict[str, Any]:
        """Обновление файловой системы Godot"""
        code = """
extends EditorScript

func _run():
    var editor_interface = Engine.get_singleton("EditorInterface")
    var fs = editor_interface.get_resource_filesystem()
    if fs:
        fs.scan()
        return "Filesystem refreshed"
    return "Failed to access filesystem"
"""
        return await self.execute_code(code)
