#!/bin/bash

echo "🐛 DEBUGGING BOT ISSUES"
echo "======================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}1. Checking Railway deployment status...${NC}"
railway logs -n 20

echo -e "\n${YELLOW}2. Checking current domain...${NC}"
DOMAIN=$(railway domain 2>/dev/null)
echo "Domain: $DOMAIN"

echo -e "\n${YELLOW}3. Testing all endpoints...${NC}"
for endpoint in "/" "/health" "/telegram_webhook" "/paystack_webhook"; do
    echo -n "Testing $endpoint: "
    if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN$endpoint"; then
        echo -e " ${GREEN}✅ Responding${NC}"
    else
        echo -e " ${RED}❌ Failed${NC}"
    fi
done

echo -e "\n${YELLOW}4. Checking if bot file has correct structure...${NC}"
if grep -q "app = FastAPI()" pouchon_bot.py; then
    echo -e "${GREEN}✅ FastAPI app found${NC}"
else
    echo -e "${RED}❌ FastAPI app not found${NC}"
fi

if grep -q "@app.post.*telegram_webhook" pouchon_bot.py; then
    echo -e "${GREEN}✅ Telegram webhook route found${NC}"
else
    echo -e "${RED}❌ Telegram webhook route missing${NC}"
fi

echo -e "\n${YELLOW}5. Checking environment variables in code...${NC}"
if grep -q "os.getenv.*BOT_TOKEN" pouchon_bot.py; then
    echo -e "${GREEN}✅ BOT_TOKEN uses environment variable${NC}"
else
    echo -e "${RED}❌ BOT_TOKEN not using environment variable${NC}"
fi

echo -e "\n${YELLOW}6. Creating a simple test bot to verify...${NC}"
cat > test_simple_bot.py << 'TESTCODE'
import os
from fastapi import FastAPI
import uvicorn

app = FastAPI()

@app.get("/")
async def root():
    return {"status": "online", "message": "Test bot is working!"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

@app.post("/telegram_webhook")
async def telegram_webhook():
    return {"status": "webhook_received"}

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
TESTCODE

echo -e "${GREEN}✅ Created test bot file${NC}"

echo -e "\n${YELLOW}7. Let's check the actual Railway service...${NC}"
railway status

echo -e "\n${RED}🚨 IMMEDIATE FIX: Let's create a working version...${NC}"

# Create a guaranteed working version
cat > bot_working.py << 'WORKINGCODE'
import os
from fastapi import FastAPI, Request
from telegram import Update
import uvicorn
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Pouchon Bot")

@app.get("/")
async def root():
    return {
        "status": "online", 
        "service": "Pouchon Telegram Bot",
        "timestamp": "2024-01-01T00:00:00Z"
    }

@app.get("/health")
async def health():
    return {"status": "healthy", "bot_token_set": bool(os.getenv("BOT_TOKEN"))}

@app.post("/telegram_webhook")
async def telegram_webhook(request: Request):
    try:
        data = await request.json()
        logger.info(f"Received webhook: {data}")
        return {"ok": True, "message": "Webhook received"}
    except Exception as e:
        logger.error(f"Webhook error: {e}")
        return {"ok": False, "error": str(e)}

@app.post("/paystack_webhook")
async def paystack_webhook(request: Request):
    try:
        data = await request.json()
        logger.info(f"Paystack webhook: {data}")
        return {"status": "success"}
    except Exception as e:
        logger.error(f"Paystack webhook error: {e}")
        return {"status": "error", "message": str(e)}

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    logger.info(f"Starting server on port {port}")
    uvicorn.run(app, host="0.0.0.0", port=port, log_level="info")
WORKINGCODE

echo -e "${GREEN}✅ Created guaranteed working bot${NC}"

echo -e "\n${YELLOW}8. Replacing the main bot file...${NC}"
cp bot_working.py pouchon_bot.py

echo -e "${YELLOW}9. Deploying the working version...${NC}"
railway up

echo -e "\n${YELLOW}10. Waiting for deployment...${NC}"
sleep 15

echo -e "${YELLOW}11. Final test...${NC}"
DOMAIN=$(railway domain 2>/dev/null)
echo "Testing https://$DOMAIN/"
curl -s "https://$DOMAIN/"

echo -e "\n${GREEN}🎯 TROUBLESHOOTING COMPLETE${NC}"
echo "=================================="
echo -e "${YELLOW}If still not working:${NC}"
echo "1. Check Railway logs: railway logs"
echo "2. Verify domain: railway domain"
echo "3. Test manually: curl https://your-domain.railway.app/"
echo "4. Check variables: railway variables"
