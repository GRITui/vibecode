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
| HC-1 | ContainerHealthCheck | ✅ | Verify container state via OrbStack — covered via `MockOrbStack` (running/exited/not-found/error) |
| HC-2 | DiskSpaceHealthCheck | 🚧 | Monitor disk usage (host or container) — container path covered via `MockOrbStack`; host (`df`) path still untested |
| HC-3 | MemoryHealthCheck | 🚧 | Monitor memory pressure (host or container) — container path covered via `MockOrbStack`; host (`vm_stat`) path still untested |
| HC-4 | TestRunnerHealthCheck | ✅ | Verify tests are passing — covered via `MockOrbStack` (pass/fail) |

---

## Healing Actions

| ID | Action | Status | Description |
|----|--------|--------|-------------|
| HA-1 | RestartContainerAction | ✅ | Restart stopped containers — `canHeal` and `execute` (success + failure) covered via `MockOrbStack` |
| HA-2 | ClearCacheAction | ✅ | Clear temp/cache when disk is full — `canHeal` and `execute` covered via `MockOrbStack` |
| HA-3 | DependencyHealAction | ✅ | Auto-install missing dependencies — `canHeal` and `execute` covered via `MockOrbStack` |
| HA-4 | RebuildContainerAction | ✅ | Force-remove containers for rebuild — `canHeal` and `execute` (success + failure) covered via `MockOrbStack` |

---

## Web Server Endpoints

| ID | Endpoint | Method | Status | Description |
|----|----------|--------|--------|-------------|
| EP-1 | `/health` | GET | ✅ | Latest health check status (JSON) — covered via `HummingbirdTesting`'s `.router` framework (204-no-status case) |
| EP-2 | `/status` | GET | ✅ | Bot status overview (JSON) — covered via `HummingbirdTesting`'s `.router` framework |
| EP-3 | `/webhook/telegram` | POST | ✅ | Telegram webhook receiver — covered via `HummingbirdTesting`'s `.router` framework |
| EP-4 | `/webhook/n8n` | POST | ✅ | n8n automation webhook — covered via `HummingbirdTesting`'s `.router` framework |
| EP-5 | `/dashboard` | GET | ✅ | Service-health dashboard UI (health cards + roadmap kanban) |
| EP-6 | `/roadmap.json` | GET | ✅ | Parses BACKLOG.md into kanban-ready sections (BacklogParser) |
| EP-7 | `/health/delegate` | POST | ✅ | Runs a health check cycle and delegates the decision to the small-model path |
| EP-8 | `/diagnostics` | GET | ✅ | Bot-not-responding diagnostics (ISS-2): Telegram reachability, OrbStack availability, health-monitor staleness |

---

## Telegram Commands

| ID | Command | Status | Description |
|----|---------|--------|-------------|
| TC-1 | `/start` / `/help` | 🚧 | Show available commands |
| TC-2 | `/status` | 🚧 | Check bot status and OrbStack connection |
| TC-3 | `/run` | 🚧 | Run tests with self-healing (requires approval) |
| TC-4 | `/containers` | 🚧 | List all Docker containers |
| TC-5 | `/health` | 🚧 | Check health status & small-model prompt |
| TC-6 | `/provider` | 🚧 | Pick the AI coding CLI (Claude, Cline, opencode) via inline keyboard |
| TC-7 | `/task <prompt>` | 🚧 | Run a prompt with the selected AI CLI in the dev container |

Deferred this sprint: `TelegramBotClient` is constructed directly inside `AIBotOrchestrator.init` (`Sources/AIBot/AIBotOrchestrator.swift`) with a real `URLSession`, with no protocol seam or injection point (unlike `ContainerRuntime` for OrbStack). Automated coverage for TC-1..7 needs a `TelegramBotClient`-shaped protocol + mock double, analogous to `ContainerRuntime`/`MockOrbStack` — a small production-code refactor, out of scope for this pass. TC-6/TC-7's pure pieces (`AIProvider`, provider keyboard construction, callback-data parsing, `selectedProvider` mutation) are covered directly instead.

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
| ISS-1 | OrbStack not detected handling | ✅ | `OrbStackManager.checkAvailability()` distinguishes command-not-found vs. unexpected output; `AIBotOrchestrator.start()` surfaces an actionable message for each |
| ISS-2 | Bot not responding diagnostics | ✅ | `/diag` Telegram command + `GET /diagnostics` HTTP route report token prefix, authorized-chat match, OrbStack availability, and health-monitor staleness; backed by new `TelegramBotClient.getMe()` reachability probe |
| ISS-3 | Tests not running investigation | ✅ | `SelfHealingTestRunner.diagnosticMessage(for:)` classifies `execInContainer` failures into `[container-missing]` / `[container-stopped]` / `[test-command-failed]` prefixes instead of an opaque error dump; covered by `Tests/DiagnosticsTests.swift` (5 tests) |
| ISS-4 | Add unit tests for all modules | 🚧 | BacklogParser (6 tests), Healing Actions (`canHeal`+`execute`), container-backed Health Checks (`ContainerRuntime` seam + `MockOrbStack`), WebServer routes EP-1..4 (`HummingbirdTesting` `.router` framework), and the ISS-3 diagnostics classifier now covered; Telegram Commands still need coverage |
| ISS-5 | `/roadmap.json` reads BACKLOG.md via CWD-relative path | ⬜ | Fragile if the server is launched from a different working directory; pre-existing pattern, not sprint-introduced |
| ISS-6 | `/health/delegate` has no auth | ⬜ | Can trigger real container restart/removal from an unauthenticated HTTP call; consistent with existing `/webhook/*` posture, not sprint-introduced |

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
