"""
╔══════════════════════════════════════════════════════╗
║  O.R.I.O.N. BOT  —  Telegram интеграция (aiogram)   ║
║  Синхронизируется с core через REST API              ║
╚══════════════════════════════════════════════════════╝
"""

import os
import asyncio
import logging
from datetime import datetime
from aiogram import Bot, Dispatcher, types
from aiogram.filters import Command
from aiogram.types import Message
import httpx

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(levelname)s: %(message)s')
log = logging.getLogger(__name__)

CORE_URL = os.getenv("CORE_URL", "http://localhost:8000")
BOT_TOKEN = os.getenv("TELEGRAM_TOKEN")
POLL_INTERVAL = 15  # секунд между проверками событий

if not BOT_TOKEN:
    raise ValueError("❌ TELEGRAM_TOKEN не установлен")

bot = Bot(token=BOT_TOKEN)
dp = Dispatcher()
registered_chat_id: int | None = None


# ── Команды бота ─────────────────────────────────────────────────────

@dp.message(Command("start"))
async def cmd_start(message: Message):
    """Регистрация бота в core."""
    global registered_chat_id
    chat_id = message.chat.id
    user_name = message.from_user.first_name or "User"

    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(f"{CORE_URL}/register", json={
                "chat_id": chat_id,
                "name": user_name
            }, timeout=10)
            resp.raise_for_status()
            data = resp.json()
            registered_chat_id = chat_id

            await message.answer(
                f"✅ *O.R.I.O.N. активирован*\n\n"
                f"🔗 Подключен к core\n"
                f"📊 Событий в очереди: {data.get('queued_events', 0)}\n"
                f"🆔 Chat ID: `{chat_id}`\n\n"
                f"Теперь ты будешь получать уведомления о тревогах и SOS.",
                parse_mode="Markdown"
            )
            log.info(f"✅ Зарегистрирован: chat_id={chat_id}, name={user_name}")
        except Exception as e:
            log.error(f"❌ Ошибка регистрации: {e}")
            await message.answer(
                f"❌ Не удалось подключиться к core:\n`{e}`",
                parse_mode="Markdown"
            )


@dp.message(Command("status"))
async def cmd_status(message: Message):
    """Статус системы."""
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(f"{CORE_URL}/api/status", timeout=5)
            resp.raise_for_status()
            data = resp.json()

            bot_info = data.get("bot", {})
            alert_active = data.get("alert_active", False)

            msg = (
                f"📡 *O.R.I.O.N. Status*\n\n"
                f"🟢 Core: {data.get('status', 'unknown')}\n"
                f"📍 Точек сохранено: {data.get('points_stored', 0)}\n"
                f"🚨 Тревога: {'Активна' if alert_active else 'Нет'}\n"
                f"🤖 Бот: {bot_info.get('status', 'unknown')}\n"
                f"🔄 Переподключений: {bot_info.get('reconnects', 0)}"
            )
            await message.answer(msg, parse_mode="Markdown")
        except Exception as e:
            await message.answer(f"❌ Ошибка: `{e}`", parse_mode="Markdown")


@dp.message(Command("help"))
async def cmd_help(message: Message):
    """Справка."""
    await message.answer(
        "🛡️ *O.R.I.O.N. Commands*\n\n"
        "/start — Подключить бота к системе\n"
        "/status — Статус системы\n"
        "/help — Эта справка\n\n"
        "Бот автоматически получает уведомления о тревогах и SOS от iOS приложения.",
        parse_mode="Markdown"
    )


# ── Фоновый поллинг событий ─────────────────────────────────────────

async def poll_events():
    """Периодически проверяет события от core и отправляет в Telegram."""
    log.info("🔄 Запущен поллинг событий от core")

    while True:
        await asyncio.sleep(POLL_INTERVAL)

        if not registered_chat_id:
            continue

        async with httpx.AsyncClient() as client:
            try:
                # Обновляем статус бота
                await client.post(f"{CORE_URL}/bot/status", json={
                    "status": "polling",
                    "note": f"active, chat_id={registered_chat_id}",
                    "ts": datetime.now().isoformat()
                }, timeout=5)

                # Получаем события
                resp = await client.get(f"{CORE_URL}/bot/events", timeout=5)
                resp.raise_for_status()
                data = resp.json()
                events = data.get("events", [])

                if not events:
                    continue

                log.info(f"📬 Получено событий: {len(events)}")

                for event in events:
                    await handle_event(event)

            except Exception as e:
                log.error(f"❌ Ошибка поллинга: {e}")


async def handle_event(event: dict):
    """Обработка события от core."""
    event_type = event.get("type")

    if event_type == "alert":
        await send_alert(event)
    elif event_type == "sos":
        await send_sos(event)
    else:
        log.warning(f"⚠️ Неизвестный тип события: {event_type}")


async def send_alert(event: dict):
    """Отправка тревоги."""
    if not registered_chat_id:
        return

    lat = event.get("latitude")
    lon = event.get("longitude")
    reason = event.get("reason", "Неизвестная причина")
    level = event.get("level", 1)

    maps_link = f"https://maps.google.com/?q={lat},{lon}"

    emoji = "🚨" if level >= 3 else "⚠️"
    msg = (
        f"{emoji} *ТРЕВОГА*\n\n"
        f"📝 {reason}\n"
        f"📍 [Местоположение]({maps_link})\n"
        f"🕐 {datetime.now().strftime('%H:%M:%S')}"
    )

    try:
        await bot.send_message(
            chat_id=registered_chat_id,
            text=msg,
            parse_mode="Markdown"
        )
        log.info(f"🚨 Тревога отправлена: {reason}")
    except Exception as e:
        log.error(f"❌ Ошибка отправки тревоги: {e}")


async def send_sos(event: dict):
    """Отправка SOS."""
    if not registered_chat_id:
        return

    lat = event.get("latitude")
    lon = event.get("longitude")
    source = event.get("source", "unknown")
    maps_link = event.get("maps", f"https://maps.google.com/?q={lat},{lon}")

    msg = (
        f"🆘 *SOS СИГНАЛ*\n\n"
        f"📱 Источник: {source}\n"
        f"📍 [Местоположение]({maps_link})\n"
        f"🕐 {datetime.now().strftime('%H:%M:%S')}\n\n"
        f"⚡️ Требуется немедленная помощь!"
    )

    try:
        await bot.send_message(
            chat_id=registered_chat_id,
            text=msg,
            parse_mode="Markdown"
        )
        log.info(f"🆘 SOS отправлен от {source}")
    except Exception as e:
        log.error(f"❌ Ошибка отправки SOS: {e}")


# ── Запуск ───────────────────────────────────────────────────────────

async def main():
    log.info("🚀 Запуск O.R.I.O.N. Telegram Bot (aiogram)")
    log.info(f"🔗 Core URL: {CORE_URL}")

    # Запуск фонового поллинга
    asyncio.create_task(poll_events())

    log.info("✅ Бот готов к работе")
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
