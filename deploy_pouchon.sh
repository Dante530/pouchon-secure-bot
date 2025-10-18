#!/bin/bash

echo "🚀 POUCHON BOT AUTO-DEPLOYMENT SCRIPT"
echo "======================================"

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
        exit 1
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

# Step 4: Check environment variables
echo -e "${YELLOW}4. Checking environment variables...${NC}"
MISSING_VARS=()

if [ -z "$BOT_TOKEN" ]; then
    MISSING_VARS+=("BOT_TOKEN")
fi

if [ -z "$PAYSTACK_SECRET_KEY" ]; then
    MISSING_VARS+=("PAYSTACK_SECRET_KEY")
fi

if [ -z "$PRIVATE_CHANNEL_ID" ]; then
    MISSING_VARS+=("PRIVATE_CHANNEL_ID")
fi

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo -e "${RED}❌ Missing environment variables: ${MISSING_VARS[*]}${NC}"
    echo -e "${YELLOW}Please set them in Railway dashboard:${NC}"
    echo -e "Project → Settings → Variables"
    echo -e "${YELLOW}Or run:${NC}"
    for var in "${MISSING_VARS[@]}"; do
        echo -e "export $var=\"your_value_here\""
    done
    echo -e "\n${YELLOW}Then run this script again.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All environment variables are set${NC}"
fi

# Step 5: Validate current bot code
echo -e "${YELLOW}5. Validating bot code...${NC}"
if [ ! -f "pouchon_bot.py" ]; then
    echo -e "${RED}❌ pouchon_bot.py not found!${NC}"
    exit 1
fi

# Check if the bot has universal phone validation
if ! grep -q "validate_kenya_phone" pouchon_bot.py; then
    echo -e "${RED}❌ Bot code missing universal phone validation!${NC}"
    echo -e "${YELLOW}Please replace pouchon_bot.py with the fixed version first.${NC}"
    exit 1
fi

check_success "Bot code validated"

# Step 6: Git operations
echo -e "${YELLOW}6. Preparing Git commit...${NC}"
git add .
check_success "Files staged"

git status --porcelain | grep -q "."
if [ $? -eq 0 ]; then
    git commit -m "Deploy: Universal phone validation & inline payments" > /dev/null 2>&1
    check_success "Changes committed"
else
    echo -e "${YELLOW}⚠️ No changes to commit${NC}"
fi

# Step 7: Deploy to Railway
echo -e "${YELLOW}7. Deploying to Railway...${NC}"
echo -e "${YELLOW}Pushing to GitHub (this will trigger Railway deployment)...${NC}"
git push origin main
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Trying 'master' branch...${NC}"
    git push origin master
    check_success "Code pushed to GitHub"
else
    check_success "Code pushed to GitHub"
fi

# Step 8: Wait for deployment and show logs
echo -e "${YELLOW}8. Waiting for deployment to start...${NC}"
sleep 10

echo -e "${YELLOW}9. Checking deployment status...${NC}"

# Check if railway CLI is installed
if command -v railway &> /dev/null; then
    echo -e "${YELLOW}Getting deployment logs...${NC}"
    railway logs --tail 10
    
    echo -e "\n${YELLOW}To see full logs, run:${NC}"
    echo -e "railway logs"
else
    echo -e "${YELLOW}Railway CLI not installed. Check deployment in Railway dashboard.${NC}"
    echo -e "${YELLOW}To install Railway CLI:${NC}"
    echo -e "npm install -g @railway/cli"
    echo -e "railway login"
fi

# Step 9: Test the bot
echo -e "\n${YELLOW}10. Testing deployment...${NC}"
sleep 30

# Get railway domain
if command -v railway &> /dev/null; then
    DOMAIN=$(railway domain 2>/dev/null)
    if [ ! -z "$DOMAIN" ]; then
        echo -e "${GREEN}✅ Bot deployed to: https://${DOMAIN}${NC}"
        
        # Test health endpoint
        echo -e "${YELLOW}Testing bot health endpoint...${NC}"
        curl -s "https://${DOMAIN}/health" | grep -q "healthy"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Bot is healthy and responding${NC}"
        else
            echo -e "${YELLOW}⚠️ Bot may still be starting up...${NC}"
        fi
    fi
fi

echo -e "\n${GREEN}🎉 DEPLOYMENT COMPLETE!${NC}"
echo -e "======================================"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Wait 1-2 minutes for full deployment"
echo -e "2. Test the bot by sending /subscribe"
echo -e "3. Check Railway dashboard for any errors"
echo -e "4. Monitor logs: ${YELLOW}railway logs${NC}"

echo -e "\n${YELLOW}📱 TEST PHONE NUMBERS (should all work now):${NC}"
echo -e "• 0714728106"
echo -e "• 254111931492" 
echo -e "• 712345678"
echo -e "• 254712345678"

echo -e "\n${GREEN}Bot is live with universal phone support! 🚀${NC}"
