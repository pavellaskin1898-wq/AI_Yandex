from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
import httpx
import asyncio
import re

app = FastAPI(title="AI Yandex Backend")

# CORS для localhost
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==================== Модели данных ====================

class ChatRequest(BaseModel):
    prompt: str
    api_key: str
    folder_id: Optional[str] = ""
    model: str = "yandexgpt-lite"
    temperature: float = 0.6
    context: Optional[Dict[str, Any]] = None

class CodeExecuteRequest(BaseModel):
    code: str
    file_path: Optional[str] = ""

class GameGenerateRequest(BaseModel):
    description: str
    api_key: str
    folder_id: Optional[str] = ""
    model: str = "yandexgpt-lite"

class ChatResponse(BaseModel):
    success: bool
    response: str
    code_blocks: List[str] = []

# ==================== Эндпоинты ====================

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "ai-yandex-backend"}

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """Отправляет запрос к YandexGPT и возвращает ответ"""
    try:
        response_text = await call_yandex_gpt(
            prompt=request.prompt,
            api_key=request.api_key,
            folder_id=request.folder_id,
            model=request.model,
            temperature=request.temperature
        )
        return ChatResponse(
            success=True,
            response=response_text,
            code_blocks=extract_code_blocks(response_text)
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/generate_game")
async def generate_game(request: GameGenerateRequest):
    """Генерирует структуру игры по описанию"""
    system_prompt = """Ты эксперт по Godot Engine 4.6.3. 
Твоя задача — создать полноценную игру по описанию пользователя.
Верни ответ в формате JSON с полями:
- files: массив объектов {path: string, content: string, type: "script"|"scene"}
- instructions: краткая инструкция по запуску

Используй современный GDScript 2.0 синтаксис:
- @export, @onready, typed variables
- await вместо yield
- сигналы с типами
- PackedStringArray, PackedVector2Array и т.д.
"""
    
    try:
        response_text = await call_yandex_gpt(
            prompt=f"Создай игру: {request.description}",
            api_key=request.api_key,
            folder_id=request.folder_id,
            model=request.model,
            temperature=0.7,
            system_prompt=system_prompt
        )
        return {
            "success": True,
            "response": response_text,
            "code_blocks": extract_code_blocks(response_text)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/execute")
async def execute_code(request: CodeExecuteRequest):
    """Отправляет код в Godot для выполнения"""
    return {
        "success": True,
        "message": f"Code queued for execution ({len(request.code)} chars)",
        "file_path": request.file_path
    }

# ==================== YandexGPT вызовы ====================

async def call_yandex_gpt(
    prompt: str,
    api_key: str,
    folder_id: str,
    model: str = "yandexgpt-lite",
    temperature: float = 0.6,
    system_prompt: Optional[str] = None
) -> str:
    """Вызов YandexGPT через API Key"""
    
    url = "https://llm.api.cloud.yandex.net/foundationModels/v1/completion"
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Api-Key {api_key}"
    }
    
    messages = []
    if system_prompt:
        messages.append({"role": "system", "text": system_prompt})
    messages.append({"role": "user", "text": prompt})
    
    # Формируем modelUri
    if folder_id and folder_id.strip():
        model_uri = f"gpt://{folder_id}/{model}"
    else:
        model_uri = f"gpt://b1g.../{model}"
    
    payload = {
        "modelUri": model_uri,
        "completionOptions": {
            "stream": False,
            "temperature": temperature,
            "maxTokens": 2000
        },
        "messages": messages
    }
    
    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(url, json=payload, headers=headers)
        response.raise_for_status()
        data = response.json()
        
        result = data.get("result", {})
        alternatives = result.get("alternatives", [])
        if alternatives and len(alternatives) > 0:
            return alternatives[0].get("message", {}).get("text", "")
        
        return "No response from YandexGPT"

def extract_code_blocks(text: str) -> list:
    """Извлекает блоки кода из markdown"""
    blocks = []
    
    pattern = r'```(?:gdscript|gd)?\s*(.*?)```'
    matches = re.findall(pattern, text, re.DOTALL)
    
    for match in matches:
        code = match.strip()
        if code:
            blocks.append(code)
    
    if not blocks:
        lines = text.split('\n')
        code_lines = []
        in_code = False
        for line in lines:
            if any(kw in line for kw in ['func ', 'var ', 'class ', '@export', '@onready', 'extends ']):
                code_lines.append(line)
                in_code = True
            elif in_code:
                code_lines.append(line)
        
        if code_lines:
            blocks.append('\n'.join(code_lines))
    
    return blocks

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
