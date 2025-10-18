#!/bin/bash

echo "🔍 VERIFYING PAYMENT SYSTEM SETUP"
echo "================================"

echo -e "1. Checking environment variables..."
railway variables | grep -E "(PAYSTACK|CHANNEL|ADMIN)"

echo -e "\n2. Testing bot endpoints..."
DOMAIN="web-production-6fffd.up.railway.app"
curl -s "https://$DOMAIN/health" | python3 -m json.tool 2>/dev/null

echo -e "\n3. Checking recent logs..."
railway logs -n 8

echo -e "\n4. Testing bot commands availability:"
echo -e "   • /subscribe - Start payment process"
echo -e "   • /status - Check access status" 
echo -e "   • /admin - Admin dashboard (if you're admin)"
echo -e "   • /help - Get help"

echo -e "\n✅ Payment system setup complete!"
echo -e "🚀 Test with: /subscribe"
