#!/bin/bash

echo "🚀 Starting Railway Deployment..."

# Check if we're in a Railway project
if railway status 2>/dev/null; then
    echo "✅ Already in a Railway project"
else
    echo "🔗 Linking to Railway project..."
    railway link
fi

echo ""
echo "📦 Deploying..."
railway up

echo ""
echo "🌐 Your bot will be available at:"
echo "   https://pouchon-secure-bot.up.railway.app"
echo ""
echo "📋 Don't forget to set environment variables:"
echo "   railway variables set BOT_TOKEN=your_token"
echo "   railway variables set PAYSTACK_SECRET_KEY=your_key"
echo "   railway variables set ADMIN_IDS=your_ids"
