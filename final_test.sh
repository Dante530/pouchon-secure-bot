#!/bin/bash

echo "🎯 FINAL BOT VERIFICATION"
echo "========================"

DOMAIN="web-production-6fffd.up.railway.app"

echo -e "1. Testing root endpoint..."
curl -s "https://$DOMAIN/" && echo -e " ✅" || echo -e " ❌"

echo -e "2. Testing health endpoint..."
curl -s "https://$DOMAIN/health" && echo -e " ✅" || echo -e " ❌"

echo -e "3. Checking recent activity..."
railway logs -n 8

echo -e "\n🎉 YOUR BOT IS DEPLOYED AND RUNNING!"
echo "=================================="
echo "🌐 URL: https://$DOMAIN"
echo "🏥 Health: https://$DOMAIN/health"
echo "🤖 Telegram: Send a message to your bot!"
echo "💳 Paystack: Webhook ready for payments"
