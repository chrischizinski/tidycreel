---
phase: 89-discovery-generics
reviewed: 2026-05-10T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - tidycreel.connect/R/creel-discovery.R
  - tidycreel.connect/R/creel-connection-api.R
  - tidycreel.connect/tests/testthat/test-discovery.R
  - tidycreel.connect/NAMESPACE
  - tidycreel.connect/man/list_creels.Rd
  - tidycreel.connect/man/search_creels.Rd
findings:
  critical: 1
  warning: 3
  info: 1
  total: 5
status: issues_found
---

# Phase 89: Code Review Report

**Reviewed:** 2026-05-10
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Phase 89 adds `list_creels()` and `search_creels()` S3 generics with methods for
`creel_connection_api`, `creel_connection_csv`, and `creel_connection_sqlserver`.
The structural design is sound: the empty-response early return, per-column coerce
guards, and not-supported stubs all follow established package patterns.

Three issues require attention before Phase 90 integration begins:

1. `search_creels()` passes the keyword string directly to `grepl()` without
   `fixed = TRUE`, meaning any regex-special character (e.g. `(`, `[`, `.`, `+`)
   in a keyword will produce an error or wrong results at runtime. This is the most
   impactful defect because it is a correctness bug visible to end users.

2. When the live API returns a non-empty response but none of the TODO-placeholder
   field names match, `list_creels()` silently returns a data frame with the correct
   row count but zero columns. The caller receives no indication that every column
   was dropped, which will make Phase 90 field-name debugging opaque.

3. The `endpoints` parameter in `creel_connect_api()` documentation (both the
   roxygen source and the generated Rd) lists five valid names but omits `discovery`,
   even though `discovery` is now a valid key that users can legitimately override.

---

## Critical Issues

### CR-01: `search_creels()` passes keyword to `grepl()` without `fixed = TRUE` — regex-special characters crash or mis-match

**File:** `tidycreel.connect/R/creel-discovery.R:108-109`

**Issue:** `grepl(keyword, df$title, ignore.case = TRUE)` and the matching
`df$description` call treat `keyword` as a regular expression. Any user-supplied
keyword containing a regex metacharacter — `(`, `)`, `[`, `]`, `.`, `+`, `*`, `?`,
`^`, `$`, `|`, `\` — will either throw a hard error (e.g., `"invalid regular
expression 'test['"`) or silently match differently than expected (e.g., `.` matches
any character). Because `keyword` is free-form user input this is a guaranteed
correctness failure for a non-trivial class of inputs.

Verified behaviour:

```r
> grepl("test[", "test123", ignore.case = TRUE)
Error: invalid regular expression 'test['
```

**Fix:** Add `fixed = TRUE` to both `grepl()` calls. This treats `keyword` as a
literal string, which is what the `@description` documents ("contains `keyword`"):

```r
match_title       <- grepl(keyword, df$title,       ignore.case = TRUE, fixed = TRUE)
match_description <- grepl(keyword, df$description, ignore.case = TRUE, fixed = TRUE)
```

Note: `fixed = TRUE` and `ignore.case = TRUE` are compatible in R since R 3.0.0 —
`ignore.case` still applies when `fixed = TRUE`.

---

## Warnings

### WR-01: Silent zero-column return when all TODO rename-map fields fail to match

**File:** `tidycreel.connect/R/creel-discovery.R:48-57`

**Issue:** When the live API response contains field names that do not match any of
the six TODO-placeholder names in `api_rename_map` (all are unconfirmed until Phase
90), `.rename_api_to_canonical()` returns a data frame with the original row count
but **zero columns**. The `%in% names(df)` coerce guards then all evaluate `FALSE`
and return the zero-column frame silently. The caller has no indication that every
expected column was absent — the returned object looks like a valid result (correct
`nrow()`) rather than a mapping failure.

Verified:

```r
# With 2-row raw response and zero matching field names:
# list_creels() returns a data.frame with nrow=2, ncol=0, names=character(0)
```

This is particularly important now because every field name in `api_rename_map` is a
TODO placeholder; the silent data loss will be the first symptom of a Phase 90
mismatch, and it will be confusing to diagnose.

**Fix:** After `.rename_api_to_canonical()`, assert that at least one expected column
was produced, or warn explicitly:

```r
df <- .rename_api_to_canonical(raw_df, api_rename_map)

if (ncol(df) == 0L) {
  cli::cli_warn(c(
    "{.fn list_creels}: API response contained no recognised fields.",
    "i" = "Raw field names: {.val {names(raw_df)}}",
    "i" = "Expected any of: {.val {unname(api_rename_map)}}"
  ))
}
```

A `cli_warn()` (not `cli_abort()`) is appropriate here because D-03 acknowledges the
field names are provisional — a warning surfaces the mismatch for Phase 90 debugging
without breaking any existing test.

---

### WR-02: `discovery` endpoint key omitted from `endpoints` parameter documentation

**File:** `tidycreel.connect/R/creel-connection-api.R:36-38`
**Rd file:** `tidycreel.connect/man/creel_connect_api.Rd:27-29`

**Issue:** The `@param endpoints` roxygen comment and the generated Rd both list five
valid override keys:

```
`interviews`, `counts`, `catch`, `harvest_lengths`, `release_lengths`
```

`discovery` was added to `.default_api_endpoints()` in this phase but was not added
to the documented list. A user who needs to point `list_creels()` at a non-default
endpoint path has no documented mechanism to do so, even though `creel_connect_api()`
will correctly accept `endpoints = list(discovery = "custom/path")`.

Runtime validation in `creel_connect_api()` already includes `discovery` in
`valid_names` (line 105) because it reads from `names(resolved_endpoints)`, so there
is no behaviour bug — only a documentation gap that affects discoverability.

**Fix:** Update the `@param endpoints` line to include `discovery`:

```r
#' @param endpoints Named list of endpoint path overrides. Valid names:
#'   `interviews`, `counts`, `catch`, `harvest_lengths`, `release_lengths`,
#'   `discovery`.
#'   Unspecified names retain their defaults.
```

Re-running `devtools::document()` will regenerate the Rd automatically.

---

### WR-03: `search_creels.creel_connection_sqlserver()` has no test

**File:** `tidycreel.connect/tests/testthat/test-discovery.R`

**Issue:** The test file covers:
- `list_creels.creel_connection_sqlserver()` — tested at line 61-65
- `search_creels.creel_connection_csv()` — tested at line 109-112

But `search_creels.creel_connection_sqlserver()` has no corresponding test. The
symmetry for `list_creels` (both csv and sqlserver tested) is not maintained for
`search_creels`. While the stub is three lines and clearly correct by inspection, the
asymmetry is a gap in the test matrix for the requirement (API-08 covers
not-supported errors).

**Fix:** Add the missing test:

```r
test_that("search_creels.creel_connection_sqlserver() aborts with not-supported error (API-08)", {
  conn_sql <- structure(list(), class = c("creel_connection_sqlserver", "creel_connection"))
  expect_error(search_creels(conn_sql, "test"), "not supported")
  expect_error(search_creels(conn_sql, "test"), "creel_connection_sqlserver")
})
```

---

## Info

### IN-01: Empty `body_text` emits a bare `x` bullet with no message in `cli_abort()`

**File:** `tidycreel.connect/R/creel-connection-api.R:221-225`

**Issue:** When `body_text` is `""` (empty response body), `cli_abort()` receives
`"x" = ""`, which renders as a `✖` bullet with no text — a cosmetic oddity in the
error output. Verified:

```r
> cli_abort(c("API request failed [404]", "i" = "Endpoint: foo", "x" = ""))
# Renders: ✖  (empty line after the x bullet)
```

This is not a crash and does not affect correctness, but it is slightly confusing
for a user who sees a lone `✖` with nothing after it.

**Fix:** Conditionally include the `"x"` bullet only when `body_text` is non-empty:

```r
msg <- c("API request failed [{status}]", "i" = "Endpoint: {endpoint}")
if (nzchar(body_text)) msg <- c(msg, "x" = body_text)
cli::cli_abort(msg)
```

---

_Reviewed: 2026-05-10_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
