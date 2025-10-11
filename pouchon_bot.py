# filename: bot_railway.py
import os
import hmac
import hashlib
import asyncio
from datetime import datetime, timedelta, timezone
from typing import Optional
import aiosqlite
import httpx
from fastapi import FastAPI, Request, Header, HTTPException
from telegram import Bot, Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ApplicationBuilder, CommandHandler, ContextTypes, MessageHandler, filters, CallbackQueryHandler
from dotenv import load_dotenv
load_dotenv()
BOT_TOKEN = os.getenv("BOT_TOKEN")
# ===== CONFIG =====
BOT_TOKEN = os.getenv("BOT_TOKEN")
PAYSTACK_SECRET_KEY = os.getenv("PAYSTACK_SECRET_KEY")
PRIVATE_GROUP_ID = -1003139716802
ADMIN_IDS = list(map(int, os.getenv("ADMIN_IDS").split(","))) if os.getenv("ADMIN_IDS") else []
WEBHOOK_URL = "http://127.0.0.1:8000"
# Plans
SUBSCRIPTION_PLANS = {
    "daily": {"hours": 24, "KES": 100, "USD": 20, "label": "Daily Plan"},
    "weekly": {"hours": 168, "KES": 500, "USD": 100, "label": "Weekly Plan"},
    "monthly": {"hours": 720, "KES": 1500, "USD": 400, "label": "Monthly Plan"},
}

DB_PATH = "subscriptions.db"
bot = Bot(BOT_TOKEN)
app = FastAPI()

# ===== DB HELPERS =====
async def init_db():
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("""
        CREATE TABLE IF NOT EXISTS subscriptions (
            user_id INTEGER PRIMARY KEY,
            plan TEXT,
            expires_at TEXT,
            reference TEXT,
            phone TEXT,
            active INTEGER DEFAULT 0
        )
        """)
        await db.commit()

async def save_subscription(user_id, plan, expires_at, reference, phone):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("""
        INSERT OR REPLACE INTO subscriptions (user_id, plan, expires_at, reference, phone, active)
        VALUES (?, ?, ?, ?, ?, 1)
        """, (user_id, plan, expires_at.isoformat(), reference, phone))
        await db.commit()

async def mark_inactive(user_id):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("UPDATE subscriptions SET active=0 WHERE user_id=?", (user_id,))
        await db.commit()

async def get_expired_users():
    now = datetime.now(timezone.utc)
    async with aiosqlite.connect(DB_PATH) as db:
        cur = await db.execute("SELECT user_id FROM subscriptions WHERE active=1 AND expires_at<=?", (now.isoformat(),))
        rows = await cur.fetchall()
        return [r[0] for r in rows]

async def get_active_subscriptions():
    async with aiosqlite.connect(DB_PATH) as db:
        cur = await db.execute("SELECT user_id, plan, expires_at, reference, phone FROM subscriptions WHERE active=1")
        return await cur.fetchall()

async def get_subscription(user_id):
    async with aiosqlite.connect(DB_PATH) as db:
        cur = await db.execute("SELECT user_id, plan, expires_at, reference, phone, active FROM subscriptions WHERE user_id=?", (user_id,))
        return await cur.fetchone()

async def update_subscription_expiry(user_id, new_expires_at):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("UPDATE subscriptions SET expires_at=?, active=1 WHERE user_id=?", (new_expires_at.isoformat(), user_id))
        await db.commit()

# ===== PAYSTACK HELPERS =====
async def initialize_paystack_payment(user_id, amount, currency, plan_name, mobile_money=False, phone=None):
    url = "https://api.paystack.co/transaction/initialize"
    headers = {"Authorization": f"Bearer {PAYSTACK_SECRET_KEY}"}
    payload = {"email": f"{user_id}@telegram.fake", "amount": int(amount*100), "metadata": {"user_id": user_id, "plan": plan_name}}
    if mobile_money:
        payload["channel"] = ["mobile_money"]
        payload["mobile_money"] = {"provider": "mpesa", "phone": phone}
        payload["currency"] = "KES"
    async with httpx.AsyncClient() as client:
        resp = await client.post(url, headers=headers, json=payload, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        return data["data"]["authorization_url"], data["data"]["reference"]

async def verify_paystack_payment(reference):
    url = f"https://api.paystack.co/transaction/verify/{reference}"
    headers = {"Authorization": f"Bearer {PAYSTACK_SECRET_KEY}"}
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, headers=headers, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        return data["data"]["status"] == "success"

def verify_paystack_signature(raw_body, signature: Optional[str]):
    if not signature: return False
    computed = hmac.new(PAYSTACK_SECRET_KEY.encode(), raw_body, hashlib.sha512).hexdigest()
    return hmac.compare_digest(computed, signature)

# ===== BOT HANDLERS =====
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = "Welcome! Choose a plan by sending its name:\n"
    for plan, v in SUBSCRIPTION_PLANS.items():
        text += f"{plan} — KSh {v['KES']} / ${v['USD']} ({v['label']})\n"
    await update.message.reply_text(text)

from telegram import Update
from telegram.ext import ApplicationBuilder, ContextTypes, CommandHandler, MessageHandler, filters

ADMIN_IDS = [8273608494]  # your Telegram ID
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = update.message.text
    print("Webhook received:", update)

    if update.effective_user.id in ADMIN_IDS:
        if text in SUBSCRIPTION_PLANS:
            plan = text
            context.user_data["pending_plan"] = plan
            keyboard = [
                [InlineKeyboardButton("🇰🇪 MPESA (Kenya)", callback_data="kenya")],
                [InlineKeyboardButton("🌍 Card (International)", callback_data="intl")]
            ]
            await update.message.reply_text(
                "Choose payment method:",
                reply_markup=InlineKeyboardMarkup(keyboard)
            )
            return

        await update.message.reply_text("Send /start to choose a plan.")
    else:
        print(f"Ignored message from {update.effective_user.id}")

    # Check plan choice
    if text in SUBSCRIPTION_PLANS:
        plan = text
        context.user_data["pending_plan"] = plan
        keyboard = [
            [InlineKeyboardButton("🇰🇪 MPESA (Kenya)", callback_data="kenya")],
            [InlineKeyboardButton("🌍 Card (International)", callback_data="intl")]
        ]
        await update.message.reply_text("Choose payment method:", reply_markup=InlineKeyboardMarkup(keyboard))
        return
    await update.message.reply_text("Send /start to choose a plan.")

async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()  # Acknowledge the button press
    user = query.from_user
    choice = query.data
    plan = context.user_data.get("pending_plan")

    if not plan:
        await query.message.reply_text("No plan selected. Send /start to choose a plan.")
        return

    if choice == "kenya":
        await query.message.reply_text(f"{user.first_name}, you chose {plan} via MPESA (Kenya).")
        # Add MPESA processing logic here
    elif choice == "intl":
        await query.message.reply_text(f"{user.first_name}, you chose {plan} via Card (International).")
        # Add card processing logic here
    else:
        await query.message.reply_text("Invalid choice. Please try again.")
    # MPESA flow
    if choice == "kenya":
        context.user_data["awaiting_phone"] = True
        await query.edit_message_text("Send your MPESA phone number (e.g., 07XXXXXXXX or +2547XXXXXXXX).")
        return
    # Card flow
    if choice == "intl":
        amount = SUBSCRIPTION_PLANS[plan]["USD"]
        auth_url, reference = await initialize_paystack_payment(user.id, amount, "USD", plan, mobile_money=False)
        context.user_data["reference"] = reference
        context.user_data["plan"] = plan
        await query.edit_message_text(f"Click to pay ${amount} via card:\n{auth_url}")

async def handle_phone(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not context.user_data.get("awaiting_phone"):
        return
    phone = update.message.text.strip()
    plan = context.user_data.get("pending_plan")
    user = update.effective_user
    if phone.startswith("0"): phone = "254" + phone[1:]
    amount = SUBSCRIPTION_PLANS[plan]["KES"]
    auth_url, reference = await initialize_paystack_payment(user.id, amount, "KES", plan, mobile_money=True, phone=phone)
    context.user_data["reference"] = reference
    context.user_data["plan"] = plan
    context.user_data.pop("awaiting_phone")
    await update.message.reply_text(f"Click to pay KSh {amount} via MPESA:\n{auth_url}")

# ===== GRANT & REVOKE =====
async def grant_access(user_id, plan_name, reference, phone=None):
    hours = SUBSCRIPTION_PLANS[plan_name]["hours"]
    expires_at = datetime.now(timezone.utc) + timedelta(hours=hours)
    invite = await bot.create_chat_invite_link(PRIVATE_GROUP_ID, member_limit=1, expire_date=int(expires_at.timestamp()))
    await bot.send_message(user_id, f"🎉 Payment confirmed!\nYour invite link (expires in {hours}h): {invite.invite_link}")
    await save_subscription(user_id, plan_name, expires_at, reference, phone)

async def revoke_access(user_id):
    try:
        await bot.ban_chat_member(PRIVATE_GROUP_ID, user_id)
        await bot.unban_chat_member(PRIVATE_GROUP_ID, user_id)
        await mark_inactive(user_id)
        return True
    except:
        return False

async def remove_expired_users():
    while True:
        expired = await get_expired_users()
        for uid in expired:
            await revoke_access(uid)
        await asyncio.sleep(60)

# ===== PAYSTACK WEBHOOK =====
@app.post("/paystack_webhook")
async def paystack_webhook(request: Request, x_paystack_signature: Optional[str] = Header(None)):
    body = await request.body()
    if not verify_paystack_signature(body, x_paystack_signature):
        raise HTTPException(403, "Invalid signature")
    data = await request.json()
    if data.get("event") == "charge.success":
        metadata = data["data"]["metadata"]
        user_id = int(metadata["user_id"])
        plan = metadata["plan"]
        reference = data["data"]["reference"]
        if await verify_paystack_payment(reference):
            await grant_access(user_id, plan, reference)
    return {"status": "ok"}
# ===== TELEGRAM WEBHOOK =====
from fastapi import Request, FastAPI
from telegram import Update
import asyncio

@app.post("/telegram_webhook")
async def telegram_webhook(request: Request):
    try:
        data = await request.json()
        
        # Ensure required fields exist to prevent errors
        if "message" in data:
            msg = data["message"]
            if "from" not in msg:
                msg["from"] = {"id": msg.get("from_id", 0), "first_name": "Unknown", "is_bot": False}
            if "date" not in msg:
                import time
                msg["date"] = int(time.time())
        
        update = Update.de_json(data, app_bot.bot)
        
        # Process asynchronously so FastAPI responds quickly
        asyncio.create_task(app_bot.process_update(update))
        return {"ok": True, "message": "Webhook processed"}

    except Exception as e:
        # Log any errors without breaking FastAPI
        print(f"❌ Error in webhook handler: {e}")
        return {"ok": False, "error": str(e)}
# ===== SETUP BOT =====
async def main():
    global app_bot
    # Build the bot application
    app_bot = ApplicationBuilder().token(BOT_TOKEN).build()

    # Add handlers
    app_bot.add_handler(CommandHandler("start", start))
    app_bot.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app_bot.add_handler(MessageHandler(filters.TEXT & filters.Regex(r"^\+?\d{9,13}$"), handle_phone))

    # Initialize the bot (required!)
    print("⚙️ Initializing bot...")
    await app_bot.initialize()
    print("✅ Bot initialized")

    # Start the bot (needed for background tasks like JobQueue)
    print("🚀 Starting bot...")
    await app_bot.start()
    print("🤖 Bot started successfully")

    # Start FastAPI
    print("🌍 Starting FastAPI server...")
    import uvicorn
    uvicorn_config = uvicorn.Config(app, host="0.0.0.0", port=int(os.getenv("PORT", 8000)), log_level="info")
    server = uvicorn.Server(uvicorn_config)
    server_task = asyncio.create_task(server.serve())

    # Keep running forever
    await asyncio.Event().wait()

    # Stop bot and server on shutdown
    await app_bot.stop()
    server.should_exit = True
    await server_task
if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
