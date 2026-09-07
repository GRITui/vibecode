#!/bin/bash
set -e

# VibeCode Model Evaluation Script (Issue #2)
# Tests tool-calling reliability for a given model via LiteLLM proxy.
# Usage: ./scripts/evaluate-model.sh [model_name]
# Example: ./scripts/evaluate-model.sh z-ai/glm-5.2:free

MODEL="${1:-z-ai/glm-5.2:free}"
LITELLM_URL="${LITELLM_API_URL:-http://localhost:4000}"
LITELLM_KEY="${LITELLM_API_KEY:-}"

echo "🔬 VibeCode Model Evaluation"
echo "=============================="
echo "Model: $MODEL"
echo "LiteLLM Proxy: $LITELLM_URL"
echo ""

# Basic connectivity test (chat completion)
echo "📡 Test 1: Basic chat completion..."
START_MS=$(date +%s%N)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$LITELLM_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  ${LITELLM_KEY:+-H "Authorization: Bearer $LITELLM_KEY"} \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hello\"}],\"max_tokens\":50}" \
  || true)
END_MS=$(date +%s%N)
LATENCY_MS=$(( (END_MS - START_MS) / 1000000 ))

if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ Basic chat responded in ${LATENCY_MS}ms"
else
    echo "   ❌ Basic chat failed (HTTP $HTTP_CODE)"
    echo ""
    echo "💡 Tip: Ensure LiteLLM proxy is running and model '$MODEL' is configured."
    exit 1
fi

# Tool-calling test (if model supports it)
echo "📡 Test 2: Tool-calling request..."
TOOL_START_MS=$(date +%s%N)
TOOL_RESPONSE=$(curl -s \
  -X POST "$LITELLM_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  ${LITELLM_KEY:+-H "Authorization: Bearer $LITELLM_KEY"} \
  -d '{
    "model": "'"$MODEL"'",
    "messages": [{"role": "user", "content": "What is the weather in Paris?"}],
    "tools": [
      {
        "type": "function",
        "function": {
          "name": "get_weather",
          "parameters": {
            "type": "object",
            "properties": {
              "location": {"type": "string"}
            },
            "required": ["location"]
          }
        }
      }
    ],
    "max_tokens": 100
  }' || true)
TOOL_END_MS=$(date +%s%N)
TOOL_LATENCY_MS=$(( (TOOL_END_MS - TOOL_START_MS) / 1000000 ))

if echo "$TOOL_RESPONSE" | grep -q '"tool_calls"\|"function_call"'; then
    echo "   ✅ Tool-calling responded in ${TOOL_LATENCY_MS}ms"
    TOOL_RELIABLE="true"
else
    echo "   ⚠️  No tool call detected (response may still be valid)"
    TOOL_RELIABLE="false"
fi

echo ""
echo "📊 Evaluation Summary"
echo "====================="
echo "Model: $MODEL"
echo "Basic Latency: ${LATENCY_MS}ms"
echo "Tool Latency: ${TOOL_LATENCY_MS}ms"
echo "Tool Calling Reliable: $TOOL_RELIABLE"
echo ""
echo "💾 To record in ModelRegistry, copy the above into your Swift code:"
echo "   ModelRegistry.shared.recordEvaluation("
echo "       model: \"$MODEL\","
echo "       toolCallingReliable: $TOOL_RELIABLE,"
echo "       latencyMs: ${LATENCY_MS},"
echo "       notes: \"End-to-end eval $(date -Iseconds)\""
echo "   )"
