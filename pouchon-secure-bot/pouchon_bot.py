import os
import sqlite3
import asyncio
import threading
from datetime import datetime, timedelta

# Telegram imports
from telegram import Update, InlineKeyboardMarkup, InlineKeyboardButton
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, ContextTypes, filters
from telegram import Bot
from telegram import Update
from telegram.ext import ContextTypes

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_first_name = update.effective_user.first_name
    await update.message.reply_text(
        f"Hey {user_first_name}! 👋 Welcome to Pouchon Secure Bot.\n"
        "Use the menu below or type your phone number to continue."
    )
async def handle_plan(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    plan_selected = query.data.replace("plan_", "")
    await query.edit_message_text(
        text=f"You selected plan: {plan_selected} ✅\nPlease send your phone number to continue."
    )
async def handle_phone(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    phone = update.message.text.strip()

    # Simple phone validation
    if not (phone.startswith("07") and len(phone) == 10):
        await update.message.reply_text("❌ Invalid number. Use format 07XXXXXXXX:")
        return

    await update.message.reply_text(
        f"📱 Got your number: {phone}\nProcessing payment request..."
    )

    # (Optional placeholder for now)
    # You can later integrate payment verification here.
# FastAPI for webhook
from fastapi import FastAPI, Request
import uvicorn

# --- Config ---
BOT_TOKEN = os.getenv("BOT_TOKEN", "8406972008:AAHTmNluGB3UD6Xmj2HVVB5YAguuj2mWk-k")
PORT = int(os.getenv("PORT", 8000))
PRIVATE_GROUP_ID = -1008273608494
ADMIN_IDS = [8273608494]

# Subscription Plans
SUBSCRIPTION_PLANS = {
    "1_day": (24, 100, "1 Day - KSh 100"),
    "3_days": (72, 250, "3 Days - KSh 250"), 
    "1_week": (168, 500, "1 Week - KSh 500"),
    "1_month": (720, 1500, "1 Month - KSh 1500"),
    "international": (12, 2000, "12 Hours - $20 International")
}

# --- Database Setup ---
def setup_db():
    conn = sqlite3.connect('pouchon.db', check_same_thread=False)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS payments(
            user_id INTEGER, user_name TEXT, status TEXT, amount REAL,
            invoice_id TEXT PRIMARY KEY, subscription_plan TEXT,
            requested_at TEXT, completed_at TEXT, access_ends_at TEXT
        )
    ''')
    conn.commit()
    conn.close()

setup_db()

# --- Bot Handlers ---
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    
    # Check active subscription
    conn = sqlite3.connect('pouchon.db')
    cursor = conn.cursor()
    cursor.execute('SELECT access_ends_at FROM payments WHERE user_id=? AND status="paid" ORDER BY completed_at DESC LIMIT 1', (user.id,))
    result = cursor.fetchone()
    conn.close()

    if result and result[0]:
        access_ends = datetime.fromisoformat(result[0])
        if access_ends > datetime.now():
            await update.message.reply_text("✅ You have active subscription!")
            return

    # Show subscription plans
    keyboard = []
    for plan_name, (hours, price, description) in SUBSCRIPTION_PLANS.items():
        if plan_name == "international":
            keyboard.append([InlineKeyboardButton("🌍 " + description, callback_data=f"plan_{plan_name}")])
        else:
            keyboard.append([InlineKeyboardButton("📱 " + description, callback_data=f"plan_{plan_name}")])
    
    await update.message.reply_text(
        f"👋 Welcome, {user.first_name}!\n\nChoose your subscription plan:",
        reply_markup=InlineKeyboardMarkup(keyboard)
    )

async def handle_plan_selection(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user = query.from_user
    plan_name = query.data.replace("plan_", "")
    hours, price, description = SUBSCRIPTION_PLANS[plan_name]
    
    await query.edit_message_text(f"✅ Selected: {description}\n\nPrice: KSh {price}\nDuration: {hours} hours")

# --- FastAPI Webhook ---
app = FastAPI()

@app.get("/")
async def root():
    return {"status": "Pouchon Bot Running"}

def run_webhook():
    uvicorn.run(app, host="0.0.0.0", port=PORT)

# --- Main Bot ---
# ==================== GLOBAL APPLICATION ====================
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes
import os

# Create application globally so webhook can access it
application = Application.builder().token(os.getenv("BOT_TOKEN")).build()

# Register handlers globally
application.add_handler(CommandHandler("start", start_command))
application.add_handler(CallbackQueryHandler(handle_plan, pattern="^plan_"))
application.add_handler(MessageHandler(filters.TEXT & filters.ChatType.PRIVATE, handle_phone))

# ==================== ASYNC WEBHOOK SETUP ====================
async def set_webhook():
    WEBHOOK_URL = os.getenv("WEBHOOK_URL")
    if WEBHOOK_URL:
        await application.bot.set_webhook(f"{WEBHOOK_URL}/telegram")
        print("🚀 Webhook set and bot ready on Railway!")

# ==================== MAIN ====================
# ==================== MAIN (WEBHOOK MODE) ====================
@app.post("/telegram")
async def telegram_webhook(request: Request):
    try:
        data = await request.json()
        update = Update.de_json(data, application.bot)
        await application.process_update(update)
        return {"ok": True}
    except Exception as e:
        print(f"❌ Webhook Error: {e}")
        return {"error": str(e)}

@app.get("/")
async def root():
    return {"status": "Pouchon Bot Running"}

if __name__ == "__main__":
    import uvicorn
    import asyncio
    from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters

    BOT_TOKEN = os.getenv("BOT_TOKEN")
    if not BOT_TOKEN:
        raise ValueError("❌ BOT_TOKEN not found in environment variables")

    application = Application.builder().token(BOT_TOKEN).build()
    application.add_handler(CommandHandler("start", start_command))
    application.add_handler(CallbackQueryHandler(handle_plan, pattern="^plan_"))
    application.add_handler(MessageHandler(filters.TEXT & filters.ChatType.PRIVATE, handle_phone))

    print("🚀 Starting bot server on Railway...")
    uvicorn.run(app, host="0.0.0.0", port=8000)
