#!/bin/bash

echo "🔍 Checking Bot Status..."
echo "========================="

# Check recent logs
echo "📊 Recent Logs:"
railway logs -n 10

echo ""
echo "🌐 Testing Bot URL:"
curl -s https://pouchon-secure-bot.up.railway.app || echo "Bot is restarting..."

echo ""
echo "💡 If you see application logs above, your bot is running!"
echo "🤖 Test your bot by sending a message on Telegram"
