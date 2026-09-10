"""
Godot Bridge Module.
Handles communication with the Godot editor plugin via HTTP.
"""
import httpx
from typing import Optional, Dict, Any
from pydantic import BaseModel


class GodotBridgeConfig(BaseModel):
    godot_host: str = "127.0.0.1"
    godot_port: int = 9876
    timeout: float = 30.0
    max_retries: int = 3


class ExecuteResult(BaseModel):
    success: bool
    message: str
    response_data: Optional[Dict[str, Any]] = None


class GodotBridge:
    """
    Bridge for sending commands to Godot editor plugin.
    
    Communicates via HTTP with the TCPServer running in the Godot plugin.
    Supports code execution and file creation commands.
    """
    
    def __init__(self, config: Optional[GodotBridgeConfig] = None):
        self.config = config or GodotBridgeConfig()
        self.base_url = f"http://{self.config.godot_host}:{self.config.godot_port}"
    
    async def execute_code(
        self, 
        code: str, 
        file_path: str = ""
    ) -> ExecuteResult:
        """
        Send GDScript code to Godot for execution.
        
        Args:
            code: GDScript code to execute
            file_path: Optional path where the code should be saved
            
        Returns:
            ExecuteResult with success status and response
        """
        payload = {
            "code": code,
            "file_path": file_path
        }
        
        for attempt in range(self.config.max_retries):
            try:
                async with httpx.AsyncClient(timeout=self.config.timeout) as client:
                    resp = await client.post(
                        f"{self.base_url}/execute",
                        json=payload
                    )
                    
                    if resp.status_code == 200:
                        data = resp.json()
                        return ExecuteResult(
                            success=True,
                            message=f"Code queued for execution ({data.get('len', 0)} chars)",
                            response_data=data
                        )
                    else:
                        return ExecuteResult(
                            success=False,
                            message=f"HTTP error: {resp.status_code}",
                            response_data={"status_code": resp.status_code}
                        )
                        
            except httpx.ConnectError:
                if attempt == self.config.max_retries - 1:
                    return ExecuteResult(
                        success=False,
                        message=f"Cannot connect to Godot at {self.base_url}",
                        response_data=None
                    )
            except Exception as e:
                if attempt == self.config.max_retries - 1:
                    return ExecuteResult(
                        success=False,
                        message=f"Error: {str(e)}",
                        response_data=None
                    )
        
        return ExecuteResult(success=False, message="Unknown error")
    
    async def create_file(
        self,
        file_path: str,
        content: str,
        file_type: str = "gdscript"
    ) -> ExecuteResult:
        """
        Request Godot to create a new file.
        
        Args:
            file_path: Path relative to res:// (e.g., "scripts/player.gd")
            content: File content
            file_type: Type hint ("gdscript", "scene", etc.)
            
        Returns:
            ExecuteResult with success status
        """
        # For now, this is handled via execute_code with special directives
        # A full implementation would use a dedicated /create_file endpoint
        code = f"# CREATE_FILE: {file_path}\n{content}"
        return await self.execute_code(code, file_path)
    
    async def health_check(self) -> bool:
        """
        Check if Godot plugin server is reachable.
        
        Returns:
            True if server responds, False otherwise
        """
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                resp = await client.get(f"{self.base_url}/health")
                return resp.status_code == 200
        except Exception:
            return False
