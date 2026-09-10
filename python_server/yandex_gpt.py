# ===== python_server/yandex_gpt.py =====
"""
Клиент для работы с YandexGPT API
Использует Foundation Models API Яндекс.Облака
"""

import asyncio
import httpx
from typing import Optional, Dict, Any, List


class YandexGPTClient:
    """Класс для взаимодействия с YandexGPT через API"""
    
    # API Endpoint для YandexGPT
    COMPLETION_URL = "https://llm.api.cloud.yandex.net/foundationModels/v1/completion"
    STREAM_URL = "https://llm.api.cloud.yandex.net/foundationModels/v1/completionStream"
    
    # Модели
    MODELS = {
        "yandexgpt-lite": "yandexgpt-lite/latest",
        "yandexgpt": "yandexgpt/latest",
        "yandexgpt-pro": "yandexgpt/pro"
    }
    
    def __init__(self, iam_token: str):
        """
        Инициализация клиента
        
        Args:
            iam_token: IAM токен для авторизации в Yandex Cloud
        """
        self.iam_token = iam_token
        self.headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {iam_token}",
            "x-folder-id": self._get_default_folder_id()
        }
    
    def _get_default_folder_id(self) -> str:
        """Получение ID каталога по умолчанию (можно переопределить)"""
        # В реальном проекте нужно получать из конфига или env
        return ""  # Пустой означает использование каталога по умолчанию
    
    async def completion(
        self,
        prompt: str,
        system_prompt: str = "",
        model: str = "yandexgpt-lite",
        temperature: float = 0.7,
        max_tokens: int = 2000
    ) -> Dict[str, Any]:
        """
        Запрос к модели для получения завершения текста
        
        Args:
            prompt: Пользовательский запрос
            system_prompt: Системный промт (инструкция для модели)
            model: Название модели (yandexgpt-lite, yandexgpt, yandexgpt-pro)
            temperature: Температура генерации (0.0 - 2.0)
            max_tokens: Максимальное количество токенов в ответе
        
        Returns:
            Dictionary с текстом ответа и метаданными
        """
        model_uri = self.MODELS.get(model, self.MODELS["yandexgpt-lite"])
        
        # Формируем сообщения для API
        messages = []
        
        if system_prompt:
            messages.append({
                "role": "system",
                "text": system_prompt
            })
        
        messages.append({
            "role": "user",
            "text": prompt
        })
        
        # Тело запроса
        payload = {
            "modelUri": model_uri,
            "completionOptions": {
                "stream": False,
                "temperature": temperature,
                "maxTokens": max_tokens
            },
            "messages": messages
        }
        
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    self.COMPLETION_URL,
                    headers=self.headers,
                    json=payload
                )
                
                if response.status_code != 200:
                    error_text = response.text[:200]
                    return {
                        "text": f"API Error: {response.status_code} - {error_text}",
                        "tokens_used": 0,
                        "error": True
                    }
                
                data = response.json()
                
                # Извлекаем ответ
                result = data.get("result", {})
                alternatives = result.get("alternatives", [])
                
                if not alternatives:
                    return {
                        "text": "No response from model",
                        "tokens_used": 0,
                        "error": True
                    }
                
                text = alternatives[0].get("message", {}).get("text", "")
                
                # Получаем информацию о токенах
                usage = data.get("usage", {})
                input_tokens = usage.get("inputTextTokens", 0)
                output_tokens = usage.get("completionTokens", 0)
                total_tokens = input_tokens + output_tokens
                
                return {
                    "text": text,
                    "tokens_used": total_tokens,
                    "input_tokens": input_tokens,
                    "output_tokens": output_tokens,
                    "error": False
                }
        
        except httpx.TimeoutException:
            return {
                "text": "Request timeout",
                "tokens_used": 0,
                "error": True
            }
        except Exception as e:
            return {
                "text": f"Error: {str(e)}",
                "tokens_used": 0,
                "error": True
            }
    
    async def completion_stream(
        self,
        prompt: str,
        system_prompt: str = "",
        model: str = "yandexgpt-lite",
        temperature: float = 0.7,
        max_tokens: int = 2000
    ):
        """
        Стриминговый запрос к модели
        
        Yield:
            Чанки текста по мере генерации
        """
        model_uri = self.MODELS.get(model, self.MODELS["yandexgpt-lite"])
        
        messages = []
        if system_prompt:
            messages.append({"role": "system", "text": system_prompt})
        messages.append({"role": "user", "text": prompt})
        
        payload = {
            "modelUri": model_uri,
            "completionOptions": {
                "stream": True,
                "temperature": temperature,
                "maxTokens": max_tokens
            },
            "messages": messages
        }
        
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                async with client.stream(
                    "POST",
                    self.STREAM_URL,
                    headers=self.headers,
                    json=payload
                ) as response:
                    async for line in response.aiter_lines():
                        if line.startswith("data: "):
                            data_str = line[6:]
                            if data_str.strip() == "[DONE]":
                                break
                            
                            try:
                                import json
                                data = json.loads(data_str)
                                chunk = data.get("chunk", {})
                                text = chunk.get("delta", {}).get("text", "")
                                if text:
                                    yield text
                            except:
                                continue
        
        except Exception as e:
            yield f"[Error: {str(e)}]"
    
    async def chat(
        self,
        messages: List[Dict[str, str]],
        model: str = "yandexgpt-lite",
        temperature: float = 0.7,
        max_tokens: int = 2000
    ) -> Dict[str, Any]:
        """
        Chat-запрос с историей диалога
        
        Args:
            messages: Список сообщений [{"role": "user|assistant|system", "text": "..."}]
            model: Модель
            temperature: Температура
            max_tokens: Макс токенов
        
        Returns:
            Ответ от модели
        """
        model_uri = self.MODELS.get(model, self.MODELS["yandexgpt-lite"])
        
        payload = {
            "modelUri": model_uri,
            "completionOptions": {
                "stream": False,
                "temperature": temperature,
                "maxTokens": max_tokens
            },
            "messages": messages
        }
        
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    self.COMPLETION_URL,
                    headers=self.headers,
                    json=payload
                )
                
                if response.status_code != 200:
                    return {"text": f"API Error: {response.status_code}", "error": True}
                
                data = response.json()
                result = data.get("result", {})
                alternatives = result.get("alternatives", [])
                
                if alternatives:
                    text = alternatives[0].get("message", {}).get("text", "")
                    usage = data.get("usage", {})
                    return {
                        "text": text,
                        "tokens_used": usage.get("completionTokens", 0),
                        "error": False
                    }
                
                return {"text": "No response", "error": True}
        
        except Exception as e:
            return {"text": f"Error: {str(e)}", "error": True}
    
    def set_iam_token(self, token: str):
        """Обновление IAM токена"""
        self.iam_token = token
        self.headers["Authorization"] = f"Bearer {token}"
