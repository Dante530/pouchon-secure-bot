#!/bin/bash

echo "🚀 QUICK FIX SCRIPT FOR COMMON BOT ISSUES"
echo "=========================================="

# Fix Python syntax issues
echo "🔧 Checking Python syntax..."
python -m py_compile pouchon_bot.py && echo "✅ Syntax OK" || echo "❌ Syntax errors found"

# Update requirements if needed
echo "🔧 Updating requirements..."
pip install -r requirements.txt --upgrade

# Clean git repository
echo "🔧 Cleaning git..."
git add -A
git status

# Check if we need to push
if git status | grep -q "ahead"; then
    echo "🔧 Pushing to GitHub..."
    git push origin main
fi

# Test deployment
echo "🔧 Testing deployment..."
railway logs -n 5

echo ""
echo "✅ Quick fixes applied!"
echo "Run ./bot_doctor.sh for detailed diagnostics"
