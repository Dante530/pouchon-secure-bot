#!/bin/bash

echo "🏥 TESTING BOT HEALTH ENDPOINT"
echo "=============================="

DOMAIN="web-production-6fffd.up.railway.app"

echo -e "Testing health endpoint..."
response=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/health")

if [ "$response" = "200" ]; then
    echo -e "✅ Health endpoint responding (HTTP 200)"
    curl -s "https://$DOMAIN/health" | python3 -m json.tool 2>/dev/null || curl -s "https://$DOMAIN/health"
else
    echo -e "❌ Health endpoint failed (HTTP $response)"
    echo -e "Trying root endpoint..."
    curl -s "https://$DOMAIN/" || echo "No response"
fi

echo -e "\n📊 Checking recent logs:"
railway logs -n 5
