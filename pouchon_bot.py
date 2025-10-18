import os
import logging
import asyncio
import re
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
BOT_TOKEN = os.getenv("BOT_TOKEN")
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

def validate_kenya_phone(phone: str) -> bool:
    """
    Universal Kenya mobile money number validation
    Accepts all formats: 07XX, 7XX, 2547XX, +2547XX, 2541XX
    """
    # Remove any spaces, dashes, plus signs
    cleaned_phone = re.sub(r'[\s+\-]', '', phone)
    
    # Check if it's a valid Kenya mobile number
    patterns = [
        r'^07\d{8}$',      # 07XXXXXXXX (10 digits)
        r'^7\d{8}$',       # 7XXXXXXXX (9 digits)  
        r'^2547\d{8}$',    # 2547XXXXXXXX (12 digits)
        r'^2541\d{8}$',    # 2541XXXXXXXX (12 digits - Airtel, Telkom)
        r'^25411\d{7}$',   # 25411XXXXXXX (12 digits - Airtel)
    ]
    
    return any(re.match(pattern, cleaned_phone) for pattern in patterns)

def format_phone_for_paystack(phone: str) -> str:
    """
    Convert any Kenya phone format to 254XXXXXXXXX for Paystack
    """
    cleaned_phone = re.sub(r'[\s+\-]', '', phone)
    
    # If starts with 07, convert to 254
    if cleaned_phone.startswith('07'):
        return '254' + cleaned_phone[1:]
    
    # If starts with 7, add 254
    elif cleaned_phone.startswith('7') and len(cleaned_phone) == 9:
        return '254' + cleaned_phone
    
    # If starts with 254, return as is
    elif cleaned_phone.startswith('254'):
        return cleaned_phone
    
    # Return original if no match
    return cleaned_phone

@app.on_event("startup")
async def startup_event():
    global bot_app
    try:
        if not BOT_TOKEN:
            logger.error("BOT_TOKEN not set!")
            return
        
        bot_app = Application.builder().token(BOT_TOKEN).build()
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
        "Get 12 hours access to our exclusive private channel.\n\n"
        "💰 Payment Options:\n"
        "• 🇰🇪 Kenya: KES 60 via M-Pesa\n"
        "• 🌍 International: $20 via Card\n\n"
        "Use /subscribe to get access",
        parse_mode=ParseMode.MARKDOWN
    )

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "📋 How to get access:\n\n"
        "1. Use /subscribe\n"
        "2. Choose your payment method\n"
        "3. Complete payment\n"
        "4. Get instant channel access\n\n"
        "Need help? Contact admin."
    )

async def subscribe_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    keyboard = [
        [InlineKeyboardButton("🇰🇪 Kenya - KES 60 (M-Pesa)", callback_data="plan_kenya")],
        [InlineKeyboardButton("🌍 International - $20 (Card)", callback_data="plan_international")],
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await update.message.reply_text(
        "Choose your payment method (12 hours access):",
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
                    "Please send your mobile money number:\n\n"
                    "✅ Accepted formats:\n"
                    "• 07XXXXXXXX\n"
                    "• 7XXXXXXXX\n"
                    "• 2547XXXXXXXX\n"
                    "• 2541XXXXXXXX\n"
                    "• +2547XXXXXXXX\n\n"
                    "Works with all providers: M-Pesa, Airtel Money, Telkom Cash"
                )
            else:
                await create_inline_payment(query, user_id, plan_type, None)
                    
    elif callback_data == "check_payment":
        await check_payment_status(query, user_id)

async def create_inline_payment(query, user_id: int, plan_type: str, phone: Optional[str]):
    """Create Paystack payment and show inline payment button"""
    try:
        payment_url, reference = await create_paystack_payment(user_id, plan_type, phone)
        
        user_sessions[user_id].payment_reference = reference
        
        async with aiosqlite.connect("subscriptions.db") as db:
            plan = SUBSCRIPTION_PLANS[plan_type]
            await db.execute(
                "INSERT OR REPLACE INTO payments (reference, user_id, amount, currency, status, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                (reference, user_id, plan['amount'], plan['currency'], 'pending', datetime.now().isoformat())
            )
            await db.commit()
        
        keyboard = [
            [InlineKeyboardButton("💳 Pay Now", url=payment_url)],
            [InlineKeyboardButton("✅ I've Paid", callback_data="check_payment")]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        plan = SUBSCRIPTION_PLANS[plan_type]
        await query.edit_message_text(
            f"✅ Payment Ready!\n\n"
            f"Plan: {plan['label']}\n"
            f"Amount: {plan['amount']} {plan['currency']}\n"
            f"Access: {plan['hours']} hours\n\n"
            "Click 'Pay Now' to complete payment securely within Telegram.\n"
            "After payment, click 'I've Paid' to verify.",
            reply_markup=reply_markup
        )
        
    except Exception as e:
        logger.error(f"Payment creation error: {e}")
        await query.edit_message_text(
            "❌ Error creating payment. Please try again or contact support."
        )
        if user_id in user_sessions:
            del user_sessions[user_id]

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    message_text = update.message.text.strip()
    
    if user_id in user_sessions and user_sessions[user_id].plan_type == "kenya":
        # Validate Kenya mobile money number
        if not validate_kenya_phone(message_text):
            await update.message.reply_text(
                "❌ Invalid mobile money number.\n\n"
                "✅ Accepted formats:\n"
                "• 07XXXXXXXX\n"
                "• 7XXXXXXXX\n"
                "• 2547XXXXXXXX\n"
                "• 2541XXXXXXXX\n"
                "• +2547XXXXXXXX\n\n"
                "Please send your correct number:"
            )
            return
        
        # Format phone for Paystack
        formatted_phone = format_phone_for_paystack(message_text)
        user_sessions[user_id].phone_number = formatted_phone
        
        try:
            payment_url, reference = await create_paystack_payment(
                user_id, 
                user_sessions[user_id].plan_type, 
                formatted_phone
            )
            
            user_sessions[user_id].payment_reference = reference
            
            async with aiosqlite.connect("subscriptions.db") as db:
                plan = SUBSCRIPTION_PLANS[user_sessions[user_id].plan_type]
                await db.execute(
                    "INSERT OR REPLACE INTO payments (reference, user_id, amount, currency, status, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                    (reference, user_id, plan['amount'], plan['currency'], 'pending', datetime.now().isoformat())
                )
                await db.commit()
            
            keyboard = [
                [InlineKeyboardButton("💳 Pay Now", url=payment_url)],
                [InlineKeyboardButton("✅ I've Paid", callback_data="check_payment")]
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await update.message.reply_text(
                f"✅ Payment Ready!\n\n"
                f"📱 Number: {message_text}\n"
                f"💰 Amount: KES 60\n"
                f"⏰ Access: 12 hours\n\n"
                "Click 'Pay Now' to complete payment securely within Telegram.\n"
                "After payment, click 'I've Paid' to verify.",
                reply_markup=reply_markup
            )
            
        except Exception as e:
            logger.error(f"Kenya payment error: {e}")
            await update.message.reply_text("❌ Error creating payment. Please try again.")
            if user_id in user_sessions:
                del user_sessions[user_id]
    
    else:
        await update.message.reply_text("Use /subscribe to start payment or /help for assistance.")

async def create_paystack_payment(user_id: int, plan_type: str, phone: Optional[str]):
    """Create Paystack payment"""
    
    if not PAYSTACK_SECRET_KEY:
        raise Exception("Paystack secret key not configured")
    
    plan = SUBSCRIPTION_PLANS[plan_type]
    
    email = f"user{user_id}@pouchon.com"
    
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
    
    if plan_type == "kenya" and phone:
        payload["metadata"]["phone"] = phone
        payload["channels"] = ["mobile_money"]
    
    logger.info(f"Creating {plan_type} payment for user {user_id}")
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(url, json=payload, headers=headers, timeout=30.0)
            
            if response.status_code == 200:
                data = response.json()
                if data.get("status"):
                    return data["data"]["authorization_url"], data["data"]["reference"]
                else:
                    error_msg = data.get('message', 'Unknown error')
                    raise Exception(f"Payment failed: {error_msg}")
            else:
                raise Exception(f"Payment service error: {response.status_code}")
                
        except httpx.HTTPError as e:
            raise Exception("Payment service unavailable. Please try again.")
        except Exception as e:
            logger.error(f"Payment error: {e}")
            raise e

async def check_payment_status(query, user_id: int):
    """Check if payment was successful"""
    try:
        if user_id not in user_sessions:
            await query.edit_message_text("❌ Session expired. Please start over with /subscribe")
            return
        
        reference = user_sessions[user_id].payment_reference
        
        if not reference:
            await query.edit_message_text("❌ No payment found. Please start over with /subscribe")
            return
        
        url = f"https://api.paystack.co/transaction/verify/{reference}"
        headers = {
            "Authorization": f"Bearer {PAYSTACK_SECRET_KEY}",
            "Content-Type": "application/json"
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers, timeout=30.0)
            
            if response.status_code == 200:
                data = response.json()
                
                if data.get("status") and data["data"]["status"] == "success":
                    await grant_channel_access(user_id, user_sessions[user_id].plan_type)
                    await query.edit_message_text(
                        "✅ Payment Verified!\n\n"
                        "🎉 You now have access to the private channel!\n\n"
                        "Check your messages for the channel invite."
                    )
                    
                    if user_id in user_sessions:
                        del user_sessions[user_id]
                        
                else:
                    await query.edit_message_text(
                        "⏳ Payment not confirmed yet.\n\n"
                        "If you've paid, it may take a few moments to process.\n"
                        "Click 'I've Paid' again in 30 seconds."
                    )
            else:
                await query.edit_message_text("❌ Error verifying payment. Please try again.")
                
    except Exception as e:
        logger.error(f"Payment verification error: {e}")
        await query.edit_message_text("❌ Error checking payment. Please try again.")

async def grant_channel_access(user_id: int, plan_type: str):
    """Grant access to private channel"""
    try:
        bot = bot_app.bot if bot_app else Bot(token=BOT_TOKEN)
        
        invite_link = await bot.create_chat_invite_link(
            chat_id=PRIVATE_CHANNEL_ID,
            member_limit=1,
            expire_date=timedelta(hours=12)
        )
        
        async with aiosqlite.connect("subscriptions.db") as db:
            plan = SUBSCRIPTION_PLANS[plan_type]
            expires_at = datetime.now() + timedelta(hours=plan['hours'])
            
            await db.execute(
                """INSERT OR REPLACE INTO subscriptions 
                (user_id, plan_type, phone_number, payment_reference, amount, currency, 
                 access_granted_at, expires_at, invite_link, active) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (user_id, plan_type, 
                 user_sessions[user_id].phone_number if user_id in user_sessions else None,
                 user_sessions[user_id].payment_reference if user_id in user_sessions else None,
                 plan['amount'], plan['currency'],
                 datetime.now().isoformat(), expires_at.isoformat(),
                 invite_link.invite_link, 1)
            )
            await db.commit()
        
        async with aiosqlite.connect("subscriptions.db") as db:
            await db.execute(
                "UPDATE payments SET status = ? WHERE reference = ?",
                ('success', user_sessions[user_id].payment_reference if user_id in user_sessions else None)
            )
            await db.commit()
        
        await bot.send_message(
            chat_id=user_id,
            text=f"🎉 Welcome to the Private Channel!\n\n"
                 f"Click here to join: {invite_link.invite_link}\n\n"
                 f"⏰ Access expires in {plan['hours']} hours\n"
                 f"Enjoy the content!",
            parse_mode=ParseMode.MARKDOWN
        )
        
        logger.info(f"Access granted to user {user_id} for {plan_type} plan")
        
    except Exception as e:
        logger.error(f"Channel access error: {e}")
        try:
            await bot.send_message(
                chat_id=user_id,
                text="✅ Payment successful! Please contact admin for channel access."
            )
        except:
            pass

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
                    f"Time left: {hours}h {minutes}m\n"
                    f"Expires: {expires_date.strftime('%Y-%m-%d %H:%M')}"
                )
            else:
                await update.message.reply_text("❌ No active access. Use /subscribe to get access!")
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
    uvicorn.run(app, host="0.0.0.0", port=port)
