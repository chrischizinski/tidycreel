# Phase 89: Discovery Generics - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-10
**Phase:** 89-Discovery Generics
**Areas discussed:** Discovery endpoint behavior, search_creels() filter strategy, NGPC field names, not-supported error wording, search columns, keyword case sensitivity

---

## Discovery Endpoint Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Return all surveys (ignore stored UIDs) | Discovery is about finding what's available before you know which UIDs to connect to. list_creels() calls GetAvailableCreels with no UID filter. | ✓ |
| Filter by stored creel_uids | The endpoint respects the connection's creel_uids — useful for checking which of your already-known UIDs are available. | |
| You decide | Claude picks the interpretation that best fits the discovery use case. | |

**User's choice:** Return all surveys (ignore stored UIDs)
**Notes:** Consistent with the purpose of list_creels() — users call it to find UIDs they don't yet know.

---

## search_creels() Filter Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Client-side (call list_creels() then grepl()) | No extra API round trip. Searches title and description columns in R. Simple and works offline. | ✓ |
| Server-side keyword param | Pass keyword to API endpoint as a query parameter. Only works if NGPC API supports keyword filtering. | |
| You decide | Claude picks based on what makes the most sense for a discovery pattern. | |

**User's choice:** Client-side (call list_creels() then grepl())
**Notes:** Avoids dependency on server-side filtering support in the NGPC API.

---

## NGPC Field Names for Discovery Response

| Option | Description | Selected |
|--------|-------------|----------|
| No — use TODO placeholders | Same approach as Phase 88 D-01: best-guess candidates with # TODO: confirm field name comments. Phase 90 validates against live data. | ✓ |
| Yes — I'll provide them | You know the actual NGPC field names for creel_uid, title, description, active, data_complete, comments. | |

**User's choice:** TODO placeholders
**Notes:** Same strategy as Phase 88 — live API inspection deferred to Phase 90 integration testing.

---

## Not-Supported Error Wording

| Option | Description | Selected |
|--------|-------------|----------|
| Method not supported (never will be) | e.g. "list_creels() is not supported for CSV connections. Use creel_connect_api() to connect to a REST API that supports discovery." | ✓ |
| Not yet implemented (may be later) | Same pattern as SQL Server fetch methods: "list_creels() for CSV connections not yet implemented." | |
| You decide | Claude picks the wording. | |

**User's choice:** Method not supported (never will be)
**Notes:** User selected the preview showing `cli_abort()` with `{.fn list_creels} is not supported for {.cls creel_connection_csv}` and `"i"` bullet directing to `creel_connect_api()`. Discovery is an API-only concept.

---

## Search Columns

| Option | Description | Selected |
|--------|-------------|----------|
| title only | Simplest. Most users will search by survey name. | |
| title + description | Broader match. Catches surveys described but not named with the keyword. | ✓ |
| title + description + comments | Widest match across all text columns. May return unexpected hits from comment content. | |
| You decide | Claude picks based on discoverability. | |

**User's choice:** title + description
**Notes:** Balance between discoverability and avoiding noise from comments.

---

## Keyword Case Sensitivity

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — case-insensitive (Recommended) | grepl(keyword, ..., ignore.case = TRUE). Standard for search UX. | ✓ |
| No — case-sensitive | User must match exact case. Rarely what you want for discovery. | |
| You decide | Claude picks. | |

**User's choice:** Case-insensitive
**Notes:** Standard expectation for a search/filter function.

---

## Claude's Discretion

- Column type coercion for `active` and `data_complete` (logical vs integer from JSON)
- Whether to add a discovery endpoint entry to `.default_api_endpoints()` or construct URL directly
- Exact TODO candidate field name guesses for the api_rename_map

## Deferred Ideas

None — discussion stayed within phase scope.
