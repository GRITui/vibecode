# VibeCode - Swift AI Coding Bot

A native Swift-based AI coding bot for macOS that integrates with Telegram, OrbStack, self-healing test runners, and health monitoring sub-agents.

## Features

- 🤖 **Telegram Integration** - Control your AI bot via Telegram messages
- 📦 **OrbStack Support** - Manage Docker containers natively on macOS
- 🔧 **Self-Healing Tests** - Automatically detect and fix test failures
- ✅ **Approve/Reject Workflow** - Human-in-the-loop approval via Telegram inline keyboards
- 🏥 **Health Monitoring Sub-Agent** - Continuous health checks with delegable healing
- 🔗 **n8n Workflow Integration** - Export health data to n8n for automation
- 🧠 **Small Model Delegation** - Generate compact prompts for small LLM triage
- 🌐 **Hummingbird Web Server** - Built-in HTTP endpoints for health, status, and webhooks
- 🚀 **Native Swift** - Built for macOS using modern Swift concurrency

## Architecture

```
VibeCode/
├── Sources/
│   ├── AIBot/          # Main bot orchestrator and command handlers
│   ├── TelegramBot/    # Telegram Bot API client
│   ├── OrbStack/       # OrbStack/Docker container management
│   ├── SelfHeal/       # Self-healing test runner
│   ├── HealthMonitor/  # Health monitoring sub-agent
│   └── WebServer/      # Hummingbird HTTP server for webhooks & health
├── Tests/
└── Package.swift
```

## Prerequisites

1. **macOS 14.0+** (Sonoma or later)
2. **Swift 5.9+** (comes with Xcode 15+)
3. **OrbStack** - Install from https://orbstack.dev
4. **Telegram Bot Token** - Get from @BotFather on Telegram

## Setup

1. **Clone and build the project:**
   ```bash
   cd vibecode
   swift build
   ```

2. **Create a Telegram bot:**
   - Open Telegram and search for @BotFather
   - Send `/newbot` and follow the instructions
   - Save the bot token

3. **Get your Chat ID:**
   - Send a message to your new bot
   - Visit: `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates`
   - Find your chat ID in the response

4. **Set environment variables:**
   ```bash
   export TELEGRAM_BOT_TOKEN='your-bot-token-here'
   export TELEGRAM_CHAT_ID='your-chat-id-here'
   ```

## Usage

### Running the Bot

```bash
swift run vibecode
```

### Telegram Commands

- `/start` or `/help` - Show available commands
- `/status` - Check bot status and OrbStack connection
- `/run` - Run tests with self-healing (requires approval)
- `/containers` - List all Docker containers
- `/health` - Check health status & small-model prompt

### Approve/Reject Workflow

When you run `/run`, the bot will send a message with inline buttons:
- ✅ **Approve** - Execute the tests
- ❌ **Reject** - Cancel the operation

## Health Monitoring Sub-Agent

The `HealthMonitor` module runs as a lightweight sub-agent that:

1. **Monitors containers** - Checks if Docker containers are running
2. **Checks system resources** - Disk and memory usage
3. **Runs self-healing actions** - Automatically attempts fixes
4. **Reports status** - Sends alerts via Telegram and webhooks

### Built-in Health Checks

- `ContainerHealthCheck` - Verify container state via OrbStack
- `DiskSpaceHealthCheck` - Monitor disk usage (host or container)
- `MemoryHealthCheck` - Monitor memory pressure (host or container)
- `TestRunnerHealthCheck` - Verify tests are passing

### Built-in Healing Actions

- `RestartContainerAction` - Restart stopped containers
- `ClearCacheAction` - Clear temp/cache when disk is full
- `DependencyHealAction` - Auto-install missing dependencies
- `RebuildContainerAction` - Force-remove containers for rebuild

### Small Model Delegation

The health monitor can generate compact prompts for small LLMs:

```swift
let prompt = await healthMonitor.generateSmallModelPrompt()
// -> "System health report:\n❌ container:app (exited)\n  Error: stopped\n..."
```

Apply a small model decision back into the system:

```swift
let result = await monitor.applySmallModelDecision("restart")
// -> "Restarted test-container"
```

Supported decisions: `restart`, `rebuild`, `alert`, `escalate`, `ignore`.

### n8n Integration

Import `n8n-workflow.json` into your n8n instance to:
- Receive health status webhooks
- Send Telegram alerts when unhealthy
- Poll health status on a schedule
- Trigger healing actions automatically

Configure the webhook URL:
```bash
export HEALTH_WEBHOOK_URL='https://your-n8n-instance.com/webhook/vibecode-health'
```

## Self-Healing Test Runner

The bot includes a self-healing test runner that can:

1. **Detect test failures** - Parse test output for errors
2. **Apply healing strategies** - Automatically attempt fixes:
   - Dependency installation (npm, yarn, pip, bundle)
   - Syntax error detection
   - Retry logic
3. **Re-run tests** - Automatically retry after healing attempts

### Custom Healing Strategies

Implement the `HealingStrategy` protocol:

```swift
public protocol HealingStrategy {
    var name: String { get }
    func canHeal(testResult: TestResult) -> Bool
    func heal(testResult: TestResult, context: HealingContext) async throws -> Bool
}
```

## OrbStack Integration

The bot uses OrbStack's Docker CLI for container management:

- Create/start/stop/remove containers
- Execute commands inside containers
- Copy files to/from containers
- Monitor container status

## Configuration

Environment variables:

- `TELEGRAM_BOT_TOKEN` - Your Telegram bot token (required)
- `TELEGRAM_CHAT_ID` - Your Telegram chat ID (required)
- `HEALTH_WEBHOOK_URL` - n8n or custom webhook URL (optional)
- `HEALTH_CHECK_INTERVAL` - Health check interval in seconds (default: 60)
- `WEB_SERVER_PORT` - Hummingbird web server port (default: 8080)

## Web Server

The bot includes a built-in Hummingbird web server that exposes HTTP endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Latest health check status (JSON) |
| `/status` | GET | Bot status overview (JSON) |
| `/webhook/telegram` | POST | Telegram webhook receiver |
| `/webhook/n8n` | POST | n8n automation webhook |

The web server starts automatically alongside the Telegram bot. Configure the port via `WEB_SERVER_PORT`.

## Development

### Building

```bash
swift build
```

### Running Tests

```bash
swift test
```

### Project Structure

- **TelegramBot** - Handles Telegram Bot API communication
- **OrbStack** - Manages Docker containers via OrbStack
- **SelfHeal** - Self-healing test runner with extensible strategies
- **HealthMonitor** - Health monitoring sub-agent with healing actions
- **WebServer** - Hummingbird HTTP server for health, status, and webhook endpoints
- **AIBot** - Main orchestrator that ties everything together

## Troubleshooting

### OrbStack not detected

Make sure OrbStack is installed and running:
```bash
docker --version
```

### Bot not responding

1. Check your bot token is correct
2. Verify your chat ID is authorized
3. Check the console for error messages

### Tests not running

1. Ensure you have a running container
2. Verify the test command is correct
3. Check container logs for errors

## License

MIT

## Author

Built with 🤖 for macOS
