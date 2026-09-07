#!/bin/bash
set -e

# VibeCode LiteLLM Budget Webhook Test Script (Issue #3)
# Sends a sample LiteLLM budget alert payload to the local webhook endpoint.
# Usage: ./scripts/test-budget-webhook.sh [port]

PORT="${1:-8080}"
WEBHOOK_URL="http://localhost:$PORT/webhook/litellm-budget"

echo "🧪 VibeCode Budget Webhook Test"
echo "================================"
echo "Target: $WEBHOOK_URL"
echo ""

# Sample payload matching LiteLLM budget alert format
PAYLOAD='{
  "budget_alert": true,
  "budget_limit": 15.0,
  "current_spend": 14.50,
  "projected_spend": 16.20,
  "alert_type": "budget_threshold",
  "user_email": "ops@example.com",
  "team_name": "vibecode"
}'

echo "📡 Sending payload..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  || true)

if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Webhook returned HTTP 200"
else
    echo "   ❌ Webhook returned HTTP $HTTP_CODE"
    echo ""
    echo "💡 Tip: Ensure the VibeCode web server is running on port $PORT."
    echo "   swift run vibecode"
    exit 1
fi

echo ""
echo "📊 To test the minimal payload (no projected_spend):"
echo "   curl -X POST $WEBHOOK_URL \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"budget_alert\":true,\"budget_limit\":15.0,\"current_spend\":14.50,\"alert_type\":\"budget_threshold\"}'"
