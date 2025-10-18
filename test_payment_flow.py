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
