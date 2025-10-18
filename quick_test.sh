#!/bin/bash

echo "🧪 QUICK BOT TEST"
echo "================="

echo -e "Testing bot status..."
DOMAIN="web-production-6fffd.up.railway.app"
curl -s "https://$DOMAIN/health" | python3 -m json.tool 2>/dev/null || curl -s "https://$DOMAIN/health"

echo -e "\nChecking logs..."
railway logs -n 8

echo -e "\n🤖 Test Commands:"
echo "1. /subscribe - Choose plan"
echo "2. /status - Check access"
echo "3. /help - Get help"
