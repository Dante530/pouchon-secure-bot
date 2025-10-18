#!/bin/bash
echo "🔍 VERIFYING FIX"
echo "================"

echo -e "1. Checking current files:"
ls -la pouchon_bot*.py

echo -e "\n2. Checking Railway config:"
cat railway.toml

echo -e "\n3. Checking deployment status:"
railway logs -n 10

echo -e "\n4. Testing endpoints:"
DOMAIN="web-production-6fffd.up.railway.app"
curl -s "https://$DOMAIN/health" && echo -e " ✅ Health endpoint working" || echo -e " ❌ Health endpoint failed"
