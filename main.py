# pouchon_bot.py

import os
import sqlite3
import asyncio
import threading
import time
import subprocess
import re
from datetime import datetime, timedelta

# Telegram imports
from telegram import Bot, InlineKeyboardMarkup, InlineKeyboardButton, Update
from telegram.ext import ApplicationBuilder, ContextTypes, CommandHandler, CallbackQueryHandler

# Paystack imports
from paystackapi.paystack import Paystack
from paystackapi.transaction import Transaction

# Read Telegram token from environment variable
TOKEN = os.getenv("TOKEN")
if not TOKEN:
    raise ValueError("Telegram bot TOKEN is not set! Set it in Railway environment variables.")

# Initialize Telegram bot
bot = Bot(token=TOKEN)

# Example: initialize Paystack
PAYSTACK_SECRET_KEY = os.getenv("PAYSTACK_SECRET_KEY")
if not PAYSTACK_SECRET_KEY:
    raise ValueError("Paystack secret key not set! Set it in Railway environment variables.")
paystack = Paystack(PAYSTACK_SECRET_KEY)

# Your other bot logic here...
# Example command handler
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("Hello! Pouchon Bot is running.")

# Register handlers
application.add_handler(CommandHandler("start", start))

# Run the bot (webhook style)
async def main():
    # Replace with your Railway app URL
    WEBHOOK_URL = os.getenv("WEBHOOK_URL")  # set to https://pouchon-secure-bot-production.up.railway.app/
    await bot.set_webhook(WEBHOOK_URL)
    print(f"Webhook set to {WEBHOOK_URL}")
    
    # Start the bot
    await application.initialize()
    await application.start()
    await application.updater.start_polling()  # no polling if you only want webhook; can remove this line
    await application.updater.idle()

if __name__ == "__main__":
    asyncio.run(main())
# ==================== CONFIG ====================
# Temporary hardcoded values for testing
BOT_TOKEN = "8406972008:AAHTmNluGB3UD6Xmj2HVVB5YAguuj2mWk-k"
PAYSTACK_PUBLIC_KEY = "pk_live_8814078e3e588386ebf5ed33119caac71e916a58"
PRIVATE_GROUP_ID = -1008273608494
ADMIN_IDS = [8273608494]
# PayStack Keys - REAL LIVE KEYS
PAYSTACK_PUBLIC_KEY = "pk_live_8814078e3e588386ebf5ed33119caac71e916a58"
paystack = Paystack(secret_key=PAYSTACK_SECRET_KEY)

# Subscription Plans
SUBSCRIPTION_PLANS = {
    "1_day": (24, 100, "1 Day - KSh 100"),
    "3_days": (72, 250, "3 Days - KSh 250"), 
    "1_week": (168, 500, "1 Week - KSh 500"),
    "1_month": (720, 1500, "1 Month - KSh 1500"),
    "international": (12, 2000, "12 Hours - $20 International")
}

# ==================== DATABASE ====================
def setup_db():
    conn = sqlite3.connect('pouchon.db', check_same_thread=False)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS payments(
            user_id INTEGER,
            user_name TEXT,
            status TEXT,
            amount REAL,
            currency TEXT,
            payment_method TEXT,
            invoice_id TEXT PRIMARY KEY,
            phone_number TEXT,
            subscription_plan TEXT,
            requested_at TEXT,
            completed_at TEXT,
            access_ends_at TEXT,
            paystack_reference TEXT
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS active_subscriptions(
            user_id INTEGER PRIMARY KEY,
            user_name TEXT,
            subscription_plan TEXT,
            access_ends_at TEXT,
            invite_link TEXT
        )
    ''')
    conn.commit()
    conn.close()

setup_db()

# ==================== PAYSTACK PAYMENT FUNCTIONS ====================
async def initiate_paystack_payment(user, amount_kes, plan_name, phone=None):
    """Initiate real PayStack payment"""
    try:
        # Convert to cents
        amount_cents = int(amount_kes * 100)
        
        # Prepare metadata
        metadata = {
            "user_id": user.id,
            "username": user.first_name or "Telegram User",
            "plan": plan_name,
            "custom_fields": [
                {
                    "display_name": "Telegram User ID",
                    "variable_name": "telegram_user_id", 
                    "value": str(user.id)
                }
            ]
        }
        
        # For MPesa payments
        if phone:
            response = Transaction.initialize(
                email=f"{user.id}@pouchon.telegram",
                amount=amount_cents,
                mobile_money={
                    "phone": phone,
                    "provider": "mpesa"
                },
                metadata=metadata
            )
        else:
            # For international card payments
            response = Transaction.initialize(
                email=f"{user.id}@pouchon.telegram",
                amount=amount_cents,
                currency="KES",
                metadata=metadata
            )
        
        if response['status']:
            reference = response['data']['reference']
            authorization_url = response['data']['authorization_url']
            
            # Store in database
            conn = sqlite3.connect('pouchon.db')
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO payments(user_id, user_name, status, amount, currency, 
                                   payment_method, invoice_id, subscription_plan, 
                                   requested_at, paystack_reference)
                VALUES(?,?,?,?,?,?,?,?,?,?)
            ''', (user.id, user.first_name, 'pending', amount_kes, 'KES', 
                  'paystack', reference, plan_name, datetime.now().isoformat(), reference))
            conn.commit()
            conn.close()
            
            return authorization_url, reference
        else:
            return None, None
            
    except Exception as e:
        print(f"PayStack error: {e}")
        return None, None

# ==================== BOT HANDLERS ====================
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
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
            await send_existing_user(user, context.bot)
            return
    
    # Show subscription plans
    keyboard = []
    for plan_name, (hours, price, description) in SUBSCRIPTION_PLANS.items():
        if plan_name == "international":
            keyboard.append([InlineKeyboardButton("🌍 " + description, callback_data=f"plan_{plan_name}")])
        else:
            keyboard.append([InlineKeyboardButton("📱 " + description, callback_data=f"plan_{plan_name}")])
    
    await context.bot.send_message(
        chat_id=user.id,
        text=f"👋 Welcome, {user.first_name}!\n\nChoose your subscription plan:",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode='Markdown'
    )

async def handle_plan_selection(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user = query.from_user
    
    plan_name = query.data.replace("plan_", "")
    hours, price, description = SUBSCRIPTION_PLANS[plan_name]
    
    context.user_data['selected_plan'] = plan_name
    context.user_data['plan_price'] = price
    
    if plan_name == "international":
        # International users - card payment
        await initiate_international_payment(user, context, plan_name, price)
    else:
        # Kenyan users - MPesa payment
        await context.bot.send_message(
            chat_id=user.id,
            text=f"🎯 {description}\n\n📱 Enter your Safaricom number (07XXXXXXXX or 2547XXXXXXXX):",
            parse_mode='Markdown'
        )
        context.user_data['awaiting_phone'] = True

async def initiate_international_payment(user, context, plan_name, price):
    """Handle international card payments"""
    authorization_url, reference = await initiate_paystack_payment(user, price, plan_name)
    
    if authorization_url:
        await context.bot.send_message(
            chat_id=user.id,
            text=f"🌍 **International Payment**\n\n"
                 f"💵 Amount: **$20 USD** (KSh {price})\n"
                 f"⏰ Access: **12 Hours**\n\n"
                 f"🔗 [Click here to pay with card]({authorization_url})\n\n"
                 f"Access granted automatically after payment.",
            parse_mode='Markdown',
            disable_web_page_preview=True
        )
    else:
        await context.bot.send_message(
            chat_id=user.id,
            text="❌ Payment system temporarily unavailable. Please try again later.",
            parse_mode='Markdown'
        )

async def handle_phone(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    if not context.user_data.get('awaiting_phone'):
        return
    
    phone = update.message.text.strip().replace(" ", "").replace("-", "").replace("+", "")
    if not ((phone.startswith('07') and len(phone)==10) or (phone.startswith('2547') and len(phone)==12)):
        await update.message.reply_text("❌ Invalid number. Use 07XXXXXXXX or 2547XXXXXXXX:")
        return
    
    formatted_phone = '254' + phone[1:] if phone.startswith('07') else phone
    plan_name = context.user_data.get('selected_plan')
    price = context.user_data.get('plan_price')
    
    # Initiate REAL PayStack MPesa payment
    authorization_url, reference = await initiate_paystack_payment(user, price, plan_name, formatted_phone)
    
    if authorization_url:
        await update.message.reply_text(
            f"📱 **Payment Request Sent!**\n\n"
            f"💵 Amount: **KSh {price}**\n"
            f"📞 Phone: **{formatted_phone}**\n\n"
            f"🔗 [Click here to complete payment]({authorization_url})\n\n"
            f"Or check your phone for MPesa prompt.\n"
            f"Access granted automatically after payment.",
            parse_mode='Markdown',
            disable_web_page_preview=True
        )
    else:
        await update.message.reply_text("❌ Payment system error. Please try again.")
    
    context.user_data['awaiting_phone'] = False

# ==================== ACCESS GRANTING ====================
async def grant_access(user_id, method, reference, plan_name):
    bot = Bot(BOT_TOKEN)
    
    hours = SUBSCRIPTION_PLANS[plan_name][0]
    access_ends = datetime.now() + timedelta(hours=hours)
    
    conn = sqlite3.connect('pouchon.db')
    cursor = conn.cursor()
    
    # Update payment status
    cursor.execute(
        'UPDATE payments SET status="paid", completed_at=?, access_ends_at=? WHERE paystack_reference=?',
        (datetime.now().isoformat(), access_ends.isoformat(), reference)
    )
    
    try:
        # Create invite link
        invite_link = await bot.create_chat_invite_link(
            PRIVATE_GROUP_ID,
            member_limit=1,
            expire_date=datetime.now() + timedelta(hours=24)
        )
        
        # Store active subscription
        cursor.execute('''
            INSERT OR REPLACE INTO active_subscriptions(user_id, user_name, subscription_plan, access_ends_at, invite_link)
            VALUES(?,?,?,?,?)
        ''', (user_id, "User", plan_name, access_ends.isoformat(), invite_link.invite_link))
        
        conn.commit()
        
        # Send success message
        if plan_name == "international":
            duration = "12 hours"
        else:
            days = hours // 24
            duration = f"{days} day{'s' if days > 1 else ''}"
        
        await bot.send_message(
            chat_id=user_id,
            text=f"🎉 **Payment Confirmed!**\n\n"
                 f"✅ Access granted successfully\n"
                 f"⏰ Duration: **{duration}**\n"
                 f"💳 Method: **{method}**\n\n"
                 f"🔗 **Your private access link:**\n{invite_link.invite_link}",
            parse_mode='Markdown'
        )
        
    except Exception as e:
        print(f"Error granting access: {e}")
        await bot.send_message(
            chat_id=user_id,
            text=f"🎉 **Payment Confirmed!**\n\nContact admin for access link."
        )
    finally:
        conn.close()

# ==================== PAYSTACK WEBHOOK ====================
app = FastAPI()

@app.post("/paystack_webhook")
async def paystack_webhook(request: Request):
    """Real PayStack webhook for instant payment confirmation"""
    try:
        data = await request.json()
        
        if data.get('event') == 'charge.success':
            reference = data['data']['reference']
            user_id = data['data']['metadata']['user_id']
            plan_name = data['data']['metadata']['plan']
            
            # Grant access immediately
            await grant_access(user_id, "PayStack", reference, plan_name)
            return {"status": "success"}
        
        return {"status": "ignored"}
        
    except Exception as e:
        print(f"Webhook error: {e}")
        return {"status": "error"}

@app.get("/")
async def root():
    return {"status": "PayStack Bot Running"}

def run_webhook():
    uvicorn.run(app, host="0.0.0.0", port=8000)

# ==================== MAIN ====================
def main():
    # Start webhook
    webhook_thread = threading.Thread(target=run_webhook, daemon=True)
    webhook_thread.start()
    
    # Create bot
    app_bot = Application.builder().token(BOT_TOKEN).build()
    
    # Add handlers
    app_bot.add_handler(CommandHandler("start", start_command))
    app_bot.add_handler(CallbackQueryHandler(handle_plan_selection, pattern="^plan_"))
    app_bot.add_handler(MessageHandler(filters.TEXT & filters.ChatType.PRIVATE, handle_phone))
    app_bot.add_handler(CommandHandler("confirm", lambda u,c: u.message.reply_text("Use PayStack webhook now")))
    
    print("🚀 PayStack Bot Started - REAL PAYMENTS!")
    print("📱 MPesa for Kenyans | 🌍 Cards for International")
    print("🌐 Webhook: http://0.0.0.0:8000/paystack_webhook")
    
app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8000)))
if __name__ == "__main__":
    main()
