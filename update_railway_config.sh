#!/bin/bash

echo "🔧 UPDATING RAILWAY CONFIGURATION"
echo "=================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}1. Creating proper railway.toml configuration...${NC}"

cat > railway.toml << 'TOMLCONFIG'
[build]
builder = "NIXPACKS"

[deploy]
startCommand = "python pouchon_bot.py"

[[services]]
name = "web"
port = 8080

[services.healthcheck]
path = "/health"
timeout = 10
interval = 30
TOMLCONFIG

echo -e "${GREEN}✅ Created railway.toml with health check${NC}"

echo -e "${YELLOW}2. Updating bot to use correct port and add health endpoint...${NC}"

# Check if health endpoint exists
if ! grep -q "@app.get.*/health" pouchon_bot.py; then
    echo -e "${YELLOW}Adding health endpoint...${NC}"
    
    # Create a backup
    cp pouchon_bot.py pouchon_bot.py.backup
    
    # Add health endpoint before the main block
    sed -i '/if __name__ == "__main__":/i \
@app.get("/health")\
async def health():\
    return {"status": "healthy", "service": "pouchon-bot"}' pouchon_bot.py
    
    echo -e "${GREEN}✅ Added health endpoint${NC}"
fi

echo -e "${YELLOW}3. Checking port configuration...${NC}"
if grep -q "port.*8000" pouchon_bot.py; then
    echo -e "${YELLOW}Found port 8000, fixing to use Railway PORT...${NC}"
    sed -i 's/port.*8000/port = int(os.getenv("PORT", 8080))/g' pouchon_bot.py
    echo -e "${GREEN}✅ Fixed port configuration${NC}"
fi

echo -e "${YELLOW}4. Deploying updated configuration...${NC}"
railway up

echo -e "${YELLOW}5. Waiting for deployment...${NC}"
sleep 20

echo -e "${GREEN}✅ CONFIGURATION UPDATED${NC}"
echo "========================"

echo -e "\n${YELLOW}📋 MANUAL STEPS REQUIRED IN RAILWAY DASHBOARD:${NC}"
echo "1. Go to: https://railway.app/project/charismatic-miracle/service/web/settings"
echo "2. Scroll to 'Healthcheck Path'"
echo "3. Set it to: /health"
echo "4. Save changes"
echo ""
echo "💡 Optional: Add Watch Paths:"
echo "   - pouchon_bot.py"
echo "   - requirements.txt"
echo "   - railway.toml"

echo -e "\n${YELLOW}🌐 TEST YOUR BOT:${NC}"
echo "Health: https://web-production-6fffd.up.railway.app/health"
echo "Main: https://web-production-6fffd.up.railway.app/"
