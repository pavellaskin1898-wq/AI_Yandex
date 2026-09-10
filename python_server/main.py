"""
FastAPI application for AI Yandex Assistant.
Provides endpoints for authentication, chat, and code generation.
"""
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict, Any

from yandex_auth import YandexAuthenticator, YandexAuthResult
from yandex_gpt import (
    YandexGPTClient, 
    YandexGPTConfig, 
    Message, 
    extract_all_code_blocks
)
from godot_bridge import GodotBridge, GodotBridgeConfig


# ============== Pydantic Models ==============

class LoginRequest(BaseModel):
    login: str
    password: str


class LoginResponse(BaseModel):
    success: bool
    email: str = ""
    oauth_token: str = ""
    iam_token: Optional[str] = None
    error: Optional[str] = None


class ChatRequest(BaseModel):
    prompt: str
    context: Optional[Dict[str, Any]] = None
    token: Optional[str] = None  # OAuth token from login


class ChatResponse(BaseModel):
    success: bool
    response: str = ""
    code_blocks: Dict[str, str] = {}
    error: Optional[str] = None


class GenerateGameRequest(BaseModel):
    description: str
    token: Optional[str] = None


class GenerateGameResponse(BaseModel):
    success: bool
    files: Dict[str, str] = {}
    plan: str = ""
    error: Optional[str] = None


# ============== Application ==============

app = FastAPI(
    title="AI Yandex Assistant Backend",
    description="Backend service for Godot AI Yandex plugin",
    version="1.0.0"
)

# CORS middleware for localhost communication
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Only localhost in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global state (in production, use proper session management)
_sessions: Dict[str, Dict[str, Any]] = {}


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "ok"}


@app.post("/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    """
    Authenticate with Yandex Passport.
    
    Returns OAuth and IAM tokens for subsequent API calls.
    """
    auth = YandexAuthenticator()
    result: YandexAuthResult = await auth.login(request.login, request.password)
    
    if result.error:
        return LoginResponse(
            success=False,
            email=request.login,
            error=result.error
        )
    
    # Store session (simplified - in production use proper session mgmt)
    session_id = result.oauth_token[:16]  # Use token prefix as session ID
    _sessions[session_id] = {
        "email": result.email,
        "oauth_token": result.oauth_token,
        "iam_token": result.iam_token,
    }
    
    return LoginResponse(
        success=True,
        email=result.email,
        oauth_token=result.oauth_token,
        iam_token=result.iam_token
    )


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Send a message to YandexGPT and get a response.
    
    If the response contains GDScript code blocks, they are extracted
    and returned separately for easy integration with Godot.
    """
    if not request.token:
        return ChatResponse(
            success=False,
            error="Authentication required. Please login first."
        )
    
    # Get IAM token from session or use provided token directly
    iam_token = request.token
    session_id = request.token[:16] if len(request.token) > 16 else ""
    if session_id in _sessions:
        iam_token = _sessions[session_id].get("iam_token") or request.token
    
    if not iam_token:
        return ChatResponse(
            success=False,
            error="Invalid or expired token. Please login again."
        )
    
    # Initialize GPT client
    config = YandexGPTConfig(
        model="yandexgpt-lite",
        temperature=0.6,
        max_tokens=2000
    )
    client = YandexGPTClient(iam_token=iam_token, config=config)
    
    # Build messages
    messages = [Message(role="user", text=request.prompt)]
    
    # Add context if provided
    if request.context:
        context_text = "\n".join(f"{k}: {v}" for k, v in request.context.items())
        messages.insert(0, Message(role="system", text=f"Context:\n{context_text}"))
    
    # Get completion
    system_prompt = client.get_system_prompt_for_godot()
    result = await client.complete(messages, system_prompt=system_prompt)
    
    if result.error:
        return ChatResponse(
            success=False,
            error=result.error
        )
    
    # Extract code blocks
    code_blocks = extract_all_code_blocks(result.text)
    
    # If code was generated, send it to Godot
    if code_blocks:
        bridge = GodotBridge()
        for file_path, code in code_blocks.items():
            await bridge.execute_code(code, file_path)
    
    return ChatResponse(
        success=True,
        response=result.text,
        code_blocks=code_blocks
    )


@app.post("/generate_game", response_model=GenerateGameResponse)
async def generate_game(request: GenerateGameRequest):
    """
    Generate a complete game based on a description.
    
    This is a high-level endpoint that:
    1. Creates a development plan
    2. Generates all necessary scripts and scenes
    3. Sends them to Godot for creation
    """
    if not request.token:
        return GenerateGameResponse(
            success=False,
            error="Authentication required. Please login first."
        )
    
    # Get IAM token
    iam_token = request.token
    session_id = request.token[:16] if len(request.token) > 16 else ""
    if session_id in _sessions:
        iam_token = _sessions[session_id].get("iam_token") or request.token
    
    if not iam_token:
        return GenerateGameResponse(
            success=False,
            error="Invalid or expired token. Please login again."
        )
    
    config = YandexGPTConfig(
        model="yandexgpt-lite",
        temperature=0.7,
        max_tokens=4000
    )
    client = YandexGPTClient(iam_token=iam_token, config=config)
    
    # Enhanced system prompt for game generation
    system_prompt = """You are an expert Godot 4.6 game developer.
Generate a COMPLETE, playable game based on the user's description.

Requirements:
1. First, provide a brief development plan
2. Then generate ALL necessary files with full code
3. Include: player controller, enemies, UI, game manager, etc.
4. Use proper Godot 4.6 GDScript 2.0 syntax
5. Mark each file clearly: ```gdscript path/to/file.gd ... ```

The game should be immediately playable after importing all files."""

    messages = [
        Message(role="system", text=system_prompt),
        Message(role="user", text=f"Create a game: {request.description}")
    ]
    
    result = await client.complete(messages)
    
    if result.error:
        return GenerateGameResponse(
            success=False,
            error=result.error
        )
    
    # Extract all code blocks
    files = extract_all_code_blocks(result.text)
    
    # Send each file to Godot
    if files:
        bridge = GodotBridge()
        for file_path, content in files.items():
            await bridge.execute_code(content, file_path)
    
    return GenerateGameResponse(
        success=True,
        files=files,
        plan="Game files generated successfully"
    )


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="127.0.0.1",
        port=8000,
        reload=True
    )
