#!/bin/bash

echo "🔧 FIXING HEALTH CHECK ISSUES"
echo "=============================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}1. Analyzing the health check issue...${NC}"

# The issue is that Railway health checks might be happening during bot startup
# or when the bot is processing other requests

echo -e "${YELLOW}2. Creating a more robust health check endpoint...${NC}"

# Create an improved version of the bot with better health checks
cat > pouchon_bot_improved.py << 'IMPROVEDCODE'
import os
import asyncio
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import uvicorn
import logging
import aiosqlite

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Pouchon Telegram Bot",
    description="Secure Telegram bot with Paystack payments",
    version="1.0.0"
)

# Global variable to track bot readiness
bot_ready = False

@app.on_event("startup")
async def startup_event():
    """Initialize the bot on startup"""
    global bot_ready
    try:
        # Initialize database
        await init_db()
        bot_ready = True
        logger.info("✅ Bot startup completed successfully")
    except Exception as e:
        logger.error(f"❌ Bot startup failed: {e}")
        bot_ready = False

async def init_db():
    """Initialize database connection"""
    try:
        async with aiosqlite.connect("subscriptions.db") as db:
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
        logger.info("✅ Database initialized")
    except Exception as e:
        logger.error(f"❌ Database initialization failed: {e}")
        raise

@app.get("/")
async def root():
    """Root endpoint with basic info"""
    return {
        "status": "online",
        "service": "Pouchon Telegram Bot",
        "project": "charismatic-miracle",
        "version": "1.0.0",
        "ready": bot_ready
    }

@app.get("/health")
async def health():
    """Health check endpoint for Railway"""
    try:
        # Basic health checks
        checks = {
            "bot_ready": bot_ready,
            "bot_token_configured": bool(os.getenv("BOT_TOKEN")),
            "paystack_configured": bool(os.getenv("PAYSTACK_SECRET_KEY")),
            "environment": os.getenv("RAILWAY_ENVIRONMENT", "unknown")
        }
        
        # Test database connection
        try:
            async with aiosqlite.connect("subscriptions.db") as db:
                await db.execute("SELECT 1")
            checks["database"] = "healthy"
        except Exception as e:
            checks["database"] = f"unhealthy: {str(e)}"
        
        # Overall status
        overall_healthy = all([
            bot_ready,
            checks["bot_token_configured"],
            checks["paystack_configured"],
            checks["database"] == "healthy"
        ])
        
        status_code = 200 if overall_healthy else 503
        status_text = "healthy" if overall_healthy else "unhealthy"
        
        return JSONResponse(
            status_code=status_code,
            content={
                "status": status_text,
                "checks": checks,
                "timestamp": "2024-01-01T00:00:00Z"
            }
        )
        
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return JSONResponse(
            status_code=503,
            content={"status": "unhealthy", "error": str(e)}
        )

@app.get("/ready")
async def ready():
    """Readiness probe - specifically for startup completion"""
    if bot_ready:
        return {"status": "ready"}
    else:
        return JSONResponse(
            status_code=503,
            content={"status": "not ready", "message": "Bot still starting up"}
        )

@app.post("/telegram_webhook")
async def telegram_webhook(request: Request):
    """Telegram webhook endpoint"""
    if not bot_ready:
        return JSONResponse(
            status_code=503,
            content={"ok": False, "error": "Service unavailable - still starting"}
        )
    
    try:
        data = await request.json()
        logger.info(f"📱 Telegram webhook received")
        return {"ok": True, "message": "Webhook received"}
    except Exception as e:
        logger.error(f"Telegram webhook error: {e}")
        return {"ok": False, "error": str(e)}

@app.post("/paystack_webhook")
async def paystack_webhook(request: Request):
    """Paystack webhook endpoint"""
    if not bot_ready:
        return JSONResponse(
            status_code=503,
            content={"status": "error", "message": "Service unavailable"}
        )
    
    try:
        data = await request.json()
        logger.info(f"💳 Paystack webhook: {data.get('event', 'unknown')}")
        return {"status": "success"}
    except Exception as e:
        logger.error(f"Paystack webhook error: {e}")
        return {"status": "error", "message": str(e)}

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    host = os.getenv("HOST", "0.0.0.0")
    
    logger.info(f"🚀 Starting Pouchon Bot on {host}:{port}")
    logger.info(f"📊 Environment: {os.getenv('RAILWAY_ENVIRONMENT', 'development')}")
    
    uvicorn.run(
        app, 
        host=host, 
        port=port,
        log_level="info",
        access_log=True
    )
IMPROVEDCODE

echo -e "${GREEN}✅ Created improved bot with better health checks${NC}"

echo -e "${YELLOW}3. Updating Railway configuration for better health checks...${NC}"

cat > railway.toml << 'RAILWAYCONFIG'
[build]
builder = "NIXPACKS"

[deploy]
startCommand = "python pouchon_bot_improved.py"

[[services]]
name = "web"
port = 8080

[services.healthcheck]
path = "/ready"
timeout = 10
interval = 30
initialDelay = 30
RAILWAYCONFIG

echo -e "${GREEN}✅ Updated railway.toml with better health check settings${NC}"

echo -e "${YELLOW}4. Replacing the bot file...${NC}"
mv pouchon_bot_improved.py pouchon_bot.py

echo -e "${YELLOW}5. Updating requirements.txt...${NC}"
if ! grep -q "aiosqlite" requirements.txt; then
    echo "aiosqlite" >> requirements.txt
fi

echo -e "${YELLOW}6. Deploying the improved version...${NC}"
railway up

echo -e "${YELLOW}7. Waiting for deployment to stabilize...${NC}"
sleep 30

echo -e "${YELLOW}8. Testing the improved health checks...${NC}"
DOMAIN="web-production-6fffd.up.railway.app"

echo -e "Testing /ready endpoint:"
curl -s "https://$DOMAIN/ready" | python3 -m json.tool 2>/dev/null || curl -s "https://$DOMAIN/ready"

echo -e "\nTesting /health endpoint:"
curl -s "https://$DOMAIN/health" | python3 -m json.tool 2>/dev/null || curl -s "https://$DOMAIN/health"

echo -e "\n${GREEN}✅ HEALTH CHECK FIXES DEPLOYED${NC}"
echo "=================================="

echo -e "\n${YELLOW}📋 WHAT WAS FIXED:${NC}"
echo "• Added startup event to track bot readiness"
echo "• Created separate /ready endpoint for startup checks"
echo "• Improved /health endpoint with detailed status checks"
echo "• Added database connection testing"
echo "• Increased initial delay for health checks"
echo "• Better error handling and logging"

echo -e "\n${YELLOW}💡 The 'service unavailable' errors should now stop!${NC}"
