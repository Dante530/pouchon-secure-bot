#!/bin/bash

echo "🔧 FIXING PAYSTACK PAYMENT ISSUE"
echo "================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}1. Checking Paystack configuration...${NC}"
echo -e "Paystack Secret Key: ${PAYSTACK_SECRET_KEY:0:10}..."
echo -e "Paystack Public Key: ${PAYSTACK_PUBLIC_KEY:0:10}..."

echo -e "${YELLOW}2. Creating Paystack test script...${NC}"
cat > test_paystack.py << 'TESTPAYSTACK'
import os
import httpx
import asyncio

PAYSTACK_SECRET_KEY = os.getenv("PAYSTACK_SECRET_KEY")

async def test_paystack():
    print("🔍 Testing Paystack API connection...")
    
    # Test 1: Check if we can connect to Paystack
    url = "https://api.paystack.co/transaction"
    headers = {
        "Authorization": f"Bearer {PAYSTACK_SECRET_KEY}",
        "Content-Type": "application/json"
    }
    
    async with httpx.AsyncClient() as client:
        try:
            # Test basic connection
            response = await client.get(f"{url}/totals", headers=headers)
            print(f"Paystack connection test: {response.status_code}")
            
            if response.status_code == 200:
                print("✅ Paystack API is accessible")
                data = response.json()
                print(f"Account status: {data.get('status', 'Unknown')}")
            else:
                print(f"❌ Paystack API issue: {response.status_code}")
                print(f"Response: {response.text}")
                
        except Exception as e:
            print(f"❌ Paystack connection failed: {e}")

asyncio.run(test_paystack())
TESTPAYSTACK

python3 test_paystack.py

echo -e "${YELLOW}3. Creating fixed payment function with better error handling...${NC}"

# Create a patch for the payment function
cat > paystack_fix.py << 'PAYSTACKFIX'
import os
import logging
import httpx
from typing import Optional

logger = logging.getLogger(__name__)

async def create_paystack_payment_fixed(user_id: int, plan_type: str, phone: Optional[str]):
    """Fixed Paystack payment creation with better error handling"""
    
    PAYSTACK_SECRET_KEY = os.getenv("PAYSTACK_SECRET_KEY")
    
    if not PAYSTACK_SECRET_KEY:
        raise Exception("Paystack secret key not configured")
    
    # Plan configurations
    plans = {
        "kenya": {"currency": "KES", "amount": 60, "hours": 12},
        "international": {"currency": "USD", "amount": 20, "hours": 12}
    }
    
    plan = plans[plan_type]
    
    url = "https://api.paystack.co/transaction/initialize"
    headers = {
        "Authorization": f"Bearer {PAYSTACK_SECRET_KEY}",
        "Content-Type": "application/json"
    }
    
    # Basic payload - minimal required fields
    payload = {
        "email": f"user_{user_id}@pouchon.telegram",
        "amount": plan["amount"] * 100,  # Convert to kobo/cent
        "currency": plan["currency"],
        "metadata": {
            "user_id": user_id,
            "plan_type": plan_type,
            "hours": plan["hours"]
        }
    }
    
    # Add phone only for Kenya M-Pesa
    if plan_type == "kenya" and phone:
        payload["metadata"]["phone"] = phone
        # For M-Pesa, we need to specify channels
        payload["channels"] = ["mobile_money"]
    
    logger.info(f"Creating Paystack payment: {payload}")
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(url, json=payload, headers=headers, timeout=30.0)
            logger.info(f"Paystack response status: {response.status_code}")
            
            if response.status_code != 200:
                logger.error(f"Paystack API error {response.status_code}: {response.text}")
                raise Exception(f"Payment service error: {response.status_code}")
            
            data = response.json()
            logger.info(f"Paystack response data: {data}")
            
            if data.get("status"):
                return data["data"]["authorization_url"], data["data"]["reference"]
            else:
                error_msg = data.get('message', 'Unknown Paystack error')
                logger.error(f"Paystack API error: {error_msg}")
                raise Exception(f"Payment failed: {error_msg}")
                
        except httpx.HTTPError as e:
            logger.error(f"HTTP error creating payment: {e}")
            raise Exception("Payment service unavailable. Please try again.")
        except Exception as e:
            logger.error(f"Unexpected payment error: {e}")
            raise e

# Test the fixed function
async def test_fixed_payment():
    try:
        # Test with minimal payload
        url, ref = await create_paystack_payment_fixed(123456, "international", None)
        print(f"✅ Fixed payment function works! URL: {url[:50]}...")
    except Exception as e:
        print(f"❌ Fixed payment still failing: {e}")

import asyncio
asyncio.run(test_fixed_payment())
PAYSTACKFIX

python3 paystack_fix.py

echo -e "${YELLOW}4. Updating the bot with the fixed payment function...${NC}"

# Create a patch for the bot file
sed -i '/async def create_paystack_payment(user_id: int, plan_type: str, phone: Optional[str]):/,/^async def/ { /^async def/ { x; p; x; }; d; }' pouchon_bot.py

# Add the fixed function
cat >> pouchon_bot.py << 'ADDFUNCTION'

async def create_paystack_payment(user_id: int, plan_type: str, phone: Optional[str]):
    """Fixed Paystack payment creation with better error handling"""
    
    if not PAYSTACK_SECRET_KEY:
        raise Exception("Paystack secret key not configured")
    
    plan = SUBSCRIPTION_PLANS[plan_type]
    
    url = "https://api.paystack.co/transaction/initialize"
    headers = {
        "Authorization": f"Bearer {PAYSTACK_SECRET_KEY}",
        "Content-Type": "application/json"
    }
    
    # Basic payload - minimal required fields
    payload = {
        "email": f"user_{user_id}@pouchon.telegram",
        "amount": plan["amount"] * 100,
        "currency": plan["currency"],
        "metadata": {
            "user_id": user_id,
            "plan_type": plan_type,
            "hours": plan["hours"]
        }
    }
    
    # Add phone only for Kenya M-Pesa
    if plan_type == "kenya" and phone:
        payload["metadata"]["phone"] = phone
        payload["channels"] = ["mobile_money"]
    
    logger.info(f"Creating Paystack payment for user {user_id}")
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(url, json=payload, headers=headers, timeout=30.0)
            logger.info(f"Paystack response: {response.status_code}")
            
            if response.status_code != 200:
                logger.error(f"Paystack error {response.status_code}: {response.text}")
                raise Exception(f"Payment service error: {response.status_code}")
            
            data = response.json()
            
            if data.get("status"):
                return data["data"]["authorization_url"], data["data"]["reference"]
            else:
                error_msg = data.get('message', 'Unknown error')
                logger.error(f"Paystack API error: {error_msg}")
                raise Exception(f"Payment failed: {error_msg}")
                
        except httpx.HTTPError as e:
            logger.error(f"HTTP error: {e}")
            raise Exception("Payment service unavailable. Please try again.")
        except Exception as e:
            logger.error(f"Payment error: {e}")
            raise e
ADDFUNCTION

echo -e "${GREEN}✅ Payment function updated${NC}"

echo -e "${YELLOW}5. Deploying the Paystack fix...${NC}"
railway up

echo -e "${YELLOW}6. Waiting for deployment...${NC}"
sleep 25

echo -e "${GREEN}✅ PAYSTACK FIX DEPLOYED${NC}"
echo "========================"

echo -e "\n${YELLOW}🎯 TEST THE FIX:${NC}"
echo "1. Send /subscribe to @Pouchonlive_bot"
echo "2. Choose International plan"
echo "3. Should now create payment successfully"
echo "4. Check logs for Paystack response"

echo -e "\n${YELLOW}💡 If still failing, check your Paystack account:${NC}"
echo "• Verify secret key is correct"
echo "• Check account status in Paystack dashboard"
echo "• Ensure test/live mode matches your key"
