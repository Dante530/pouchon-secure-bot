import asyncio
import httpx

async def test_payment():
    print("🧪 Testing fixed payment with valid email...")
    
    PAYSTACK_SECRET_KEY = 'sk_live_8a8960b2063c3af5138381fc7a76d79d381f6ae4'
    
    url = "https://api.paystack.co/transaction/initialize"
    headers = {
        "Authorization": f"Bearer {PAYSTACK_SECRET_KEY}",
        "Content-Type": "application/json"
    }
    
    # Test with the new valid email format
    payload = {
        "email": "user123456@dantek361.gmail.com",  # Valid email format
        "amount": 2000,
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
            print(f"Payment test: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                if data.get("status"):
                    print("✅ PAYMENT CREATION SUCCESSFUL!")
                    print(f"Reference: {data['data']['reference']}")
                    print(f"Payment URL: {data['data']['authorization_url']}")
                    return True
                else:
                    print(f"❌ Paystack error: {data.get('message')}")
                    return False
            else:
                print(f"❌ HTTP error: {response.status_code}")
                print(f"Response: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ Test failed: {e}")
            return False

success = asyncio.run(test_payment())
if success:
    print("🎉 🎉 🎉 EMAIL FIX WORKS! 🎉 🎉 🎉")
else:
    print("🔧 Still need to investigate the issue")
