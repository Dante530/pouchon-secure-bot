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
