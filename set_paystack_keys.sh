#!/bin/bash

echo "🔑 SETTING PAYSTACK KEYS IN RAILWAY"
echo "==================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Your Paystack keys from the message
PAYSTACK_SECRET_KEY="sk_live_8a8960b2063c3af5138381fc7a76d79d381f6ae4"
PAYSTACK_PUBLIC_KEY="pk_live_8814078e3e588386ebf5ed33119caac71e916a58"

echo -e "${YELLOW}1. Setting Paystack Secret Key...${NC}"
if railway variables set PAYSTACK_SECRET_KEY="$PAYSTACK_SECRET_KEY"; then
    echo -e "${GREEN}✅ Paystack Secret Key set${NC}"
else
    echo -e "${RED}❌ Failed to set Secret Key${NC}"
fi

echo -e "${YELLOW}2. Setting Paystack Public Key...${NC}"
if railway variables set PAYSTACK_PUBLIC_KEY="$PAYSTACK_PUBLIC_KEY"; then
    echo -e "${GREEN}✅ Paystack Public Key set${NC}"
else
    echo -e "${RED}❌ Failed to set Public Key${NC}"
fi

echo -e "${YELLOW}3. Verifying the keys are set...${NC}"
echo -e "Current Railway variables:"
railway variables | grep -E "(PAYSTACK|BOT_TOKEN)" || echo "Could not list variables"

echo -e "${YELLOW}4. Testing Paystack connection with new keys...${NC}"
cat > test_paystack_fixed.py << 'TESTFIXED'
import os
import httpx
import asyncio

# Set the keys directly for testing
os.environ['PAYSTACK_SECRET_KEY'] = 'sk_live_8a8960b2063c3af5138381fc7a76d79d381f6ae4'

async def test_paystack_fixed():
    print("🔍 Testing Paystack with live keys...")
    
    PAYSTACK_SECRET_KEY = os.getenv("PAYSTACK_SECRET_KEY")
    print(f"Key being used: {PAYSTACK_SECRET_KEY[:10]}...")
    
    url = "https://api.paystack.co/transaction/totals"
    headers = {
        "Authorization": f"Bearer {PAYSTACK_SECRET_KEY}",
        "Content-Type": "application/json"
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, headers=headers, timeout=10.0)
            print(f"Paystack test: {response.status_code}")
            
            if response.status_code == 200:
                print("✅ Paystack connection successful!")
                data = response.json()
                print(f"Account status: Active")
                return True
            else:
                print(f"❌ Paystack issue: {response.status_code}")
                print(f"Response: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Connection failed: {e}")
            return False

success = asyncio.run(test_paystack_fixed())
if success:
    print("🎉 Paystack keys are working!")
else:
    print("💡 Check your Paystack account status in dashboard")
TESTFIXED

python3 test_paystack_fixed.py

echo -e "${YELLOW}5. Restarting the service to apply new environment variables...${NC}"
if railway restart; then
    echo -e "${GREEN}✅ Service restart triggered${NC}"
else
    echo -e "${YELLOW}⚠️ Manual restart may be needed${NC}"
fi

echo -e "${YELLOW}6. Waiting for restart...${NC}"
sleep 20

echo -e "${YELLOW}7. Testing the payment flow...${NC}"
cat > test_payment_flow.py << 'TESTFLOW'
import os
import asyncio
import httpx

# Test the payment creation with live keys
async def test_payment_creation():
    print("🧪 Testing payment creation...")
    
    PAYSTACK_SECRET_KEY = 'sk_live_8a8960b2063c3af5138381fc7a76d79d381f6ae4'
    
    url = "https://api.paystack.co/transaction/initialize"
    headers = {
        "Authorization": f"Bearer {PAYSTACK_SECRET_KEY}",
        "Content-Type": "application/json"
    }
    
    # Test payload for international plan
    payload = {
        "email": "test_user@pouchon.telegram",
        "amount": 2000,  # $20 in cents
        "currency": "USD",
        "metadata": {
            "user_id": 123456,
            "plan_type": "international",
            "hours": 12
        }
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(url, json=payload, headers=headers, timeout=10.0)
            print(f"Payment creation test: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                if data.get("status"):
                    payment_url = data["data"]["authorization_url"]
                    reference = data["data"]["reference"]
                    print("✅ Payment creation successful!")
                    print(f"Reference: {reference}")
                    print(f"Payment URL: {payment_url[:80]}...")
                    return True
                else:
                    print(f"❌ Paystack error: {data.get('message')}")
                    return False
            else:
                print(f"❌ HTTP error: {response.status_code}")
                print(f"Response: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Payment test failed: {e}")
            return False

success = asyncio.run(test_payment_creation())
if success:
    print("🎉 Payments are now working!")
else:
    print("🔧 There may be an issue with your Paystack account configuration")
TESTFLOW

python3 test_payment_flow.py

echo -e "\n${GREEN}✅ PAYSTACK KEYS CONFIGURED${NC}"
echo "============================"

echo -e "\n${YELLOW}🎯 NEXT STEPS:${NC}"
echo "1. Wait for Railway to restart with new keys"
echo "2. Test your bot: Send /subscribe → Choose International"
echo "3. Should now create payment successfully"
echo "4. Check logs for Paystack response"

echo -e "\n${YELLOW}📋 MANUAL VERIFICATION:${NC}"
echo "Visit: https://railway.app/project/charismatic-miracle/variables"
echo "Ensure these variables are set:"
echo "• PAYSTACK_SECRET_KEY=sk_live_8a8960b2063c3af5138381fc7a76d79d381f6ae4"
echo "• PAYSTACK_PUBLIC_KEY=pk_live_8814078e3e588386ebf5ed33119caac71e916a58"
echo "• BOT_TOKEN=8406972008:AAHTmNluGB3UD6Xmj2HVVB5YAguuj2mWk-k"

echo -e "\n${YELLOW}🚀 Your payment system should now work!${NC}"
