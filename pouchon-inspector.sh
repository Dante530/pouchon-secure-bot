#!/bin/bash
set -e

echo "🕵️‍♂️ POUCHON INSPECTOR — System Diagnostic Tool"
echo "================================================"

report() {
  STATUS=$1
  MSG=$2
  case $STATUS in
    OK) echo "[OK]   $MSG" ;;
    WARN) echo "[WARN] $MSG" ;;
    FAIL) echo "[FAIL] $MSG" ;;
  esac
}

echo ""
echo "🌍 Checking environment..."

command -v node >/dev/null && NODE_VER=$(node -v) && report OK "Node.js installed ($NODE_VER)" || report FAIL "Node.js missing"
command -v npm >/dev/null && NPM_VER=$(npm -v) && report OK "npm installed ($NPM_VER)" || report FAIL "npm missing"
command -v python >/dev/null && PY_VER=$(python --version 2>&1) && report OK "Python installed ($PY_VER)" || report WARN "Python not found"
command -v git >/dev/null && GIT_VER=$(git --version) && report OK "Git installed ($GIT_VER)" || report FAIL "Git missing"
command -v railway >/dev/null && report OK "Railway CLI installed" || report WARN "Railway CLI not found (manual deploy required)"

echo ""
echo "📁 Checking project files..."

if [ -f "package.json" ]; then
  APP_TYPE="node"
  report OK "Detected Node.js project"
elif [ -f "requirements.txt" ] || ls *.py &>/dev/null; then
  APP_TYPE="python"
  report OK "Detected Python project"
else
  APP_TYPE="unknown"
  report FAIL "Could not detect project type (no package.json or requirements.txt)"
fi

if [ "$APP_TYPE" = "node" ]; then
  MAIN_FILE=$(ls *.js 2>/dev/null | grep -E 'index|bot|main' | head -n 1)
  [ -n "$MAIN_FILE" ] && report OK "Found main JS file: $MAIN_FILE" || report FAIL "No .js main file found"
elif [ "$APP_TYPE" = "python" ]; then
  MAIN_FILE=$(ls *.py 2>/dev/null | grep -E 'secure_bot|main|bot' | head -n 1)
  [ -n "$MAIN_FILE" ] && report OK "Found main Python file: $MAIN_FILE" || report FAIL "No .py main file found"
fi

if [ -f "Procfile" ]; then
  report OK "Procfile exists"
  grep -q "node" Procfile && report OK "Procfile uses Node" || true
  grep -q "python" Procfile && report OK "Procfile uses Python" || true
else
  report WARN "Procfile missing"
fi

if [ -f ".env" ]; then
  report OK ".env file found"
  grep -q "PORT=" .env && report OK "PORT variable set" || report WARN "PORT missing in .env"
else
  report WARN ".env file missing"
fi

echo ""
echo "🔌 Checking port 8000..."
if command -v lsof >/dev/null && lsof -i:8000 &>/dev/null; then
  report FAIL "Port 8000 is already in use"
else
  report OK "Port 8000 is free"
fi

if [ -f ".env" ] && grep -q "TOKEN=" .env; then
  TOKEN=$(grep TOKEN .env | head -n 1 | cut -d '=' -f2)
  if command -v curl >/dev/null && curl -s "https://api.telegram.org/bot${TOKEN}/getMe" | grep -q "\"ok\":true"; then
    report OK "Telegram bot token valid"
  else
    report WARN "Telegram bot token invalid or expired"
  fi
else
  report WARN "No Telegram bot token found in .env"
fi

echo ""
echo "🔧 Checking Git..."
if [ -d ".git" ]; then
  BRANCH=$(git branch --show-current)
  report OK "Git initialized (on branch $BRANCH)"
  git status --short | grep . >/dev/null && report WARN "Uncommitted changes exist" || report OK "Working directory clean"
else
  report WARN "Git not initialized"
fi

echo ""
echo "✅ Diagnostic complete."
echo "Run 'bash pouchon-inspector.sh' anytime to recheck."
