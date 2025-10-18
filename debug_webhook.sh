#!/bin/bash

echo "🐛 DEBUGGING WEBHOOK ISSUES"
echo "==========================="

echo -e "1. Checking if bot is properly initialized..."
curl -s "https://web-production-6fffd.up.railway.app/botinfo" | python3 -m json.tool 2>/dev/null || curl -s "https://web-production-6fffd.up.railway.app/botinfo"

echo -e "\n2. Checking health endpoint..."
curl -s "https://web-production-6fffd.up.railway.app/health" | python3 -m json.tool 2>/dev/null

echo -e "\n3. Checking recent logs..."
railway logs -n 10

echo -e "\n4. Testing webhook with simulation..."
./simulate_telegram_message.sh

echo -e "\n🔍 ANALYSIS:"
echo "If botinfo shows 'Bot not initialized', the Telegram bot isn't starting properly."
echo "If health shows 'bot_initialized: false', check BOT_TOKEN environment variable."
echo "If logs don't show webhook processing, the webhook isn't set or bot isn't handling updates."
