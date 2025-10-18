#!/bin/bash
echo "🔍 QUICK STATUS CHECK"
echo "====================="
echo "Domain: $(railway domain 2>/dev/null)"
echo ""
echo "Recent logs:"
railway logs -n 5
echo ""
echo "Testing endpoints:"
DOMAIN=$(railway domain 2>/dev/null)
curl -s "https://$DOMAIN/" | head -c 100
echo ""
echo "✅ Run ./debug_bot.sh for detailed debugging"
