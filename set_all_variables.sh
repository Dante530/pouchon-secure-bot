#!/bin/bash

echo "🔐 Setting ALL Environment Variables on Railway..."
echo "=================================================="

# Set all variables
railway variables set BOT_TOKEN="8406972008:AAHTmNluGB3UD6Xmj2HVVB5YAguuj2mWk-k" && echo "✅ BOT_TOKEN set"
railway variables set PAYSTACK_SECRET_KEY="sk_live_8a8960b2063c3af5138381fc7a76d79d381f6ae4" && echo "✅ PAYSTACK_SECRET_KEY set"
railway variables set PAYSTACK_PUBLIC_KEY="pk_live_8814078e3e588386ebf5ed33119caac71e916a58" && echo "✅ PAYSTACK_PUBLIC_KEY set"
railway variables set ADMIN_IDS="8273608494" && echo "✅ ADMIN_IDS set"
railway variables set PRIVATE_GROUP_ID="-1003139716802" && echo "✅ PRIVATE_GROUP_ID set"
railway variables set WEBHOOK_URL="https://pouchon-secure-bot-production.up.railway.app/" && echo "✅ WEBHOOK_URL set"

echo ""
echo "🎉 All variables set! Your bot will restart with new configuration."
echo "📋 Check variables: railway variables list"
echo "📊 Check logs: railway logs -n 10"
