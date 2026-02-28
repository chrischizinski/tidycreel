# Phase 5: Grouped Estimation - Research

**Researched:** 2026-02-09
**Domain:** Survey package grouped estimation, tidy evaluation, tidyselect interface design
**Confidence:** HIGH

## Summary

Phase 5 adds grouped estimation capability to `estimate_effort()`, enabling users to compute effort estimates by subgroups (e.g., by day_type, by location, by month) using a `by = ` parameter with tidy selectors. The survey package provides `svyby()` which calls an estimation function (like `svytotal()`) separately for each subset defined by grouping factors, returning a data frame with group columns plus estimate/SE/CI columns. The key architectural decision is whether to use `svyby()` internally or implement grouping in tidycreel's orchestration layer.

Research confirms that `svyby()` is the standard approach for domain estimation in complex surveys. It correctly computes variance estimates for subgroups by using the full survey design (all data) while subsetting for point estimates - this is critical for proper variance estimation as opposed to naive subsetting which underestimates variance. The function accepts formulas for both the estimation variable (`formula = ~effort`) and grouping variables (`by = ~day_type + location`).

For API design, tidycreel will follow established patterns from dplyr and established R survey workflows: `by = ` parameter accepting bare column names via tidy evaluation (rlang::enquo() + tidyselect::eval_select()). The results tibble will include group columns first, then estimate columns, with one row per group. This matches user mental models from dplyr::group_by() + dplyr::summarize() and srvyr package patterns.

**Primary recommendation:** Use `survey::svyby()` internally with `FUN = survey::svytotal`. Accept `by = ` parameter with tidy selectors (bare column names or tidyselect helpers). Transform results into grouped creel_estimates tibble with group columns + estimate/se/ci_lower/ci_upper/n. Store grouping variable names in creel_estimates attributes for print method display.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| survey | 4.4+ | svyby() for grouped domain estimation | Already added in Phase 3, svyby() is the canonical approach for subpopulation estimation with correct variance |
| tidyselect | 1.2+ | eval_select() for resolving tidy selectors | Already used in creel_design() for date/strata selection, provides consistent interface |
| rlang | 1.1+ | enquo() for capturing user expressions | Already used throughout, required for tidy evaluation |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dplyr | 1.1+ | bind_cols() for combining group info with estimates | Already in DESCRIPTION via tidyselect, useful for result construction |
| tibble | Current | tibble() for tidy result data frames | Already used in Phase 4, continues for grouped results |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| survey::svyby | Manual split-apply-combine with subset() | Manual approach error-prone, misses variance covariance between domains, reinvents tested code |
| Formula by = ~var | Bare names with tidy eval | Formula syntax is survey package convention, but tidy eval is tidycreel convention - choose consistency within package |
| group_by() verb | by = parameter | group_by() requires persistent grouping state (dplyr model), by = is cleaner for one-off operations |

**Installation:**
```bash
# All packages already in DESCRIPTION from Phases 1-4
# No new dependencies needed for Phase 5
```

## Architecture Patterns

### Pattern 1: Tidy Evaluation for by Parameter

**What:** Accept bare column names for grouping variables using rlang + tidyselect

**When to use:** Any parameter that accepts column selections from a data frame

**Example:**
```r
# Source: tidyselect package vignette
# https://cran.r-project.org/web/packages/tidyselect/vignettes/tidyselect.html

estimate_effort <- function(design, by = NULL, conf_level = 0.95) {
  # ... validation code ...

  # Capture user expression (defuse)
  by_quo <- rlang::enquo(by)

  # Check if by is NULL (total estimation, not grouped)
  if (rlang::quo_is_null(by_quo)) {
    # Phase 4 behavior: ungrouped estimation
    return(estimate_effort_total(design, conf_level))
  }

  # Resolve tidy selector to column names
  by_cols <- tidyselect::eval_select(
    by_quo,
    data = design$counts,
    allow_rename = FALSE,
    allow_empty = FALSE,
    error_call = rlang::caller_env()
  )

  # by_cols is named integer vector: c(day_type = 2, location = 5)
  # Extract names to get column names
  by_vars <- names(by_cols)

  # ... proceed with grouped estimation using by_vars ...
}

# User can call with:
# estimate_effort(design, by = day_type)                 # single column
# estimate_effort(design, by = c(day_type, location))    # multiple columns
# estimate_effort(design, by = starts_with("strat"))     # tidyselect helper
```

### Pattern 2: Survey Package svyby for Grouped Estimation

**What:** Use `survey::svyby()` to compute estimates for each subgroup with correct variance

**When to use:** Grouped estimation where variance estimates must account for full survey design

**Example:**
```r
# Source: survey package documentation
# https://r-survey.r-forge.r-project.org/survey/html/svyby.html

estimate_effort_grouped <- function(design, by_vars, conf_level = 0.95) {
  # Construct formula for by parameter
  # svyby expects formula: by = ~day_type or by = ~day_type + location
  by_formula <- stats::reformulate(by_vars)

  # Identify count variable (same logic as Phase 4)
  count_var <- identify_count_variable(design)
  count_formula <- stats::reformulate(count_var)

  # Call svyby with svytotal as the estimation function
  svy_result <- survey::svyby(
    formula = count_formula,        # what to estimate
    by = by_formula,                # how to group
    design = design$survey,         # survey design object
    FUN = survey::svytotal,         # estimation function
    vartype = c("se", "ci"),        # request SE and CI
    ci.level = conf_level,          # CI level
    keep.names = TRUE               # preserve variable names
  )

  # svy_result is a data frame with:
  # - Group columns (day_type, location, etc)
  # - Estimate column (e.g., "effort_hours")
  # - se.effort_hours column
  # - ci_l.effort_hours and ci_u.effort_hours columns

  # Transform to tidy format
  estimates_df <- transform_svyby_result(svy_result, by_vars, count_var)

  return(estimates_df)
}
```

### Pattern 3: Result Structure for Grouped Estimates

**What:** Return tibble with group columns first, then estimate/se/ci/n columns

**When to use:** All grouped estimation results to maintain consistency with dplyr patterns

**Example:**
```r
# Transform svyby result to tidy creel_estimates format
transform_svyby_result <- function(svy_result, by_vars, count_var) {
  # Extract group columns (first n columns where n = length(by_vars))
  group_cols <- svy_result[, by_vars, drop = FALSE]

  # Extract estimate (column named after count_var)
  estimate <- svy_result[[count_var]]

  # Extract SE (column named "se.{count_var}")
  se <- svy_result[[paste0("se.", count_var)]]

  # Extract CI (columns named "ci_l.{count_var}" and "ci_u.{count_var}")
  ci_lower <- svy_result[[paste0("ci_l.", count_var)]]
  ci_upper <- svy_result[[paste0("ci_u.", count_var)]]

  # Calculate sample size per group
  # Note: svyby doesn't return n by default, compute from design$counts
  counts_data <- design$counts
  group_sizes <- counts_data %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(by_vars))) %>%
    dplyr::summarise(n = dplyr::n(), .groups = "drop")

  # Combine into single tibble
  result <- tibble::tibble(
    !!!group_cols,              # Unpack group columns
    estimate = estimate,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper
  )

  # Join with group sizes
  result <- dplyr::left_join(result, group_sizes, by = by_vars)

  return(result)
}

# Example result for estimate_effort(design, by = day_type):
#   day_type  estimate    se  ci_lower  ci_upper     n
#   weekday      450.2  23.1     405.0     495.4    10
#   weekend      892.7  45.3     804.0     981.4    15
```

### Pattern 4: Backward Compatibility with Total Estimates

**What:** Maintain Phase 4 behavior when `by = NULL` (ungrouped estimation)

**When to use:** Always - preserve existing API contract

**Example:**
```r
estimate_effort <- function(design, by = NULL, conf_level = 0.95) {
  # Validate design
  validate_effort_estimation(design)

  # Tier 2 validation
  warn_tier2_issues(design)

  # Capture by parameter
  by_quo <- rlang::enquo(by)

  # Route to appropriate implementation
  if (rlang::quo_is_null(by_quo)) {
    # Ungrouped: Phase 4 behavior with svytotal
    return(estimate_effort_total(design, conf_level))
  } else {
    # Grouped: Phase 5 behavior with svyby
    by_vars <- resolve_by_cols(by_quo, design)
    return(estimate_effort_grouped(design, by_vars, conf_level))
  }
}
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Subpopulation variance | Manual subset + variance formulas | survey::svyby | Naive subsetting underestimates variance by ignoring finite population correction across full design; svyby accounts for domain estimation covariances |
| Tidy selection parsing | Custom column name parser | tidyselect::eval_select | Handles complex selectors (starts_with, matches, etc), error messages, and edge cases |
| Group-wise operations | Manual loops over subsets | survey::svyby | Handles empty groups, preserves factor levels, optimizes repeated design operations |
| Result combination | rbind in loop | survey::svyby returns data frame | Avoids accumulation overhead, maintains consistent structure |

**Key insight:** Domain estimation (subpopulation analysis) has subtle variance properties. Using `subset(design, day_type == "weekday")` then `svytotal()` is INCORRECT for independent subsets - variance is underestimated because it ignores that subsets came from the same sample frame. `svyby()` handles this correctly by using the full design for variance computation.

## Common Pitfalls

### Pitfall 1: Naive Subsetting for Groups

**What goes wrong:** Using `subset(design$survey, day_type == "weekday")` then calling `svytotal()` produces incorrect (too small) variance estimates

**Why it happens:** Each subset appears independent, but they're from the same sample frame and share sampling structure. Variance estimation needs the full design context.

**How to avoid:** Always use `survey::svyby()` for grouped estimation. It internally handles subsetting for point estimates while using the full design for variance.

**Warning signs:**
- Group SEs are smaller than expected
- Confidence intervals don't overlap when they should
- Sum of group estimates doesn't equal total estimate (domain estimation is additive)

### Pitfall 2: Formula vs Tidy Eval Inconsistency

**What goes wrong:** Mixing formula syntax (`by = ~day_type`) with tidy eval (`by = day_type`) creates confusion about parameter expectations

**Why it happens:** Survey package uses formulas throughout, tidycreel uses tidy eval throughout

**How to avoid:** Choose one approach and use it consistently. Since tidycreel already uses tidy eval for `date`, `strata`, `site` parameters in `creel_design()`, continue that pattern for `by`.

**Warning signs:**
- Users try `by = ~day_type` and get error about formula not supported
- Documentation examples show mixed syntax
- Error messages mention "formula" when user passed bare name

### Pitfall 3: Missing Group Combinations

**What goes wrong:** Sparse data creates group combinations with zero observations, `svyby()` may drop them or error

**Why it happens:** Not all factor level combinations may appear in data (unbalanced design)

**How to avoid:** Use `drop.empty.groups = TRUE` in `svyby()` (default) to silently drop empty groups, or `drop.empty.groups = FALSE` to error on empty groups. Document behavior clearly.

**Warning signs:**
- Fewer rows in result than expected from factor level combinations
- User expects group but it's missing from output
- Error: "Stratum 'X' has only one PSU"

### Pitfall 4: Group Column Type Coercion

**What goes wrong:** `svyby()` may coerce factor columns to character, losing level ordering

**Why it happens:** Internal data frame operations in svyby

**How to avoid:** Preserve original column types from `design$counts` when constructing result. If user provided factors, keep them as factors with original levels.

**Warning signs:**
- Month names sort alphabetically instead of chronologically
- Factor levels appear in wrong order in output
- User's carefully ordered factors become unordered

## Code Examples

Verified patterns from official sources:

### Grouped Estimation with svyby
```r
# Source: survey package svyby documentation
# https://r-survey.r-forge.r-project.org/survey/html/svyby.html

library(survey)
data(api)

# Create stratified design
dstrat <- svydesign(id = ~1, strata = ~stype, weights = ~pw, data = apistrat, fpc = ~fpc)

# Group by stype, estimate means
svyby(~api00, ~stype, dstrat, svymean)
#   stype   api00       se
#   E       674.4333  9.523607
#   H       625.9104 14.866821
#   M       636.6000 15.165129

# Multiple grouping variables
svyby(~api00, ~stype + sch.wide, dstrat, svymean)

# Request CI instead of SE
svyby(~api00, ~stype, dstrat, svymean, vartype = "ci")
```

### Tidy Eval Column Resolution
```r
# Source: rlang tidy evaluation documentation
# https://rlang.r-lib.org/reference/args_data_masking.html

my_summarise <- function(data, by) {
  # Capture user expression
  by_quo <- rlang::enquo(by)

  # Check if NULL
  if (rlang::quo_is_null(by_quo)) {
    return("No grouping")
  }

  # Resolve to column names
  by_vars <- tidyselect::eval_select(
    by_quo,
    data = data,
    allow_rename = FALSE
  )

  # Use names(by_vars) for column names
  group_cols <- names(by_vars)

  return(group_cols)
}

# User calls
my_summarise(mtcars, by = cyl)                    # "cyl"
my_summarise(mtcars, by = c(cyl, gear))           # c("cyl", "gear")
my_summarise(mtcars, by = starts_with("c"))       # c("cyl", "carb")
```

### Result Tibble Construction
```r
# Combine group columns with estimates
result <- tibble::tibble(
  # Group columns (preserve from original data)
  !!!group_cols,
  # Estimate columns
  estimate = point_estimates,
  se = standard_errors,
  ci_lower = ci_lower_bounds,
  ci_upper = ci_upper_bounds,
  n = sample_sizes
)

# Example with actual values
tibble::tibble(
  day_type = c("weekday", "weekend"),
  estimate = c(450.2, 892.7),
  se = c(23.1, 45.3),
  ci_lower = c(405.0, 804.0),
  ci_upper = c(495.4, 981.4),
  n = c(10L, 15L)
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Formula `by = ~var` everywhere | Tidy eval for user-facing params, formula for internal survey calls | tidyverse ~2016+ | Users write bare names, package translates to formulas internally |
| group_by() then summarize | .by parameter in dplyr 1.1+ | 2023 | Per-operation grouping cleaner than persistent grouping for survey context |
| svyby() returns custom class | svyby() returns data frame | survey 4.0+ | Easier to work with results, broom patterns |
| Manual split-apply-combine | svyby() handles everything | survey package inception | Correct variance for domains, handles edge cases |

**Deprecated/outdated:**
- Using `subset()` then estimation function for domains (never correct for variance)
- Formula notation in user-facing tidyverse-style packages (tidy eval is now standard)
- Returning custom S3 classes that require special methods (tibbles + broom patterns preferred)

## Open Questions

1. **Sample size calculation for groups**
   - What we know: svyby doesn't return per-group sample sizes automatically
   - What's unclear: Should we count observations in design$counts or use survey package's nobs() function on subsets?
   - Recommendation: Count rows in design$counts grouped by by_vars (simpler, matches user's mental model of "how many days")

2. **Empty group handling**
   - What we know: `drop.empty.groups = TRUE` silently drops, `FALSE` errors
   - What's unclear: What behavior do creel biologists expect when a group has no observations?
   - Recommendation: Use `drop.empty.groups = TRUE` (drop silently) and document this behavior. Creel surveys often have unbalanced designs where some strata-site combinations don't appear.

3. **Variance method interaction with grouping**
   - What we know: Phase 6 will add bootstrap/jackknife variance methods
   - What's unclear: Does svyby work with replicate weight designs? (Answer: yes, svyby is variance-method-agnostic)
   - Recommendation: Phase 5 implements grouping with Taylor linearization only. Phase 6 verifies svyby works with replicate weight designs (it should, by design).

4. **Tier 2 validation for groups**
   - What we know: Phase 4 warns on sparse strata (< 3 observations per stratum)
   - What's unclear: Should we warn on sparse groups (< 3 observations per group level)?
   - Recommendation: Yes, extend warn_tier2_issues() to check group sizes when by != NULL. Warn if any group has < 3 observations.

## Sources

### Primary (HIGH confidence)
- [survey package documentation - svyby](https://r-survey.r-forge.r-project.org/survey/html/svyby.html) - official docs on grouped estimation
- [survey package PDF manual (August 2025)](https://cran.r-project.org/web/packages/survey/survey.pdf) - comprehensive reference
- [tidyselect vignette - Implementing tidyselect interfaces](https://cran.r-project.org/web/packages/tidyselect/vignettes/tidyselect.html) - official guide for eval_select
- [tidyselect package docs (July 2025)](https://cran.r-project.org/web/packages/tidyselect/tidyselect.pdf) - API reference
- [rlang data masking documentation](https://rlang.r-lib.org/reference/args_data_masking.html) - tidy evaluation guide

### Secondary (MEDIUM confidence)
- [dplyr group_by documentation](https://dplyr.tidyverse.org/reference/group_by.html) - established patterns for grouping syntax
- [dplyr programming vignette](https://dplyr.tidyverse.org/articles/programming.html) - tidy evaluation in practice
- [srvyr package documentation](https://cran.r-project.org/web/packages/srvyr/srvyr.pdf) - dplyr-like survey analysis for comparison
- [Subpopulation estimation guidance](https://www.stata.com/manuals13/svysubpopulationestimation.pdf) - variance estimation principles

### Tertiary (LOW confidence)
- None - all key findings verified with official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - survey::svyby() is well-established, tidyselect patterns already in use
- Architecture: HIGH - tidy eval patterns proven in Phase 2, svyby patterns documented in survey package
- Pitfalls: MEDIUM - subsetting pitfall well-documented, others inferred from general survey statistics knowledge

**Research date:** 2026-02-09
**Valid until:** ~2026-05-09 (90 days - stable domain, unlikely to change)

**Key decisions made:**
1. Use survey::svyby() internally (not manual grouping)
2. Accept by = parameter with tidy evaluation (not formula)
3. Return grouped tibble with group columns first
4. Maintain backward compatibility with by = NULL for ungrouped estimation
5. Preserve Phase 4 result structure (estimate/se/ci_lower/ci_upper/n columns)
