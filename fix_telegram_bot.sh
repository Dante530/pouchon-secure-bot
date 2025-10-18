#!/bin/bash

echo "🔧 FIXING TELEGRAM BOT FUNCTIONALITY"
echo "===================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}1. Creating a fully functional Telegram bot...${NC}"

cat > pouchon_bot_fixed.py << 'BOTCODE'
import os
import logging
from fastapi import FastAPI, Request
from telegram import Update, Bot
from telegram.ext import Application, CommandHandler, ContextTypes
import uvicorn
import asyncio

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(title="Pouchon Telegram Bot")

# Global bot instance
bot_app = None

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
        
        # Add command handlers
        bot_app.add_handler(CommandHandler("start", start_command))
        bot_app.add_handler(CommandHandler("help", help_command))
        bot_app.add_handler(CommandHandler("subscribe", subscribe_command))
        
        # Initialize bot (but don't start polling - we use webhooks)
        await bot_app.initialize()
        
        logger.info("✅ Telegram bot initialized successfully")
        
        # Test bot token by getting bot info
        bot_info = await bot_app.bot.get_me()
        logger.info(f"✅ Bot connected: @{bot_info.username} ({bot_info.first_name})")
        
    except Exception as e:
        logger.error(f"❌ Failed to initialize Telegram bot: {e}")

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    user = update.effective_user
    await update.message.reply_text(
        f"👋 Hello {user.first_name}!\n\n"
        "Welcome to Pouchon Bot! 🤖\n\n"
        "Available commands:\n"
        "/start - Show this welcome message\n"
        "/help - Get help\n"
        "/subscribe - Choose a subscription plan"
    )

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /help command"""
    await update.message.reply_text(
        "📋 Pouchon Bot Help:\n\n"
        "I can help you manage subscriptions and process payments.\n\n"
        "Commands:\n"
        "/start - Welcome message\n"
        "/help - This help message\n"
        "/subscribe - Choose subscription plan\n\n"
        "Need support? Contact admin."
    )

async def subscribe_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /subscribe command"""
    await update.message.reply_text(
        "💰 Subscription Plans:\n\n"
        "• Daily - $20\n"
        "• Weekly - $100\n"
        "• Monthly - $400\n\n"
        "Use /subscribe to choose a plan when ready."
    )

@app.post("/telegram_webhook")
async def telegram_webhook(request: Request):
    """Handle Telegram webhook updates"""
    try:
        # Parse the update
        data = await request.json()
        update = Update.de_json(data, bot_app.bot if bot_app else None)
        
        logger.info(f"📱 Received update from user: {update.effective_user.id if update.effective_user else 'unknown'}")
        
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

@app.get("/")
async def root():
    return {
        "status": "online",
        "service": "Pouchon Telegram Bot",
        "webhook_ready": bot_app is not None
    }

@app.get("/health")
async def health():
    bot_ready = bot_app is not None
    bot_token_set = bool(os.getenv("BOT_TOKEN"))
    
    return {
        "status": "healthy" if bot_ready else "degraded",
        "bot_initialized": bot_ready,
        "bot_token_configured": bot_token_set,
        "environment": os.getenv("RAILWAY_ENVIRONMENT", "production")
    }

@app.get("/botinfo")
async def bot_info():
    """Get bot information"""
    if not bot_app or not bot_app.bot:
        return {"error": "Bot not initialized"}
    
    try:
        bot = await bot_app.bot.get_me()
        return {
            "username": f"@{bot.username}",
            "name": bot.first_name,
            "id": bot.id
        }
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    logger.info(f"🚀 Starting Pouchon Bot on port {port}")
    uvicorn.run(app, host="0.0.0.0", port=port)
BOTCODE

echo -e "${GREEN}✅ Created fully functional Telegram bot${NC}"

echo -e "${YELLOW}2. Replacing the bot file...${NC}"
mv pouchon_bot_fixed.py pouchon_bot.py

echo -e "${YELLOW}3. Updating requirements.txt for Telegram...${NC}"
cat > requirements.txt << 'REQUIREMENTS'
fastapi==0.104.1
uvicorn==0.24.0
python-telegram-bot==20.7
python-dotenv==1.0.0
httpx==0.25.2
aiosqlite==0.19.0
REQUIREMENTS

echo -e "${GREEN}✅ Updated requirements${NC}"

echo -e "${YELLOW}4. Deploying the fixed bot...${NC}"
railway up

echo -e "${YELLOW}5. Waiting for deployment...${NC}"
sleep 25

echo -e "${YELLOW}6. Testing the bot functionality...${NC}"
./simulate_telegram_message.sh

echo -e "\n${GREEN}✅ TELEGRAM BOT FIX DEPLOYED${NC}"
echo "==============================="

echo -e "\n${YELLOW}📋 NEXT STEPS:${NC}"
echo "1. Wait for deployment to complete"
echo "2. Run the simulation again: ./simulate_telegram_message.sh"
echo "3. Check bot info: curl https://web-production-6fffd.up.railway.app/botinfo"
echo "4. Set Telegram webhook (see instructions below)"

echo -e "\n${YELLOW}🔧 SET TELEGRAM WEBHOOK MANUALLY:${NC}"
echo "Replace YOUR_DOMAIN with your Railway domain:"
echo "curl -X POST https://api.telegram.org/botYOUR_BOT_TOKEN/setWebhook?url=https://web-production-6fffd.up.railway.app/telegram_webhook"
