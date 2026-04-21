"""
╔══════════════════════════════════════════════════════╗
║  O.R.I.O.N. CORE  —  Центральный сервер (FastAPI)   ║
║  v2.0 — с синхронизацией бота и SSE для сайта        ║
╚══════════════════════════════════════════════════════╝
"""

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse, StreamingResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List
from collections import deque
import asyncio
import json
import os
import httpx

app = FastAPI(title="O.R.I.O.N. Core", version="2.0.0")
templates = Jinja2Templates(directory="templates")

# ── Состояние системы ────────────────────────────────────────────
locations_db: List[dict]      = []
current_alert: Optional[dict] = None
registered_chat_id: Optional[int] = None

bot_state = {
    "online":    False,
    "status":    "unknown",
    "note":      "",
    "last_seen": None,
    "reconnects": 0,
}

# Очередь событий для бота (пока он офлайн)
bot_event_queue: deque = deque(maxlen=100)

# SSE подписчики — браузерные соединения
sse_subscribers: List[asyncio.Queue] = []

BOT_API_URL = "https://api.telegram.org/bot" + os.getenv("TELEGRAM_TOKEN", "")


# ── Модели ───────────────────────────────────────────────────────

class LocationUpdate(BaseModel):
    latitude: float
    longitude: float
    timestamp: Optional[datetime] = None
    source: str = "manual"

class AlertPayload(BaseModel):
    level: int
    reason: str
    latitude: float
    longitude: float

class RegisterPayload(BaseModel):
    chat_id: int
    name: str = ""

class CodeConfirm(BaseModel):
    code: str

class BotStatusPayload(BaseModel):
    status: str
    note: str = ""
    ts: Optional[str] = None


# ── SSE утилиты ──────────────────────────────────────────────────

async def broadcast_sse(event_type: str, data: dict):
    payload = json.dumps({"type": event_type, "data": data, "ts": datetime.now().isoformat()})
    dead = []
    for q in sse_subscribers:
        try:
            q.put_nowait(payload)
        except asyncio.QueueFull:
            dead.append(q)
    for q in dead:
        sse_subscribers.remove(q)


async def push_bot_event(event: dict):
    event["ts"] = datetime.now().isoformat()
    bot_event_queue.append(event)
    await broadcast_sse("event", event)


# ── Telegram fallback ─────────────────────────────────────────────

async def send_telegram_direct(chat_id: int, text: str):
    """Отправка напрямую через API когда бот недоступен."""
    if not os.getenv("TELEGRAM_TOKEN"):
        return
    async with httpx.AsyncClient() as client:
        try:
            await client.post(f"{BOT_API_URL}/sendMessage", json={
                "chat_id": chat_id, "text": text, "parse_mode": "Markdown"
            }, timeout=5)
        except Exception as e:
            print(f"[CORE] Telegram direct send error: {e}")


def _bot_is_stale() -> bool:
    if not bot_state["last_seen"]:
        return True
    delta = (datetime.now() - datetime.fromisoformat(bot_state["last_seen"])).total_seconds()
    return delta > 90


# ── Страницы ─────────────────────────────────────────────────────

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    return templates.TemplateResponse("index.html", {
        "request":       request,
        "points_count":  len(locations_db),
        "last_location": locations_db[-1] if locations_db else None,
        "alert":         current_alert,
        "chat_id":       registered_chat_id,
        "bot_online":    not _bot_is_stale(),
        "bot_status":    bot_state["status"],
    })


@app.get("/api/status")
async def api_status():
    return {
        "status":        "online",
        "system":        "O.R.I.O.N.",
        "version":       "2.0.0",
        "points_stored": len(locations_db),
        "alert_active":  current_alert is not None,
        "registered":    registered_chat_id is not None,
        "bot":           {**bot_state, "stale": _bot_is_stale()},
    }


# ── Bridge: бот ↔ core ───────────────────────────────────────────

@app.post("/register")
async def register_bot(payload: RegisterPayload):
    global registered_chat_id
    registered_chat_id      = payload.chat_id
    bot_state["online"]     = True
    bot_state["last_seen"]  = datetime.now().isoformat()
    bot_state["status"]     = "online"
    bot_state["reconnects"] = bot_state["reconnects"] + 1
    print(f"[CORE] ✅ Бот подключён: chat_id={payload.chat_id}, reconnect #{bot_state['reconnects']}")

    await broadcast_sse("bot_connected", {
        "chat_id":   payload.chat_id,
        "reconnects": bot_state["reconnects"],
    })
    return {
        "status":         "registered",
        "chat_id":        payload.chat_id,
        "queued_events":  len(bot_event_queue),
    }


@app.post("/bot/status")
async def update_bot_status(payload: BotStatusPayload):
    bot_state["online"]    = True
    bot_state["status"]    = payload.status
    bot_state["note"]      = payload.note
    bot_state["last_seen"] = payload.ts or datetime.now().isoformat()
    await broadcast_sse("bot_status", {"status": payload.status, "note": payload.note})
    return {"ok": True}


@app.get("/bot/events")
async def get_bot_events():
    events = list(bot_event_queue)
    bot_event_queue.clear()
    return {"events": events, "count": len(events)}


@app.get("/bot/info")
async def bot_info():
    return {
        **bot_state,
        "stale":         _bot_is_stale(),
        "queued_events": len(bot_event_queue),
        "registered_id": registered_chat_id,
    }


# ── Геолокация ───────────────────────────────────────────────────

@app.post("/location/update")
async def receive_location(data: LocationUpdate):
    point = {
        "latitude":  data.latitude,
        "longitude": data.longitude,
        "timestamp": (data.timestamp or datetime.now()).isoformat(),
        "source":    data.source,
    }
    locations_db.append(point)
    await broadcast_sse("location", point)
    print(f"[CORE] 📍 #{len(locations_db)}: ({data.latitude:.5f}, {data.longitude:.5f})")
    return {"status": "received", "total": len(locations_db)}


@app.get("/location/history")
async def get_history(limit: int = 50):
    return {"points": locations_db[-limit:], "total": len(locations_db)}


# ── Тревога ──────────────────────────────────────────────────────

@app.post("/alert/trigger")
async def trigger_alert(payload: AlertPayload):
    global current_alert
    current_alert = {
        "level":     payload.level,
        "reason":    payload.reason,
        "latitude":  payload.latitude,
        "longitude": payload.longitude,
        "triggered": datetime.now().isoformat(),
        "attempts":  0,
    }
    print(f"[CORE] 🚨 Тревога: {payload.reason}")
    await broadcast_sse("alert", current_alert)

    if _bot_is_stale() and registered_chat_id:
        # Бот недоступен — шлём напрямую через API
        maps = f"https://maps.google.com/?q={payload.latitude},{payload.longitude}"
        await send_telegram_direct(
            registered_chat_id,
            f"🚨 *ТРЕВОГА*\n_{payload.reason}_\n[Позиция]({maps})\n\n"
            f"_Бот офлайн — уведомление через core_"
        )
    else:
        await push_bot_event({
            "type":      "alert",
            "level":     payload.level,
            "reason":    payload.reason,
            "latitude":  payload.latitude,
            "longitude": payload.longitude,
        })

    return {"status": "alert_dispatched", "bot_alive": not _bot_is_stale()}


@app.post("/alert/confirm")
async def confirm_safe(data: CodeConfirm):
    global current_alert
    secret = os.getenv("SECRET_CODE", "0000")
    if data.code != secret:
        if current_alert:
            current_alert["attempts"] = current_alert.get("attempts", 0) + 1
        raise HTTPException(status_code=403, detail="Неверный код")
    current_alert = None
    await broadcast_sse("alert_cleared", {"ts": datetime.now().isoformat()})
    return {"status": "confirmed"}


@app.get("/alert/status")
async def alert_status():
    return {"active": current_alert is not None, "alert": current_alert}


# ── SSE стрим ────────────────────────────────────────────────────

@app.get("/events/stream")
async def sse_stream(request: Request):
    """Держит соединение с браузером, шлёт события в реальном времени."""
    queue: asyncio.Queue = asyncio.Queue(maxsize=50)
    sse_subscribers.append(queue)

    async def generate():
        # Начальное состояние
        init_data = {
            "type": "init",
            "data": {
                "points": len(locations_db),
                "bot":    {**bot_state, "stale": _bot_is_stale()},
                "alert":  current_alert,
            }
        }
        yield f"data: {json.dumps(init_data)}\n\n"
        try:
            while True:
                if await request.is_disconnected():
                    break
                try:
                    payload = await asyncio.wait_for(queue.get(), timeout=25.0)
                    yield f"data: {payload}\n\n"
                except asyncio.TimeoutError:
                    yield ": ping\n\n"
        finally:
            if queue in sse_subscribers:
                sse_subscribers.remove(queue)

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "Connection": "keep-alive", "X-Accel-Buffering": "no"}
    )


# ── SOS от iOS приложения ────────────────────────────────────────

class SOSTriggerPayload(BaseModel):
    latitude:  float
    longitude: float
    timestamp: Optional[str] = None
    source:    str = "ios"

@app.post("/sos/trigger")
async def sos_trigger(payload: SOSTriggerPayload):
    """iOS приложение шлёт сюда SOS — core уведомляет бота."""
    print(f"[CORE] 🆘 SOS от {payload.source}: ({payload.latitude}, {payload.longitude})")
    maps = f"https://maps.google.com/?q={payload.latitude},{payload.longitude}"

    sos_event = {
        "type":      "sos",
        "latitude":  payload.latitude,
        "longitude": payload.longitude,
        "source":    payload.source,
        "maps":      maps,
    }
    await broadcast_sse("sos", sos_event)

    if _bot_is_stale() and registered_chat_id:
        await send_telegram_direct(
            registered_chat_id,
            f"🆘 *SOS из приложения!*\n[Местоположение]({maps})\nИсточник: {payload.source}"
        )
    else:
        await push_bot_event(sos_event)

    return {"status": "sos_received", "bot_alive": not _bot_is_stale()}
