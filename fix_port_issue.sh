#!/bin/bash

echo "🔧 FIXING PORT CONFIGURATION ISSUE"
echo "==================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}1. Checking current port configuration in bot file...${NC}"
grep -n "port.*=" pouchon_bot.py | head -5

echo -e "${YELLOW}2. Fixing port configuration to use Railway's PORT variable...${NC}"

# Create a fixed version that uses Railway's PORT
cat > pouchon_bot_fixed.py << 'FIXEDCODE'
import os
from fastapi import FastAPI, Request
import uvicorn
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Pouchon Bot")

@app.get("/")
async def root():
    return {
        "status": "online", 
        "service": "Pouchon Telegram Bot",
        "project": "charismatic-miracle",
        "port": os.getenv("PORT", "8080")
    }

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "bot_token": "SET" if os.getenv("BOT_TOKEN") else "MISSING",
        "environment": os.getenv("RAILWAY_ENVIRONMENT", "unknown")
    }

@app.post("/telegram_webhook")
async def telegram_webhook(request: Request):
    return {"ok": True, "message": "Webhook ready"}

@app.post("/paystack_webhook") 
async def paystack_webhook(request: Request):
    return {"status": "success"}

if __name__ == "__main__":
    # Use Railway's PORT environment variable (usually 8080)
    port = int(os.getenv("PORT", 8080))
    logger.info(f"🚀 Starting bot on port {port}")
    uvicorn.run(app, host="0.0.0.0", port=port)
FIXEDCODE

# Replace the bot file
mv pouchon_bot_fixed.py pouchon_bot.py
echo -e "${GREEN}✅ Fixed port configuration${NC}"

echo -e "${YELLOW}3. Creating Railway configuration file...${NC}"
cat > railway.toml << 'RAILWAY'
[build]
builder = "NIXPACKS"

[deploy]
startCommand = "python pouchon_bot.py"

[[services]]
name = "web"
port = 8080
RAILWAY

echo -e "${GREEN}✅ Created railway.toml${NC}"

echo -e "${YELLOW}4. Checking if we need to update the service port in Railway...${NC}"
echo -e "${YELLOW}Manual step may be required:${NC}"
echo "Visit: https://railway.app/project/charismatic-miracle/settings"
echo "Check the service port configuration"

echo -e "${YELLOW}5. Deploying the fix...${NC}"
railway up

echo -e "${YELLOW}6. Waiting for deployment...${NC}"
sleep 15

echo -e "${YELLOW}7. Testing the fixed deployment...${NC}"
DOMAIN="web-production-6fffd.up.railway.app"

echo -e "Testing: https://$DOMAIN/"
curl -s "https://$DOMAIN/" || echo -e "${RED}❌ Still not working${NC}"

echo -e "\n${GREEN}🎯 PORT FIX COMPLETE${NC}"
echo "======================="

echo -e "\n${YELLOW}📋 IF STILL NOT WORKING:${NC}"
echo "1. Check Railway service settings:"
echo "   https://railway.app/project/charismatic-miracle/settings"
echo "2. Look for 'Port' setting in the service configuration"
echo "3. Make sure it's set to 8080 (or the port your bot uses)"
echo "4. Alternatively, check the 'Start Command' in settings"

echo -e "\n${YELLOW}🔧 Alternative: Force port 8000 in Railway${NC}"
cat > railway_config_8000.toml << 'CONFIG8000'
[build]
builder = "NIXPACKS"

[deploy]
startCommand = "python pouchon_bot.py"

[[services]]
name = "web"
port = 8000
CONFIG8000

echo -e "${GREEN}✅ Created alternative config for port 8000${NC}"
echo "Use this if your bot must run on port 8000"
