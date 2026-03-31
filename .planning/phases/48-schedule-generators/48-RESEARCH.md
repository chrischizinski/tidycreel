# Phase 48: Schedule Generators - Research

**Researched:** 2026-03-23
**Domain:** R date arithmetic, S3 class construction, file I/O (CSV/xlsx), tidy selectors
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Sampling intensity API**
- Accept either `n_days` (integer total) or `sampling_rate` (fraction 0–1) — not both at once; function errors if both are supplied
- Intensity is stratified by day type: both parameters accept a named vector (e.g., `c(weekday = 0.3, weekend = 0.6)`) OR a scalar that expands uniformly across all strata
- Sampling days are randomly selected within each stratum; a `seed` argument is required for reproducibility
- Sampling operates at the day level by default (a day is in or out; all its periods are included); an optional `period_intensity` argument enables sub-day period-level selection

**Period structure**
- `period_id` defaults to ordinal integers (1, 2, 3, …); an optional `period_labels` argument substitutes human-readable names
- Default output is one row per day × period (expanded form); `expand_periods = FALSE` collapses to one row per sampling day
- Default output includes sampled days only; `include_all = TRUE` returns the full season calendar with a `sampled` logical column
- When `period_labels` are supplied, `period_id` is character by default; `ordered_periods = TRUE` returns an ordered factor

**Bus route circuit input**
- `generate_bus_schedule()` mirrors the `creel_design(survey_type = "bus_route")` API
- Accepts a `sampling_frame` data frame with same structure as `creel_design()`
- Uses tidy selectors for `site`, `circuit`, and `p_site` columns (same argument names as `creel_design()`)
- Adds a `crew` scalar argument for crew size, which influences inclusion probability computation
- Output tibble has `inclusion_prob` columns that feed directly into `creel_design(survey_type = "bus_route")`

**File round-trip fidelity**
- `read_schedule()` uses column name matching for type coercion — no embedded metadata rows, no sidecar files
- After coercion, `read_schedule()` validates column values: checks `day_type` values, dates in plausible range, `period_id` positive; aborts with `cli_abort()` on failure
- Same coercion logic for both CSV and xlsx — no format-specific code paths
- `readxl` added to Suggests; `rlang::check_installed("readxl")` guard (mirrors `writexl` pattern)

### Claude's Discretion

- `creel_schedule` S3 class design — use the `c("creel_schedule", "data.frame")` tibble subclass pattern consistent with `creel_summary_*` objects
- Exact column names in the fixed schema beyond `date`, `day_type`, `period_id`, `sampled` — confirm from `creel-design.R` test fixtures
- Internal date arithmetic implementation using `lubridate` (already decided in STATE.md)
- Error message wording and `cli_abort()` call structure

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SCHED-01 | User can generate a sampling calendar given season start/end dates, weekday/weekend day split, number of periods per day, and sampling intensity as a tidy tibble | Date sequence generation, day-type classification, stratified random sampling, period expansion |
| SCHED-02 | User can generate a bus-route schedule given a sampling calendar plus circuit definitions, sites per circuit, crew size, and seed — output has `inclusion_prob` columns ready for `creel_design(survey_type = "bus_route")` | Mirrors existing `creel_design()` tidy-selector API; `pi_i = p_site × p_period` already in codebase |
| SCHED-03 | User can export any schedule tibble to CSV (base R) or xlsx (writexl, optional) for field use | `write.csv()` base R; `writexl::write_xlsx()` with `rlang::check_installed()` guard |
| SCHED-04 | User can read a previously saved schedule file back into R as a validated `creel_schedule` object with correct column types, ready to pass to `creel_design()` | Column-name-based coercion, `checkmate::makeAssertCollection()` validation, `readxl` in Suggests |
</phase_requirements>

---

## Summary

Phase 48 builds four public functions (`generate_schedule()`, `generate_bus_schedule()`, `write_schedule()`, `read_schedule()`) on top of an internal `creel_schedule` S3 class. The code domain is almost entirely internal R patterns already in the codebase: date arithmetic via `lubridate`, tidy column selectors via `rlang::enquo()` + `resolve_single_col()`, validator construction via `checkmate::makeAssertCollection()`, and error handling via `cli::cli_abort()`.

The canonical `creel_design()` calendar schema is confirmed from code inspection: a data frame with a `date` column (class `Date`) and one or more character/factor strata columns. `day_type` is stored as character throughout. The `$calendar` slot of a `creel_design` object is the direct pass-through of whatever data frame is supplied. `generate_schedule()` must produce a tibble that satisfies `validate_calendar_schema()` (one Date column + one character/factor column), so the minimum required columns are `date` (Date) and `day_type` (character). Additional columns `period_id` (integer or character) and, when `include_all = TRUE`, `sampled` (logical) complete the schema.

The biggest implementation risk is the file round-trip: Excel opens CSVs with locale-dependent date formatting and can silently reformat date columns. The `read_schedule()` coercion layer must handle at least `character → as.Date()`, Excel serial-number dates (numeric → as.Date(origin = "1899-12-30")), and POSIXct → as.Date() without special-casing CSV vs xlsx. This design decision is locked and confirmed in CONTEXT.md.

**Primary recommendation:** Write the code in the order `generate_schedule()` → `generate_bus_schedule()` → `write_schedule()` → `read_schedule()` → validator. Each function builds on or is tested against the previous one, and the round-trip test (success criterion 5) closes the loop.

---

## Standard Stack

### Core (already in DESCRIPTION Imports)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| lubridate | >= 1.9.5 | DST-safe date sequences, weekday detection | Decided in STATE.md; base `seq.Date()` skips DST days in some locales |
| rlang | existing | `enquo()`, `check_installed()`, `cli_abort()` | Package-wide pattern |
| tidyselect | >= 1.2.0 | Tidy column selectors in `generate_bus_schedule()` | Matches `creel_design()` API exactly |
| checkmate | existing | `makeAssertCollection()` for batch validation in `read_schedule()` | Package-wide pattern |
| cli | existing | `cli_abort()` error messages | Package-wide pattern |
| tibble | existing | `as_tibble()` for output class construction | Package-wide for data frame outputs |

### Supporting (add to DESCRIPTION Suggests)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| writexl | >= 1.5.4 | xlsx export in `write_schedule()` | Optional; zero transitive deps; decided in STATE.md |
| readxl | >= 1.4.0 | xlsx reading in `read_schedule()` | Optional; `rlang::check_installed("readxl")` guard |

**lubridate is NOT yet in DESCRIPTION** — it must be added to `Imports` in this phase. `writexl` and `readxl` are NOT yet in DESCRIPTION — both must be added to `Suggests`.

**Installation (adds to DESCRIPTION):**
```r
# Imports: lubridate (>= 1.9.5)
# Suggests: writexl (>= 1.5.4), readxl (>= 1.4.0)
usethis::use_package("lubridate", min_version = "1.9.5")
usethis::use_package("writexl", type = "Suggests", min_version = "1.5.4")
usethis::use_package("readxl", type = "Suggests", min_version = "1.4.0")
```

---

## Architecture Patterns

### Confirmed creel_design() Calendar Schema

From code inspection of `R/creel-design.R` and `tests/testthat/test-creel-design.R`:

```r
# Minimum valid calendar — passes validate_calendar_schema() and creel_design()
data.frame(
  date     = as.Date(c("2024-06-01", "2024-06-02")),
  day_type = c("weekday", "weekend")  # character, NOT factor
)
```

- `date`: class `Date` (not character, not POSIXct, not numeric)
- `day_type`: class `character` (not factor — this is enforced throughout codebase)
- `validate_calendar_schema()` checks: ≥1 Date column + ≥1 character/factor column

**`generate_schedule()` minimum output columns:**

| Column | Type | Notes |
|--------|------|-------|
| `date` | Date | One row per sampled day × period (expanded form default) |
| `day_type` | character | "weekday" or "weekend" — always character |
| `period_id` | integer or character | Integer by default; character when `period_labels` supplied |
| `sampled` | logical | Only present when `include_all = TRUE` |

### Recommended File Structure

```
R/
├── schedule-generators.R      # generate_schedule(), generate_bus_schedule()
├── schedule-io.R              # write_schedule(), read_schedule()
├── creel-design.R             # existing — no changes needed
└── validate-schemas.R         # existing — add validate_creel_schedule() here
tests/testthat/
├── test-schedule-generators.R # SCHED-01, SCHED-02 tests
└── test-schedule-io.R         # SCHED-03, SCHED-04, round-trip tests
```

### Pattern 1: S3 Tibble Subclass Construction (creel_schedule)

The project uses `class(obj) <- c("creel_summary_*", "data.frame")` for all summary tibble subclasses. The `creel_schedule` class follows the same pattern:

```r
# Source: R/creel-summaries.R lines 96-99, confirmed pattern
new_creel_schedule <- function(data) {
  stopifnot(is.data.frame(data))
  class(data) <- c("creel_schedule", "data.frame")
  data
}
```

This is a simple class attribute assignment (not `structure(list(...))` — that is used only for non-tibble objects like `creel_design`).

### Pattern 2: Tidy Selector Resolution (for generate_bus_schedule)

`generate_bus_schedule()` must use the same resolver pattern as `creel_design()`:

```r
# Source: R/creel-design.R lines 803-818 (resolve_single_col — internal helper)
generate_bus_schedule <- function(schedule, sampling_frame, site, circuit = NULL,
                                  p_site, crew, seed = NULL) {
  site_quo    <- rlang::enquo(site)
  circuit_quo <- rlang::enquo(circuit)
  p_site_quo  <- rlang::enquo(p_site)

  site_col   <- resolve_single_col(site_quo,   sampling_frame, "site",   rlang::caller_env())
  p_site_col <- resolve_single_col(p_site_quo, sampling_frame, "p_site", rlang::caller_env())
  # circuit_col optional: resolve only if !rlang::quo_is_null(circuit_quo)
}
```

`resolve_single_col` and `resolve_multi_cols` are defined in `R/creel-design.R` as internal (`@noRd`) functions. `generate_bus_schedule()` lives in the same package so can call them directly.

### Pattern 3: Batch Validation (checkmate::makeAssertCollection)

```r
# Source: R/validate-schemas.R lines 15-43 — canonical project pattern
validate_creel_schedule <- function(data) {
  collection <- checkmate::makeAssertCollection()
  checkmate::assert_data_frame(data, min.rows = 1, add = collection)

  if (is.data.frame(data) && nrow(data) > 0) {
    # Check required columns exist
    req_cols <- c("date", "day_type", "period_id")
    missing  <- setdiff(req_cols, names(data))
    if (length(missing) > 0) {
      collection$push(paste0("Missing required columns: ", paste(missing, collapse = ", ")))
    }

    # Type checks (only if columns present)
    if ("date" %in% names(data) && !inherits(data$date, "Date")) {
      collection$push("Column 'date' must be class Date")
    }
    if ("day_type" %in% names(data) && !is.character(data$day_type)) {
      collection$push("Column 'day_type' must be character")
    }
    # Value checks: date range, day_type values, period_id > 0
    if ("date" %in% names(data) && inherits(data$date, "Date")) {
      if (any(data$date < as.Date("1970-01-01") | data$date > as.Date("2100-01-01"))) {
        collection$push("Column 'date' contains implausible values")
      }
    }
  }

  if (!collection$isEmpty()) {
    msgs <- collection$getMessages()
    cli::cli_abort(c(
      "Schedule validation failed:",
      stats::setNames(msgs, rep("x", length(msgs))),
      "i" = "Use generate_schedule() or read_schedule() to create valid creel_schedule objects."
    ))
  }
  invisible(data)
}
```

### Pattern 4: rlang::check_installed Guard (for readxl/writexl)

```r
# Source: decided in STATE.md; mirrors writexl pattern already in project
write_schedule <- function(schedule, path, format = c("csv", "xlsx")) {
  format <- match.arg(format)
  if (format == "xlsx") {
    rlang::check_installed("writexl", reason = "to write xlsx files")
    writexl::write_xlsx(schedule, path)
  } else {
    utils::write.csv(schedule, path, row.names = FALSE)
  }
  invisible(path)
}

read_schedule <- function(path) {
  ext <- tools::file_ext(path)
  if (ext %in% c("xlsx", "xls")) {
    rlang::check_installed("readxl", reason = "to read xlsx files")
    raw <- readxl::read_excel(path)
  } else {
    raw <- utils::read.csv(path, stringsAsFactors = FALSE)
  }
  coerce_schedule_columns(raw)  # shared coercion — no format-specific paths
}
```

### Pattern 5: DST-Safe Date Arithmetic with lubridate

```r
# lubridate::seq() is DST-safe; base seq.Date() can skip days at DST boundaries
# in some locales. Decision from STATE.md.
season_dates <- seq(
  lubridate::ymd(start_date),
  lubridate::ymd(end_date),
  by = "1 day"
)
# Classify weekday vs weekend
day_types <- ifelse(
  lubridate::wday(season_dates, week_start = 1) %in% c(6, 7),
  "weekend",
  "weekday"
)
```

### Pattern 6: Stratified Random Day Selection

```r
# Within each day_type stratum, sample with set.seed(seed)
select_sampled_days <- function(dates, day_types, n_days = NULL, sampling_rate = NULL,
                                 seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  # Split by stratum, sample within each, recombine
  strata <- unique(day_types)
  sampled <- logical(length(dates))
  for (s in strata) {
    idx  <- which(day_types == s)
    n_s  <- if (!is.null(n_days)) n_days[[s]] else round(length(idx) * sampling_rate[[s]])
    n_s  <- min(n_s, length(idx))
    sampled[sample(idx, n_s)] <- TRUE
  }
  sampled
}
```

### Pattern 7: Column-Name-Based Coercion for read_schedule()

```r
# Shared coercion — no CSV vs xlsx branch. Handles the common Excel workflows:
# 1. Date stored as character (Excel saved as text): as.Date(x)
# 2. Date stored as Excel serial number (numeric): as.Date(as.integer(x), origin = "1899-12-30")
# 3. Date stored as POSIXct (readxl default for date-formatted cells): as.Date(x)
coerce_schedule_columns <- function(df) {
  if ("date" %in% names(df)) {
    df$date <- coerce_to_date(df$date)
  }
  if ("day_type" %in% names(df)) {
    df$day_type <- as.character(df$day_type)
  }
  if ("period_id" %in% names(df)) {
    df$period_id <- suppressWarnings(as.integer(df$period_id))
  }
  if ("sampled" %in% names(df)) {
    df$sampled <- as.logical(df$sampled)
  }
  df
}

coerce_to_date <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXct") || inherits(x, "POSIXlt")) return(as.Date(x))
  if (is.numeric(x)) return(as.Date(as.integer(x), origin = "1899-12-30"))
  # character: try standard ISO first, then common formats
  parsed <- tryCatch(as.Date(x), error = function(e) NA_Date_)
  parsed
}
```

### Anti-Patterns to Avoid

- **Using `factor` for `day_type`:** All existing code stores `day_type` as character. Using factor would break `validate_calendar_schema()` (which accepts both but creates inconsistency) and downstream join operations.
- **Using `Sys.time()` as default seed:** Makes tests non-reproducible. The `seed` argument is required, not optional.
- **Format-specific code paths in read_schedule():** CONTEXT.md locks this — same coercion logic for CSV and xlsx.
- **Using `seq.Date()` without lubridate for long seasons:** May miss DST-transition days in some locales. Always use `lubridate::ymd()` + `seq()` or `lubridate::interval()`.
- **Assuming named vector has names matching day_type values:** Must validate that names in `n_days`/`sampling_rate` vector match the actual day types in the season (e.g., user passes `c(weekday=0.3, weekend=0.6)` but a custom day_type split uses different names).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| xlsx writing | Custom binary format encoder | `writexl::write_xlsx()` | xlsx spec is complex; writexl has zero transitive deps |
| xlsx reading | Custom binary parser | `readxl::read_excel()` | Date cell types vary by Excel version; readxl handles all cases |
| Date sequence generation | Manual loop over days | `lubridate` + `seq()` | DST safety, locale handling |
| Tidy column selection | Manual `match()` on column names | `rlang::enquo()` + `resolve_single_col()` | Already in codebase; handles rename, helpers, multiple matches |
| Batch input validation | Individual `if/stop()` chains | `checkmate::makeAssertCollection()` | Collects all errors before aborting; project-wide pattern |
| Package availability check | `requireNamespace()` + manual error | `rlang::check_installed()` | Provides actionable install message automatically |

**Key insight:** The project already solved all the hard problems (tidy selectors, batch validation, optional-package guards). Phase 48 composes these existing pieces rather than inventing new patterns.

---

## Common Pitfalls

### Pitfall 1: Excel Serial-Number Dates in CSV Round-Trip

**What goes wrong:** A biologist opens the exported CSV in Excel, makes no edits, saves as CSV. Excel reformats the `date` column from ISO "2024-06-01" to a locale-specific string (e.g., "6/1/2024" on US systems or "01.06.2024" on European systems), or in rare cases to a serial number (44713.0). `as.Date()` without a format argument fails silently or returns NA for non-ISO strings.

**Why it happens:** Excel treats CSV column contents as data, not as typed values. Date detection is locale-dependent.

**How to avoid:** In `coerce_to_date()`, try ISO `as.Date(x)` first, then fall back to `as.Date(as.integer(x), origin = "1899-12-30")` for serial numbers. For character formats, accept both ISO and common locale variants using explicit `format` arguments. Log a warning (not an abort) if some dates coerced with fallback logic.

**Warning signs:** `NA` values in `date` column after `read_schedule()`.

### Pitfall 2: Seed Reproducibility Across R Sessions

**What goes wrong:** `set.seed()` is called inside the function body but the global RNG state is not saved/restored. Functions that call `generate_schedule()` inside other code may have different results depending on what RNG calls preceded them.

**Why it happens:** `set.seed()` modifies global RNG state. R does not have a scoped RNG mechanism in base.

**How to avoid:** Use `withr::with_seed(seed, { ... })` internally to scope the RNG change. `withr` is already in Suggests. Alternatively, save and restore with `old_seed <- .Random.seed; set.seed(seed); on.exit(.Random.seed <<- old_seed)`. `withr::with_seed()` is cleaner.

**Warning signs:** Tests that check specific sampled day sets pass in isolation but fail when run in a different order.

### Pitfall 3: p_site Sum-to-One Constraint in generate_bus_schedule()

**What goes wrong:** `creel_design(survey_type = "bus_route")` validates that `p_site` values sum to 1.0 within each circuit (tolerance 1e-6). If `generate_bus_schedule()` produces a sampling frame where this constraint is violated, the user gets a confusing `creel_design()` error at the next step rather than an actionable error at schedule generation time.

**Why it happens:** Crew allocation can produce inclusion probabilities that don't sum to 1 if not explicitly normalized.

**How to avoid:** `generate_bus_schedule()` should validate or normalize `p_site` within each circuit before returning. Document the constraint in the function signature.

**Warning signs:** `creel_design()` fails with "p_site values must sum to 1.0" when given `generate_bus_schedule()` output.

### Pitfall 4: Period Expansion Producing Unexpectedly Large Tibbles

**What goes wrong:** A 180-day season with 3 periods per day in expanded form = 540 rows. A 270-day season with 4 periods = 1,080 rows. Users may not anticipate this and be surprised by large output.

**Why it happens:** Default behavior is expanded (one row per day × period).

**How to avoid:** Document in the function's `@description` that expanded form row count = (sampled days) × n_periods. Consider printing a one-line summary in a `print.creel_schedule` method.

### Pitfall 5: creel_schedule Class Not Surviving write/read Round-Trip

**What goes wrong:** `write_schedule()` writes to CSV (which has no class metadata). `read_schedule()` returns a plain `data.frame`. The `creel_schedule` class attribute is lost. Downstream code that checks `inherits(x, "creel_schedule")` fails.

**Why it happens:** CSV format stores no R metadata.

**How to avoid:** `read_schedule()` must explicitly assign the class after coercion and validation: `new_creel_schedule(coerced_df)`. This is the closed round-trip: write strips the class, read restores it.

---

## Code Examples

### generate_schedule() Skeleton

```r
# Source: R/creel-design.R patterns + lubridate docs
generate_schedule <- function(
    start_date, end_date,
    n_periods,
    n_days       = NULL,
    sampling_rate = NULL,
    period_labels = NULL,
    expand_periods = TRUE,
    include_all    = FALSE,
    ordered_periods = FALSE,
    period_intensity = NULL,
    seed) {

  # 1. Validate mutually-exclusive intensity args
  if (!is.null(n_days) && !is.null(sampling_rate)) {
    cli::cli_abort(c(
      "Supply {.arg n_days} or {.arg sampling_rate}, not both.",
      "x" = "Both arguments were non-NULL."
    ))
  }

  # 2. Build season date sequence (lubridate DST-safe)
  all_dates  <- seq(lubridate::ymd(start_date), lubridate::ymd(end_date), by = "1 day")
  day_types  <- ifelse(lubridate::wday(all_dates, week_start = 1) %in% 6:7,
                       "weekend", "weekday")

  # 3. Stratified random sampling
  sampled <- withr::with_seed(seed, select_sampled_days(all_dates, day_types,
                                                         n_days, sampling_rate))

  # 4. Build base tibble
  base <- tibble::tibble(date = all_dates, day_type = day_types, sampled = sampled)
  if (!include_all) base <- base[base$sampled, ]

  # 5. Expand periods
  if (expand_periods) {
    base <- expand_periods_impl(base, n_periods, period_labels, ordered_periods)
  }
  if (!include_all) base$sampled <- NULL  # drop if not requested

  new_creel_schedule(base)
}
```

### read_schedule() Coercion Chain

```r
# Source: CONTEXT.md locked decision + coerce_to_date() pattern above
read_schedule <- function(path) {
  ext <- tools::file_ext(path)
  if (tolower(ext) %in% c("xlsx", "xls")) {
    rlang::check_installed("readxl", reason = "to read xlsx schedule files")
    raw <- readxl::read_excel(path, col_types = "text")  # read all as text first
  } else {
    raw <- utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character")
  }
  coerced <- coerce_schedule_columns(raw)  # shared, no format branches
  validate_creel_schedule(coerced)
  new_creel_schedule(coerced)
}
```

Reading xlsx with `col_types = "text"` forces all columns to character, then the shared `coerce_schedule_columns()` handles type restoration uniformly.

### Round-Trip Test Pattern

```r
test_that("schedule round-trips through write and read", {
  sched <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 2, sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42
  )
  tmp <- withr::local_tempfile(fileext = ".csv")
  write_schedule(sched, tmp)
  sched2 <- read_schedule(tmp)

  expect_s3_class(sched2, "creel_schedule")
  expect_equal(sched$date,      sched2$date)
  expect_equal(sched$day_type,  sched2$day_type)
  expect_equal(sched$period_id, sched2$period_id)

  # Confirm passes creel_design() without error
  expect_no_error(
    creel_design(sched2, date = date, strata = day_type)
  )
})
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `seq.Date()` for date ranges | `lubridate::ymd()` + `seq()` | lubridate >= 1.9.0 | DST safety, locale independence |
| `requireNamespace()` guard | `rlang::check_installed()` | rlang >= 1.0.0 | Actionable install message automatically |
| Manual class assignment as scalar | `c("subclass", "data.frame")` vector | tidyverse S3 convention | Enables method dispatch and `inherits()` |
| `read.csv(colClasses=...)` type specification | Read all as `"text"` then coerce | readxl pattern | Handles Excel date integer codes uniformly |

**Not deprecated but noteworthy:**
- `class(obj) <- c("creel_schedule", "data.frame")`: The project uses this pattern (not `vctrs::new_vctr` or `tibble::new_tibble`) for all summary subclasses. Phase 48 must match.
- `structure(list(...), class = "creel_design")`: The `creel_design` class is a named list, NOT a tibble subclass. `creel_schedule` is a tibble/data.frame subclass — different constructor approach.

---

## Open Questions

1. **Exact `day_type` allowed values**
   - What we know: `creel_design()` accepts any character values in the strata column; "weekday" and "weekend" appear in all test fixtures
   - What's unclear: Should `generate_schedule()` hard-code "weekday"/"weekend" or accept a custom `day_type_labels` argument?
   - Recommendation: Hard-code "weekday"/"weekend" for v0.9.0; CONTEXT.md does not mention custom labels, and SCHED-F01 (deferred) is where routing complexity lives

2. **Inclusion probability formula for generate_bus_schedule()**
   - What we know: `creel_design()` computes `pi_i = p_site × p_period`. Crew size is a new argument not in `creel_design()`.
   - What's unclear: How does `crew` modify `p_period`? The most natural interpretation is `p_period = crew × (period_duration / open_hours)`, but this is not specified in CONTEXT.md.
   - Recommendation: Planner should define the formula explicitly in Wave 0 or ask user; default assumption is `p_period` is computed as `(crew × surveys_per_period) / n_total_circuits`

3. **`period_intensity` argument scope**
   - What we know: An optional `period_intensity` argument enables sub-day period-level selection
   - What's unclear: Whether this is in scope for v0.9.0 SCHED-01 or deferred
   - Recommendation: Implement argument stub with `NULL` default and `cli_abort()` "not yet implemented" if non-NULL — allows API stability without implementation cost

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat >= 3.0.0 (edition 3) |
| Config file | `DESCRIPTION` (Config/testthat/edition: 3) |
| Quick run command | `testthat::test_file("tests/testthat/test-schedule-generators.R")` |
| Full suite command | `devtools::test()` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCHED-01 | `generate_schedule()` returns tibble with `date` (Date), `day_type` (character), `period_id` (integer) | unit | `testthat::test_file("tests/testthat/test-schedule-generators.R")` | ❌ Wave 0 |
| SCHED-01 | Stratified sampling respects `sampling_rate` per day type | unit | same | ❌ Wave 0 |
| SCHED-01 | `seed` arg produces reproducible output | unit | same | ❌ Wave 0 |
| SCHED-01 | `expand_periods = FALSE` collapses to one row per day | unit | same | ❌ Wave 0 |
| SCHED-01 | `include_all = TRUE` adds `sampled` logical column | unit | same | ❌ Wave 0 |
| SCHED-01 | Errors when both `n_days` and `sampling_rate` supplied | unit | same | ❌ Wave 0 |
| SCHED-02 | `generate_bus_schedule()` output passes `creel_design(survey_type = "bus_route")` | integration | `testthat::test_file("tests/testthat/test-schedule-generators.R")` | ❌ Wave 0 |
| SCHED-02 | `inclusion_prob` column present in output | unit | same | ❌ Wave 0 |
| SCHED-03 | `write_schedule()` produces readable CSV via base R | unit | `testthat::test_file("tests/testthat/test-schedule-io.R")` | ❌ Wave 0 |
| SCHED-03 | xlsx export works when writexl installed | unit | same | ❌ Wave 0 |
| SCHED-03 | Informative error when writexl missing and xlsx requested | unit | same | ❌ Wave 0 |
| SCHED-04 | `read_schedule()` returns `creel_schedule` object | unit | `testthat::test_file("tests/testthat/test-schedule-io.R")` | ❌ Wave 0 |
| SCHED-04 | Column types correct after read (Date, character, integer) | unit | same | ❌ Wave 0 |
| SCHED-04 | Round-trip: write → read → `creel_design()` succeeds | integration | same | ❌ Wave 0 |
| SCHED-04 | Validation error on bad `day_type` values after read | unit | same | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `testthat::test_file("tests/testthat/test-schedule-generators.R")` or `test-schedule-io.R` as relevant
- **Per wave merge:** `devtools::test()`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/testthat/test-schedule-generators.R` — covers SCHED-01, SCHED-02
- [ ] `tests/testthat/test-schedule-io.R` — covers SCHED-03, SCHED-04, round-trip
- [ ] `R/schedule-generators.R` — new file (generate_schedule, generate_bus_schedule, helpers)
- [ ] `R/schedule-io.R` — new file (write_schedule, read_schedule, coerce helpers)
- [ ] DESCRIPTION: add `lubridate (>= 1.9.5)` to Imports
- [ ] DESCRIPTION: add `writexl (>= 1.5.4)` and `readxl (>= 1.4.0)` to Suggests

---

## Sources

### Primary (HIGH confidence)

- `R/creel-design.R` (inspected 2026-03-23) — confirmed calendar schema: `date` (Date) + `day_type` (character); `resolve_single_col()` / `resolve_multi_cols()` patterns; `new_creel_design()` S3 list constructor; `validate_creel_design()` Tier 1 validation
- `R/validate-schemas.R` (inspected 2026-03-23) — `validate_calendar_schema()` logic; `checkmate::makeAssertCollection()` pattern
- `R/creel-summaries.R` (inspected 2026-03-23) — `class(obj) <- c("creel_summary_*", "data.frame")` tibble subclass pattern
- `tests/testthat/test-creel-design.R` (inspected 2026-03-23) — confirmed column names and types in test fixtures
- `DESCRIPTION` (inspected 2026-03-23) — confirmed lubridate/writexl/readxl NOT yet in deps; need to be added
- `.planning/phases/48-schedule-generators/48-CONTEXT.md` — locked decisions and discretion areas
- `.planning/REQUIREMENTS.md` — SCHED-01 through SCHED-04 requirement text
- `.planning/STATE.md` — lubridate in Imports decision; writexl in Suggests decision; research flag on creel_schedule schema

### Secondary (MEDIUM confidence)

- lubridate DST handling: documented behavior in lubridate package (training knowledge, consistent with STATE.md decision rationale)
- readxl `col_types = "text"` pattern: common pattern for locale-safe Excel reading; consistent with locked decision to use uniform coercion

### Tertiary (LOW confidence)

- Excel serial-number date origin "1899-12-30": well-known Excel quirk (off-by-one from 1900-01-01 due to Lotus 1-2-3 bug); not verified against current readxl documentation but stable for decades

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries confirmed in DESCRIPTION or STATE.md decisions; versions from DESCRIPTION
- Architecture patterns: HIGH — confirmed from direct code inspection of creel-design.R, validate-schemas.R, creel-summaries.R
- Pitfalls: MEDIUM — Excel round-trip pitfalls from established R/Excel interop knowledge; seed scoping pattern from withr docs; p_site sum constraint from creel-design.R validation code

**Research date:** 2026-03-23
**Valid until:** 2026-04-23 (stable domain — lubridate, readxl, writexl release cadence is slow)
