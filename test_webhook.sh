#!/bin/bash

echo "🔍 TESTING WEBHOOK ENDPOINT"
echo "==========================="

DOMAIN="web-production-6fffd.up.railway.app"

echo -e "1. Testing GET request to webhook (should show method not allowed):"
curl -s "https://$DOMAIN/telegram_webhook" | head -c 100
echo -e "\n"

echo -e "2. Testing POST request to webhook:"
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"update_id": 1, "message": {"message_id": 1, "from": {"id": 123, "first_name": "Test"}, "chat": {"id": 123}, "text": "/start"}}' \
  "https://$DOMAIN/telegram_webhook"

echo -e "\n\n3. Checking recent logs:"
railway logs -n 6
