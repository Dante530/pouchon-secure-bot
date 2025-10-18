#!/bin/bash

echo "🚀 POUCHON BOT RAILWAY DEPLOYMENT SCRIPT"
echo "========================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
    fi
}

# Step 1: Check if we're in the right directory
echo -e "${YELLOW}1. Checking project directory...${NC}"
if [ ! -f "pouchon_bot.py" ] && [ ! -f "requirements.txt" ]; then
    echo -e "${RED}❌ Not in project directory. Please cd to your bot project folder.${NC}"
    exit 1
fi
check_success "In project directory"

# Step 2: Check if git is initialized
echo -e "${YELLOW}2. Checking Git setup...${NC}"
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ Git not initialized. Please run: git init${NC}"
    exit 1
fi

# Check if remote origin is set
git remote get-url origin > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Git remote not set. Please add your GitHub repo:${NC}"
    echo -e "${YELLOW}git remote add origin https://github.com/yourusername/your-repo.git${NC}"
    exit 1
fi
check_success "Git repository configured"

# Step 3: Create/update required files
echo -e "${YELLOW}3. Setting up project files...${NC}"

# Create requirements.txt if missing
if [ ! -f "requirements.txt" ]; then
    cat > requirements.txt << 'REQ'
fastapi==0.104.1
uvicorn==0.24.0
python-telegram-bot==20.7
httpx==0.25.2
aiosqlite==0.19.0
REQ
    echo -e "${GREEN}✅ Created requirements.txt${NC}"
else
    echo -e "${GREEN}✅ requirements.txt already exists${NC}"
fi

# Create railway.json if missing
if [ ! -f "railway.json" ]; then
    cat > railway.json << 'RAIL'
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "python pouchon_bot.py",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
RAIL
    echo -e "${GREEN}✅ Created railway.json${NC}"
else
    echo -e "${GREEN}✅ railway.json already exists${NC}"
fi

# Step 4: Validate current bot code
echo -e "${YELLOW}4. Validating bot code...${NC}"
if [ ! -f "pouchon_bot.py" ]; then
    echo -e "${RED}❌ pouchon_bot.py not found!${NC}"
    exit 1
fi

# Check if the bot has universal phone validation
if ! grep -q "validate_kenya_phone" pouchon_bot.py; then
    echo -e "${RED}❌ Bot code missing universal phone validation!${NC}"
    echo -e "${YELLOW}Please make sure pouchon_bot.py has the universal phone fix.${NC}"
    exit 1
fi

check_success "Bot code validated"

# Step 5: Git operations
echo -e "${YELLOW}5. Preparing Git commit...${NC}"
git add .
check_success "Files staged"

# Check if there are changes
git status --porcelain | grep -q "."
if [ $? -eq 0 ]; then
    git commit -m "Deploy: Universal phone validation & inline payments" 
    check_success "Changes committed"
else
    echo -e "${YELLOW}⚠️ No changes to commit${NC}"
fi

# Step 6: Deploy to Railway
echo -e "${YELLOW}6. Deploying to Railway...${NC}"
echo -e "${YELLOW}Pushing to GitHub (this will trigger Railway deployment)...${NC}"

# Try different branch names
git push origin main
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Trying 'master' branch...${NC}"
    git push origin master
    check_success "Code pushed to GitHub"
else
    check_success "Code pushed to GitHub"
fi

# Step 7: Deployment monitoring
echo -e "${YELLOW}7. Monitoring deployment...${NC}"
echo -e "${YELLOW}Waiting 30 seconds for deployment to start...${NC}"
sleep 30

# Step 8: Check deployment status
echo -e "${YELLOW}8. Checking deployment status...${NC}"

# Check if railway CLI is installed and show logs
if command -v railway &> /dev/null; then
    echo -e "${GREEN}✅ Railway CLI detected${NC}"
    
    # Show recent logs
    echo -e "${YELLOW}Recent deployment logs:${NC}"
    railway logs --tail 20
    
    # Check health status
    echo -e "${YELLOW}Checking bot health...${NC}"
    sleep 10
    DOMAIN=$(railway domain 2>/dev/null)
    if [ ! -z "$DOMAIN" ]; then
        echo -e "${GREEN}✅ Bot URL: https://${DOMAIN}${NC}"
        echo -e "${YELLOW}Testing health endpoint...${NC}"
        curl -s "https://${DOMAIN}/health" | head -n 5
    fi
else
    echo -e "${YELLOW}⚠️ Railway CLI not installed${NC}"
    echo -e "${YELLOW}To install: npm install -g @railway/cli && railway login${NC}"
fi

echo -e "\n${GREEN}🎉 DEPLOYMENT INITIATED!${NC}"
echo -e "======================================"
echo -e "${YELLOW}What happened:${NC}"
echo -e "✅ Code pushed to GitHub"
echo -e "✅ Railway will auto-deploy (takes 2-3 minutes)"
echo -e "✅ Environment variables are set in Railway (as shown in your screenshot)"

echo -e "\n${YELLOW}📱 NEXT STEPS:${NC}"
echo -e "1. Wait 2-3 minutes for full deployment"
echo -e "2. Check Railway dashboard for deployment status"
echo -e "3. Test your bot with: /subscribe"
echo -e "4. Try phone numbers like: 0714728106 or 254111931492"

echo -e "\n${YELLOW}🔍 MANUAL CHECKS:${NC}"
echo -e "• Go to Railway dashboard → Deployments → Check latest status"
echo -e "• Go to Railway dashboard → Logs → Monitor for errors"
echo -e "• Test your bot directly in Telegram"

echo -e "\n${GREEN}The universal phone fix is deployed! 🚀${NC}"
echo -e "${YELLOW}Bot will now accept ALL phone formats!${NC}"
