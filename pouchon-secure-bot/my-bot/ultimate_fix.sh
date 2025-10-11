#!/bin/bash
set -e

echo "🚀 Starting Ultimate Railway Auto-Fix Script..."

# === Detect project type ===
if [ -f "package.json" ]; then
  APP_TYPE="node"
elif [ -f "requirements.txt" ] || ls *.py &>/dev/null; then
  APP_TYPE="python"
else
  echo "❌ Could not detect Node.js or Python project."
  exit 1
fi

# === Move contents up if nested ===
if [ -d "my-bot" ]; then
  echo "📦 Moving files from 'my-bot/' to project root..."
  mv my-bot/* . 2>/dev/null || true
  rm -rf my-bot
fi

# === Fix Procfile ===
if [ "$APP_TYPE" = "node" ]; then
  echo "📝 Creating Procfile for Node.js..."
  echo "web: npm start" > Procfile
else
  echo "📝 Creating Procfile for Python..."
  echo "web: python secure_bot.py" > Procfile
fi

# === Fix start script or entry ===
if [ "$APP_TYPE" = "node" ]; then
  echo "🛠️ Ensuring package.json has a valid start script..."
  if command -v jq &>/dev/null; then
    jq '.scripts.start = "node index.js"' package.json > package.tmp.json && mv package.tmp.json package.json
  else
    sed -i 's/"scripts": {/"scripts": {\n    "start": "node index.js",/' package.json
  fi
elif [ "$APP_TYPE" = "python" ]; then
  echo "🧠 Checking for secure_bot.py..."
  if ! [ -f "secure_bot.py" ]; then
    echo "❌ secure_bot.py not found — please ensure your main bot file is named secure_bot.py"
    exit 1
  fi
fi

# === Install dependencies ===
echo "📦 Installing dependencies..."
if [ "$APP_TYPE" = "node" ]; then
  npm install
else
  pip install -r requirements.txt || echo "⚠️ Warning: Could not install Python dependencies."
fi

# === Port configuration ===
echo "🌐 Setting PORT environment variable..."
export PORT=8000
echo "PORT=8000" > .env

# === Git setup ===
echo "📤 Committing and pushing changes..."
git add .
git commit -m "Ultimate Railway auto-fix deployment setup" || echo "✅ Nothing to commit."
git push

# === Auto trigger redeploy (optional) ===
if [ -f ".railway/project.json" ]; then
  echo "🚀 Attempting Railway CLI redeploy..."
  if command -v railway &>/dev/null; then
    railway up --service pouchon-secure-bot || echo "⚠️ Railway redeploy failed, do it manually."
  else
    echo "⚠️ Railway CLI not found. Please install it if you want auto redeploy."
  fi
fi

echo "✅ All done!"
echo "👉 Go to your Railway dashboard and open the latest deployment logs."
echo "If you see 'Server running on port 8000', you’re golden. 🌟"
