"""
Yandex Passport Authentication Module.
Handles login via passport.yandex.ru and obtains OAuth/IAM tokens.
"""
import httpx
from typing import Optional, Dict, Any
from pydantic import BaseModel


class YandexAuthResult(BaseModel):
    email: str
    oauth_token: str
    iam_token: Optional[str] = None
    error: Optional[str] = None


class YandexAuthenticator:
    """
    Authenticates with Yandex Passport using login/password.
    
    Note: This is a simplified implementation. Yandex may require
    2FA, captcha, or other verification methods for some accounts.
    For production use, consider using OAuth flow with user consent.
    """
    
    def __init__(self):
        self.base_url = "https://passport.yandex.ru"
        self.oauth_url = "https://oauth.yandex.ru"
        self.iam_url = "https://iam.api.cloud.yandex.net"
        self.client_id = "23cabbbdc6cd418abb4b39c32c41195d"  # Yandex Browser client ID (public)
    
    async def login(self, login: str, password: str) -> YandexAuthResult:
        """
        Perform login with Yandex Passport.
        
        Args:
            login: Yandex login (email or username)
            password: Account password
            
        Returns:
            YandexAuthResult with tokens or error
        """
        async with httpx.AsyncClient(timeout=30.0) as client:
            try:
                # Step 1: Get CSRF token and session
                resp = await client.get(f"{self.base_url}/auth")
                if resp.status_code != 200:
                    return YandexAuthResult(
                        email=login, 
                        oauth_token="", 
                        error=f"Failed to get auth page: {resp.status_code}"
                    )
                
                csrf_token = resp.cookies.get("csrf")
                if not csrf_token:
                    # Try to extract from HTML if not in cookies
                    import re
                    match = re.search(r'name="csrf"\s+value="([^"]+)"', resp.text)
                    if match:
                        csrf_token = match.group(1)
                
                # Step 2: Submit login form
                login_data = {
                    "login": login,
                    "password": password,
                    "csrf": csrf_token or "",
                    "retpath": "https://passport.yandex.ru/profile",
                }
                
                headers = {
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Origin": self.base_url,
                    "Referer": f"{self.base_url}/auth",
                }
                
                resp = await client.post(
                    f"{self.base_url}/auth/step/post/password",
                    data=login_data,
                    headers=headers,
                    follow_redirects=False
                )
                
                # Check for successful auth (redirect or specific status)
                if resp.status_code not in [302, 303] and "session_key" not in resp.cookies:
                    # Try alternative endpoint
                    resp = await client.post(
                        f"{self.base_url}/auth",
                        data=login_data,
                        headers=headers,
                        follow_redirects=False
                    )
                
                session_cookie = resp.cookies.get("session_key") or resp.cookies.get("yandexuid")
                if not session_cookie and resp.status_code not in [302, 303]:
                    return YandexAuthResult(
                        email=login,
                        oauth_token="",
                        error="Authentication failed. Check login/password or 2FA."
                    )
                
                # Step 3: Exchange session for OAuth token
                oauth_resp = await client.post(
                    f"{self.oauth_url}/token",
                    data={
                        "grant_type": "password",
                        "client_id": self.client_id,
                        "client_secret": "",  # Not needed for this flow
                        "username": login,
                        "password": password,
                    },
                    headers={"Content-Type": "application/x-www-form-urlencoded"}
                )
                
                oauth_data = oauth_resp.json()
                if "access_token" in oauth_data:
                    oauth_token = oauth_data["access_token"]
                else:
                    # Fallback: use session cookie as token proxy
                    oauth_token = session_cookie or ""
                
                # Step 4: Get IAM token from OAuth token
                iam_token = await self._get_iam_token(oauth_token)
                
                return YandexAuthResult(
                    email=login,
                    oauth_token=oauth_token,
                    iam_token=iam_token
                )
                
            except Exception as e:
                return YandexAuthResult(
                    email=login,
                    oauth_token="",
                    error=str(e)
                )
    
    async def _get_iam_token(self, oauth_token: str) -> Optional[str]:
        """Exchange OAuth token for IAM token."""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(
                    "https://iam.api.cloud.yandex.net/iam/v1/tokens",
                    json={"yandexPassportOauthToken": oauth_token},
                    headers={"Content-Type": "application/json"}
                )
                if resp.status_code == 200:
                    data = resp.json()
                    return data.get("iamToken")
        except Exception:
            pass
        return None
    
    async def refresh_iam_token(self, oauth_token: str) -> Optional[str]:
        """Refresh IAM token using existing OAuth token."""
        return await self._get_iam_token(oauth_token)
