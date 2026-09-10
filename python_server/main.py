"""
AI Yandex Agent - Python Backend Server
FastAPI application for Yandex Alice/YandexGPT integration with Godot

This server handles:
1. Authentication with Yandex Passport
2. Communication with YandexGPT/Alice Dialogs API
3. Code generation based on user prompts
4. Sending generated GDScript code back to Godot editor
"""

import asyncio
import json
import logging
from typing import Optional, Dict, Any
from dataclasses import dataclass

import aiohttp
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, SecretStr
import uvicorn

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# FastAPI application
app = FastAPI(
    title="AI Yandex Agent Backend",
    description="Backend server for Yandex Alice/GPT integration with Godot",
    version="1.0.0"
)


# ==================== Pydantic Models ====================

class AuthRequest(BaseModel):
    """Authentication request model."""
    username: str
    password: SecretStr


class GenerateRequest(BaseModel):
    """Game generation request model."""
    prompt: str
    username: str


class CodeRequest(BaseModel):
    """Code execution request model."""
    code: str
    username: str


class AuthResponse(BaseModel):
    """Authentication response model."""
    status: str
    username: Optional[str] = None
    token: Optional[str] = None
    message: Optional[str] = None


class GenerateResponse(BaseModel):
    """Generation response model."""
    status: str
    message: Optional[str] = None
    code: Optional[str] = None


# ==================== Global State ====================

# Store authenticated users and their tokens
authenticated_users: Dict[str, Dict[str, Any]] = {}

# Yandex API configuration
YANDEX_AUTH_URL = "https://passport.yandex.ru/auth"
YANDEX_GPT_URL = "https://llm.api.cloud.yandex.net/foundationModels/v1/completion"

# Godot server configuration
GODOT_SERVER_HOST = "127.0.0.1"
GODOT_SERVER_PORT = 8765


# ==================== Helper Functions ====================

async def authenticate_yandex(username: str, password: str) -> Optional[Dict[str, Any]]:
    """
    Authenticate with Yandex Passport using login/password.
    
    This is a simplified implementation. In production, you should:
    1. Use proper CSRF token handling
    2. Handle 2FA if enabled
    3. Use OAuth2 flow instead of password authentication
    
    Returns auth data including IAM token if successful.
    """
    logger.info(f"Attempting authentication for user: {username}")
    
    # NOTE: This is a placeholder implementation
    # Real implementation would require:
    # 1. GET request to passport.yandex.ru to get CSRF token
    # 2. POST request with credentials and CSRF token
    # 3. Parse response for oauth_token
    # 4. Exchange oauth_token for IAM token
    
    try:
        async with aiohttp.ClientSession() as session:
            # Step 1: Get CSRF token (simplified)
            async with session.get(YANDEX_AUTH_URL) as response:
                if response.status != 200:
                    logger.error(f"Failed to get auth page: {response.status}")
                    return None
            
            # Step 2: Attempt login (simplified - requires proper form data)
            # In real implementation, you need to extract CSRF token from cookies/forms
            login_data = {
                'login': username,
                'passwd': password,
            }
            
            # This is a placeholder - real implementation needs proper CSRF handling
            # async with session.post(YANDEX_AUTH_URL, data=login_data) as response:
            #     if response.status == 200:
            #         # Parse response for tokens
            #         pass
            
            # For demo purposes, we'll simulate successful auth
            # In production, implement proper passport authentication
            logger.warning("Using simulated authentication (demo mode)")
            
            return {
                'username': username,
                'oauth_token': 'simulated_oauth_token_' + username,
                'iam_token': 'simulated_iam_token_' + username,
            }
            
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        return None


async def get_iam_token(oauth_token: str) -> Optional[str]:
    """
    Exchange OAuth token for IAM token.
    IAM token is required for YandexGPT API calls.
    """
    logger.info("Exchanging OAuth token for IAM token")
    
    try:
        async with aiohttp.ClientSession() as session:
            url = "https://iam.api.cloud.yandex.net/iam/v1/tokens"
            headers = {
                'Content-Type': 'application/json',
            }
            data = {
                'yandexPassportOauthToken': oauth_token
            }
            
            async with session.post(url, json=data, headers=headers) as response:
                if response.status == 200:
                    result = await response.json()
                    iam_token = result.get('iamToken')
                    logger.info("IAM token received successfully")
                    return iam_token
                else:
                    logger.error(f"Failed to get IAM token: {response.status}")
                    return None
                    
    except Exception as e:
        logger.error(f"IAM token exchange error: {e}")
        return None


async def call_yandex_gpt(prompt: str, iam_token: str) -> Optional[str]:
    """
    Call YandexGPT API to generate game code.
    
    The prompt should instruct the model to generate GDScript code
    that can be executed in Godot Editor.
    """
    logger.info(f"Calling YandexGPT with prompt: {prompt[:100]}...")
    
    # System prompt for code generation
    system_prompt = """Ты — опытный разработчик игр на Godot Engine 4.6.3.
Твоя задача — генерировать рабочий GDScript код для создания игр.

Требования к коду:
1. Код должен быть на GDScript 2.0 (синтаксис Godot 4.x)
2. Используй @tool аннотации для скриптов редактора
3. Код должен быть готовым к выполнению в редакторе Godot
4. Включай комментарии на русском языке
5. Создавай полные, рабочие решения

Формат ответа:
- Сначала краткое описание того, что будет создано
- Затем полный GDScript код в блоке кода
- Код должен включать создание сцен, узлов, и настройку свойств"""

    try:
        async with aiohttp.ClientSession() as session:
            url = YANDEX_GPT_URL
            headers = {
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {iam_token}',
            }
            
            data = {
                "modelUri": "gpt://b1gxxxxxxxxx/yandexgpt-lite",  # Replace with your folder ID
                "completionOptions": {
                    "stream": False,
                    "temperature": 0.7,
                    "maxTokens": 4000
                },
                "messages": [
                    {
                        "role": "system",
                        "text": system_prompt
                    },
                    {
                        "role": "user",
                        "text": f"Создай игру по следующему описанию: {prompt}"
                    }
                ]
            }
            
            async with session.post(url, json=data, headers=headers) as response:
                if response.status == 200:
                    result = await response.json()
                    # Extract generated text from response
                    alternatives = result.get('result', {}).get('alternatives', [])
                    if alternatives:
                        generated_text = alternatives[0].get('message', {}).get('text', '')
                        logger.info("YandexGPT response received")
                        return generated_text
                    else:
                        logger.warning("No alternatives in GPT response")
                        return None
                else:
                    error_text = await response.text()
                    logger.error(f"YandexGPT API error: {response.status} - {error_text}")
                    return None
                    
    except Exception as e:
        logger.error(f"YandexGPT call error: {e}")
        return None


def extract_code_from_response(text: str) -> str:
    """
    Extract GDScript code from GPT response.
    Looks for code blocks marked with ```gdscript or ```
    """
    import re
    
    # Try to find gdscript code blocks first
    pattern = r'```gdscript\s*(.*?)\s*```'
    matches = re.findall(pattern, text, re.DOTALL | re.IGNORECASE)
    
    if not matches:
        # Try generic code blocks
        pattern = r'```\s*(.*?)\s*```'
        matches = re.findall(pattern, text, re.DOTALL)
    
    if matches:
        # Return the largest code block
        return max(matches, key=len).strip()
    
    # If no code blocks found, return the whole text
    return text.strip()


async def send_code_to_godot(code: str) -> bool:
    """
    Send generated GDScript code to Godot editor via HTTP.
    """
    logger.info("Sending code to Godot editor...")
    
    try:
        async with aiohttp.ClientSession() as session:
            url = f"http://{GODOT_SERVER_HOST}:{GODOT_SERVER_PORT}/execute"
            headers = {
                'Content-Type': 'application/json',
            }
            data = {
                'code': code
            }
            
            async with session.post(url, json=data, headers=headers, timeout=aiohttp.ClientTimeout(total=10)) as response:
                if response.status == 200:
                    result = await response.json()
                    if result.get('success'):
                        logger.info("Code executed successfully in Godot")
                        return True
                    else:
                        logger.warning(f"Godot reported failure: {result.get('message')}")
                        return False
                else:
                    logger.error(f"Failed to send code to Godot: {response.status}")
                    return False
                    
    except Exception as e:
        logger.error(f"Error sending code to Godot: {e}")
        return False


# ==================== API Endpoints ====================

@app.get("/")
async def root():
    """Root endpoint - health check."""
    return {
        "status": "ok",
        "service": "AI Yandex Agent Backend",
        "version": "1.0.0"
    }


@app.post("/auth", response_model=AuthResponse)
async def authenticate(request: AuthRequest):
    """
    Authenticate user with Yandex Passport.
    
    Stores authentication tokens for subsequent API calls.
    """
    username = request.username
    password = request.password.get_secret_value()
    
    logger.info(f"Auth request for user: {username}")
    
    # Authenticate with Yandex
    auth_data = await authenticate_yandex(username, password)
    
    if not auth_data:
        raise HTTPException(status_code=401, detail="Authentication failed")
    
    # Store auth data
    authenticated_users[username] = auth_data
    
    # Send auth confirmation to Godot
    async with aiohttp.ClientSession() as session:
        try:
            godot_url = f"http://{GODOT_SERVER_HOST}:{GODOT_SERVER_PORT}/auth"
            godot_data = {
                'username': username,
                'token': auth_data.get('iam_token', '')
            }
            await session.post(godot_url, json=godot_data, timeout=aiohttp.ClientTimeout(total=5))
        except Exception as e:
            logger.warning(f"Could not notify Godot about auth: {e}")
    
    return AuthResponse(
        status="authenticated",
        username=username,
        token=auth_data.get('iam_token'),
        message=f"Successfully authenticated as {username}"
    )


@app.post("/generate", response_model=GenerateResponse)
async def generate_game(request: GenerateRequest):
    """
    Generate game code based on user prompt.
    
    Uses YandexGPT to create GDScript code and sends it to Godot for execution.
    """
    username = request.username
    prompt = request.prompt
    
    logger.info(f"Generation request from {username}: {prompt[:100]}...")
    
    # Check if user is authenticated
    if username not in authenticated_users:
        raise HTTPException(status_code=401, detail="User not authenticated")
    
    auth_data = authenticated_users[username]
    iam_token = auth_data.get('iam_token')
    
    if not iam_token:
        raise HTTPException(status_code=500, detail="No valid IAM token available")
    
    # Call YandexGPT
    gpt_response = await call_yandex_gpt(prompt, iam_token)
    
    if not gpt_response:
        raise HTTPException(status_code=500, detail="Failed to generate code from YandexGPT")
    
    # Extract code from response
    generated_code = extract_code_from_response(gpt_response)
    
    # Send code to Godot
    code_sent = await send_code_to_godot(generated_code)
    
    if code_sent:
        return GenerateResponse(
            status="success",
            message="Game code generated and sent to Godot",
            code=generated_code
        )
    else:
        return GenerateResponse(
            status="partial",
            message="Code generated but failed to execute in Godot",
            code=generated_code
        )


@app.post("/code")
async def receive_code(request: CodeRequest):
    """
    Receive code from external source (for future use).
    """
    username = request.username
    code = request.code
    
    logger.info(f"Received code from {username}")
    
    # Forward to Godot
    success = await send_code_to_godot(code)
    
    return {
        "status": "success" if success else "failed",
        "message": "Code forwarded to Godot" if success else "Failed to forward code"
    }


@app.get("/status")
async def get_status():
    """Get server status and authenticated users."""
    return {
        "status": "running",
        "authenticated_users": list(authenticated_users.keys()),
        "godot_server": f"{GODOT_SERVER_HOST}:{GODOT_SERVER_PORT}"
    }


# ==================== Main Entry Point ====================

if __name__ == "__main__":
    print("=" * 60)
    print("AI Yandex Agent Backend Server")
    print("=" * 60)
    print(f"Starting server on http://0.0.0.0:8000")
    print(f"Godot server target: {GODOT_SERVER_HOST}:{GODOT_SERVER_PORT}")
    print("=" * 60)
    print("\nIMPORTANT: This is a demo implementation.")
    print("For production use, implement proper Yandex Passport authentication")
    print("with CSRF token handling and OAuth2 flow.\n")
    
    uvicorn.run(app, host="0.0.0.0", port=8000)
