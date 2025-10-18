import requests
import json

url = "https://web-production-6fffd.up.railway.app/telegram_webhook"

# Test with a realistic message
test_message = {
    "update_id": 100000001,
    "message": {
        "message_id": 123,
        "from": {
            "id": 8273608494,
            "is_bot": False,
            "first_name": "Test",
            "username": "testuser"
        },
        "chat": {
            "id": 8273608494,
            "first_name": "Test", 
            "username": "testuser",
            "type": "private"
        },
        "date": 1739629200,
        "text": "/start"
    }
}

print("Testing Telegram webhook...")
try:
    response = requests.post(url, json=test_message, timeout=10)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.text}")
    
    if response.status_code == 200:
        print("✅ Webhook is working!")
    else:
        print("❌ Webhook issue detected")
        
except Exception as e:
    print(f"❌ Webhook test failed: {e}")
