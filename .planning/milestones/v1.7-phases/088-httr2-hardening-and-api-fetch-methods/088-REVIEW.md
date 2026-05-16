---
phase: 088-httr2-hardening-and-api-fetch-methods
reviewed: 2026-05-09T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - tidycreel.connect/R/creel-connection-api.R
  - tidycreel.connect/R/fetch-loaders.R
  - tidycreel.connect/DESCRIPTION
  - tidycreel.connect/NAMESPACE
  - tidycreel.connect/tests/testthat/helper-api.R
  - tidycreel.connect/tests/testthat/test-api-fetch.R
  - tidycreel.connect/tests/testthat/test-fetch-catch.R
  - tidycreel.connect/tests/testthat/test-fetch-counts.R
  - tidycreel.connect/tests/testthat/test-fetch-interviews.R
  - tidycreel.connect/tests/testthat/test-fetch-lengths.R
findings:
  critical: 0
  warning: 4
  info: 4
  total: 8
status: issues_found
---

# Phase 088: Code Review Report

**Reviewed:** 2026-05-09
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 088 delivers `.api_fetch()` hardening (retry, manual error handling, cli_abort) and five S3 methods on `creel_connection_api`: `fetch_interviews`, `fetch_counts`, `fetch_catch`, `fetch_harvest_lengths`, `fetch_release_lengths`. The domain constraints are correctly honored: `iiUID` (no underscore) is used for harvest/release length joins, `ii_UID` (with underscore) for interviews/catch, `catch_uid` and `length_uid` are synthesized via `seq_len(nrow(df))`, and `length_type` is a constant injected from the code rather than the API. The httr2 hardening pattern (`req_retry` before `req_error`) is correct for httr2 1.2.2 semantics and the code comment accurately explains the ordering rationale.

No blockers were found. Four warnings are raised: one is a silent data-corruption path in date parsing, two are correctness risks tied to unresolved API contract questions (documented as TODOs), and one is a test that cannot distinguish working retry behavior from absent retry behavior.

---

## Warnings

### WR-01: `.parse_api_date()` silently produces NA for unrecognized date formats

**File:** `tidycreel.connect/R/creel-connection-api.R:235-241`

**Issue:** The function tries two `tryFormats` formats and one `strptime` format. If none match, `result` contains `NA`. No warning is emitted and no caller checks for NA in the date column. The downstream validator (`validate_fetch_interviews`, `validate_fetch_counts`) checks only that the column `inherits(df[[col]], "Date")` — it passes even when all values are `NA`. A malformed date from the API (e.g., an ISO 8601 timestamp with timezone offset like `"2016-03-28T10:00:00+05:00"`) will silently produce an NA row that passes validation and propagates into estimator calculations.

**Fix:** Emit a warning when NA dates are produced from non-NA inputs after all formats are exhausted, so callers are informed:

```r
.parse_api_date <- function(x) {
  result  <- suppressWarnings(as.Date(x, tryFormats = c("%Y-%m-%d", "%m/%d/%Y")))
  na_mask <- is.na(result) & !is.na(x)
  if (any(na_mask)) {
    result[na_mask] <- as.Date(strptime(x[na_mask], "%Y-%m-%dT%H:%M:%S"))
  }
  # Warn on values that could not be parsed by any format
  still_na <- is.na(result) & !is.na(x)
  if (any(still_na)) {
    cli::cli_warn(c(
      "{sum(still_na)} date value{?s} could not be parsed and will be NA.",
      "i" = "Unparsed: {.val {unique(x[still_na])}}"
    ))
  }
  result
}
```

---

### WR-02: Effort column silently absent when API field names differ from expected — validator error is misleading

**File:** `tidycreel.connect/R/fetch-loaders.R:115-120`

**Issue:** The effort derivation `df$effort <- as.numeric(raw_df[[hours_col]]) + as.numeric(raw_df[[minutes_col]]) / 60` only fires when BOTH `"ii_TimeFishedHours"` and `"ii_TimeFishedMinutes"` are present in the raw API response (the `&&` condition on line 117). If either field is absent (e.g., because field names differ from expectation — both are flagged with `# TODO: confirm field name with live API`), the `effort` column is never added to `df`. The downstream call to `validate_fetch_interviews(df)` then aborts with:

```
fetch_interviews() validation failed:
x effort (numeric): column missing
```

This error message gives no indication that the root cause is missing API source fields (`ii_TimeFishedHours` / `ii_TimeFishedMinutes`), making diagnosis difficult. Moreover, if only one of the two fields is present, the condition silently skips rather than producing a partial or diagnostic result.

**Fix:** Produce a descriptive error when the effort fields are absent rather than deferring to the generic validator:

```r
hours_col   <- "ii_TimeFishedHours"
minutes_col <- "ii_TimeFishedMinutes"
hours_present   <- hours_col   %in% names(raw_df)
minutes_present <- minutes_col %in% names(raw_df)
if (hours_present && minutes_present) {
  df$effort <- as.numeric(raw_df[[hours_col]]) +
               as.numeric(raw_df[[minutes_col]]) / 60
} else {
  missing_fields <- c(hours_col[!hours_present], minutes_col[!minutes_present])
  cli::cli_abort(c(
    "Cannot compute {.field effort}: required API field{?s} absent from response.",
    "x" = "Missing: {.val {missing_fields}}"
  ))
}
```

---

### WR-03: `ir_Count` silently dropped in `fetch_release_lengths.creel_connection_api()` — aggregated rows are undercounted

**File:** `tidycreel.connect/R/fetch-loaders.R:414-415`

**Issue:** The NGPC release lengths endpoint returns `ir_Count` alongside `ir_LengthGroup`. The code silently drops `ir_Count`:

```r
# ir_Count is NOT renamed — no canonical target; dropped silently
# TODO: confirm ir_Count aggregation policy with live API
```

If the API pre-aggregates records (i.e., one row represents `ir_Count` fish at that length group), then discarding `ir_Count` produces incorrect length frequency data. For a row with `ir_Count = 5`, the current code produces one row with `length_mm` set to the group value instead of five rows (or any other correct expansion). The test fixture uses `ir_Count = 1`, which hides this defect entirely.

**Fix:** Before shipping to production, confirm the API aggregation contract. If rows are aggregated, expand by count or reject aggregated responses with a clear error. The TODO must be resolved; this is not safe to ship to live data without verification.

Interim hardening — error if `ir_Count` > 1 is detected, to prevent silent miscalculation:

```r
if ("ir_Count" %in% names(raw_df)) {
  if (any(raw_df[["ir_Count"]] > 1L, na.rm = TRUE)) {
    cli::cli_abort(c(
      "Release lengths API response contains aggregated rows ({.field ir_Count} > 1).",
      "i" = "Expansion of aggregated length groups is not yet implemented.",
      "i" = "Resolve aggregation policy before using live API data."
    ))
  }
}
```

---

### WR-04: Retry test cannot verify that `req_retry` actually fires — passes even if retry is broken

**File:** `tidycreel.connect/tests/testthat/test-api-fetch.R:43-51`

**Issue:** The test provides three mocked 429 responses and expects an error:

```r
expect_error(fetch_interviews(conn), "API request failed")
```

This test will also pass if `req_retry` is removed entirely from `.api_fetch()`. Without retry, the first 429 response is returned, the manual `status >= 400L` check fires, and `cli_abort("API request failed [429]")` is raised — producing the exact same error message the test expects. The retry mechanism is not verified; only the final error is asserted.

**Fix:** Verify that all three mocked responses were consumed (i.e., that three HTTP requests were made). One approach with httr2's mocking is to assert the list is exhausted after the call. A pragmatic alternative is to use a counter via `local()`:

```r
test_that(".api_fetch() retries 3 times on 429 then aborts", {
  attempt_count <- 0L
  httr2::local_mocked_responses(function(req) {
    attempt_count <<- attempt_count + 1L
    httr2::response(429, headers = "Content-Type: application/json", body = charToRaw(""))
  })
  conn <- make_api_conn()
  expect_error(fetch_interviews(conn), "API request failed")
  expect_equal(attempt_count, 3L)  # Confirms retry fired twice after initial attempt
})
```

---

## Info

### IN-01: `stringsAsFactors = FALSE` is redundant in all zero-row `data.frame()` calls

**File:** `tidycreel.connect/R/fetch-loaders.R:95-103, 172-178, 241-249, 318-327, 398-407`

**Issue:** `DESCRIPTION` declares `R (>= 4.1.0)`. Since R 4.0.0, `stringsAsFactors` defaults to `FALSE`. The argument is present in all five early-return data frames (one per fetch method). It is harmless but adds noise.

**Fix:** Remove `stringsAsFactors = FALSE` from all five zero-row `data.frame()` constructor calls.

---

### IN-02: Empty `"x"` cli bullet when API error response has an empty body

**File:** `tidycreel.connect/R/creel-connection-api.R:218-222`

**Issue:** When the error body is empty (`body_text = ""`), the cli_abort call produces:

```r
cli::cli_abort(c(
  "API request failed [404]",
  "i" = "Endpoint: AnalysisData/GetInterviewData",
  "x" = ""   # renders as a blank "x" bullet
))
```

The rendered error message shows a dangling `x` marker with no content. This is cosmetically confusing but does not cause incorrect behavior.

**Fix:** Conditionally include the body bullet only when `body_text` is non-empty:

```r
msg <- c("API request failed [{status}]", "i" = "Endpoint: {endpoint}")
if (nzchar(body_text)) msg <- c(msg, "x" = body_text)
cli::cli_abort(msg)
```

---

### IN-03: API integration tests do not assert actual column values for `catch_count`

**File:** `tidycreel.connect/tests/testthat/test-fetch-interviews.R:85`, `test-fetch-catch.R:61`

**Issue:** Both API tests check that `catch_count` is numeric (`is.numeric(result$catch_count)`) but do not assert the actual value parsed from the mock JSON (e.g., `"Num":2`). A renaming or type-coercion regression that produces `NA` or the wrong value would not be caught.

**Fix:** Add value assertions to the existing tests:

```r
# In test-fetch-interviews.R:
expect_equal(result$catch_count, 2)

# In test-fetch-catch.R:
expect_equal(result$catch_count, 2)
```

---

### IN-04: Test coverage asymmetry between `fetch_harvest_lengths` and `fetch_release_lengths` empty API response

**File:** `tidycreel.connect/tests/testthat/test-fetch-lengths.R:84-88` vs `113-123`

**Issue:** The release lengths empty test (line 122) checks the actual value of `length_type`:

```r
expect_equal(character(0), result$length_type)
```

The harvest lengths empty test (line 87) only checks column presence:

```r
expect_true("length_type" %in% names(result))
```

This asymmetry is minor but means the harvest case does not verify that `length_type` is character class in the zero-row case.

**Fix:** Add type-class and value assertion to the harvest lengths empty test for consistency with the release test:

```r
expect_true(is.character(result$length_type))
expect_equal(character(0), result$length_type)
```

---

_Reviewed: 2026-05-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
