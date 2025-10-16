#!/bin/bash
echo "🤖 BOT DEPLOYMENT STATUS"
echo "========================"
echo "📦 Variables Status:"
railway variables list

echo ""
echo "📊 Recent Logs:"
railway logs -n 5

echo ""
echo "🌐 Bot URL: https://pouchon-secure-bot.up.railway.app"
echo "💡 Test your bot by sending a message on Telegram!"
