#!/bin/bash

echo "🤖 SIMULATING TELEGRAM MESSAGE"
echo "=============================="

DOMAIN="web-production-6fffd.up.railway.app"
WEBHOOK_URL="https://$DOMAIN/telegram_webhook"

# Create a simulated Telegram message payload
cat > simulated_message.json << 'MESSAGE'
{
  "update_id": 100000000,
  "message": {
    "message_id": 1,
    "from": {
      "id": 8273608494,
      "is_bot": false,
      "first_name": "Test",
      "username": "testuser"
    },
    "chat": {
      "id": 8273608494,
      "first_name": "Test",
      "username": "testuser",
      "type": "private"
    },
    "date": 1739629200,
    "text": "/start"
  }
}
MESSAGE

echo -e "📤 Sending simulated Telegram message to:"
echo -e "   $WEBHOOK_URL"
echo -e ""

# Send the simulated message
response=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d @simulated_message.json \
  "$WEBHOOK_URL")

echo -e "📥 Response from bot:"
echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

echo -e "\n🔍 Checking logs for the webhook call:"
railway logs -n 5

echo -e "\n💡 If you don't see the webhook being processed in logs, the bot isn't handling Telegram messages properly."
