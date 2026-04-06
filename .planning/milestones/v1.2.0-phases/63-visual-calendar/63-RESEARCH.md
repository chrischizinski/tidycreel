# Phase 63: Visual Calendar - Research

**Researched:** 2026-04-05
**Domain:** R S3 print methods, ASCII calendar formatting, knitr document output
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Cell content — bus-route schedules (have `circuit` column)**
- Each date cell shows two lines: day_type abbreviation on line 1, circuit assignment(s) on line 2
- Example: `WD\nC1` for a weekday with circuit 1; `WD\nC1,C2` for a day with multiple circuits
- Multiple circuits on the same date (from different periods) are shown comma-separated on one line
- This applies to both console (newline separator) and pandoc (HTML `<br>` separator) output

**Cell content — instantaneous (and other non-bus-route) schedules**
- Each date cell shows the day_type abbreviation only (no circuit row)
- No separate "sampled" marker needed — presence in the cell implies sampled

**Day type abbreviations**
- Derive dynamically from the actual `day_type` label stored in the data: first 2 characters, uppercased
- Do NOT hardcode WD/WE; this ensures custom labels (e.g., "holiday", "closure") abbreviate correctly
- Abbreviation collision handling: if two day_type labels share the same first-2-char abbreviation, fall back to 3 chars (or more) until unique

**Non-sampled day rendering**
- Always render the full calendar month grid (Mon-Sun structure, all weeks), regardless of whether the schedule was generated with `include_all = TRUE` or `FALSE`
- Non-sampled dates: show the date number only (e.g., `15`) with no day_type or circuit content
- When the schedule has a `sampled` column (`include_all = TRUE` was used), non-sampled rows (`sampled == FALSE`) are ignored during rendering — they display the same as dates not in the tibble at all
- Net effect: the calendar always looks like a real calendar with sampled dates filled in and non-sampled dates blank

**Week layout**
- Calendar grid starts on Sunday (US convention: Sun Mon Tue Wed Thu Fri Sat)
- One row per week; one column per day of week

**Console print (print.creel_schedule)**
- Retain the existing one-line summary header above the grid: `# A creel_schedule: {N} rows x {M} cols ({D} days, {P} periods)`
- Calendar grid(s) follow immediately below the header
- Do NOT call `NextMethod()` — the calendar fully replaces the raw data frame dump
- For multi-month schedules, show ALL months (a full creel season is 3-6 months)
- Separate consecutive month grids with a blank line; label each with the month and year above it

**Document knit_print (knit_print.creel_schedule)**
- Same week-grid layout as the console calendar: 7 columns (Sun-Sat), one row per week, same cell content logic
- Each month gets a `### Month YYYY` markdown heading immediately above its pipe table
- Multi-line cell content uses HTML `<br>` tag (e.g., `WD<br>C1`) — renders correctly in pandoc HTML output
- Method uses `rlang::check_installed("knitr")` guard (consistent with `writexl`/`readxl` pattern in this package)
- Returns `knitr::asis_output()` wrapping raw markdown — do not use `knitr::kable()`
- Add `knitr` to `Suggests` in DESCRIPTION

### Claude's Discretion

- Exact ASCII cell width and border characters (dashes, pipes) for the console grid
- Whether to use `cli` for console output or plain `cat()` (either is fine)
- File placement: new file (e.g., `R/schedule-print.R`) or added to `R/schedule-generators.R`
- Whether to export `knit_print.creel_schedule` via `@export` or `@exportS3Method knitr knit_print`

### Deferred Ideas (OUT OF SCOPE)

- **iCal / Google Calendar export vignette**: Export a `creel_schedule` (with shift times and count times) to `.ics` format so field staff can load their survey days on phones via Google Calendar or Outlook. Belongs in its own phase (requires `ics` or similar package, iCal format generation).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CAL-01 | User can print a `creel_schedule` as a formatted monthly ASCII calendar grid in the console, showing day type and circuit (bus-route) per date cell | `print.creel_schedule()` S3 method replaces `NextMethod()` with calendar rendering; `format.creel_schedule()` pattern from `print-methods.R`; `lubridate::wday()` with `week_start=7` for Sunday-first layout |
| CAL-02 | User can embed a `creel_schedule` as a pandoc-ready month-grid markdown table in R Markdown and Quarto documents | `knit_print.creel_schedule()` S3 method returning `knitr::asis_output()`; `@exportS3Method knitr knit_print` roxygen tag generates correct NAMESPACE entry; knitr already in `Suggests` |
</phase_requirements>

---

## Summary

Phase 63 adds two S3 print methods to the existing `creel_schedule` class. The `print.creel_schedule()` method replaces the current `NextMethod()` delegation with an ASCII monthly calendar grid. The `knit_print.creel_schedule()` method generates pandoc pipe-table markdown suitable for knitr-rendered documents. Both methods share the same underlying calendar-building logic — split schedule by month, build a 7-column Sun-Sat grid, fill sampled date cells with day_type abbreviation (and circuit for bus-route), leave non-sampled dates showing only the date number.

The core algorithmic challenge is the calendar grid construction: computing Sunday-first day offsets with `lubridate::wday(week_start=7)`, padding the first week, and wrapping rows at Saturday. A secondary challenge is the abbreviation collision algorithm: "weekday" and "weekend" share their first **four** characters (W-E-E-K), requiring the loop to go to length 5 ("WEEKD"/"WEEKE") before achieving uniqueness. The S3 dispatch for `knitr::knit_print` requires `@exportS3Method knitr knit_print` in the roxygen header, which generates `S3method(knitr::knit_print, creel_schedule)` in NAMESPACE without requiring knitr in `Imports`.

**Primary recommendation:** Implement a private `build_month_grid()` helper that both `format.creel_schedule()` (console) and `knit_print.creel_schedule()` (document) call with a `mode = c("ascii", "pandoc")` argument. This avoids duplication of the date/grid logic while keeping the two output formats distinct.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| lubridate | >= 1.9.5 (already Imports) | Date arithmetic, `wday()`, `floor_date()`, `ceiling_date()` | Already in DESCRIPTION Imports; provides `week_start` parameter for Sun-first offset |
| knitr | 1.51 (already Suggests) | `asis_output()`, `knit_print` generic | Already in DESCRIPTION Suggests; `knitr::asis_output()` is the correct return type for raw markdown injection |
| cli | (already Imports) | One-line summary header, optional console styling | Already used in `print.creel_schedule()` for the header line |
| rlang | (already Imports) | `rlang::check_installed("knitr")` guard | Pattern already used for `writexl`/`readxl` in `schedule-io.R` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| base R `format()`, `strrep()`, `sprintf()` | base | Cell padding, border lines, string alignment | Preferred for ASCII grid construction — no extra dependencies |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `knitr::asis_output()` | `knitr::kable()` | `kable()` can't render multi-line cell content with `<br>`; `asis_output()` passes raw markdown through unchanged |
| base `cat()` for console | `cli` for console grid | `cli` is fine for the header line; plain `cat()` is simpler for the grid rows and avoids ANSI escapes in the output |
| `@exportS3Method knitr knit_print` | `@export` with `knit_print.creel_schedule <- function(...)` | `@export` alone creates a top-level exported function but does not register it as an S3 method; `@exportS3Method` is the correct roxygen2 >= 7.2.0 tag |

**Installation:** No new packages required. Both knitr and lubridate are already present.

---

## Architecture Patterns

### Recommended File Placement

Place all new code in `R/schedule-print.R` (new file). This keeps schedule-generators.R focused on generation logic and follows the `print-methods.R` separation pattern already in the package.

```
R/
├── schedule-generators.R   # existing: generate_schedule(), print.creel_schedule() (to be replaced)
├── schedule-print.R        # NEW: format.creel_schedule(), print.creel_schedule(), knit_print.creel_schedule()
├── print-methods.R         # existing: other format/print methods (MOR, diagnostic)
```

The existing `print.creel_schedule()` in `schedule-generators.R` at line 29 must be removed when `schedule-print.R` is added.

### Pattern 1: format/print Split for Testability

**What:** `format.creel_schedule()` builds a character vector; `print.creel_schedule()` calls `cat(format(x, ...), sep = "\n")` and returns `invisible(x)`. Tests assert on `format()` output (character vector), not on side effects.

**When to use:** All console S3 print methods in this package — established by `format.creel_estimates_mor()` / `print.creel_estimates_mor()` pattern.

```r
# Source: R/print-methods.R (lines 50-53)
print.creel_estimates_mor <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}
```

### Pattern 2: knitr::knit_print S3 Method with asis_output

**What:** Define `knit_print.creel_schedule()` returning `knitr::asis_output(markdown_string)`. Register with `@exportS3Method knitr knit_print` roxygen tag (requires roxygen2 >= 7.2.0, which this project already uses per RoxygenNote: 7.3.3).

**When to use:** Whenever a package object should render as raw markdown/HTML in knitr documents instead of using the default print method.

```r
#' @exportS3Method knitr knit_print
knit_print.creel_schedule <- function(x, ...) {
  rlang::check_installed("knitr", reason = "to render creel_schedule in documents")
  md <- build_month_grid(x, mode = "pandoc")
  knitr::asis_output(paste(md, collapse = "\n"))
}
```

This generates `S3method(knitr::knit_print, creel_schedule)` in NAMESPACE without requiring `importFrom(knitr, knit_print)`.

### Pattern 3: Sunday-First Calendar Grid Construction

**What:** Use `lubridate::wday(date, week_start = 7)` to get day-of-week offsets where Sunday = 1, Saturday = 7. Build rows by grouping dates into weeks where week boundaries fall at Sunday.

**Key verified facts:**
- `wday(as.Date("2025-05-04"), week_start = 7)` returns `1` (Sunday = 1)
- `wday(as.Date("2025-05-10"), week_start = 7)` returns `7` (Saturday = 7)
- `floor_date(date, "month")` and `ceiling_date(date, "month") - days(1)` give month bounds
- Padding before first date = `wday(month_start, week_start=7) - 1` empty cells

```r
# Core grid construction (pseudocode)
build_month_grid <- function(dates_in_month, schedule_lookup, mode) {
  month_start <- lubridate::floor_date(dates_in_month[1], "month")
  month_end   <- lubridate::ceiling_date(month_start, "month") - lubridate::days(1)
  all_dates   <- seq(month_start, month_end, by = "day")
  pad_left    <- lubridate::wday(month_start, week_start = 7) - 1L
  # Build 7-column rows chunked from c(rep(NA, pad_left), all_dates, tail_pad)
}
```

### Pattern 4: Abbreviation Collision Resolution

**What:** Loop from `k = 2` upward, computing `toupper(substr(labels, 1, k))` for all unique day_type values. Stop at the first `k` where no duplicates exist. Cap at `nchar(max_label)` to avoid infinite loop.

**Critical finding (HIGH confidence, verified in R):** "weekday" and "weekend" — the standard labels — share their first **4** characters ("WEEK"). The collision loop must reach `k = 5` to produce "WEEKD"/"WEEKE". Hardcoding k=2 would produce "WE"/"WE" (collision). Any implementation must use the loop.

```r
make_abbrevs <- function(day_type_labels) {
  unique_labels <- unique(day_type_labels)
  max_len <- max(nchar(unique_labels))
  for (k in seq(2, max_len)) {
    abbrevs <- toupper(substr(unique_labels, 1, k))
    if (!anyDuplicated(abbrevs)) break
  }
  # Return named vector: label -> abbreviation
  stats::setNames(abbrevs, unique_labels)
}
```

### Pattern 5: Circuit Aggregation per Date

**What:** A bus-route schedule has a `circuit` column and may have multiple rows per date (one per period). The calendar cell shows all circuits assigned on that date, comma-separated. Deduplicate before joining.

```r
# Aggregate circuits per date
if ("circuit" %in% names(x)) {
  circuit_by_date <- tapply(x$circuit, x$date, function(v) paste(sort(unique(v)), collapse = ","))
}
```

### Anti-Patterns to Avoid

- **Calling `NextMethod()` in `print.creel_schedule()`:** The context decision explicitly removes this — it would dump the raw data frame after the calendar. Remove it completely.
- **Using `knitr::kable()` for the document output:** `kable()` does not support multi-line cell content with `<br>`. Use `knitr::asis_output()` with raw markdown string.
- **Hardcoding "WD"/"WE" abbreviations:** The abbreviation algorithm must be dynamic. Standard "weekday"/"weekend" labels collide up to 4 characters.
- **Assuming `period_id` is always present:** `expand_periods = FALSE` schedules omit `period_id`. The print method must handle its absence gracefully.
- **Using `cli_text()` for the calendar grid rows:** `cli` adds ANSI escapes and word-wraps; plain `cat()` is more predictable for fixed-width ASCII art.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Month boundaries | Custom day-counting arithmetic | `lubridate::floor_date()` + `ceiling_date()` | Handles leap years, month-length variation, timezone edge cases |
| Day-of-week offset | Manual modular arithmetic | `lubridate::wday(week_start = 7)` | Sunday-first offset verified; avoids off-by-one from 0 vs 1 indexing |
| knitr output injection | `print()` that happens to work in Rmd | `knitr::asis_output()` | `asis_output` is the contract knitr checks; anything else may get escaped or reformatted |
| Package optional dependency guard | `requireNamespace()` manually | `rlang::check_installed()` | Already the package convention; gives better error messages |

---

## Common Pitfalls

### Pitfall 1: Abbreviation Length for Standard Labels
**What goes wrong:** Using `substr(label, 1, 2)` directly produces "WE"/"WE" for "weekday"/"weekend" — both abbreviate identically. The calendar cells would be indistinguishable.
**Why it happens:** "weekday" and "weekend" share "W", "E", "E", "K" — first unique character is at position 5.
**How to avoid:** Use the collision-resolution loop (Pattern 4 above); verify with `anyDuplicated()`.
**Warning signs:** Unit test asserting that two different day_type values produce different cell content will fail.

### Pitfall 2: knit_print Not Dispatching
**What goes wrong:** `knit_print.creel_schedule` exists but is not registered as an S3 method, so knitr falls back to `print()` in documents.
**Why it happens:** Using `@export` alone creates a top-level function but does not add `S3method(knitr::knit_print, creel_schedule)` to NAMESPACE.
**How to avoid:** Use `@exportS3Method knitr knit_print` — this is the correct roxygen2 tag (supported since roxygen2 7.2.0; project uses 7.3.3).
**Warning signs:** Knitting a test document shows the raw data frame instead of the calendar table.

### Pitfall 3: Multi-Row Dates in the Schedule
**What goes wrong:** A schedule with `n_periods = 2` has 2 rows per date. Treating each row as a unique date creates duplicates in the calendar.
**Why it happens:** `generate_schedule()` expands periods by default — one row per date × period combination.
**How to avoid:** Deduplicate dates before grid construction. For circuit display, aggregate circuits per date before building cells. Use `unique(x$date)` as the date list, then look up cell content per unique date.
**Warning signs:** Same date appears in calendar cell twice, or cell content lists the same circuit repeatedly.

### Pitfall 4: Pandoc Pipe Table Alignment with HTML `<br>`
**What goes wrong:** Multi-line cell content using `<br>` only renders in HTML output. PDF output via LaTeX will show literal `<br>` text.
**Why it happens:** HTML tags in pipe tables are passed through in HTML output but not in PDF.
**How to avoid:** This is a known limitation and is acceptable per the decisions (context says "renders correctly in pandoc HTML output"). No action needed — document it in the function's roxygen `@details`.
**Warning signs:** Users knitting to PDF report literal `<br>` in calendar cells (expected behavior, not a bug).

### Pitfall 5: include_all Schedules with sampled = FALSE Rows
**What goes wrong:** A schedule created with `include_all = TRUE` contains all season dates, but non-sampled ones have `sampled == FALSE`. If these are included in cell content lookup, non-sampled dates will show abbreviations they shouldn't.
**Why it happens:** The full tibble is passed to `print()`, including non-sampled rows.
**How to avoid:** Filter to `sampled == TRUE` rows (or rows where `sampled` column is absent, meaning all rows are sampled) before building the date-to-cell-content lookup.

---

## Code Examples

### Calendar Grid Construction (Core Logic)
```r
# Source: verified in R session 2026-04-05
# lubridate wday with week_start=7: Sun=1, Mon=2, ..., Sat=7
# Padding before first day of month:
pad_left <- lubridate::wday(month_start, week_start = 7L) - 1L

# All dates in month:
all_dates <- seq(
  lubridate::floor_date(any_date, "month"),
  lubridate::ceiling_date(any_date, "month") - lubridate::days(1),
  by = "day"
)
```

### Abbreviation Collision Resolution
```r
# Source: verified in R session 2026-04-05
# "weekday"/"weekend" collide through k=4; unique at k=5
make_day_abbrevs <- function(day_type_labels) {
  unique_labels <- unique(day_type_labels)
  max_len <- max(nchar(unique_labels))
  for (k in seq(2L, max_len)) {
    abbrevs <- toupper(substr(unique_labels, 1L, k))
    if (!anyDuplicated(abbrevs)) break
  }
  stats::setNames(abbrevs, unique_labels)
}
```

### rlang::check_installed Pattern (from schedule-io.R)
```r
# Source: R/schedule-io.R lines 125, 169
rlang::check_installed("writexl", reason = "to write xlsx schedule files")
rlang::check_installed("readxl",  reason = "to read xlsx schedule files")
# Apply same pattern:
rlang::check_installed("knitr", reason = "to render creel_schedule in documents")
```

### knitr::asis_output Return
```r
# Source: verified in R session 2026-04-05, knitr 1.51
# class(knitr::asis_output("## Test\n")) == "knit_asis"
knit_print.creel_schedule <- function(x, ...) {
  rlang::check_installed("knitr", reason = "to render creel_schedule in documents")
  md_lines <- build_calendar_md(x)  # returns character vector
  knitr::asis_output(paste(md_lines, collapse = "\n"))
}
```

### NAMESPACE Registration via roxygen2
```r
#' @exportS3Method knitr knit_print
knit_print.creel_schedule <- function(x, ...) { ... }
# Generates in NAMESPACE:
# S3method(knitr::knit_print,creel_schedule)
# Does NOT require importFrom(knitr, knit_print)
```

### Existing print.creel_schedule Header to Preserve
```r
# Source: R/schedule-generators.R lines 29-37
cli::cli_text(
  "# A creel_schedule: {nrow(x)} rows x {ncol(x)} cols ",
  "({if ('date' %in% names(x)) length(unique(x$date)) else NA_integer_} days, ",
  "{if ('period_id' %in% names(x)) length(unique(x$period_id)) else 1L} periods)"
)
```

### Circuit Detection Branch
```r
# Source: CONTEXT.md — established package pattern
has_circuit <- "circuit" %in% names(x)
```

### Console Pipe Table Row Example
```
May 2025
| Sun      | Mon      | Tue      | Wed      | Thu      | Fri      | Sat      |
|----------|----------|----------|----------|----------|----------|----------|
|          |          |          |          | 1        | 2        | 3        |
|          |          |          |          | WEEKD    | WEEKE    | WEEKE    |
|          |          |          |          | C1       | C1,C2    |          |
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `@export` for imported-package S3 methods | `@exportS3Method pkg generic` | roxygen2 7.2.0 (2022) | Correct NAMESPACE entry without importing the generic |
| `print()` method calling `knitr::kable()` | `knit_print()` returning `knitr::asis_output()` | knitr ~1.40 | Proper knitr dispatch; supports raw HTML in cells |

**Deprecated/outdated:**
- `registerS3method("knit_print", "creel_schedule", ...)` in `.onLoad()`: unnecessary with `@exportS3Method` tag in roxygen2 7.2+

---

## Open Questions

1. **Cell width for console grid**
   - What we know: Must accommodate date number + day_type abbreviation + circuit (e.g., "WEEKD\nC1,C2,C3"). With 7 columns + borders, terminal width matters.
   - What's unclear: Maximum number of circuits per date in practice; whether very long circuit lists (e.g., "C1,C2,C3,C4") need truncation.
   - Recommendation: This is discretion territory per CONTEXT.md. Set a fixed cell width (e.g., 10 chars) and let overflow wrap naturally; or dynamically size to the widest cell content in the schedule.

2. **Month header format string**
   - What we know: CONTEXT.md specifies `"May 2025"` format (full month name + year).
   - What's unclear: Whether `format(date, "%B %Y")` or `paste(month.name[month(date)], year(date))` is preferred.
   - Recommendation: `format(month_start, "%B %Y")` — single call, uses locale-appropriate month names, consistent with base R practice.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3rd edition (>= 3.0.0) |
| Config file | `tests/testthat.R` / `Config/testthat/edition: 3` in DESCRIPTION |
| Quick run command | `devtools::test(filter = "schedule-print")` |
| Full suite command | `devtools::test()` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAL-01 | `format.creel_schedule()` returns character vector with month header | unit | `devtools::test(filter = "schedule-print")` | No — Wave 0 |
| CAL-01 | ASCII grid has 7-column Sun-Sat header row | unit | `devtools::test(filter = "schedule-print")` | No — Wave 0 |
| CAL-01 | Sampled date cells contain day_type abbreviation | unit | `devtools::test(filter = "schedule-print")` | No — Wave 0 |
| CAL-01 | Non-sampled dates show date number only | unit | `devtools::test(filter = "schedule-print")` | No — Wave 0 |
| CAL-01 | Bus-route schedule cells show circuit on second line | unit | `devtools::test(filter = "schedule-print")` | No — Wave 0 |
| CAL-01 | Multi-month schedule produces one grid per month | unit | `devtools::test(filter = "schedule-print")` | No — Wave 0 |
| CAL-01 | `print.creel_schedule()` returns invisibly | unit | `devtools::test(filter = "schedule-print")` | No — Wave 0 |
| CAL-01 | Abbreviation collision: "weekday"/"weekend" produce distinct abbreviations | unit | `devtools::test(filter = "schedule-print")` | No — Wave 0 |
| CAL-02 | `knit_print.creel_schedule()` returns `knit_asis` class object | unit | `devtools::test(filter = "schedule-print")` | No — Wave 0 |
| CAL-02 | Document output contains pandoc pipe table syntax (`\|---|`) | unit | `devtools::test(filter = "schedule-print")` | No — Wave 0 |
| CAL-02 | Bus-route cells use `<br>` for multi-line in document output | unit | `devtools::test(filter = "schedule-print")` | No — Wave 0 |
| CAL-02 | Month heading uses `### Month YYYY` format | unit | `devtools::test(filter = "schedule-print")` | No — Wave 0 |
| CAL-02 | R CMD CHECK passes 0 errors 0 warnings | integration | `rcmdcheck::rcmdcheck()` | N/A |

### Sampling Rate
- **Per task commit:** `devtools::test(filter = "schedule-print")`
- **Per wave merge:** `devtools::test()`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test-schedule-print.R` — covers CAL-01 and CAL-02 (new file; does not yet exist)
- [ ] No framework gaps — testthat infrastructure already present

---

## Sources

### Primary (HIGH confidence)
- Direct R session verification (2026-04-05): `lubridate::wday(week_start=7)` behavior, `knitr::asis_output()` class, `knitr::knit_print` as S3 generic with `UseMethod`, abbreviation collision for "weekday"/"weekend"
- `R/schedule-generators.R` (read directly): existing `print.creel_schedule()` at line 29, `new_creel_schedule()`, `generate_schedule()` column structure
- `R/print-methods.R` (read directly): `format.X()` + `print.X()` pattern, `cat(format(x), sep="\n")` idiom
- `R/schedule-io.R` (read directly): `rlang::check_installed()` pattern at lines 125, 169
- `DESCRIPTION` (read directly): knitr already in Suggests; lubridate already in Imports; RoxygenNote 7.3.3 confirms `@exportS3Method` support
- `NAMESPACE` (read directly): `S3method(print,creel_schedule)` at line 19; `@exportS3Method knitr knit_print` pattern needed

### Secondary (MEDIUM confidence)
- roxygen2 7.2.0 changelog: `@exportS3Method` tag introduced for importing-package S3 method registration

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages verified present in project; APIs verified in R session
- Architecture: HIGH — format/print pattern read directly from codebase; S3 dispatch verified
- Pitfalls: HIGH — abbreviation collision verified empirically; knit_print dispatch verified via NAMESPACE inspection
- Validation: HIGH — testthat infrastructure confirmed present; test file gap identified

**Research date:** 2026-04-05
**Valid until:** 2026-06-05 (stable APIs — lubridate, knitr, roxygen2 change slowly)
