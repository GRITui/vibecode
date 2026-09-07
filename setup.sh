#!/bin/bash
set -e

echo "🚀 VibeCode Setup"
echo "================="
echo ""

# Detect if .env exists
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
    echo "⚠️  .env already exists."
    read -p "Do you want to overwrite it? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "✅ Keeping existing .env. Skipping prompt."
        SKIP_PROMPT=1
    fi
fi

if [ -z "$SKIP_PROMPT" ]; then
    echo ""
    echo "Please enter your configuration values:"
    echo ""

    # TELEGRAM_BOT_TOKEN
    DEFAULT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
    if [ -n "$DEFAULT_TOKEN" ]; then
        read -p "TELEGRAM_BOT_TOKEN [$DEFAULT_TOKEN]: " TOKEN
        TOKEN="${TOKEN:-$DEFAULT_TOKEN}"
    else
        read -p "TELEGRAM_BOT_TOKEN: " TOKEN
    fi

    # TELEGRAM_CHAT_ID
    DEFAULT_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
    if [ -n "$DEFAULT_CHAT_ID" ]; then
        read -p "TELEGRAM_CHAT_ID [$DEFAULT_CHAT_ID]: " CHAT_ID
        CHAT_ID="${CHAT_ID:-$DEFAULT_CHAT_ID}"
    else
        read -p "TELEGRAM_CHAT_ID: " CHAT_ID
    fi

    # HEALTH_WEBHOOK_URL
    DEFAULT_WEBHOOK="${HEALTH_WEBHOOK_URL:-}"
    if [ -n "$DEFAULT_WEBHOOK" ]; then
        read -p "HEALTH_WEBHOOK_URL (optional) [$DEFAULT_WEBHOOK]: " WEBHOOK
        WEBHOOK="${WEBHOOK:-$DEFAULT_WEBHOOK}"
    else
        read -p "HEALTH_WEBHOOK_URL (optional): " WEBHOOK
    fi

    # HEALTH_CHECK_INTERVAL
    DEFAULT_INTERVAL="${HEALTH_CHECK_INTERVAL:-60}"
    read -p "HEALTH_CHECK_INTERVAL (seconds) [$DEFAULT_INTERVAL]: " INTERVAL
    INTERVAL="${INTERVAL:-$DEFAULT_INTERVAL}"

    # WEB_SERVER_PORT
    DEFAULT_PORT="${WEB_SERVER_PORT:-8080}"
    read -p "WEB_SERVER_PORT [$DEFAULT_PORT]: " PORT
    PORT="${PORT:-$DEFAULT_PORT}"

    # LiteLLM / LLM Configuration
    DEFAULT_LITELLM_URL="${LITELLM_API_URL:-}"
    if [ -n "$DEFAULT_LITELLM_URL" ]; then
        read -p "LITELLM_API_URL (optional) [$DEFAULT_LITELLM_URL]: " LITELLM_URL
        LITELLM_URL="${LITELLM_URL:-$DEFAULT_LITELLM_URL}"
    else
        read -p "LITELLM_API_URL (optional, e.g. http://localhost:4000): " LITELLM_URL
    fi

    DEFAULT_LITELLM_KEY="${LITELLM_API_KEY:-}"
    if [ -n "$DEFAULT_LITELLM_KEY" ]; then
        read -p "LITELLM_API_KEY (optional) [$DEFAULT_LITELLM_KEY]: " LITELLM_KEY
        LITELLM_KEY="${LITELLM_KEY:-$DEFAULT_LITELLM_KEY}"
    else
        read -p "LITELLM_API_KEY (optional): " LITELLM_KEY
    fi

    # Budget alert webhook
    DEFAULT_BUDGET_WEBHOOK="${LITELLM_BUDGET_WEBHOOK_URL:-}"
    if [ -n "$DEFAULT_BUDGET_WEBHOOK" ]; then
        read -p "LITELLM_BUDGET_WEBHOOK_URL (optional) [$DEFAULT_BUDGET_WEBHOOK]: " BUDGET_WEBHOOK
        BUDGET_WEBHOOK="${BUDGET_WEBHOOK:-$DEFAULT_BUDGET_WEBHOOK}"
    else
        read -p "LITELLM_BUDGET_WEBHOOK_URL (optional): " BUDGET_WEBHOOK
    fi

    cat > "$ENV_FILE" <<EOF
# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN=$TOKEN
TELEGRAM_CHAT_ID=$CHAT_ID

# Health Monitor Configuration
HEALTH_WEBHOOK_URL=$WEBHOOK
HEALTH_CHECK_INTERVAL=$INTERVAL

# Web Server Configuration
WEB_SERVER_PORT=$PORT

# LiteLLM / LLM Configuration
LITELLM_API_URL=$LITELLM_URL
LITELLM_API_KEY=$LITELLM_KEY

# Budget Alert Webhook
LITELLM_BUDGET_WEBHOOK_URL=$BUDGET_WEBHOOK
EOF
    echo ""
    echo "✅ .env created successfully."
fi

echo ""
echo "🔧 Building project..."
swift build

echo ""
echo "🧪 Running tests..."
swift test

echo ""
echo "✅ Setup complete!"
echo ""
echo "To run the bot:"
echo "  source .env && swift run vibecode"
echo ""
