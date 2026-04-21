# O.R.I.O.N. Production Deployment

## Быстрый старт

### Локальный запуск

1. Установите зависимости:
```bash
pip install -r requirements.txt
```

2. Создайте `.env` файл:
```bash
cp .env.example .env
# Отредактируйте .env и добавьте ваш TELEGRAM_TOKEN
```

3. Запустите core сервер:
```bash
uvicorn core.main:app --host 0.0.0.0 --port 8000
```

4. В отдельном терминале запустите бота:
```bash
python bot.py
```

### Docker Compose (рекомендуется)

1. Создайте `.env` файл с вашими настройками
2. Запустите:
```bash
docker-compose up -d
```

3. Проверьте логи:
```bash
docker-compose logs -f
```

## Деплой на сервер

### VPS (Ubuntu/Debian)

1. Установите Docker и Docker Compose
2. Клонируйте проект на сервер
3. Настройте `.env`
4. Запустите: `docker-compose up -d`
5. Настройте nginx как reverse proxy (опционально)

### Heroku / Railway / Render

1. Создайте новое приложение
2. Добавьте переменные окружения из `.env.example`
3. Деплойте через Git или GitHub интеграцию

## Endpoints

- `GET /` - Web dashboard
- `GET /api/status` - Статус системы
- `POST /location/update` - Обновление локации (от iOS)
- `POST /sos/trigger` - SOS сигнал (от iOS)
- `POST /alert/trigger` - Тревога
- `GET /events/stream` - SSE stream для real-time обновлений
- `POST /register` - Регистрация бота
- `GET /bot/events` - События для бота

## Архитектура

```
iOS App → Core Server ← Telegram Bot
              ↓
         Web Dashboard (SSE)
```

- **Core**: FastAPI сервер, центральный хаб
- **Bot**: Telegram бот, поллинг событий от core
- **iOS**: Отправляет локации и SOS на core
- **Web**: Real-time dashboard через Server-Sent Events
