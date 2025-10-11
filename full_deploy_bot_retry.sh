#!/bin/bash
# full_deploy_bot_retry.sh
# Automated GitHub + Railway + Telegram bot deployment
# Includes webhook retry until success

# -----------------------------
# 1️⃣ User Variables
# -----------------------------
GITHUB_USER="Dante530"
REPO_NAME="pouchon-secure-bot"
BOT_TOKEN="8406972008:AAHTmNluGB3UD6Xmj2HVVB5YAguuj2mWk-k"
PAYSTACK_SECRET_KEY="sk_live_8a8960b2063c3af5138381fc7a76d79d381f6ae4"
PAYSTACK_PUBLIC_KEY="pk_live_8814078e3e588386ebf5ed33119caac71e916a58"
ADMIN_IDS="8273608494"
PRIVATE_GROUP_ID="-1008273608494"
WEBHOOK_URL="https://pouchon-secure-bot-production.up.railway.app/"
BOT_FILE="pouchon_bot.py"

# -----------------------------
# 2️⃣ Create requirements.txt
# -----------------------------
cat > requirements.txt <<EOL
python-telegram-bot[asyncio]==20.3
fastapi==0.114.0
httpx==1.9.0
uvicorn==0.23.1
aiosqlite==0.21.0
EOL
echo "✅ requirements.txt created"

# -----------------------------
# 3️⃣ Git commit & push
# -----------------------------
git init
git add .
git commit -m "Production-ready bot deployment"

# Add remote if it doesn't exist
if git remote | grep origin; then
    git remote set-url origin https://github.com/$GITHUB_USER/$REPO_NAME.git
else
    git remote add origin https://github.com/$GITHUB_USER/$REPO_NAME.git
fi

git branch -M main
git push -u origin main
echo "✅ Code pushed to GitHub"

# -----------------------------
# 4️⃣ Set Railway environment variables
# -----------------------------
echo "⚡ Setting Railway environment variables..."
railway variables set BOT_TOKEN="$BOT_TOKEN"
railway variables set PAYSTACK_SECRET_KEY="$PAYSTACK_SECRET_KEY"
railway variables set PAYSTACK_PUBLIC_KEY="$PAYSTACK_PUBLIC_KEY"
railway variables set ADMIN_IDS="$ADMIN_IDS"
railway variables set PRIVATE_GROUP_ID="$PRIVATE_GROUP_ID"
railway variables set WEBHOOK_URL="$WEBHOOK_URL"
echo "✅ Railway environment variables set"

# -----------------------------
# 5️⃣ Deploy to Railway
# -----------------------------
echo "⚡ Deploying to Railway..."
railway up

# -----------------------------
# 6️⃣ Wait a few seconds for deploy to settle
# -----------------------------
echo "⏳ Waiting 15 seconds for deployment to settle..."
sleep 15

# -----------------------------
# 7️⃣ Set Telegram Webhook (with retries)
# -----------------------------
echo "⚡ Setting Telegram webhook..."
MAX_RETRIES=5
RETRY_DELAY=5
COUNT=0
while [ $COUNT -lt $MAX_RETRIES ]; do
    RESPONSE=$(curl -s -F "url=${WEBHOOK_URL}telegram_webhook" \
        https://api.telegram.org/bot$BOT_TOKEN/setWebhook)
    if [[ $RESPONSE == *"true"* ]]; then
        echo "✅ Webhook set successfully: $RESPONSE"
        break
    else
        echo "⚠ Webhook failed, retrying in $RETRY_DELAY seconds..."
        COUNT=$((COUNT+1))
        sleep $RETRY_DELAY
    fi
done
if [ $COUNT -eq $MAX_RETRIES ]; then
    echo "❌ Webhook could not be set. Check your URL and bot token."
fi

# -----------------------------
# 8️⃣ Check Railway logs
# -----------------------------
echo "⚡ Fetching Railway logs..."
railway logs

echo "🎉 Deployment complete! Bot should now be live and receiving updates."
