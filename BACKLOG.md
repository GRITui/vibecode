# VibeCode Backlog

This backlog captures features, enhancements, and known items derived from the project README and architecture. Items are organized by category and can be moved to a task tracker as they are picked up.

---

## Core Features

| ID | Feature | Status | Notes |
|----|---------|--------|-------|
| F-1 | 🤖 Telegram Integration | ✅ | Control the AI bot via Telegram messages |
| F-2 | 📦 OrbStack Support | ✅ | Manage Docker containers natively on macOS |
| F-3 | 🔧 Self-Healing Tests | ✅ | Automatically detect and fix test failures |
| F-4 | ✅ Approve/Reject Workflow | ✅ | Human-in-the-loop approval via Telegram inline keyboards |
| F-5 | 🏥 Health Monitoring Sub-Agent | ✅ | Continuous health checks with delegable healing |
| F-6 | 🔗 n8n Workflow Integration | ✅ | Export health data to n8n for automation |
| F-7 | 🧠 Small Model Delegation | ✅ | Generate compact prompts for small LLM triage |
| F-8 | 🌐 Hummingbird Web Server | ✅ | Built-in HTTP endpoints for health, status, and webhooks |

---

## Health Checks

| ID | Check | Status | Description |
|----|-------|--------|-------------|
| HC-1 | ContainerHealthCheck | 🚧 | Verify container state via OrbStack |
| HC-2 | DiskSpaceHealthCheck | 🚧 | Monitor disk usage (host or container) |
| HC-3 | MemoryHealthCheck | 🚧 | Monitor memory pressure (host or container) |
| HC-4 | TestRunnerHealthCheck | 🚧 | Verify tests are passing |

---

## Healing Actions

| ID | Action | Status | Description |
|----|--------|--------|-------------|
| HA-1 | RestartContainerAction | 🚧 | Restart stopped containers |
| HA-2 | ClearCacheAction | 🚧 | Clear temp/cache when disk is full |
| HA-3 | DependencyHealAction | 🚧 | Auto-install missing dependencies |
| HA-4 | RebuildContainerAction | 🚧 | Force-remove containers for rebuild |

---

## Web Server Endpoints

| ID | Endpoint | Method | Status | Description |
|----|----------|--------|--------|-------------|
| EP-1 | `/health` | GET | 🚧 | Latest health check status (JSON) |
| EP-2 | `/status` | GET | 🚧 | Bot status overview (JSON) |
| EP-3 | `/webhook/telegram` | POST | 🚧 | Telegram webhook receiver |
| EP-4 | `/webhook/n8n` | POST | 🚧 | n8n automation webhook |

---

## Telegram Commands

| ID | Command | Status | Description |
|----|---------|--------|-------------|
| TC-1 | `/start` / `/help` | 🚧 | Show available commands |
| TC-2 | `/status` | 🚧 | Check bot status and OrbStack connection |
| TC-3 | `/run` | 🚧 | Run tests with self-healing (requires approval) |
| TC-4 | `/containers` | 🚧 | List all Docker containers |
| TC-5 | `/health` | 🚧 | Check health status & small-model prompt |

---

## Self-Healing Strategies

| ID | Strategy | Status | Notes |
|----|----------|--------|-------|
| SH-1 | Dependency installation | 🚧 | npm, yarn, pip, bundle |
| SH-2 | Syntax error detection | 🚧 | Detect and report syntax issues |
| SH-3 | Retry logic | 🚧 | Automatically retry after healing attempts |
| SH-4 | Custom HealingStrategy protocol | 🚧 | Allow users to implement custom strategies |

---

## Configuration & Environment

| ID | Config | Status | Notes |
|----|--------|--------|-------|
| CFG-1 | `TELEGRAM_BOT_TOKEN` | ✅ | Required |
| CFG-2 | `TELEGRAM_CHAT_ID` | ✅ | Required |
| CFG-3 | `HEALTH_WEBHOOK_URL` | 🚧 | n8n or custom webhook URL (optional) |
| CFG-4 | `HEALTH_CHECK_INTERVAL` | 🚧 | Interval in seconds (default: 60) |
| CFG-5 | `WEB_SERVER_PORT` | 🚧 | Hummingbird web server port (default: 8080) |

---

## Infrastructure / DevEx

| ID | Item | Status | Notes |
|----|------|--------|-------|
| INF-1 | macOS 14.0+ support | ✅ | Sonoma or later |
| INF-2 | Swift 5.9+ support | ✅ | Xcode 15+ |
| INF-3 | OrbStack detection | 🚧 | Ensure `docker --version` works |
| INF-4 | Project build & test CI | ✅ | GitHub Actions workflow added (`ci.yml`) |
| INF-5 | Documentation site | ⬜ | Generate docs from inline comments |
| INF-6 | Release automation | ⬜ | Tagged releases with changelog |

---

## Troubleshooting / Known Gaps

| ID | Issue | Status | Notes |
|----|-------|--------|-------|
| ISS-1 | OrbStack not detected handling | ⬜ | Better error messages and fallback |
| ISS-2 | Bot not responding diagnostics | ⬜ | Self-diag for token/chat ID issues |
| ISS-3 | Tests not running investigation | ⬜ | Container logs, command validation |
| ISS-4 | Add unit tests for all modules | ⬜ | Currently only basic tests exist |

---

## Legend

- ✅ — Implemented / Available
- 🚧 — Partially implemented or in progress
- ⬜ — Not yet started / Backlog

---

## Closed / Updated Issues

| Issue | Status | Notes |
|-------|--------|-------|
| #1 Telegram Bot MVP | ✅ Closed | MVP complete: commands, inline keyboards, webhooks. Follow-ups: persistent chat history, advanced command parsing, rate limiting. |
| #2 Evaluate z-ai/glm-5.2:free | 🚧 In Progress | Added `LLMConfig` module with model registry and LiteLLM proxy support. Evaluation script `scripts/evaluate-model.sh` added. Awaiting live API test to decide placement in fallback chain. |
| #3 LiteLLM Budget Alert Webhooks | 🚧 In Progress | Webhook endpoint `/webhook/litellm-budget` wired; test script `scripts/test-budget-webhook.sh` added. Awaiting live test with $15/month cap and alert routing to Telegram. |

---

*Generated from README.md and project architecture.*
