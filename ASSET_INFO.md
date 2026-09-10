# AI Yandex - Godot Asset Library Metadata

## Basic Information

**Name:** AI Yandex Assistant  
**Version:** 1.0.0  
**Godot Version:** 4.6+  
**Category:** Tools  
**License:** MIT  

## Description

AI-powered assistant plugin that integrates YandexGPT and Alice APIs directly into the Godot Editor. Generate GDScript code, create complete game templates, and get intelligent assistance for your game development workflow.

### Key Features

- **Yandex Account Integration**: Secure login with your Yandex account
- **YandexGPT Code Generation**: AI-powered GDScript 2.0 code generation
- **Automatic Code Execution**: Generated code is sent directly to the Godot editor
- **Dock Panel Interface**: Seamless integration into the Godot Editor UI
- **Encrypted Token Storage**: Secure local storage of authentication tokens
- **Game Template Generation**: Create complete game prototypes from descriptions

## Tags

`ai`, `yandex`, `alice`, `gpt`, `assistant`, `codegen`, `automation`, `tools`, `editor`, `llm`

## Repository

GitHub: [Your Repository URL]

## Documentation

Full documentation available in README.md

## Screenshots

*(Add screenshots when publishing to Asset Library)*

1. Dock panel showing login interface
2. Chat interface with generated code
3. Game generation in progress
4. Settings panel

## Installation Instructions

1. Download and extract to `addons/AI_Yandex/`
2. Enable plugin in Project Settings → Plugins
3. Install Python dependencies: `pip install -r python_server/requirements.txt`
4. Run Python server: `python python_server/main.py`
5. Login with Yandex account in the dock panel

## Dependencies

### Godot Side
- None (uses built-in Godot APIs)

### Python Side
- fastapi >= 0.109.0
- uvicorn[standard] >= 0.27.0
- aiohttp >= 3.9.1
- httpx >= 0.26.0
- pydantic >= 2.5.3
- python-multipart >= 0.0.6

## Compatibility

- **Minimum Godot Version:** 4.6.3
- **Tested On:** Windows 10/11, Linux (Ubuntu 22.04), macOS 13+
- **Python Version:** 3.9+

## Author

Your Name / Organization

## Changelog

### 1.0.0 (Initial Release)
- Yandex Passport authentication
- YandexGPT integration for code generation
- Godot dock panel UI
- HTTP bridge between Python and Godot
- Encrypted token storage
- Automatic GDScript execution in editor

## Support

For issues, questions, or contributions:
- GitHub Issues: [Your Issues URL]
- Documentation: See README.md
- Email: [Your Contact Email]

## License

MIT License - Free to use in personal and commercial projects.

---

*This asset is not affiliated with or endorsed by Yandex LLC or Godot Engine.*
