#!/bin/bash

echo "🤖 TELEGRAM BOT DOCTOR - AUTOMATED DIAGNOSTICS"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
PROBLEMS=()
WARNINGS=()
SOLUTIONS=()
MANUAL_FIXES=()

# Function to log problems
log_problem() {
    PROBLEMS+=("$1")
    echo -e "${RED}❌ PROBLEM:${NC} $1"
}

# Function to log warnings
log_warning() {
    WARNINGS+=("$1")
    echo -e "${YELLOW}⚠️ WARNING:${NC} $1"
}

# Function to log solutions
log_solution() {
    SOLUTIONS+=("$1")
    echo -e "${GREEN}🔧 SOLUTION:${NC} $1"
}

# Function to log manual fixes
log_manual_fix() {
    MANUAL_FIXES+=("$1")
    echo -e "${BLUE}👤 MANUAL FIX NEEDED:${NC} $1"
}

# Function to check Railway status
check_railway_status() {
    echo -e "\n${BLUE}=== CHECKING RAILWAY STATUS ===${NC}"
    
    if command -v railway &> /dev/null; then
        echo -e "${GREEN}✅ Railway CLI installed${NC}"
        
        # Check if we're in a Railway project
        if railway status &> /dev/null; then
            echo -e "${GREEN}✅ In Railway project${NC}"
        else
            log_problem "Not in a Railway project directory"
            log_solution "Run: railway link"
        fi
    else
        log_warning "Railway CLI not installed"
        log_solution "Install with: npm install -g @railway/cli"
    fi
}

# Function to check deployment status
check_deployment() {
    echo -e "\n${BLUE}=== CHECKING DEPLOYMENT STATUS ===${NC}"
    
    # Get recent logs
    echo -e "${YELLOW}📊 Recent Logs:${NC}"
    railway logs -n 10 2>/dev/null | while read line; do
        if echo "$line" | grep -q "ERROR\|error\|Error\|FAILED\|failed"; then
            echo -e "${RED}$line${NC}"
        elif echo "$line" | grep -q "INFO\|info\|STARTED\|started"; then
            echo -e "${GREEN}$line${NC}"
        else
            echo "$line"
        fi
    done
    
    # Check if bot is responding
    echo -e "\n${YELLOW}🌐 Testing Bot Endpoints:${NC}"
    DOMAIN=$(railway domain 2>/dev/null || echo "pouchon-secure-bot.up.railway.app")
    
    # Test root endpoint
    if curl -s "https://$DOMAIN" &> /dev/null; then
        echo -e "${GREEN}✅ Root endpoint responding${NC}"
    else
        log_warning "Root endpoint not responding (404 may be normal)"
    fi
    
    # Test webhook endpoints
    if curl -s "https://$DOMAIN/telegram_webhook" &> /dev/null; then
        echo -e "${GREEN}✅ Telegram webhook endpoint exists${NC}"
    else
        log_problem "Telegram webhook endpoint not found"
    fi
    
    if curl -s "https://$DOMAIN/paystack_webhook" &> /dev/null; then
        echo -e "${GREEN}✅ Paystack webhook endpoint exists${NC}"
    else
        log_warning "Paystack webhook endpoint not found"
    fi
}

# Function to check environment variables
check_environment() {
    echo -e "\n${BLUE}=== CHECKING ENVIRONMENT VARIABLES ===${NC}"
    
    # Try to get variables (this might not work in all CLI versions)
    railway variables 2>/dev/null | grep -E "(BOT_TOKEN|PAYSTACK|ADMIN)" || {
        log_warning "Cannot check environment variables via CLI"
        log_manual_fix "Check variables in Railway dashboard: https://railway.app"
        log_manual_fix "Required variables: BOT_TOKEN, PAYSTACK_SECRET_KEY, PAYSTACK_PUBLIC_KEY, ADMIN_IDS, PRIVATE_GROUP_ID"
    }
}

# Function to check local files
check_local_files() {
    echo -e "\n${BLUE}=== CHECKING LOCAL FILES ===${NC}"
    
    # Check main bot file
    if [ -f "pouchon_bot.py" ]; then
        echo -e "${GREEN}✅ Main bot file exists${NC}"
        
        # Check for syntax errors
        if python -m py_compile pouchon_bot.py; then
            echo -e "${GREEN}✅ Python syntax valid${NC}"
        else
            log_problem "Python syntax error in pouchon_bot.py"
            log_solution "Run: python -m py_compile pouchon_bot.py to see details"
        fi
    else
        log_problem "Main bot file pouchon_bot.py missing"
    fi
    
    # Check requirements
    if [ -f "requirements.txt" ]; then
        echo -e "${GREEN}✅ Requirements file exists${NC}"
        
        # Check if all requirements are installed locally
        if pip install -r requirements.txt --dry-run | grep -q "already satisfied"; then
            echo -e "${GREEN}✅ All requirements available${NC}"
        else
            log_warning "Some requirements may not be installed on Railway"
        fi
    else
        log_problem "requirements.txt missing"
    fi
    
    # Check for exposed secrets
    echo -e "\n${YELLOW}🔒 Checking for exposed secrets:${NC}"
    if grep -r "BOT_TOKEN\|PAYSTACK_SECRET_KEY" . --include="*.py" --include="*.js" | grep -v "os.getenv\|process.env" | grep -q .; then
        log_problem "Hardcoded secrets found in files"
        log_solution "Remove hardcoded tokens and use environment variables"
        grep -r "BOT_TOKEN\|PAYSTACK_SECRET_KEY" . --include="*.py" --include="*.js" | grep -v "os.getenv\|process.env"
    else
        echo -e "${GREEN}✅ No hardcoded secrets found${NC}"
    fi
}

# Function to check GitHub status
check_github_status() {
    echo -e "\n${BLUE}=== CHECKING GITHUB STATUS ===${NC}"
    
    if [ -d ".git" ]; then
        echo -e "${GREEN}✅ Git repository initialized${NC}"
        
        # Check remote
        if git remote -v | grep -q "github.com/Dante530/pouchon-secure-bot"; then
            echo -e "${GREEN}✅ GitHub remote configured${NC}"
        else
            log_warning "GitHub remote not configured correctly"
            log_solution "Run: git remote add origin https://github.com/Dante530/pouchon-secure-bot.git"
        fi
        
        # Check if local is ahead of remote
        if git status | grep -q "Your branch is ahead"; then
            log_warning "Local changes not pushed to GitHub"
            log_solution "Run: git push origin main"
        fi
    else
        log_warning "Not a git repository"
    fi
}

# Function to check bot functionality
check_bot_functionality() {
    echo -e "\n${BLUE}=== CHECKING BOT FUNCTIONALITY ===${NC}"
    
    # Check if bot has the necessary imports
    if grep -q "ApplicationBuilder" pouchon_bot.py; then
        echo -e "${GREEN}✅ Telegram bot setup detected${NC}"
    else
        log_problem "Telegram bot setup not found in code"
    fi
    
    if grep -q "paystack" pouchon_bot.py -i; then
        echo -e "${GREEN}✅ Paystack integration detected${NC}"
    else
        log_warning "Paystack integration not found"
    fi
    
    # Check webhook setup
    if grep -q "WEBHOOK_URL" pouchon_bot.py; then
        echo -e "${GREEN}✅ Webhook configuration detected${NC}"
    else
        log_warning "Webhook URL configuration not found"
    fi
}

# Function to provide summary and solutions
provide_summary() {
    echo -e "\n${BLUE}=== DIAGNOSTICS SUMMARY ===${NC}"
    
    if [ ${#PROBLEMS[@]} -eq 0 ]; then
        echo -e "${GREEN}🎉 No critical problems found!${NC}"
    else
        echo -e "${RED}❌ Found ${#PROBLEMS[@]} critical problem(s):${NC}"
        for problem in "${PROBLEMS[@]}"; do
            echo -e "  • $problem"
        done
    fi
    
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️ Found ${#WARNINGS[@]} warning(s):${NC}"
        for warning in "${WARNINGS[@]}"; do
            echo -e "  • $warning"
        done
    fi
    
    if [ ${#SOLUTIONS[@]} -gt 0 ]; then
        echo -e "\n${GREEN}🔧 AUTOMATIC SOLUTIONS:${NC}"
        for solution in "${SOLUTIONS[@]}"; do
            echo -e "  • $solution"
        done
    fi
    
    if [ ${#MANUAL_FIXES[@]} -gt 0 ]; then
        echo -e "\n${BLUE}👤 MANUAL FIXES REQUIRED:${NC}"
        for fix in "${MANUAL_FIXES[@]}"; do
            echo -e "  • $fix"
        done
    fi
    
    # Final recommendation
    echo -e "\n${BLUE}📋 RECOMMENDED NEXT STEPS:${NC}"
    if [ ${#PROBLEMS[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ Your bot should be working! Test it on Telegram.${NC}"
    else
        echo -e "${YELLOW}🔧 Fix the problems above, then run this script again.${NC}"
    fi
}

# Function to attempt automatic fixes
attempt_automatic_fixes() {
    echo -e "\n${BLUE}=== ATTEMPTING AUTOMATIC FIXES ===${NC}"
    
    # Fix git remote if needed
    if ! git remote -v | grep -q "github.com/Dante530/pouchon-secure-bot" && [ -d ".git" ]; then
        echo -e "${YELLOW}🔧 Fixing GitHub remote...${NC}"
        git remote add origin https://github.com/Dante530/pouchon-secure-bot.git 2>/dev/null && \
        echo -e "${GREEN}✅ GitHub remote configured${NC}"
    fi
    
    # Push changes if ahead
    if git status | grep -q "Your branch is ahead" && [ -d ".git" ]; then
        echo -e "${YELLOW}🔧 Pushing changes to GitHub...${NC}"
        git push origin main && \
        echo -e "${GREEN}✅ Changes pushed to GitHub${NC}"
    fi
    
    # Remove any .pyc files
    find . -name "*.pyc" -delete 2>/dev/null && \
    echo -e "${GREEN}✅ Cleaned Python cache files${NC}"
}

# Main execution
main() {
    check_railway_status
    check_local_files
    check_github_status
    check_bot_functionality
    check_environment
    check_deployment
    attempt_automatic_fixes
    provide_summary
}

# Run main function
main
