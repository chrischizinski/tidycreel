---
phase: 90
status: issues_found
files_reviewed: 7
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
---

# Phase 90 Code Review — Real-Data Validation

## Files Reviewed

- `inst/validation/calamus-2016-validation.R`
- `inst/extdata/calamus-2016/interviews.csv`
- `inst/extdata/calamus-2016/counts.csv`
- `inst/extdata/calamus-2016/catch.csv`
- `inst/extdata/calamus-2016/harvest_lengths.csv`
- `inst/extdata/calamus-2016/release_lengths.csv`
- `inst/extdata/calamus-2016/reference-outputs.csv`

## Critical Issues

None.

## Warning Issues

### W-01 — Relative path has no working-directory runtime guard

**File**: `inst/validation/calamus-2016-validation.R`, line 16
**Confidence**: 88

```r
fixture_dir <- file.path("inst", "extdata", "calamus-2016")
```

The header documents that the script must be run from the package root, but
there is no existence guard before the first `read.csv()`. If a user runs this
from an IDE that sets the working directory to a sub-folder, all four `read.csv()`
calls fail with R's generic "cannot open file" message, giving no hint that
the working directory is the cause.

**Fix**: Add an existence guard immediately after line 16:

```r
if (!dir.exists(fixture_dir)) {
  stop(sprintf(
    "Fixture directory not found: '%s'\nRun this script from the package root directory.",
    fixture_dir
  ))
}
```

---

### W-02 — No file-existence checks before `read.csv()` calls

**File**: `inst/validation/calamus-2016-validation.R`, lines 20, 26, 32, 46
**Confidence**: 85

All four `read.csv()` calls proceed unconditionally. A missing or renamed
fixture file produces R's default `cannot open file 'X'` error. The script
already validates fixture *content* (lines 57–62) but skips checking that
the files exist at all.

**Fix**: Add a small helper:

```r
read_fixture <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("Missing fixture file: %s", path))
  }
  read.csv(path, stringsAsFactors = FALSE)
}
```

## Info Issues

### I-01 — `harvest_lengths.csv` and `release_lengths.csv` are never read

**File**: `inst/validation/calamus-2016-validation.R` (absent); fixture files present
**Confidence**: 82

Both `inst/extdata/calamus-2016/harvest_lengths.csv` (10 rows) and
`inst/extdata/calamus-2016/release_lengths.csv` (4 rows) exist as fixtures
but are not referenced anywhere in the validation script. If a
length-distribution validation step is planned for a future phase, add a
comment in the script noting that. If these files are permanently out of
scope for this validation, document that or remove them to avoid confusion.

---

### I-02 — Blanket `suppressWarnings()` has no documentation of expected warnings

**File**: `inst/validation/calamus-2016-validation.R`, lines 149–151
**Confidence**: 80

```r
eff     <- suppressWarnings(estimate_effort(design))
cat_est <- suppressWarnings(estimate_total_catch(design))
harv    <- suppressWarnings(estimate_harvest_rate(design))
```

All three estimator calls suppress all warnings with no comment explaining
which warnings are expected (e.g., "lonely PSU" warnings from the survey
package when a stratum has only one PSU). Blanket suppression will silently
mask unexpected warnings introduced by future estimator changes.

## Correctness Checks — All Passed

- `estimate_harvest_rate(design)` is the correct function for bus_route total
  harvest (Jones & Pollock 2012, Eq. 19.5). No misuse of `estimate_total_harvest()` found.
- `catch_type == "harvested"` filter is correct for deriving `harvest_count`.
- `computed` list key names exactly match `estimand` column values in `reference-outputs.csv`.
- `vapply(..., numeric(1L))` is safe; estimators return a single-row estimates tibble.
- `TRUE`/`FALSE` used throughout; no `T`/`F` abbreviations found.
- Species codes read as `character` class via `colClasses`, making string comparisons correct.
- `stringsAsFactors = FALSE` used consistently on all `read.csv()` and `data.frame()` calls.

## CSV Fixture Sanity Check

| File | Rows | Notes |
|------|------|-------|
| `interviews.csv` | 24 (12 unique UIDs, intentionally duplicated) | date, site, circuit columns present |
| `counts.csv` | 7 | date + angler_count only |
| `catch.csv` | 16 | catch_type: caught, harvested, released; species as character |
| `harvest_lengths.csv` | 10 | length_type = "harvest"; not read by validation script |
| `release_lengths.csv` | 4 | length_type = "release"; not read by validation script |
| `reference-outputs.csv` | 3 | estimands: effort_total, catch_total, harvest_total |
