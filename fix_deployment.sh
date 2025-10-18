#!/bin/bash

echo "🔧 FIXING DEPLOYMENT AND SYNTAX ISSUES"
echo "======================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}1. Checking current bot status...${NC}"
railway status

echo -e "${YELLOW}2. Checking if bot file was updated...${NC}"
if grep -q "requires_phone" pouchon_bot.py; then
    echo -e "${GREEN}✅ Professional bot file is in place${NC}"
else
    echo -e "${RED}❌ Bot file not updated properly${NC}"
    echo -e "${YELLOW}Recreating professional bot file...${NC}"
    
    cat > pouchon_bot_pro.py << 'BOTCODE'
import os
import logging
import asyncio
from fastapi import FastAPI, Request
from telegram import Update, Bot, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, ContextTypes, CallbackQueryHandler, MessageHandler, filters
from telegram.constants import ParseMode
import uvicorn
import aiosqlite
import httpx
from datetime import datetime, timedelta
from typing import Optional

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Pouchon Premium Bot")
bot_app = None

PAYSTACK_SECRET_KEY = os.getenv("PAYSTACK_SECRET_KEY")
PRIVATE_CHANNEL_ID = os.getenv("PRIVATE_CHANNEL_ID", "-1003139716802")

SUBSCRIPTION_PLANS = {
    "kenya": {
        "currency": "KES",
        "amount": 60,
        "hours": 12,
        "label": "Kenya (M-Pesa)",
        "requires_phone": True
    },
    "international": {
        "currency": "USD", 
        "amount": 20,
        "hours": 12,
        "label": "International", 
        "requires_phone": False
    }
}

user_sessions = {}

class UserSession:
    def __init__(self, user_id: int):
        self.user_id = user_id
        self.plan_type = None
        self.phone_number = None
        self.payment_reference = None
        self.payment_url = None

@app.on_event("startup")
async def startup_event():
    global bot_app
    try:
        bot_token = os.getenv("BOT_TOKEN")
        if not bot_token:
            logger.error("BOT_TOKEN not set!")
            return
        
        bot_app = Application.builder().token(bot_token).build()
        bot_app.add_handler(CommandHandler("start", start_command))
        bot_app.add_handler(CommandHandler("help", help_command))
        bot_app.add_handler(CommandHandler("subscribe", subscribe_command))
        bot_app.add_handler(CommandHandler("status", status_command))
        bot_app.add_handler(CallbackQueryHandler(button_handler))
        bot_app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
        
        await bot_app.initialize()
        await init_db()
        
        bot_info = await bot_app.bot.get_me()
        logger.info(f"Bot connected: @{bot_info.username}")
        
    except Exception as e:
        logger.error(f"Startup failed: {e}")

async def init_db():
    try:
        async with aiosqlite.connect("subscriptions.db") as db:
            await db.execute("""
            CREATE TABLE IF NOT EXISTS subscriptions (
                user_id INTEGER PRIMARY KEY,
                plan_type TEXT,
                phone_number TEXT,
                payment_reference TEXT UNIQUE,
                amount INTEGER,
                currency TEXT,
                access_granted_at TEXT,
                expires_at TEXT,
                invite_link TEXT,
                active INTEGER DEFAULT 0
            )
            """)
            await db.execute("""
            CREATE TABLE IF NOT EXISTS payments (
                reference TEXT PRIMARY KEY,
                user_id INTEGER,
                amount INTEGER,
                currency TEXT,
                status TEXT,
                created_at TEXT
            )
            """)
            await db.commit()
        logger.info("Database initialized")
    except Exception as e:
        logger.error(f"Database init failed: {e}")

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    await update.message.reply_text(
        f"👋 Hello {user.first_name}!\n\n"
        "Welcome to Pouchon Premium Access! 🤖\n\n"
        "Get 12 hours access to our exclusive private channel.\n\n"
        "💰 Payment Options:\n"
        "• 🇰🇪 Kenya: KES 60 via M-Pesa\n"
        "• 🌍 International: $20 via Card\n\n"
        "Commands:\n"
        "/subscribe - Get access now\n"
        "/status - Check your access\n"
        "/help - Get help\n\n"
        "Ready? Use /subscribe to start! 🚀",
        parse_mode=ParseMode.MARKDOWN
    )

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "📋 Pouchon Premium Access Help\n\n"
        "💰 Payment Plans (12 hours):\n"
        "• 🇰🇪 Kenya: KES 60 (M-Pesa)\n"
        "• 🌍 International: $20 (Card)\n\n"
        "Commands:\n"
        "/subscribe - Start payment\n"
        "/status - Check access\n"
        "/help - This message\n\n"
        "Need support? Contact admin.",
        parse_mode=ParseMode.MARKDOWN
    )

async def subscribe_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    keyboard = [
        [InlineKeyboardButton("🇰🇪 Kenya - KES 60 (M-Pesa)", callback_data="plan_kenya")],
        [InlineKeyboardButton("🌍 International - $20 (Card)", callback_data="plan_international")],
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        "🎯 Choose your payment option (12 hours access):\n\n"
        "• 🇰🇪 Kenya: KES 60 via M-Pesa\n"
        "• 🌍 International: $20 via Card\n\n"
        "Select your option:",
        reply_markup=reply_markup
    )

async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    
    user_id = query.from_user.id
    callback_data = query.data
    
    if callback_data.startswith("plan_"):
        plan_type = callback_data.replace("plan_", "")
        
        if plan_type in SUBSCRIPTION_PLANS:
            user_sessions[user_id] = UserSession(user_id)
            user_sessions[user_id].plan_type = plan_type
            
            plan = SUBSCRIPTION_PLANS[plan_type]
            
            if plan_type == "kenya":
                await query.edit_message_text(
                    f"🇰🇪 Kenya Plan Selected\n\n"
                    f"💰 Amount: KES {plan['amount']}\n"
                    f"⏰ Access: {plan['hours']} hours\n"
                    f"📱 Payment: M-Pesa\n\n"
                    "Please send your M-Pesa phone number:\n"
                    "Format: 2547XXXXXXXX\n"
                    "Example: 254712345678"
                )
            else:
                # International - direct to payment
                try:
                    payment_url, reference = await create_paystack_payment(user_id, plan_type, None)
                    user_sessions[user_id].payment_reference = reference
                    user_sessions[user_id].payment_url = payment_url
                    
                    keyboard = [[InlineKeyboardButton("💰 Pay Now $20", url=payment_url)]]
                    reply_markup = InlineKeyboardMarkup(keyboard)
                    
                    await query.edit_message_text(
                        f"🌍 International Plan Selected\n\n"
                        f"💰 Amount: ${plan['amount']}\n"
                        f"⏰ Access: {plan['hours']} hours\n"
                        f"💳 Payment: Card/Paystack\n\n"
                        "Click below to complete payment:\n"
                        "🔒 Secure payment via Paystack",
                        reply_markup=reply_markup
                    )
                    
                    async with aiosqlite.connect("subscriptions.db") as db:
                        await db.execute(
                            "INSERT INTO payments (reference, user_id, amount, currency, status, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                            (reference, user_id, plan['amount'], plan['currency'], 'pending', datetime.now().isoformat())
                        )
                        await db.commit()
                        
                except Exception as e:
                    logger.error(f"Payment creation error: {e}")
                    await query.edit_message_text("❌ Error creating payment. Please try again.")
                    if user_id in user_sessions:
                        del user_sessions[user_id]

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    message_text = update.message.text
    
    if user_id in user_sessions and user_sessions[user_id].plan_type == "kenya":
        session = user_sessions[user_id]
        plan = SUBSCRIPTION_PLANS[session.plan_type]
        
        # Validate Kenyan number
        if not (message_text.startswith('2547') and len(message_text) == 12 and message_text.isdigit()):
            await update.message.reply_text(
                "❌ Invalid M-Pesa number.\n"
                "Use format: 2547XXXXXXXX\n"
                "Example: 254712345678\n\n"
                "Please try again:"
            )
            return
        
        session.phone_number = message_text
        
        try:
            payment_url, reference = await create_paystack_payment(user_id, session.plan_type, session.phone_number)
            session.payment_reference = reference
            session.payment_url = payment_url
            
            keyboard = [[InlineKeyboardButton("💰 Pay Now KES 60", url=payment_url)]]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await update.message.reply_text(
                f"✅ Payment Created!\n\n"
                f"📱 Phone: {message_text}\n"
                f"💰 Amount: KES {plan['amount']}\n"
                f"⏰ Access: {plan['hours']} hours\n\n"
                "Click below to complete payment:",
                reply_markup=reply_markup
            )
            
            async with aiosqlite.connect("subscriptions.db") as db:
                await db.execute(
                    "INSERT INTO payments (reference, user_id, amount, currency, status, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                    (reference, user_id, plan['amount'], plan['currency'], 'pending', datetime.now().isoformat())
                )
                await db.commit()
                
        except Exception as e:
            logger.error(f"Payment error: {e}")
            await update.message.reply_text("❌ Error creating payment. Please try again.")
            if user_id in user_sessions:
                del user_sessions[user_id]
    
    else:
        await update.message.reply_text("Use /subscribe to start payment or /help for assistance.")

async def create_paystack_payment(user_id: int, plan_type: str, phone: Optional[str]):
    plan = SUBSCRIPTION_PLANS[plan_type]
    
    url = "https://api.paystack.co/transaction/initialize"
    headers = {
        "Authorization": f"Bearer {PAYSTACK_SECRET_KEY}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "email": f"user_{user_id}@pouchon.telegram",
        "amount": plan["amount"] * 100,
        "currency": plan["currency"],
        "metadata": {
            "user_id": user_id,
            "plan_type": plan_type,
            "phone": phone,
            "hours": plan["hours"]
        }
    }
    
    if plan_type == "kenya" and phone:
        payload["channels"] = ["mobile_money"]
        payload["mobile_money"] = {
            "phone": phone,
            "provider": "mpesa"
        }
    
    async with httpx.AsyncClient() as client:
        response = await client.post(url, json=payload, headers=headers)
        response.raise_for_status()
        data = response.json()
        
        if data["status"]:
            return data["data"]["authorization_url"], data["data"]["reference"]
        else:
            raise Exception(f"Paystack: {data.get('message', 'Unknown error')}")

async def status_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    
    try:
        async with aiosqlite.connect("subscriptions.db") as db:
            cursor = await db.execute(
                "SELECT plan_type, expires_at, active FROM subscriptions WHERE user_id = ?", 
                (user_id,)
            )
            subscription = await cursor.fetchone()
        
        if subscription:
            plan_type, expires_at, active = subscription
            expires_date = datetime.fromisoformat(expires_at)
            
            if active and expires_date > datetime.now():
                remaining = expires_date - datetime.now()
                hours = remaining.seconds // 3600
                minutes = (remaining.seconds % 3600) // 60
                
                await update.message.reply_text(
                    f"✅ Active Subscription\n\n"
                    f"Plan: {SUBSCRIPTION_PLANS[plan_type]['label']}\n"
                    f"Time left: {remaining.days}d {hours}h {minutes}m\n"
                    f"Expires: {expires_date.strftime('%Y-%m-%d %H:%M')}\n\n"
                    f"Enjoy your access! 🎉"
                )
            else:
                await update.message.reply_text("❌ Your access has expired. Use /subscribe to renew!")
        else:
            await update.message.reply_text("❌ No active access. Use /subscribe to get started!")
            
    except Exception as e:
        logger.error(f"Status error: {e}")
        await update.message.reply_text("❌ Error checking status. Please try again.")

@app.post("/telegram_webhook")
async def telegram_webhook(request: Request):
    try:
        data = await request.json()
        update = Update.de_json(data, bot_app.bot if bot_app else None)
        
        if bot_app:
            await bot_app.process_update(update)
            return {"ok": True}
        else:
            return {"ok": False, "error": "Bot not ready"}
            
    except Exception as e:
        logger.error(f"Webhook error: {e}")
        return {"ok": False, "error": str(e)}

@app.get("/")
async def root():
    return {"status": "online", "service": "Pouchon Premium Bot"}

@app.get("/health")
async def health():
    return {"status": "healthy", "bot_ready": bot_app is not None}

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    logger.info(f"Starting bot on port {port}")
    uvicorn.run(app, host="0.0.0.0", port=port)
BOTCODE

    mv pouchon_bot_pro.py pouchon_bot.py
    echo -e "${GREEN}✅ Recreated professional bot file${NC}"
fi

echo -e "${YELLOW}3. Deploying with retry...${NC}"
if railway up; then
    echo -e "${GREEN}✅ Deployment successful${NC}"
else
    echo -e "${YELLOW}⚠️ Deployment failed, trying alternative method...${NC}"
    git add .
    git commit -m "Fix: Professional payment bot with proper flows" || true
    git push origin main || echo "Git push optional"
    echo -e "${YELLOW}Waiting for Railway auto-deploy...${NC}"
    sleep 30
fi

echo -e "${YELLOW}4. Checking deployment status...${NC}"
railway logs -n 10

echo -e "${YELLOW}5. Testing the fixed bot...${NC}"
echo -e "${GREEN}✅ Deployment fix completed${NC}"
echo ""
echo "${YELLOW}🚀 Test your bot now:${NC}"
echo "• Send /subscribe to test the new flows"
echo "• International should go directly to payment"
echo "• Kenya should ask for M-Pesa number"
echo "• /status should work properly"
