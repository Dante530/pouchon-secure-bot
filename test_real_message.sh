#!/bin/bash

echo "🤖 TESTING REAL TELEGRAM MESSAGE FLOW"
echo "======================================"

DOMAIN="web-production-6fffd.up.railway.app"
WEBHOOK_URL="https://$DOMAIN/telegram_webhook"

# Create a more realistic Telegram message payload
cat > real_message.json << 'MESSAGE'
{
  "update_id": 100000001,
  "message": {
    "message_id": 123,
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
    "text": "/start",
    "entities": [
      {
        "offset": 0,
        "length": 6,
        "type": "bot_command"
      }
    ]
  }
}
MESSAGE

echo -e "📤 Sending realistic /start command to webhook..."
echo -e "   URL: $WEBHOOK_URL"
echo -e ""

# Send the message
response=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d @real_message.json \
  -w "HTTP Status: %{http_code}\n" \
  "$WEBHOOK_URL")

echo -e "📥 Response:"
echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

echo -e "\n🔍 Checking logs for processing..."
railway logs -n 10

echo -e "\n💡 Send a real message to @Pouchonlive_bot on Telegram now!"
