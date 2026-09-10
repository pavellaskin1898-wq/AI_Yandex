# AI Yandex Plugin for Godot 4.6

AI-powered assistant plugin for Godot Engine 4.6+ that integrates with YandexGPT and Alice APIs for code generation, game creation, and intelligent assistance.

## Features

- **Yandex Authentication**: Login with your Yandex account (email/password)
- **YandexGPT Integration**: Generate GDScript code using Yandex's large language model
- **Code Execution**: Automatically send generated code to Godot editor for execution
- **Dock Panel UI**: Integrated panel in the Godot editor for seamless workflow
- **Secure Token Storage**: OAuth tokens are encrypted and stored locally

## Installation

### 1. Install the Godot Plugin

1. Copy the `addons/AI_Yandex/` folder into your Godot project's `addons/` directory
2. Open your project in Godot 4.6+
3. Go to `Project → Project Settings → Plugins`
4. Find "AI Yandex" in the list and click **Enable**

### 2. Install Python Dependencies

```bash
cd python_server
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Run the Python Backend

```bash
python main.py
```

The server will start on `http://127.0.0.1:8000`

### 4. Configure the Plugin

1. In Godot, open the AI Yandex dock panel (right side of the editor)
2. Enter your Yandex login and password
3. Click "Sign in"
4. The plugin will authenticate and obtain necessary tokens

## Usage

### Basic Chat

1. Type your request in the text field (e.g., "Create a player movement script")
2. Click "Send"
3. The AI will generate code and automatically send it to Godot

### Generate a Complete Game

1. Describe your game idea (e.g., "Create a simple platformer with coins and enemies")
2. Click "Generate Game"
3. The AI will create all necessary scripts and scenes

### Manual Code Execution

Generated code blocks are automatically sent to Godot. You can also manually execute GDScript by sending it through the API.

## API Endpoints

The Python backend provides the following endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/login` | POST | Authenticate with Yandex |
| `/chat` | POST | Send a message and get response |
| `/generate_game` | POST | Generate a complete game |

### Example: Login Request

```bash
curl -X POST http://127.0.0.1:8000/login \
  -H "Content-Type: application/json" \
  -d '{"login": "your_email@yandex.ru", "password": "your_password"}'
```

### Example: Chat Request

```bash
curl -X POST http://127.0.0.1:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Create a player controller", "token": "your_oauth_token"}'
```

## Configuration

Edit `user://ai_yandex_secure.dat` (encrypted) or modify defaults in the plugin settings:

- **Server URL**: `http://127.0.0.1:8000` (Python backend)
- **Godot Port**: `9876` (HTTP server in Godot plugin)
- **Model**: `yandexgpt-lite` or `yandexgpt`
- **Temperature**: `0.6` (creativity level)

## Troubleshooting

### "Cannot connect to Python server"

- Ensure the Python backend is running (`python main.py`)
- Check that port 8000 is not blocked by firewall
- Verify the server URL in plugin settings

### "Authentication failed"

- Double-check your Yandex login and password
- Some accounts may require 2FA - use an app-specific password
- Clear stored tokens: delete `user://ai_yandex_secure.dat`

### "Cannot connect to Godot"

- Ensure the plugin is enabled in Godot
- Check that port 9876 is available
- Restart Godot and re-enable the plugin

### "No code generated"

- Try a more specific prompt
- Check your YandexGPT API quota
- Verify IAM token is valid (re-login if needed)

## Security Notes

- Passwords are **never stored** - only OAuth tokens are saved
- Tokens are encrypted using Godot's built-in encryption
- All communication is local (localhost) except for Yandex API calls
- For production use, consider implementing proper session management

## Requirements

- **Godot Engine**: 4.6.3 or later
- **Python**: 3.9+
- **Dependencies**: See `python_server/requirements.txt`

## License

MIT License - See LICENSE file for details

## Support

For issues, feature requests, or contributions, please visit the repository.
