---
phase: 084-camera-missing-data
reviewed: 2026-05-03T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - R/impute-camera-counts.R
  - tests/testthat/test-impute-camera-counts.R
  - DESCRIPTION
  - _pkgdown.yml
findings:
  critical: 2
  warning: 3
  info: 2
  total: 7
status: issues_found
---

# Phase 084: Code Review Report

**Reviewed:** 2026-05-03
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Phase 084 delivers `impute_camera_counts()`, a per-stratum Poisson GLM / NB GLMM imputer for camera count outages. The core GLM path is structurally sound: input guards, the all-missing abort, Poisson family, and integer coercion all behave correctly. Two blockers require fixes before this ships: the `.imputed` flag produces false positives for any non-operational row that arrives with a non-NA count, and the documented "zero-inflated negative binomial" GLMM is actually a plain negative binomial (no `ziformula`). Three warnings cover row-order fragility, citation inconsistency, and a missing test fixture. Two info items cover the cli pluralization and a minor import annotation note.

---

## Critical Issues

### CR-01: `.imputed` flag produces false positives for non-operational rows with pre-existing counts

**File:** `R/impute-camera-counts.R:235-236`

**Issue:** The `.imputed` flag is computed post-`rbind` as:

```r
result$.imputed <- result[[status_col]] != "operational" &
  !is.na(result[[count_col]])
```

This flags as "imputed" every row where `status != "operational"` AND `count` is not `NA` after the loop. That is correct for rows that *were* outages (they had `NA` counts before imputation). However, a row that arrives with `status != "operational"` and a *pre-existing non-NA count* (e.g., a partial-outage day where a manual count was recorded) is:

- excluded from model training (`obs_mask` requires `"operational"`)
- excluded from prediction (`outage_mask` requires `is.na(count)`)
- never touched by the imputation loop

Yet the post-loop condition still evaluates to `TRUE` for it, incorrectly asserting it was imputed.

**Fix:** Track which rows were actual outages at input time and carry that vector through to the result. Because `do.call(rbind, imputed_list)` does not preserve original row order when strata are not grouped consecutively (see WR-01), the cleanest approach is to build `.imputed` inside the loop on `stratum_data` before returning, then let the rbind assemble it with the rest:

```r
# Inside the lapply, after prediction:
stratum_data[[count_col]][outage_mask] <- as.integer(round(predicted))
stratum_data[[".imputed"]]             <- outage_mask   # TRUE only for rows imputed this loop
stratum_data

# For the no-outage early-return path:
if (!any(outage_mask)) {
  stratum_data[[".imputed"]] <- FALSE
  return(stratum_data)
}
```

Then remove steps 7 (the post-rbind `.imputed` assignment) entirely. This also eliminates the row-order dependency described in WR-01.

---

### CR-02: GLMM path fits plain negative binomial, not zero-inflated NB as documented

**File:** `R/impute-camera-counts.R:192-195` (and docstring lines 11, 31, 118)

**Issue:** The docstring, the `@param method` description, and the `rlang::check_installed()` reason string all state the GLMM method fits a *zero-inflated* negative binomial (ZINB). The actual call is:

```r
glmmTMB::glmmTMB(
  glmm_formula,
  data   = stratum_data[obs_mask, , drop = FALSE],
  family = glmmTMB::nbinom2(link = "log")
)
```

`glmmTMB`'s default for `ziformula` is `~0`, meaning **no zero-inflation component is estimated**. This is a standard NB GLMM. The difference matters: users selecting `method = "glmm"` to handle zero-heavy camera count data will not get the ZINB model they expect, potentially leading to biased imputation and incorrect citations of methodology.

**Fix — option A (implement ZINB as documented):**

```r
glmmTMB::glmmTMB(
  glmm_formula,
  ziformula = ~1,
  data      = stratum_data[obs_mask, , drop = FALSE],
  family    = glmmTMB::nbinom2(link = "log")
)
```

**Fix — option B (correct the documentation to match the implementation):**

If plain NB GLMM is intentional, update all docstring references from "zero-inflated negative binomial" to "negative binomial", remove the `ziformula` from all documentation, and update the `rlang::check_installed()` reason string accordingly.

---

## Warnings

### WR-01: Row order is not preserved when input strata are interleaved

**File:** `R/impute-camera-counts.R:229-230`

**Issue:** The imputation loop iterates over `unique(data[[strata_col]])` and reassembles via `do.call(rbind, imputed_list)`. When the input data has interleaved strata — for example, `weekday, weekend, weekday, weekend` — rows are returned grouped by stratum in `unique()` order, not in original row order. Downstream consumers that rely on positional row correspondence with the original data frame (e.g., joining by row index, or the test at line 208 which does `expect_equal(result$date, counts$date)`) will silently receive wrong results when strata are not pre-grouped.

The `@return` documentation does not warn callers about this constraint.

**Fix:** Restore original row order after `rbind` using the original row names (which R preserves as `"1"`, `"2"`, etc. before `row.names(result) <- NULL`):

```r
# Before rbind, record original order
orig_rownames <- as.integer(rownames(data))

result <- do.call(rbind, imputed_list)
# Restore original order
result <- result[order(as.integer(rownames(result))), , drop = FALSE]
row.names(result) <- NULL
```

Alternatively, add a `.row_idx` column to `data` before splitting, then remove it after reassembly.

---

### WR-02: Hartill citation year is inconsistent between description and reference block

**File:** `R/impute-camera-counts.R:9,170` vs `43-46`

**Issue:** The `@description` (line 9) and an inline comment (line 170) cite "Hartill 2016", but the `@references` block (lines 43-46) gives the correct publication year as 2020 (DOI `10.1016/j.fishres.2020.105706`). This creates a confusing mismatch for users checking citations.

**Fix:**

```r
# Line 9: change "Hartill 2016" to "Hartill 2020"
#' The GLM method (default, Hartill 2020) fits a Poisson GLM with `strata_col`

# Line 170: change "Hartill 2016" to "Hartill 2020"
    # to the per-stratum Poisson mean (Hartill 2020).
```

---

### WR-03: No test fixture covers non-operational rows with pre-existing non-NA counts

**File:** `tests/testthat/test-impute-camera-counts.R`

**Issue:** The CR-01 false-positive scenario (a row with `status != "operational"` but a count that was already non-NA on input) has zero test coverage. None of the four helper fixtures include this case. Without a test, the false-positive in the `.imputed` flag would not be caught by the test suite.

**Fix:** Add a helper and at least one test:

```r
make_camera_counts_partial_outage <- function() {
  # Row 2: battery_failure but a manual count of 40 was recorded
  data.frame(
    date           = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05")),
    day_type       = c("weekday", "weekday", "weekday"),
    ingress_count  = c(48L, 40L, 43L),      # row 2 is non-NA despite non-operational
    camera_status  = c("operational", "battery_failure", "operational"),
    stringsAsFactors = FALSE
  )
}

test_that("non-operational row with pre-existing count is NOT flagged .imputed", {
  counts <- make_camera_counts_partial_outage()
  result <- impute_camera_counts(counts, count_col = "ingress_count",
                                 strata_col = "day_type")
  expect_false(result$.imputed[2])
})
```

---

## Info

### IN-01: cli pluralization produces "stratuma" for multiple strata

**File:** `R/impute-camera-counts.R:135`

**Issue:** The cli warning uses `"stratum{?/a}"`, which cli expands as: singular → `"stratum"` (appends `""`), plural → `"stratuma"` (appends `"a"`). The correct plural of "stratum" is "strata", requiring the stem to be split.

**Fix:**

```r
# Current (wrong plural: "stratuma"):
"High missingness detected in {length(high_miss_strata)} stratum{?/a}."

# Correct:
"High missingness detected in {length(high_miss_strata)} strat{?um/a}."
```

---

### IN-02: `@importFrom stats predict` covers GLM but not glmmTMB S3 dispatch

**File:** `R/impute-camera-counts.R:82`

**Issue:** `@importFrom stats predict` registers `stats::predict` as the generic. When `fit` is a `glmmTMB` object, R dispatches to `glmmTMB:::predict.glmmTMB`. Because `glmmTMB` is in `Suggests` (not `Imports`), its namespace is not guaranteed to be loaded at package load time. In practice, `glmmTMB::glmmTMB()` is called before `predict()` in every code path, which loads the namespace and makes dispatch work. However, the `@importFrom` annotation does not document this dependency, and a future code reorganization could move the predict call to a context where glmmTMB is not yet loaded.

**Fix:** Add a comment next to the `predict()` call on the GLMM object noting the dispatch dependency, or add `glmmTMB` to `Imports` if ZINB support is core to the package contract. At minimum, the `@importFrom` annotation is not wrong, but the reliance on side-effect namespace loading is worth noting in a comment.

```r
# predict() dispatches to glmmTMB:::predict.glmmTMB; glmmTMB namespace is
# guaranteed loaded here because glmmTMB::glmmTMB() was called above.
predicted <- predict(fit, newdata = ..., type = "response")
```

---

_Reviewed: 2026-05-03_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
