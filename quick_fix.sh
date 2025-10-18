#!/bin/bash

echo "🔧 POUCHON BOT QUICK FIX SCRIPT"
echo "================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if we're in project directory
if [ ! -f "pouchon_bot.py" ]; then
    echo -e "${RED}❌ Please run this script in your bot project directory${NC}"
    exit 1
fi

echo -e "${YELLOW}1. Checking for common issues...${NC}"

# Fix 1: Check if bot has universal phone validation
if ! grep -q "validate_kenya_phone" pouchon_bot.py; then
    echo -e "${RED}❌ Bot missing phone validation fix${NC}"
    echo -e "${YELLOW}Run the main deployment script instead${NC}"
    exit 1
fi

# Fix 2: Restart railway deployment
echo -e "${YELLOW}2. Restarting Railway deployment...${NC}"
if command -v railway &> /dev/null; then
    railway restart
    echo -e "${GREEN}✅ Deployment restarted${NC}"
else
    echo -e "${YELLOW}⚠️ Railway CLI not installed${NC}"
fi

# Fix 3: Show recent logs
echo -e "${YELLOW}3. Recent logs:${NC}"
if command -v railway &> /dev/null; then
    railway logs --tail 5
else
    echo -e "${YELLOW}Install Railway CLI: npm install -g @railway/cli${NC}"
fi

echo -e "\n${GREEN}✅ Quick fix complete!${NC}"
echo -e "${YELLOW}If issues persist, run the full deployment script.${NC}"
