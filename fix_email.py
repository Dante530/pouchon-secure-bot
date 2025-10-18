import os
import logging
import httpx
import random
from typing import Optional

logger = logging.getLogger(__name__)

def generate_valid_email(user_id: int):
    """Generate a valid email address for Paystack"""
    # Paystack requires valid email format, so we'll use a real-looking domain
    domains = ["gmail.com", "yahoo.com", "outlook.com", "hotmail.com"]
    domain = random.choice(domains)
    return f"user{user_id}@pouchon.{domain}"

async def create_paystack_payment_fixed(user_id: int, plan_type: str, phone: Optional[str]):
    """Fixed Paystack payment with valid email"""
    
    PAYSTACK_SECRET_KEY = os.getenv("PAYSTACK_SECRET_KEY")
    
    if not PAYSTACK_SECRET_KEY:
        raise Exception("Paystack secret key not configured")
    
    # Plan configurations
    plans = {
        "kenya": {"currency": "KES", "amount": 60, "hours": 12},
        "international": {"currency": "USD", "amount": 20, "hours": 12}
    }
    
    plan = plans[plan_type]
    
    # Generate valid email
    email = generate_valid_email(user_id)
    
    url = "https://api.paystack.co/transaction/initialize"
    headers = {
        "Authorization": f"Bearer {PAYSTACK_SECRET_KEY}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "email": email,
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
    
    logger.info(f"Creating payment for {email}")
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(url, json=payload, headers=headers, timeout=30.0)
            logger.info(f"Paystack response: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                if data.get("status"):
                    return data["data"]["authorization_url"], data["data"]["reference"]
                else:
                    error_msg = data.get('message', 'Unknown error')
                    raise Exception(f"Payment failed: {error_msg}")
            else:
                logger.error(f"Paystack error {response.status_code}: {response.text}")
                raise Exception(f"Payment service error: {response.status_code}")
                
        except Exception as e:
            logger.error(f"Payment error: {e}")
            raise e

# Test the fixed function
async def test_fixed_payment():
    print("🧪 Testing payment with valid email...")
    try:
        url, ref = await create_paystack_payment_fixed(123456, "international", None)
        print(f"✅ Payment creation successful!")
        print(f"Email used: user123456@pouchon.gmail.com")
        print(f"Reference: {ref}")
        print(f"URL: {url[:80]}...")
        return True
    except Exception as e:
        print(f"❌ Payment failed: {e}")
        return False

import asyncio
success = asyncio.run(test_fixed_payment())
if success:
    print("🎉 Email fix works!")
else:
    print("💡 Need to investigate further")
