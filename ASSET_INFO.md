# AI Yandex Agent - Godot Asset Library Information

## Основное

**Название:** AI Yandex Agent  
**Категория:** Editor Plugins  
**Подкатегория:** Tools, AI Integration  
**Версия:** 1.0.0  
**Godot Version:** 4.6.3+  
**License:** MIT  
**Author:** AI Developer  

## Описание

AI Yandex Agent — это мощный плагин для Godot Engine, который интегрирует возможности искусственного интеллекта от Яндекса прямо в редактор игр. Плагин позволяет генерировать GDScript-код для создания игр с помощью YandexGPT на основе текстового описания.

### Ключевые особенности

- 🤖 **ИИ-генерация кода** — Используйте YandexGPT для создания GDScript-кода по описанию
- 🔐 **Авторизация Яндекс** — Вход через Yandex Passport (логин/пароль)
- 🎮 **Автоматическое выполнение** — Сгенерированный код выполняется прямо в редакторе
- 🖥️ **Интеграция в UI** — Удобная док-панель в интерфейсе редактора
- 📝 **Логирование операций** — Полное отслеживание всех действий
- 🌐 **HTTP-коммуникация** — Надёжная связь между Godot и Python-бэкендом

## Требования

### Системные требования

- **Godot Engine:** 4.6.3.stable.official или новее
- **Python:** 3.9 или выше (для бэкенд-сервера)
- **Интернет-соединение:** Обязательно (для работы с Yandex API)

### Python-зависимости

Плагин требует установки Python-сервера со следующими зависимостями:

```
fastapi>=0.104.0
uvicorn>=0.24.0
aiohttp>=3.9.0
pydantic>=2.5.0
requests>=2.31.0
```

## Установка

1. Скачайте плагин из Godot Asset Library
2. Включите плагин в **Project → Project Settings → Plugins**
3. Скопируйте папку `python_server` в удобное место
4. Установите Python-зависимости: `pip install -r requirements.txt`
5. Запустите Python-сервер: `python main.py`
6. Введите учётные данные Яндекс в док-панели

## Использование

### Быстрый старт

1. **Авторизация:** Введите логин и пароль Яндекс в док-панели
2. **Ввод промта:** Опишите игру, которую хотите создать
3. **Генерация:** Нажмите "Сгенерировать игру"
4. **Результат:** Код будет создан и выполнен в редакторе

### Примеры промтов

- "Create a simple platformer with jumping and movement"
- "Создай арканоид с ракеткой и мячом"
- "Make a clicker game with upgrades"
- "Сделай гоночную игру с препятствиями"

## Технические детали

### Архитектура

```
┌─────────────────┐     HTTP      ┌─────────────────┐
│   Godot Editor  │◄─────────────►│  Python Server  │
│                 │    (8765)     │                 │
│  ┌───────────┐  │               │  ┌───────────┐  │
│  │ Dock Panel│  │               │  │ FastAPI   │  │
│  └───────────┘  │               │  └───────────┘  │
│  ┌───────────┐  │               │  ┌───────────┐  │
│  │ HTTP Srv  │  │◄─────────────►│  │ YandexGPT │  │
│  └───────────┘  │    (8000)     │  └───────────┘  │
└─────────────────┘     HTTP      └─────────────────┘
```

### API Endpoints

#### Python Server (порт 8000)
- `POST /auth` — Аутентификация пользователя
- `POST /generate` — Генерация кода игры
- `POST /code` — Отправка кода в Godot
- `GET /status` — Статус сервера

#### Godot HTTP Server (порт 8765)
- `POST /execute` — Выполнение GDScript-кода
- `POST /auth` — Уведомление об аутентификации
- `GET /status` — Статус сервера

## Известные ограничения

⚠️ **Важно:** Этот плагин использует симулированную аутентификацию для демонстрационных целей. Для продакшена необходимо:

1. Реализовать полную аутентификацию через Yandex Passport с CSRF-токенами
2. Использовать OAuth2 flow вместо аутентификации по паролю
3. Настроить правильное хранение IAM-токенов

### Ограничения генерации кода

- Качество кода зависит от формулировки промта
- Не все жанры игр могут быть созданы автоматически
- Может потребоваться ручная доработка кода
- Требуется стабильное интернет-соединение

## Скриншоты

### Док-панель
*(Место для скриншота док-панели в редакторе Godot)*

### Процесс генерации
*(Место для скриншота процесса генерации кода)*

### Результат
*(Место для скриншота созданной игры)*

## История версий

### 1.0.0 (Первый релиз)

- ✅ Базовая интеграция с YandexGPT
- ✅ Авторизация через Яндекс
- ✅ Генерация GDScript-кода
- ✅ HTTP-сервер для коммуникации
- ✅ Док-панель в редакторе
- ✅ Логирование операций

## Поддержка

### Контакты

- **Email:** support@example.com (замените на ваш)
- **GitHub:** https://github.com/yourusername/ai-yandex-godot (замените на ваш)
- **Документация:** См. README.md в репозитории

### Сообщение о проблемах

При возникновении проблем:
1. Проверьте логи в док-панели
2. Убедитесь, что Python-сервер запущен
3. Проверьте подключение к интернету
4. Убедитесь, что порты 8000 и 8765 свободны

## Лицензия

MIT License

Copyright (c) 2024 AI Developer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

**Ключевые слова:** AI, Yandex, GPT, Code Generation, Tool, Editor Plugin, Automation, Machine Learning

**Repository URL:** https://github.com/yourusername/ai-yandex-godot (замените на ваш)  
**Documentation URL:** https://github.com/yourusername/ai-yandex-godot/blob/main/README.md (замените на ваш)
