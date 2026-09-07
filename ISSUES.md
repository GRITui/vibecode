# Local Issue Tracker

Mirrors and augments GitHub issues for offline/Sprint work.

---

## #1 — Telegram Bot MVP (GitHub #1)
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

## #2 — Evaluate z-ai/glm-5.2:free (GitHub #2)
**Status:** 🚧 In Progress (Sprint 1)
**Goal:** Test tool-calling reliability; decide if it replaces current primary or gets added to fallback chain.

### Current State
- Added `LLMConfig` module with model registry (thread-safe singleton)
- Fallback chain: `gpt-4o-mini` → `z-ai/glm-5.2:free` → `openai/gpt-4o-mini` → `anthropic/claude-3-haiku`
- `ModelRegistry` can record evaluations per model and recommend the lowest-latency reliable model
- Unit tests validate fallback chain inclusion, model selection, and registry recommendation logic
- Evaluation script `scripts/evaluate-model.sh` added for live testing

### Pending
- End-to-end tool-calling test with live `z-ai/glm-5.2:free` API
- Measure latency and reliability against real payloads
- Decision: primary replacement vs. fallback-only

---

## #3 — Configure LiteLLM Budget Alert Webhooks (GitHub #3)
**Status:** 🚧 In Progress (Sprint 1)
**Goal:** Wire webhook alerts for the $15/month hard cap.

### Current State
- Webhook endpoint `/webhook/litellm-budget` added to `WebServer`
- `LiteLLMBudgetAlert` parser handles LiteLLM JSON payload with budget fields
- Alerts forwarded to Telegram with formatted spend / limit / percentage summary
- Environment variables: `LITELLM_BUDGET_WEBHOOK_URL`, `LITELLM_MONTHLY_BUDGET_USD`
- Unit tests validate payload parsing (full and minimal)
- Integration test script `scripts/test-budget-webhook.sh` added

### Pending
- Live test with actual LiteLLM proxy sending budget threshold payload
- Wire into n8n workflow if needed

---

*Last updated: Sprint 1*
