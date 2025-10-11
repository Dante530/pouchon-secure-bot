#!/bin/bash
set -e

echo "🧠 POUCHON AUTO-HEALER — One Command Deploy"
echo "==========================================="

report() {
  STATUS=$1
  MSG=$2
  echo "[$STATUS] $MSG"
}

# === ENVIRONMENT CHECK ===
echo ""
echo "🌍 Checking environment..."

for cmd in node npm git railway; do
  if ! command -v $cmd &>/dev/null; then
    report "FIX" "Installing $cmd..."
    case $cmd in
      node) pkg install nodejs -y ;;
      npm) pkg install nodejs -y ;;
      git) pkg install git -y ;;
      railway)
        npm install -g @railway/cli
        ;;
    esac
  else
    report "OK" "$cmd installed ($( $cmd --version | head -n 1))"
  fi
done

# === GIT SETUP ===
echo ""
echo "🔧 Checking Git..."
if [ ! -d ".git" ]; then
  git init
  git branch -M main
  report "OK" "Initialized Git repository"
else
  report "OK" "Git already initialized"
fi

if ! git remote | grep -q origin; then
  echo ""
  echo "🔗 Adding GitHub remote..."
  read -p "Enter your GitHub repo URL (e.g. https://github.com/username/repo.git): " REPO
  git remote add origin "$REPO"
  report "OK" "Remote added: $REPO"
else
  report "OK" "Git remote already set"
fi

# === FILE CHECKS ===
echo ""
echo "📁 Checking project files..."

if [ -f "package.json" ]; then
  MAIN_FILE=$(ls *.js | grep -E 'index|main|bot' | head -n 1)
  [ -n "$MAIN_FILE" ] && report "OK" "Found main JS file: $MAIN_FILE" || { report "FAIL" "No main .js file"; exit 1; }
else
  report "FAIL" "No package.json found — not a Node project?"
  exit 1
fi

if [ ! -f "Procfile" ]; then
  echo "web: node index.js" > Procfile
  report "FIX" "Procfile created"
else
  report "OK" "Procfile exists"
fi

if [ ! -f ".env" ]; then
  echo "PORT=8000" > .env
  report "FIX" "Created .env with default PORT=8000"
fi

# === TELEGRAM TOKEN CHECK ===
if ! grep -q "TOKEN=" .env; then
  read -p "Enter your Telegram bot token: " TOKEN
  echo "TOKEN=$TOKEN" >> .env
  report "FIX" "Added Telegram token to .env"
fi

# === GIT PUSH ===
echo ""
echo "🚀 Preparing for Git push..."
git add .
git commit -m "Auto-Healer deployment setup" || true
git push -u origin main || true
report "OK" "Code pushed to GitHub"

# === RAILWAY DEPLOY ===
echo ""
echo "🌐 Deploying to Railway..."
if ! railway whoami &>/dev/null; then
  report "INFO" "You need to log in to Railway once"
  railway login
fi

railway init --service pouchon-bot --yes || true
railway up

report "✅ DONE" "Deployment complete! Your bot is now live 🚀"
