import asyncio
import os

os.environ['PAYSTACK_SECRET_KEY'] = 'sk_live_8a8960b2063c3af5138381fc7a76d79d381f6ae4'

async def test_international():
    print("🌍 Testing International payment creation...")
    
    # Import the fixed function
    from pouchon_bot import create_paystack_payment
    
    try:
        user_id = 8273608494
        plan_type = "international"
        
        print(f"Creating payment for user {user_id}, plan {plan_type}")
        payment_url, reference = await create_paystack_payment(user_id, plan_type, None)
        
        print("✅ INTERNATIONAL PAYMENT CREATION SUCCESSFUL!")
        print(f"Reference: {reference}")
        print(f"Payment URL: {payment_url}")
        return True
        
    except Exception as e:
        print(f"❌ International payment failed: {e}")
        return False

success = asyncio.run(test_international())
if success:
    print("🎉 International payments are working!")
else:
    print("🔧 International payments still need fixing")
