#!/bin/bash
set -e

echo "🧩 POUCHON START FIXER — Auto Start Command Generator"
echo "===================================================="

# Detect project type
if [ -f "package.json" ]; then
  TYPE="node"
  MAIN_FILE=$(ls *.js | grep -E 'index|bot|main' | head -n 1)
elif [ -f "requirements.txt" ] || ls *.py &>/dev/null; then
  TYPE="python"
  MAIN_FILE=$(ls *.py | grep -E 'secure_bot|bot|main' | head -n 1)
else
  echo "❌ Could not detect project type."
  exit 1
fi

# Show detection results
echo "Detected project type: $TYPE"
echo "Detected main file: ${MAIN_FILE:-None}"

if [ -z "$MAIN_FILE" ]; then
  echo "❌ No main executable file found."
  exit 1
fi

# Write the correct Procfile
if [ "$TYPE" = "node" ]; then
  echo "web: node $MAIN_FILE" > Procfile
elif [ "$TYPE" = "python" ]; then
  echo "web: python $MAIN_FILE" > Procfile
fi

echo "✅ Procfile updated:"
cat Procfile

# Test run
echo ""
echo "🧠 Testing start command..."
if [ "$TYPE" = "node" ]; then
  node "$MAIN_FILE" &
elif [ "$TYPE" = "python" ]; then
  python "$MAIN_FILE" &
fi

sleep 5
echo ""
echo "✅ Test run complete. If no errors above, it’s working fine."
echo "You can now deploy safely."
