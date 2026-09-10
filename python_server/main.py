import asyncio
import argparse
import json
from aiohttp import web
import requests

# Глобальные настройки
API_KEY = None
FOLDER_ID = None
MODEL = "yandexgpt-lite"
TEMPERATURE = 0.7


async def health_handler(request):
    """Endpoint для проверки здоровья сервера"""
    return web.json_response({
        "status": "ok",
        "service": "ai-yandex-backend"
    })


async def chat_handler(request):
    """Основной endpoint для чата с Yandex GPT"""
    global API_KEY, FOLDER_ID, MODEL, TEMPERATURE
    
    try:
        data = await request.json()
    except json.JSONDecodeError:
        return web.json_response(
            {"error": "invalid json"},
            status=400
        )
    
    prompt = data.get("prompt", "")
    api_key = data.get("api_key", API_KEY)
    folder_id = data.get("folder_id", FOLDER_ID)
    model = data.get("model", MODEL)
    temperature = data.get("temperature", TEMPERATURE)
    
    if not prompt:
        return web.json_response(
            {"error": "prompt is required"},
            status=400
        )
    
    if not api_key:
        return web.json_response(
            {"error": "api_key is required"},
            status=400
        )
    
    if not folder_id:
        return web.json_response(
            {"error": "folder_id is required"},
            status=400
        )
    
    # Формируем URI модели
    model_uri = f"gpt://{folder_id}/{model}"
    
    # Запрос к Yandex GPT API
    url = "https://llm.api.cloud.yandex.net/foundationModels/v1/completion"
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Api-Key {api_key}"
    }
    
    payload = {
        "modelUri": model_uri,
        "completionOptions": {
            "stream": False,
            "temperature": temperature,
            "maxTokens": 2000
        },
        "messages": [
            {
                "role": "system",
                "text": (
                    "Ты помощник разработчика игр на Godot Engine. "
                    "Ты пишешь код на GDScript. "
                    "Если тебя просят написать код, обязательно оборачивай его в блоки кода."
                )
            },
            {
                "role": "user",
                "text": prompt
            }
        ]
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=60)
        response.raise_for_status()
        
        result = response.json()
        
        # Извлекаем ответ
        if "result" in result and "alternatives" in result["result"]:
            alternatives = result["result"]["alternatives"]
            
            if alternatives and len(alternatives) > 0:
                message = alternatives[0].get("message", {})
                text = message.get("text", "")
                
                # Парсим блоки кода из ответа
                code_blocks = extract_code_blocks(text)
                
                return web.json_response({
                    "response": text,
                    "code_blocks": code_blocks
                })
        
        return web.json_response({
            "response": "No response from AI",
            "code_blocks": []
        })
        
    except requests.exceptions.RequestException as e:
        return web.json_response(
            {"error": str(e)},
            status=500
        )


def extract_code_blocks(text: str) -> list:
    """Извлекает блоки кода из текста ответа"""
    import re
    
    # Ищем блоки кода в формате ```language ... ```
    pattern = r"```(?:gdscript|python|javascript|json)?\s*([\s\S]*?)```"
    matches = re.findall(pattern, text)
    
    return [match.strip() for match in matches if match.strip()]


def create_app():
    """Создаёт и настраивает веб-приложение"""
    app = web.Application()
    app.router.add_get("/health", health_handler)
    app.router.add_post("/chat", chat_handler)
    return app


def main():
    parser = argparse.ArgumentParser(description="AI Yandex Backend Server")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8000, help="Port to listen on")
    
    args = parser.parse_args()
    
    print(f"[AI_Yandex Python Server] Starting on {args.host}:{args.port}")
    
    app = create_app()
    web.run_app(app, host=args.host, port=args.port, print=None)


if __name__ == "__main__":
    main()
