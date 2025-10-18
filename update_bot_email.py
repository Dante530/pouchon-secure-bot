import re

# Read the current bot file
with open('pouchon_bot.py', 'r') as f:
    content = f.read()

# Find and replace the create_paystack_payment function
old_function = '''async def create_paystack_payment(user_id: int, plan_type: str, phone: Optional[str]):
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
            raise e'''

new_function = '''async def create_paystack_payment(user_id: int, plan_type: str, phone: Optional[str]):
    """Fixed Paystack payment with valid email format"""
    
    if not PAYSTACK_SECRET_KEY:
        raise Exception("Paystack secret key not configured")
    
    plan = SUBSCRIPTION_PLANS[plan_type]
    
    # Generate valid email that Paystack will accept
    import random
    domains = ["gmail.com", "yahoo.com", "outlook.com", "hotmail.com"]
    domain = random.choice(domains)
    email = f"user{user_id}@pouchon.{domain}"
    
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
    
    logger.info(f"Creating Paystack payment for {email}")
    
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
                
        except httpx.HTTPError as e:
            logger.error(f"HTTP error: {e}")
            raise Exception("Payment service unavailable. Please try again.")
        except Exception as e:
            logger.error(f"Payment error: {e}")
            raise e'''

# Replace the function
if old_function in content:
    content = content.replace(old_function, new_function)
    with open('pouchon_bot.py', 'w') as f:
        f.write(content)
    print("✅ Bot file updated with valid email format")
else:
    print("❌ Could not find the function to replace")
    print("The bot file structure may have changed")
