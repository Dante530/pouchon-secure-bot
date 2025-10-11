#!/bin/bash
echo "🚀 Starting full deploy of pouchon-secure-bot ..."

# Step 1: Create or update requirements.txt
echo "✅ Writing updated requirements.txt..."
cat > requirements.txt <<EOF
aiogram==3.4.1
fastapi==0.111.0
uvicorn==0.30.1
aiohttp==3.9.5
aiosqlite==0.20.0
requests==2.32.3
python-dotenv==1.0.1
EOF

# Step 2: Create Dockerfile for Railway
echo "✅ Writing Dockerfile..."
cat > Dockerfile <<EOF
FROM python:3.11-slim

WORKDIR /app
COPY . /app

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8000
CMD ["python3", "pouchon_bot.py"]
EOF

# Step 3: Git commit and push
echo "✅ Pushing latest code to GitHub..."
git init
git add .
git commit -m "🚀 Final auto-deploy version with CLI fix"
git branch -M main
git remote remove origin 2>/dev/null
git remote add origin https://github.com/Dante530/pouchon-secure-bot.git
git push -u origin main --force

# Step 4: Detect correct Railway CLI command
echo "🔍 Detecting Railway CLI syntax..."
if railway env --help >/dev/null 2>&1; then
  SET_CMD="railway env set"
else
  SET_CMD="railway variables set"
fi

echo "✅ Using command: $SET_CMD"

# Step 5: Set environment variables
echo "🌍 Setting Railway environment variables..."
$SET_CMD BOT_TOKEN="8406972008:AAHTmNluGB3UD6Xmj2HVVB5YAguuj2mWk-k"
$SET_CMD PAYSTACK_SECRET_KEY="sk_live_8a8960b2063c3af5138381fc7a76d79d381f6ae4"
$SET_CMD PAYSTACK_PUBLIC_KEY="pk_live_8814078e3e588386ebf5ed33119caac71e916a58"
$SET_CMD ADMIN_IDS="8273608494"
$SET_CMD PRIVATE_GROUP_ID="-1008273608494"
$SET_CMD WEBHOOK_URL="https://pouchon-secure-bot-production.up.railway.app/"

# Step 6: Deploy to Railway
echo "🚀 Deploying to Railway..."
railway up

# Step 7: Set Telegram webhook
echo "🌐 Setting Telegram webhook..."
curl -F "url=https://pouchon-secure-bot-production.up.railway.app/telegram_webhook" \
https://api.telegram.org/bot8406972008:AAHTmNluGB3UD6Xmj2HVVB5YAguuj2mWk-k/setWebhook

echo "✅ Deployment complete! Bot should now be running on Railway!"o

