# Phase 88: httr2 Hardening and API Fetch Methods - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-09
**Phase:** 88 — httr2 Hardening and API Fetch Methods
**Areas discussed:** Unknown API field names, catch_uid / length_uid synthesis, Test strategy for API methods, req_retry / error scope

---

## Unknown API Field Names

| Option | Description | Selected |
|--------|-------------|----------|
| Best-guess + TODO comments | Use candidate names from STATE.md, mark with TODO, validate in Phase 90 | ✓ |
| Inspect reference code first | Read existing reference scripts before writing any rename maps | |
| Hard-code knowns, stub unknowns | Write rename maps only for confirmed fields; return NA for unknowns | |

**User's choice:** Best-guess + TODO comments
**Notes:** No additional reference docs beyond STATE.md candidates. Use `ii_NumberAnglers` for angler count in GetCountData (TODO: confirm). `ir_Count` aggregation policy is unresolved — add TODO and pick sensible default.

**Follow-up Q — Additional reference docs:**

| Option | Description | Selected |
|--------|-------------|----------|
| No — just use STATE.md candidates | No additional docs to reference | ✓ |
| Yes — there are scripts/docs in the repo | Point to file path | |

---

## catch_uid / length_uid Synthesis

| Option | Description | Selected |
|--------|-------------|----------|
| Synthesize as row number | `seq_len(nrow(df))` if absent from API response | ✓ |
| Return NA column | Add NA column with correct name | |
| Drop from API canonical contract | Change validators; API path has different column set | |

**User's choice:** Synthesize as row number
**Notes:** Keeps the canonical contract intact so downstream code works identically for CSV and API paths.

**Follow-up Q — Where synthesis happens:**

| Option | Description | Selected |
|--------|-------------|----------|
| Inside each fetch_* method | Conditional: only add seq_len() if column absent | ✓ |
| Inside .api_fetch() | Pass expected UID column names to .api_fetch() | |

---

## Test Strategy for API Methods

| Option | Description | Selected |
|--------|-------------|----------|
| httr2 mock responses | `local_mocked_responses()` — no extra dependencies | ✓ |
| httptest2 package | Record real API responses as fixtures | |
| Skip — defer to Phase 90 | No unit tests; validate in integration script only | |

**User's choice:** httr2 mock responses

**Follow-up Q — Coverage (multi-select):**

| Scenario | Selected |
|----------|----------|
| Happy path — canonical columns returned | ✓ |
| Empty response — 0-row data frame | ✓ |
| Non-2xx error handling | ✓ |
| Retry behavior (429/503) | ✓ |

**Notes:** All four scenarios selected. Full coverage in Phase 88 tests.

---

## req_retry / Error Scope

**Q1 — Retry codes:**

| Option | Description | Selected |
|--------|-------------|----------|
| 429 and 503 only | Exactly per requirement | ✓ |
| 429, 503, and 502 | Also retry on Bad Gateway | |
| Any 5xx + 429 | Retry all server errors | |

**Q2 — Backoff strategy:**

| Option | Description | Selected |
|--------|-------------|----------|
| httr2 default — exponential backoff | Respects Retry-After headers | ✓ |
| Fixed 1-second delay | Simpler but less adaptive | |

**Q3 — Error message content:**

| Option | Description | Selected |
|--------|-------------|----------|
| HTTP status + parsed error body | `cli::cli_abort()` with status, endpoint, JSON body | ✓ |
| HTTP status only | Simpler but loses API context | |
| HTTP status + raw body string | Avoids JSON parse errors on HTML bodies | |

**Notes:** Use `req_error()` to disable httr2 auto-error, then check `resp_status()` manually to build the cli message with full context.

---

## Claude's Discretion

None — all areas had user decisions.

## Deferred Ideas

None — discussion stayed within phase scope.
