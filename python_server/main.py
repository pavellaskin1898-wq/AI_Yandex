# ===== python_server/main.py =====
"""
AI Yandex Agent - Python Backend Server
FastAPI приложение для интеграции с YandexGPT/Alice API
"""

import os
import re
import asyncio
import httpx
from typing import Optional, Dict, List, Any
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import uvicorn

# Импорт локальных модулей
from yandex_auth import YandexAuthenticator
from yandex_gpt import YandexGPTClient
from godot_bridge import GodotBridge

app = FastAPI(title="AI Yandex Agent Backend", version="1.0.0")

# CORS для локального доступа
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Глобальные клиенты
authenticator = YandexAuthenticator()
gpt_client: Optional[YandexGPTClient] = None
godot_bridge = GodotBridge()


class LoginRequest(BaseModel):
    email: str = Field(..., description="Yandex email")
    password: str = Field(..., description="Yandex password")


class LoginResponse(BaseModel):
    success: bool
    email: Optional[str] = None
    oauth_token: Optional[str] = None
    iam_token: Optional[str] = None
    error: Optional[str] = None


class ChatRequest(BaseModel):
    prompt: str = Field(..., description="User prompt")
    context: Dict[str, Any] = Field(default_factory=dict, description="Additional context")
    token: Optional[str] = Field(None, description="OAuth token")


class ChatResponse(BaseModel):
    success: bool
    text: Optional[str] = None
    code: Optional[str] = None
    tokens_used: Optional[int] = None
    error: Optional[str] = None


class GenerateGameRequest(BaseModel):
    task: str = Field(..., description="Game development task")
    token: Optional[str] = Field(None, description="OAuth token")


class FileInfo(BaseModel):
    path: str
    content: str


class GenerateGameResponse(BaseModel):
    success: bool
    files: List[FileInfo] = []
    error: Optional[str] = None


@app.on_event("startup")
async def startup_event():
    """Инициализация при запуске"""
    print("[AI Yandex] Backend server starting...")
    godot_bridge.set_godot_port(int(os.getenv("GODOT_PORT", "9876")))


@app.post("/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    """
    Авторизация в Яндексе по логину/паролю
    Возвращает OAuth и IAM токены для последующих запросов
    """
    try:
        result = await authenticator.login_with_password(request.email, request.password)
        
        if not result.get("success"):
            return LoginResponse(
                success=False,
                error=result.get("error", "Authentication failed")
            )
        
        oauth_token = result.get("oauth_token", "")
        iam_token = result.get("iam_token", "")
        
        # Инициализируем GPT клиент с токенами
        global gpt_client
        gpt_client = YandexGPTClient(iam_token)
        
        return LoginResponse(
            success=True,
            email=request.email,
            oauth_token=oauth_token,
            iam_token=iam_token
        )
    
    except Exception as e:
        return LoginResponse(
            success=False,
            error=str(e)
        )


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Отправка запроса к YandexGPT
    Возвращает текстовый ответ и опционально извлечённый код
    """
    if not gpt_client:
        raise HTTPException(status_code=401, detail="Not authenticated. Call /login first.")
    
    try:
        model = request.context.get("model", "yandexgpt-lite")
        temperature = request.context.get("temperature", 0.7)
        max_tokens = request.context.get("max_tokens", 2000)
        
        # Формируем системный промт для генерации GDScript кода
        system_prompt = """Ты — опытный разработчик Godot Engine 4.6.
Твоя задача — помогать создавать игры на GDScript 2.0.
Отвечай на русском языке.
Если нужно написать код, используй блоки ```gdscript ... ```.
Код должен быть совместим с Godot 4.6.3.stable.official.
Используй современный синтаксис GDScript 2.0: @export, @onready, typed variables, await, Callable."""

        response = await gpt_client.completion(
            prompt=request.prompt,
            system_prompt=system_prompt,
            model=model,
            temperature=temperature,
            max_tokens=max_tokens
        )
        
        text = response.get("text", "")
        tokens_used = response.get("tokens_used", 0)
        
        # Извлекаем код из markdown блоков
        code = extract_code_from_response(text)
        
        return ChatResponse(
            success=True,
            text=text,
            code=code,
            tokens_used=tokens_used
        )
    
    except Exception as e:
        return ChatResponse(
            success=False,
            error=str(e)
        )


@app.post("/generate_game", response_model=GenerateGameResponse)
async def generate_game(request: GenerateGameRequest):
    """
    Генерация полноценной игры по описанию задачи
    Возвращает список файлов с кодом и сценами
    """
    if not gpt_client:
        raise HTTPException(status_code=401, detail="Not authenticated. Call /login first.")
    
    try:
        # Системный промт для генерации структуры проекта
        system_prompt = """Ты — senior Godot разработчик.
Создай полноценную игру по заданию пользователя.
Верни ответ в формате JSON со списком файлов:
{
    "files": [
        {"path": "res://game/main.gd", "content": "..."},
        {"path": "res://game/player.gd", "content": "..."}
    ]
}
Используй только GDScript 2.0 для Godot 4.6.3.
Включи все необходимые скрипты и описание сцен."""

        response = await gpt_client.completion(
            prompt=f"Создай игру: {request.task}",
            system_prompt=system_prompt,
            model="yandexgpt",
            temperature=0.7,
            max_tokens=4000
        )
        
        text = response.get("text", "")
        
        # Парсим JSON ответ или извлекаем файлы из текста
        files = parse_files_from_response(text)
        
        if not files:
            # Если не удалось распарсить, создаём базовую структуру
            files = create_basic_game_structure(request.task)
        
        # Отправляем файлы в Godot для создания
        for file_info in files:
            await godot_bridge.create_file(file_info["path"], file_info["content"])
        
        return GenerateGameResponse(
            success=True,
            files=[FileInfo(**f) for f in files]
        )
    
    except Exception as e:
        return GenerateGameResponse(
            success=False,
            error=str(e)
        )


@app.get("/health")
async def health_check():
    """Проверка работоспособности сервера"""
    return {
        "status": "ok",
        "authenticated": gpt_client is not None,
        "godot_connected": await godot_bridge.check_connection()
    }


def extract_code_from_response(text: str) -> Optional[str]:
    """Извлечение GDScript кода из markdown блоков"""
    patterns = [
        r'```gdscript\s*(.*?)\s*```',
        r'```gd\s*(.*?)\s*```',
        r'```\s*(.*?)\s*```'
    ]
    
    for pattern in patterns:
        match = re.search(pattern, text, re.DOTALL)
        if match:
            code = match.group(1).strip()
            # Проверяем, что это действительно GDScript
            if any(keyword in code for keyword in ['extends', 'func ', '@export', '@onready', 'var ']):
                return code
    
    return None


def parse_files_from_response(text: str) -> List[Dict[str, str]]:
    """Парсинг JSON ответа со списком файлов"""
    import json
    
    try:
        # Пытаемся найти JSON в тексте
        json_match = re.search(r'\{.*"files".*\}', text, re.DOTALL)
        if json_match:
            data = json.loads(json_match.group())
            return data.get("files", [])
    except:
        pass
    
    return []


def create_basic_game_structure(task: str) -> List[Dict[str, str]]:
    """Создание базовой структуры игры по заданию"""
    return [
        {
            "path": "res://game/main.gd",
            "content": """extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var score_label: Label = $UI/ScoreLabel

var score: int = 0

func _ready():
    print("Game started!")
    update_score()

func add_score(points: int):
    score += points
    update_score()

func update_score():
    if score_label:
        score_label.text = "Score: %d" % score
"""
        },
        {
            "path": "res://game/player.gd",
            "content": """extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -400.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
    # Добавляем гравитацию
    if not is_on_floor():
        velocity.y += gravity * delta
    
    # Обработка прыжка
    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = jump_velocity
    
    # Обработка движения
    var direction: float = Input.get_axis("ui_left", "ui_right")
    if direction:
        velocity.x = direction * speed
    else:
        velocity.x = move_toward(velocity.x, 0, speed)
    
    move_and_slide()
"""
        }
    ]


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8000"))
    print(f"[AI Yandex] Starting server on http://127.0.0.1:{port}")
    uvicorn.run(app, host="127.0.0.1", port=port)
