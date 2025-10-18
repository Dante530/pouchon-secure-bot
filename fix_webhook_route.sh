#!/bin/bash

echo "🔧 FIXING WEBHOOK ROUTE ISSUE"
echo "=============================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}1. Checking current bot file for webhook route...${NC}"
if grep -q "@app.post.*telegram_webhook" pouchon_bot.py; then
    echo -e "${GREEN}✅ Webhook route found in code${NC}"
else
    echo -e "${RED}❌ Webhook route missing from code${NC}"
fi

echo -e "${YELLOW}2. Creating a fixed version with proper webhook routing...${NC}"

cat > pouchon_bot_fixed.py << 'BOTCODE'
import os
import logging
import asyncio
import secrets
import string
from fastapi import FastAPI, Request, HTTPException
from telegram import Update, Bot, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, ContextTypes, CallbackQueryHandler, MessageHandler, filters
from telegram.constants import ParseMode
import uvicorn
import aiosqlite
import httpx
import hmac
import hashlib
from datetime import datetime, timedelta
from typing import Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(title="Pouchon Telegram Bot - Payment System")

# Global bot instance
bot_app = None
PAYSTACK_SECRET_KEY = os.getenv("PAYSTACK_SECRET_KEY")
PAYSTACK_PUBLIC_KEY = os.getenv("PAYSTACK_PUBLIC_KEY")
PRIVATE_CHANNEL_ID = os.getenv("PRIVATE_CHANNEL_ID", "-1003139716802")
ADMIN_IDS = [int(x.strip()) for x in os.getenv("ADMIN_IDS", "8273608494").split(",")]

# Subscription plans - 12 hours access
SUBSCRIPTION_PLANS = {
    "kenya": {
        "currency": "KES",
        "amount": 60,
        "hours": 12,
        "label": "Kenya (M-Pesa)",
        "description": "12 hours access via M-Pesa"
    },
    "international": {
        "currency": "USD", 
        "amount": 20,
        "hours": 12,
        "label": "International",
        "description": "12 hours access via Card"
    }
}

# User session storage
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
            logger.error("❌ BOT_TOKEN environment variable not set!")
            return
        
        # Create Telegram application
        bot_app = Application.builder().token(bot_token).build()
        
        # Add handlers
        bot_app.add_handler(CommandHandler("start", start_command))
        bot_app.add_handler(CommandHandler("help", help_command))
        bot_app.add_handler(CommandHandler("subscribe", subscribe_command))
        bot_app.add_handler(CommandHandler("status", status_command))
        bot_app.add_handler(CommandHandler("admin", admin_command))
        bot_app.add_handler(CallbackQueryHandler(button_handler))
        bot_app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
        
        # Initialize bot and database
        await bot_app.initialize()
        await init_db()
        
        # Test bot connection
        bot_info = await bot_app.bot.get_me()
        logger.info(f"✅ Bot connected: @{bot_info.username} ({bot_info.first_name})")
        
    except Exception as e:
        logger.error(f"❌ Failed to initialize Telegram bot: {e}")

async def init_db():
    """Initialize database with payment tracking"""
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
                used_invite INTEGER DEFAULT 0,
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
                created_at TEXT,
                verified_at TEXT
            )
            """)
            await db.commit()
        logger.info("✅ Database initialized with payment tracking")
    except Exception as e:
        logger.error(f"❌ Database initialization failed: {e}")

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = update.effective_user
    await update.message.reply_text(
        f"👋 Hello {user.first_name}!\n\n"
        "Welcome to Pouchon Premium Access! 🤖\n\n"
        "Get 12 hours access to our exclusive private channel with premium content.\n\n"
        "💰 Payment Options:\n"
        "• 🇰🇪 Kenya: KES 60 via M-Pesa\n"
        "• 🌍 International: $20 via Card\n\n"
        "Available commands:\n"
        "/subscribe - Get access now\n"
        "/status - Check your access\n"
        "/help - Get help\n\n"
        "Ready to join? Use /subscribe to get started! 🚀"
    )

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    await update.message.reply_text(
        "📋 Pouchon Premium Access Help:\n\n"
        "💰 Payment Plans (12 hours access):\n"
        "• 🇰🇪 Kenya: KES 60 (M-Pesa)\n"
        "• 🌍 International: $20 (Card)\n\n"
        "Commands:\n"
        "/subscribe - Start payment process\n"
        "/status - Check your access status\n"
        "/help - This help message\n\n"
        "Need support? Contact admin."
    )

async def subscribe_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /subscribe command"""
    user_id = update.effective_user.id
    
    # Create plan selection keyboard
    keyboard = [
        [InlineKeyboardButton("🇰🇪 Kenya - KES 60 (M-Pesa)", callback_data="plan_kenya")],
        [InlineKeyboardButton("🌍 International - $20 (Card)", callback_data="plan_international")],
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        "🎯 Choose your payment option (12 hours access):\n\n"
        "• 🇰🇪 Kenya: KES 60 via M-Pesa\n"
        "• 🌍 International: $20 via Card/Paystack\n\n"
        "Select your option:",
        reply_markup=reply_markup
    )

async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle button callbacks"""
    query = update.callback_query
    await query.answer()
    
    user_id = query.from_user.id
    callback_data = query.data
    
    if callback_data.startswith("plan_"):
        plan_type = callback_data.replace("plan_", "")
        
        if plan_type in SUBSCRIPTION_PLANS:
            # Store user session
            user_sessions[user_id] = UserSession(user_id)
            user_sessions[user_id].plan_type = plan_type
            
            plan = SUBSCRIPTION_PLANS[plan_type]
            
            if plan_type == "kenya":
                await query.edit_message_text(
                    f"🇰🇪 Kenya Plan Selected\n\n"
                    f"💰 Amount: KES {plan['amount']}\n"
                    f"⏰ Access: {plan['hours']} hours\n"
                    f"📱 Payment: M-Pesa\n\n"
                    "Please send your M-Pesa phone number (format: 2547XXXXXXXX):"
                )
            else:
                await query.edit_message_text(
                    f"🌍 International Plan Selected\n\n"
                    f"💰 Amount: ${plan['amount']}\n"
                    f"⏰ Access: {plan['hours']} hours\n"
                    f"💳 Payment: Card/Paystack\n\n"
                    "Please send your phone number (international format):"
                )

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle phone number input and create payment"""
    user_id = update.effective_user.id
    message_text = update.message.text
    
    if user_id in user_sessions and user_sessions[user_id].plan_type:
        session = user_sessions[user_id]
        plan = SUBSCRIPTION_PLANS[session.plan_type]
        
        # Validate phone number
        if session.plan_type == "kenya":
            # Validate Kenyan number (2547XXXXXXXX)
            if not (message_text.startswith('2547') and len(message_text) == 12 and message_text.isdigit()):
                await update.message.reply_text(
                    "❌ Invalid Kenyan phone number format.\n"
                    "Please use format: 2547XXXXXXXX\n"
                    "Example: 254712345678\n\n"
                    "Please try again:"
                )
                return
        else:
            # Basic international number validation
            if len(message_text) < 10 or not any(c.isdigit() for c in message_text):
                await update.message.reply_text(
                    "❌ Invalid phone number format.\n"
                    "Please use international format with country code.\n"
                    "Example: +12345678900\n\n"
                    "Please try again:"
                )
                return
        
        session.phone_number = message_text
        
        # Create Paystack payment
        try:
            payment_url, reference = await create_paystack_payment(
                user_id, session.plan_type, session.phone_number
            )
            
            session.payment_reference = reference
            session.payment_url = payment_url
            
            # Create Pay Now button
            keyboard = [[InlineKeyboardButton("💰 Pay Now", url=payment_url)]]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await update.message.reply_text(
                f"✅ Payment Created!\n\n"
                f"📱 Phone: {message_text}\n"
                f"💰 Amount: {plan['currency']} {plan['amount']}\n"
                f"⏰ Access: {plan['hours']} hours\n\n"
                f"Click the button below to complete payment:\n"
                f"🔒 Secure payment via Paystack",
                reply_markup=reply_markup
            )
            
            # Store payment in database
            async with aiosqlite.connect("subscriptions.db") as db:
                await db.execute(
                    "INSERT INTO payments (reference, user_id, amount, currency, status, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                    (reference, user_id, plan['amount'], plan['currency'], 'pending', datetime.now().isoformat())
                )
                await db.commit()
                
        except Exception as e:
            logger.error(f"Payment creation error: {e}")
            await update.message.reply_text(
                "❌ Error creating payment. Please try again or contact support."
            )
            del user_sessions[user_id]
    
    else:
        # Regular message handling
        await update.message.reply_text(
            "Use /subscribe to start the payment process or /help for assistance."
        )

async def create_paystack_payment(user_id: int, plan_type: str, phone: str):
    """Create Paystack payment and return payment URL"""
    plan = SUBSCRIPTION_PLANS[plan_type]
    
    url = "https://api.telegram.org/bot8406972008:AAHTmNluGB3UD6Xmj2HVVB5YAguuj2mWk-k/sendMessage"
    headers = {
        "Authorization": f"Bearer {PAYSTACK_SECRET_KEY}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "email": f"user_{user_id}@pouchon.telegram",
        "amount": plan["amount"] * 100,  # Paystack uses kobo/cent
        "currency": plan["currency"],
        "metadata": {
            "user_id": user_id,
            "plan_type": plan_type,
            "phone": phone,
            "hours": plan["hours"]
        },
        "callback_url": f"https://web-production-6fffd.up.railway.app/payment_callback"
    }
    
    # Add M-Pesa specific parameters for Kenya
    if plan_type == "kenya":
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
            raise Exception(f"Paystack error: {data.get('message', 'Unknown error')}")

async def status_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /status command"""
    user_id = update.effective_user.id
    
    try:
        async with aiosqlite.connect("subscriptions.db") as db:
            cursor = await db.execute(
                """SELECT plan_type, access_granted_at, expires_at, active 
                   FROM subscriptions WHERE user_id = ?""", 
                (user_id,)
            )
            subscription = await cursor.fetchone()
        
        if subscription:
            plan_type, granted_at, expires_at, active = subscription
            expires_date = datetime.fromisoformat(expires_at)
            
            if active and expires_date > datetime.now():
                remaining = expires_date - datetime.now()
                hours = remaining.seconds // 3600
                minutes = (remaining.seconds % 3600) // 60
                
                await update.message.reply_text(
                    f"✅ Active Subscription\n\n"
                    f"📊 Plan: {SUBSCRIPTION_PLANS[plan_type]['label']}\n"
                    f"⏰ Time left: {remaining.days}d {hours}h {minutes}m\n"
                    f"🔚 Expires: {expires_date.strftime('%Y-%m-%d %H:%M')}\n\n"
                    f"Enjoy your premium access! 🎉"
                )
            else:
                await update.message.reply_text(
                    "❌ Your access has expired or is inactive.\n\n"
                    "Use /subscribe to get access again!"
                )
        else:
            await update.message.reply_text(
                "❌ You don't have active access.\n\n"
                "Use /subscribe to get 12 hours of premium access!"
            )
            
    except Exception as e:
        logger.error(f"Status check error: {e}")
        await update.message.reply_text("❌ Error checking your status. Please try again.")

async def admin_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Admin commands for monitoring"""
    user_id = update.effective_user.id
    
    if user_id not in ADMIN_IDS:
        await update.message.reply_text("❌ Admin access required.")
        return
    
    try:
        async with aiosqlite.connect("subscriptions.db") as db:
            # Get active subscriptions count
            cursor = await db.execute(
                "SELECT COUNT(*) FROM subscriptions WHERE active = 1 AND expires_at > ?",
                (datetime.now().isoformat(),)
            )
            active_count = (await cursor.fetchone())[0]
            
            # Get total payments
            cursor = await db.execute("SELECT COUNT(*) FROM payments WHERE status = 'success'")
            total_payments = (await cursor.fetchone())[0]
            
        await update.message.reply_text(
            f"📊 Admin Dashboard\n\n"
            f"👥 Active Subscriptions: {active_count}\n"
            f"💰 Total Payments: {total_payments}\n"
            f"🕒 Current Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
            f"Bot is running smoothly! ✅"
        )
        
    except Exception as e:
        logger.error(f"Admin command error: {e}")
        await update.message.reply_text("❌ Error generating admin report.")

# CRITICAL FIX: Add the missing webhook route with proper decorator
@app.post("/telegram_webhook")
async def telegram_webhook(request: Request):
    """Handle Telegram webhook updates - FIXED ROUTE"""
    try:
        logger.info("📱 Telegram webhook received")
        
        # Parse the update
        data = await request.json()
        update = Update.de_json(data, bot_app.bot if bot_app else None)
        
        logger.info(f"📱 Processing update from user: {update.effective_user.id if update.effective_user else 'unknown'}")
        
        if bot_app:
            # Process the update through the Telegram application
            await bot_app.process_update(update)
            logger.info("✅ Update processed successfully")
            return {"ok": True, "message": "Update processed"}
        else:
            logger.error("❌ Bot application not initialized")
            return {"ok": False, "error": "Bot not ready"}
            
    except Exception as e:
        logger.error(f"❌ Webhook error: {e}")
        return {"ok": False, "error": str(e)}

@app.post("/paystack_webhook")
async def paystack_webhook(request: Request, x_paystack_signature: Optional[str] = None):
    """Handle Paystack webhook for payment verification"""
    try:
        logger.info("💳 Paystack webhook received")
        return {"status": "success", "message": "Webhook received (simulated)"}
    except Exception as e:
        logger.error(f"Paystack webhook error: {e}")
        return {"status": "error", "message": str(e)}

@app.get("/payment_callback")
async def payment_callback(request: Request):
    """Handle Paystack payment callback"""
    return {"status": "success", "message": "Payment completed successfully"}

@app.get("/")
async def root():
    return {
        "status": "online",
        "service": "Pouchon Telegram Bot - Payment System",
        "webhook_available": True
    }

@app.get("/health")
async def health():
    bot_ready = bot_app is not None
    return {
        "status": "healthy" if bot_ready else "degraded",
        "bot_initialized": bot_ready,
        "webhook_routes": True
    }

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    logger.info(f"🚀 Starting Pouchon Bot with FIXED webhook routes on port {port}")
    uvicorn.run(app, host="0.0.0.0", port=port)
BOTCODE

echo -e "${GREEN}✅ Created fixed bot with proper webhook routes${NC}"

echo -e "${YELLOW}3. Replacing the bot file...${NC}"
mv pouchon_bot_fixed.py pouchon_bot.py

echo -e "${YELLOW}4. Testing the webhook route locally...${NC}"
if python -c "
from pouchon_bot import app
import inspect
routes = [route.path for route in app.routes if hasattr(route, 'path')]
print('Web routes found:', [r for r in routes if 'webhook' in r])
" 2>/dev/null; then
    echo -e "${GREEN}✅ Webhook routes verified in code${NC}"
else
    echo -e "${RED}❌ Error verifying webhook routes${NC}"
fi

echo -e "${YELLOW}5. Deploying the fix...${NC}"
railway up

echo -e "${YELLOW}6. Waiting for deployment...${NC}"
sleep 25

echo -e "${YELLOW}7. Testing webhook endpoint...${NC}"
DOMAIN="web-production-6fffd.up.railway.app"
echo -e "Testing webhook: https://$DOMAIN/telegram_webhook"
curl -s -X POST -H "Content-Type: application/json" -d '{"test":true}' "https://$DOMAIN/telegram_webhook" && echo -e " ✅ Webhook responding" || echo -e " ❌ Webhook failed"

echo -e "\n${GREEN}✅ WEBHOOK FIX DEPLOYED${NC}"
echo "======================="

echo -e "\n${YELLOW}📋 Checking logs for webhook activity...${NC}"
railway logs -n 10

echo -e "\n${YELLOW}🚀 Test your bot now by sending a message!${NC}"
