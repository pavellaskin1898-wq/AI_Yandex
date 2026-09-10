"""
YandexGPT API Wrapper.
Provides completion and streaming capabilities using Yandex Foundation Models API.
"""
import httpx
from typing import Optional, List, Dict, Any, AsyncGenerator
from pydantic import BaseModel


class YandexGPTConfig(BaseModel):
    model: str = "yandexgpt-lite"
    temperature: float = 0.6
    max_tokens: int = 2000
    folder_id: Optional[str] = None  # Yandex Cloud folder ID (optional for some endpoints)


class Message(BaseModel):
    role: str  # "system", "user", "assistant"
    text: str


class YandexGPTResult(BaseModel):
    text: str
    usage: Dict[str, int] = {}
    error: Optional[str] = None


class YandexGPTClient:
    """
    Client for YandexGPT / Yandex Foundation Models API.
    Supports both completion and streaming modes.
    """
    
    def __init__(self, iam_token: str, config: Optional[YandexGPTConfig] = None):
        self.iam_token = iam_token
        self.config = config or YandexGPTConfig()
        self.base_url = "https://llm.api.cloud.yandex.net/foundationModels/v1"
        self.headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {iam_token}",
        }
    
    async def complete(
        self,
        messages: List[Message],
        system_prompt: Optional[str] = None
    ) -> YandexGPTResult:
        """
        Get a completion from YandexGPT.
        
        Args:
            messages: List of conversation messages
            system_prompt: Optional system prompt to prepend
            
        Returns:
            YandexGPTResult with generated text
        """
        all_messages = []
        if system_prompt:
            all_messages.append({"role": "system", "text": system_prompt})
        all_messages.extend([{"role": m.role, "text": m.text} for m in messages])
        
        payload = {
            "modelUri": f"gpt://{self.config.model}",
            "completionOptions": {
                "stream": False,
                "temperature": self.config.temperature,
                "maxTokens": self.config.max_tokens,
            },
            "messages": all_messages,
        }
        
        if self.config.folder_id:
            payload["folderId"] = self.config.folder_id
        
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                resp = await client.post(
                    f"{self.base_url}/completion",
                    json=payload,
                    headers=self.headers
                )
                
                if resp.status_code != 200:
                    return YandexGPTResult(
                        text="",
                        error=f"API error: {resp.status_code} - {resp.text}"
                    )
                
                data = resp.json()
                result = data.get("result", {})
                alternatives = result.get("alternatives", [])
                
                if not alternatives:
                    return YandexGPTResult(text="", error="No alternatives in response")
                
                generated_text = alternatives[0].get("message", {}).get("text", "")
                usage = result.get("usage", {})
                
                return YandexGPTResult(
                    text=generated_text,
                    usage={
                        "input_tokens": usage.get("inputTextTokens", 0),
                        "output_tokens": usage.get("completionTokens", 0),
                        "total_tokens": usage.get("totalTokens", 0),
                    }
                )
                
        except Exception as e:
            return YandexGPTResult(text="", error=str(e))
    
    async def stream_complete(
        self,
        messages: List[Message],
        system_prompt: Optional[str] = None
    ) -> AsyncGenerator[str, None]:
        """
        Stream a completion from YandexGPT.
        
        Yields chunks of text as they are generated.
        Note: Streaming requires special handling and may not be 
        available in all API versions. This is a simplified implementation.
        """
        # For now, fall back to non-streaming and yield the full result
        # A proper streaming implementation would use SSE or chunked transfer
        result = await self.complete(messages, system_prompt)
        if result.text:
            yield result.text
    
    def get_system_prompt_for_godot(self) -> str:
        """
        Returns a system prompt optimized for Godot 4.6 GDScript generation.
        """
        return """You are an expert Godot 4.6 game developer specializing in GDScript 2.0.
Your task is to generate clean, efficient, and well-documented GDScript code.

Key guidelines:
- Use Godot 4.6 syntax (@export, @onready, @tool, @rpc, typed variables)
- Follow GDScript 2.0 conventions (no yield, use await, proper type hints)
- Include comments explaining complex logic
- Generate complete, runnable code snippets
- When creating scenes, provide both .tscn structure and attached scripts
- Prefer composition over inheritance where appropriate
- Use signals for decoupled communication between nodes
- Handle errors gracefully with try/except or proper checks

Always respond with code blocks marked as ```gdscript ... ``` or ```gd ... ```.
If the user asks for a complete game, break it down into logical files."""


# Convenience function for extracting code blocks from markdown responses
def extract_code_blocks(text: str, language: str = "gdscript") -> List[str]:
    """
    Extract code blocks of specified language from markdown text.
    
    Args:
        text: Markdown-formatted text
        language: Language identifier (e.g., "gdscript", "gd")
        
    Returns:
        List of code block contents
    """
    import re
    pattern = rf"```(?:{language}|gd)\s*(.*?)```"
    matches = re.findall(pattern, text, re.DOTALL)
    return [match.strip() for match in matches]


def extract_all_code_blocks(text: str) -> Dict[str, str]:
    """
    Extract all code blocks from markdown text, detecting language.
    
    Returns:
        Dict mapping file extension suggestion to code content
    """
    import re
    pattern = r"```(\w*)\s*(.*?)```"
    matches = re.findall(pattern, text, re.DOTALL)
    
    result = {}
    for lang, code in matches:
        ext = ".gd" if lang in ["gdscript", "gd"] else ".txt"
        key = f"generated_{len(result)}{ext}"
        result[key] = code.strip()
    
    return result
