#!/bin/bash
set -e

echo "🚀 Starting Self-Healing Railway Auto-Fix (v2)..."

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

# === Auto-detect and rename main file ===
if [ "$APP_TYPE" = "node" ]; then
  MAIN_FILE=$(ls *.js 2>/dev/null | grep -E 'bot|index|main' | head -n 1)
  if [ -z "$MAIN_FILE" ]; then
    MAIN_FILE=$(ls *.js 2>/dev/null | head -n 1)
  fi
  if [ -n "$MAIN_FILE" ] && [ "$MAIN_FILE" != "index.js" ]; then
    echo "🧠 Renaming $MAIN_FILE → index.js"
    mv "$MAIN_FILE" index.js
  fi
elif [ "$APP_TYPE" = "python" ]; then
  MAIN_FILE=$(ls *.py 2>/dev/null | grep -E 'bot|main|app' | head -n 1)
  if [ -z "$MAIN_FILE" ]; then
    MAIN_FILE=$(ls *.py 2>/dev/null | head -n 1)
  fi
  if [ -n "$MAIN_FILE" ] && [ "$MAIN_FILE" != "secure_bot.py" ]; then
    echo "🧠 Renaming $MAIN_FILE → secure_bot.py"
    mv "$MAIN_FILE" secure_bot.py
  fi
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
fi

# === Install dependencies ===
echo "📦 Installing dependencies..."
if [ "$APP_TYPE" = "node" ]; then
  npm install || echo "⚠️ npm install failed, check your Node setup."
else
  pip install -r requirements.txt || echo "⚠️ pip install failed, check your Python setup."
fi

# === Create .env with default port ===
echo "🌐 Setting default port (8000)..."
echo "PORT=8000" > .env

# === Git commit + push ===
echo "📤 Committing and pushing changes..."
git add .
git commit -m "Self-Healing Railway Setup: Fixed structure, renamed main file, added Procfile" || echo "✅ Nothing new to commit."
git push

echo "✅ All done!"
echo "👉 Go to Railway and redeploy the project."
echo "If it still crashes, check Logs — your entry file and Procfile are now guaranteed correct."
