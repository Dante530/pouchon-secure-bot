#!/bin/bash
set -e

echo "🧑‍⚕️ POUCHON DOCTOR — Self-Healing Setup Tool"
echo "============================================="

report() {
  STATUS=$1
  MSG=$2
  case $STATUS in
    OK) echo "[OK]   $MSG" ;;
    WARN) echo "[WARN] $MSG" ;;
    FAIL) echo "[FAIL] $MSG" ;;
  esac
}

fix_prompt() {
  read -p "⚙️  Fix this issue automatically? (y/n): " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# === ENVIRONMENT CHECK ===
echo ""
echo "🌍 Checking environment..."

command -v node >/dev/null && NODE_VER=$(node -v) && report OK "Node.js installed ($NODE_VER)" || {
  report FAIL "Node.js missing"
  echo "💡 Install with: pkg install nodejs -y"
}

command -v npm >/dev/null && NPM_VER=$(npm -v) && report OK "npm installed ($NPM_VER)" || {
  report FAIL "npm missing"
  echo "💡 Install with: pkg install nodejs-lts -y"
}

command -v git >/dev/null && GIT_VER=$(git --version) && report OK "Git installed ($GIT_VER)" || {
  report FAIL "Git missing"
  echo "💡 Install with: pkg install git -y"
}

if ! command -v railway >/dev/null; then
  report WARN "Railway CLI not found"
  if fix_prompt; then
    npm i -g @railway/cli && report OK "Railway CLI installed successfully"
  fi
else
  report OK "Railway CLI installed"
fi

# === PROJECT DETECTION ===
echo ""
echo "📁 Checking project files..."

if [ -f "package.json" ]; then
  APP_TYPE="node"
  report OK "Detected Node.js project"
else
  report FAIL "No package.json found — run npm init -y"
fi

MAIN_FILE=$(ls *.js 2>/dev/null | grep -E 'index|bot|main' | head -n 1)
if [ -n "$MAIN_FILE" ]; then
  report OK "Main file: $MAIN_FILE"
else
  report WARN "No main .js file found"
fi

if [ ! -f "Procfile" ]; then
  report WARN "Procfile missing"
  if fix_prompt; then
    echo "web: node index.js" > Procfile
    report OK "Procfile created"
  fi
else
  report OK "Procfile found"
fi

# === ENV FILE CHECK ===
if [ ! -f ".env" ]; then
  report WARN ".env file missing"
  if fix_prompt; then
    echo "PORT=8000" > .env
    echo "TOKEN=your_bot_token_here" >> .env
    report OK ".env created (update your TOKEN manually!)"
  fi
else
  report OK ".env found"
fi

# === TELEGRAM TOKEN VALIDATION ===
if grep -q "TOKEN=" .env; then
  TOKEN=$(grep TOKEN .env | cut -d '=' -f2)
  if command -v curl >/dev/null && curl -s "https://api.telegram.org/bot${TOKEN}/getMe" | grep -q "\"ok\":true"; then
    report OK "Telegram bot token valid"
  else
    report WARN "Invalid or missing bot token"
  fi
fi

# === GIT CHECK ===
echo ""
echo "🔧 Checking Git setup..."
if [ ! -d ".git" ]; then
  report WARN "Git not initialized"
  if fix_prompt; then
    git init
    git remote add origin https://github.com/Dante530/pouchon-secure-bot.git
    git branch -M main
    report OK "Git initialized and remote set"
  fi
else
  report OK "Git repository already initialized"
fi

# === PORT CHECK ===
if command -v lsof >/dev/null && lsof -i:8000 &>/dev/null; then
  report WARN "Port 8000 is busy — killing process..."
  if fix_prompt; then
    fuser -k 8000/tcp && report OK "Port 8000 freed"
  fi
else
  report OK "Port 8000 free"
fi

echo ""
echo "✅ All checks done!"
echo "Run 'bash pouchon-doctor.sh' anytime to auto-repair setup."
