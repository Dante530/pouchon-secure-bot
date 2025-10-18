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
