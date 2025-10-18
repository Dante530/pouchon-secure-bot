#!/bin/bash

echo "🔍 QUICK VERIFICATION"
echo "====================="

echo -e "1. Recent logs (last 8 lines):"
railway logs -n 8

echo -e "\n2. Bot health:"
curl -s "https://web-production-6fffd.up.railway.app/health" | python3 -m json.tool 2>/dev/null || echo "Health check failed"

echo -e "\n3. Service status:"
railway status 2>/dev/null || echo "Status check unavailable"

echo -e "\n✅ If you see bot initialization and webhook processing, everything is working!"
