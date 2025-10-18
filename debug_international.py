import asyncio
import os

# Mock the environment
os.environ['PAYSTACK_SECRET_KEY'] = 'sk_live_8a8960b2063c3af5138381fc7a76d79d381f6ae4'

async def test_international_flow():
    print("🔍 Testing International payment flow...")
    
    # Simulate what happens when user selects International plan
    user_id = 8273608494
    plan_type = "international"
    phone = None
    
    print(f"User: {user_id}")
    print(f"Plan: {plan_type}")
    print(f"Phone: {phone}")
    
    # Test the payment creation
    try:
        from pouchon_bot import create_paystack_payment
        payment_url, reference = await create_paystack_payment(user_id, plan_type, phone)
        print(f"✅ International payment created successfully!")
        print(f"URL: {payment_url}")
        print(f"Reference: {reference}")
        return True
    except Exception as e:
        print(f"❌ International payment failed: {e}")
        return False

# Run the test
success = asyncio.run(test_international_flow())
if success:
    print("🎉 International flow should work!")
else:
    print("🔧 Need to fix International flow")
