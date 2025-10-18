#!/bin/bash

echo "🔗 SETTING UP TELEGRAM WEBHOOK"
echo "==============================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

BOT_TOKEN="8406972008:AAHTmNluGB3UD6Xmj2HVVB5YAguuj2mWk-k"
DOMAIN="web-production-6fffd.up.railway.app"
WEBHOOK_URL="https://$DOMAIN/telegram_webhook"

echo -e "🤖 Bot Token: ${BOT_TOKEN:0:10}..."
echo -e "🌐 Webhook URL: $WEBHOOK_URL"
echo -e ""

echo -e "${YELLOW}1. Setting Telegram webhook...${NC}"
response=$(curl -s -X POST \
  "https://api.telegram.org/bot$BOT_TOKEN/setWebhook?url=$WEBHOOK_URL")

echo -e "Response:"
echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

echo -e "\n${YELLOW}2. Checking webhook info...${NC}"
response=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo")
echo -e "Webhook info:"
echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

echo -e "\n${YELLOW}3. Testing bot connection...${NC}"
response=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getMe")
echo -e "Bot info:"
echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

echo -e "\n${GREEN}✅ WEBHOOK SETUP COMPLETE${NC}"
echo "========================"

echo -e "\n${YELLOW}📋 NEXT STEPS:${NC}"
echo "1. Wait for the fix_telegram_bot.sh to deploy"
echo "2. Send a message to your bot on Telegram"
echo "3. Check logs: railway logs"
echo "4. If still not working, the bot code needs proper Telegram handlers"
