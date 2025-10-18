#!/bin/bash

echo "🔍 VERIFYING PAYSTACK SETUP"
echo "============================"

echo -e "1. Checking Railway variables..."
railway variables | grep PAYSTACK || echo "Paystack variables not found"

echo -e "\n2. Testing Paystack connection..."
python3 -c "
import os
import requests

key = 'sk_live_8a8960b2063c3af5138381fc7a76d79d381f6ae4'
url = 'https://api.paystack.co/transaction/totals'
headers = {'Authorization': f'Bearer {key}'}

try:
    response = requests.get(url, headers=headers, timeout=10)
    print(f'Paystack Status: {response.status_code}')
    if response.status_code == 200:
        print('✅ Paystack is accessible')
    else:
        print(f'❌ Paystack issue: {response.text}')
except Exception as e:
    print(f'❌ Connection failed: {e}')
"

echo -e "\n3. Checking bot logs for recent activity..."
railway logs -n 6

echo -e "\n4. Test your bot: Send /subscribe to @Pouchonlive_bot"
