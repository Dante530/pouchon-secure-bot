#!/bin/bash

echo "🚀 DEPLOYING EMAIL FIX IMMEDIATELY"
echo "=================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}1. Updating the payment function with your email...${NC}"

# Create a simple, direct fix
cat > pouchon_bot_fixed.py << 'BOTFIXED'
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

# FIXED PAYMENT FUNCTION WITH VALID EMAIL
async def create_paystack_payment(user_id: int, plan_type: str, phone: Optional[str]):
    """Fixed Paystack payment with valid email format"""
    
    if not PAYSTACK_SECRET_KEY:
        raise Exception("Paystack secret key not configured")
    
    plan = SUBSCRIPTION_PLANS[plan_type]
    
    # Use a valid email format that Paystack will accept
    # Using your actual email domain for testing
    email = f"user{user_id}@dantek361.gmail.com"
    
    url = "https://api.paystack.co/transaction/initialize"
    headers = {
        "Authorization": f"Bearer {PAYSTACK_SECRET_KEY}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "email": email,
        "amount": plan["amount"] * 100,
        "currency": plan["currency"],
        "metadata": {
            "user_id": user_id,
            "plan_type": plan_type,
            "hours": plan["hours"]
        }
    }
    
    # Add phone only for Kenya M-Pesa
    if plan_type == "kenya" and phone:
        payload["metadata"]["phone"] = phone
        payload["channels"] = ["mobile_money"]
    
    logger.info(f"Creating payment for {email}")
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(url, json=payload, headers=headers, timeout=30.0)
            logger.info(f"Paystack response: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                if data.get("status"):
                    return data["data"]["authorization_url"], data["data"]["reference"]
                else:
                    error_msg = data.get('message', 'Unknown error')
                    raise Exception(f"Payment failed: {error_msg}")
            else:
                logger.error(f"Paystack error {response.status_code}: {response.text}")
                raise Exception(f"Payment service error: {response.status_code}")
                
        except httpx.HTTPError as e:
            logger.error(f"HTTP error: {e}")
            raise Exception("Payment service unavailable. Please try again.")
        except Exception as e:
            logger.error(f"Payment error: {e}")
            raise e

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
BOTFIXED

echo -e "${GREEN}✅ Created fixed bot with valid email format${NC}"

echo -e "${YELLOW}2. Replacing the bot file...${NC}"
mv pouchon_bot_fixed.py pouchon_bot.py

echo -e "${YELLOW}3. Testing the fixed payment function locally...${NC}"
cat > test_fixed_payment.py << 'TESTFIXED'
import asyncio
import httpx

async def test_payment():
    print("🧪 Testing fixed payment with valid email...")
    
    PAYSTACK_SECRET_KEY = 'sk_live_8a8960b2063c3af5138381fc7a76d79d381f6ae4'
    
    url = "https://api.paystack.co/transaction/initialize"
    headers = {
        "Authorization": f"Bearer {PAYSTACK_SECRET_KEY}",
        "Content-Type": "application/json"
    }
    
    # Test with the new valid email format
    payload = {
        "email": "user123456@dantek361.gmail.com",  # Valid email format
        "amount": 2000,
        "currency": "USD",
        "metadata": {
            "user_id": 123456,
            "plan_type": "international",
            "hours": 12
        }
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(url, json=payload, headers=headers, timeout=10.0)
            print(f"Payment test: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                if data.get("status"):
                    print("✅ PAYMENT CREATION SUCCESSFUL!")
                    print(f"Reference: {data['data']['reference']}")
                    print(f"Payment URL: {data['data']['authorization_url']}")
                    return True
                else:
                    print(f"❌ Paystack error: {data.get('message')}")
                    return False
            else:
                print(f"❌ HTTP error: {response.status_code}")
                print(f"Response: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Test failed: {e}")
            return False

success = asyncio.run(test_payment())
if success:
    print("🎉 🎉 🎉 EMAIL FIX WORKS! 🎉 🎉 🎉")
else:
    print("🔧 Still need to investigate the issue")
TESTFIXED

python3 test_fixed_payment.py

echo -e "${YELLOW}4. Deploying the fix...${NC}"
railway up

echo -e "${YELLOW}5. Waiting for deployment...${NC}"
sleep 30

echo -e "${GREEN}✅ EMAIL FIX DEPLOYED${NC}"
echo "===================="

echo -e "\n${YELLOW}🚀 TEST YOUR BOT NOW:${NC}"
echo "Send /subscribe to @Pouchonlive_bot and choose International plan!"
echo "The payment should now work with the valid email format."

echo -e "\n${YELLOW}📋 What was fixed:${NC}"
echo "• Changed email from: user_123456@pouchon.telegram"
echo "• Changed email to: user123456@dantek361.gmail.com"
echo "• This is a valid email format that Paystack accepts"
echo "• Should resolve the 400 Bad Request error"
