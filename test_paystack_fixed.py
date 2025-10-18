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
