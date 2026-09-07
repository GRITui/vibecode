# Local Issue Tracker

Mirrors and augments GitHub issues for offline/Sprint work.

---

## #11 — Telegram Bot MVP
**Status:** ✅ Closed (Sprint 1)
**Resolution:** MVP complete as of Sprint 1.

### Completed
- `/start`, `/help`, `/status`, `/run`, `/containers`, `/health` commands
- Inline approve/reject keyboard for `/run`
- Webhook endpoints (`/webhook/telegram`, `/webhook/n8n`)
- Mini App session endpoints (`/miniapp/launch`, `/miniapp/me`, `/miniapp/logout`)

### Remaining Follow-ups
- Persistent chat history (store conversation threads across restarts)
- Advanced command parsing (e.g., `/run --target container-name`)
- Rate limiting on commands

---

## #3 — Evaluate z-ai/glm-5.2:free
**Status:** 🚧 In Progress (Sprint 1)
**Goal:** Test tool-calling reliability; decide if it replaces current primary or gets added to fallback chain.

### Current State
- Added `LLMConfig` module with model registry
- Fallback chain: `gpt-4o-mini` → `z-ai/glm-5.2:free` → `openai/gpt-4o-mini` → `anthropic/claude-3-haiku`
- `ModelRegistry` can record evaluations per model

### Pending
- End-to-end tool-calling test with `z-ai/glm-5.2:free`
- Measure latency and reliability
- Decision: primary replacement vs. fallback-only

---

## #40 — Configure LiteLLM Budget Alert Webhooks
**Status:** 🚧 In Progress (Sprint 1)
**Goal:** Wire webhook alerts for the $15/month hard cap.

### Current State
- Webhook endpoint `/webhook/litellm-budget` added to `WebServer`
- Alerts forwarded to Telegram configured chat ID
- Environment variables: `LITELLM_BUDGET_WEBHOOK_URL`, `LITELLM_MONTHLY_BUDGET_USD`

### Pending
- Live test with actual LiteLLM proxy sending budget threshold payload
- Validate Telegram alert formatting
- Wire into n8n workflow if needed

---

*Last updated: Sprint 1*
