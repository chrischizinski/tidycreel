# Migration Guide: Variance Engine Integration

**Version**: 0.4.0 (unreleased) **Date**: 2025-10-27 **Impact**: Medium
(Breaking changes in return schema, removed function)

------------------------------------------------------------------------

## Summary of Changes

This release introduces a **unified variance calculation engine** across
all tidycreel estimators, enabling advanced variance methods and
improved diagnostics. While most function parameters remain backward
compatible, **the return value structure has changed**, which may impact
existing code.

------------------------------------------------------------------------

## Breaking Changes

### 1. Return Value Schema Changed ⚠️

**All estimator functions now return additional columns:**

- `deff`: Design effect (ratio of actual variance to SRS variance)
- `variance_info`: List-column with detailed variance information

**OLD SCHEMA:**

``` r
tibble(
  [grouping_vars],
  estimate, se, ci_low, ci_high, n, method, diagnostics
)
```

**NEW SCHEMA:**

``` r
tibble(
  [grouping_vars],
  estimate, se, ci_low, ci_high,
  deff,           # NEW
  n, method, diagnostics,
  variance_info   # NEW
)
```

**Functions affected:** - [`est_cpue()`](reference/est_cpue.md) -
[`est_effort.aerial()`](reference/est_effort.aerial.md) -
[`est_effort.busroute_design()`](reference/est_effort.busroute_design.md) -
[`est_effort.instantaneous()`](reference/est_effort.instantaneous.md) -
[`est_effort.progressive()`](reference/est_effort.progressive.md) -
[`est_total_harvest()`](reference/est_total_harvest.md) -
[`aggregate_cpue()`](reference/aggregate_cpue.md)

#### Impact

**Code using positional column access will break:**

``` r
# ❌ BREAKS - column positions changed
result <- est_cpue(design, response = "catch_kept")
result[[5]]  # Was 'ci_high', now 'deff'

# ✅ SAFE - use named access
result$ci_high  # Still works
```

**Code selecting specific columns may need updates:**

``` r
# ❌ MAY BREAK - if not using dplyr::everything()
result %>% select(-diagnostics)  # Now also has variance_info

# ✅ SAFE - explicitly select needed columns
result %>% select(estimate, se, ci_low, ci_high, n)
```

#### Migration Path

**Option 1: Update to named column access (recommended)**

``` r
# Before
my_estimate <- result[[1]]  # Fragile

# After
my_estimate <- result$estimate  # Robust
```

**Option 2: Select only needed columns**

``` r
# Add at end of your pipeline
result <- est_cpue(...) %>%
  select(estimate, se, ci_low, ci_high, n, method)  # Ignore new columns
```

**Option 3: Ignore new columns in your code**

The new columns don’t affect existing calculations - you can simply
ignore them:

``` r
# This still works as before
harvest <- est_total_harvest(effort_est, cpue_est)
# harvest$estimate, harvest$se, etc. all work as expected
```

------------------------------------------------------------------------

### 2. Function Removed: `est_effort_aerial()` ⚠️

**Removed**: `est_effort_aerial()` (top-level function) **Use instead**:
[`est_effort.aerial()`](reference/est_effort.aerial.md) (S3 method)

#### Migration Path

``` r
# ❌ REMOVED
result <- est_effort_aerial(design, response = "counts")

# ✅ USE THIS
result <- est_effort.aerial(design, response = "counts")

# OR use generic
result <- est_effort(design, response = "counts", method = "aerial")
```

------------------------------------------------------------------------

### 3. Reserved Column Name: `.interview_id` 🆕

The internal column name `.interview_id` is now reserved in
[`aggregate_cpue()`](reference/aggregate_cpue.md).

#### Impact

If your input data contains a column named `.interview_id`, you’ll get
an error:

``` r
# ❌ ERRORS if data has .interview_id column
aggregate_cpue(
  cpue_data = interviews,  # Contains .interview_id
  ...
)
# Error: Input data contains a column named `.interview_id`
```

#### Migration Path

``` r
# ✅ Rename the column
interviews_clean <- interviews %>%
  rename(original_interview_id = .interview_id)

aggregate_cpue(cpue_data = interviews_clean, ...)
```

------------------------------------------------------------------------

## New Features (Opt-In)

### 1. Multiple Variance Methods 🆕

You can now choose variance estimation methods:

``` r
result <- est_cpue(
  design,
  response = "catch_kept",
  variance_method = "bootstrap",  # NEW parameter
  n_replicates = 1000            # NEW parameter
)
```

**Available methods:** - `"survey"` (default) - Standard survey package
(Taylor linearization) - `"bootstrap"` - Bootstrap resampling -
`"jackknife"` - Jackknife resampling - `"svyrecvar"` - Survey package
internals (advanced) - `"linearization"` - Alias for “survey”

**Usage:**

``` r
# Bootstrap variance (more accurate for complex designs)
result_boot <- est_cpue(
  design,
  response = "catch_kept",
  variance_method = "bootstrap",
  n_replicates = 2000  # Higher = more precision
)

# Jackknife variance (faster than bootstrap)
result_jk <- est_cpue(
  design,
  response = "catch_kept",
  variance_method = "jackknife"
)
```

**When to use:** - **Survey** (default): Standard approach, fastest -
**Bootstrap**: More accurate for complex designs, slower -
**Jackknife**: Balance of speed and accuracy - **Linearization**: Same
as “survey”, included for clarity

------------------------------------------------------------------------

### 2. Variance Decomposition 🆕

Decompose variance into components to understand survey design
efficiency:

``` r
result <- est_cpue(
  design,
  response = "catch_kept",
  decompose_variance = TRUE  # NEW parameter
)

# Access decomposition
var_info <- result$variance_info[[1]]
var_info$decomposition  # Variance components
```

**Use cases:** - Determine optimal sample allocation - Identify largest
variance sources - Design effects by component - Sample size planning

------------------------------------------------------------------------

### 3. Design Diagnostics 🆕

Get diagnostic information about your survey design:

``` r
result <- est_cpue(
  design,
  response = "catch_kept",
  design_diagnostics = TRUE  # NEW parameter
)

# Access diagnostics
var_info <- result$variance_info[[1]]
var_info$diagnostics_survey  # Design diagnostics
```

**Provides:** - Design type and structure - Clustering information -
Effective sample size - Design effects

------------------------------------------------------------------------

## Enhanced Error Handling 🆕

### Zero Effort Warning

The package now warns when data contains zero or negative effort:

``` r
# Data with zero effort
interviews$hours_fished[1:3] <- 0

result <- est_cpue(design, response = "catch_kept")
# Warning: 3 observation(s) have zero or negative effort
# These will produce Inf or NaN CPUE values
# Consider filtering data or setting a minimum effort threshold
```

**These values are now automatically converted to NA instead of
Inf/NaN.**

### Empty Groups Warning

When using grouped estimation with empty or very small groups:

``` r
result <- est_cpue(design, by = "stratum", response = "catch_kept")
# Warning: 2 group(s) have fewer than 3 observations
# Variance estimates may be unstable for these groups
```

------------------------------------------------------------------------

## Backward Compatibility

### What Still Works ✅

**All existing code using default parameters should work:**

``` r
# This still works exactly as before (just returns extra columns)
result <- est_cpue(design, response = "catch_kept")
result <- est_effort.instantaneous(design, response = "counts")
result <- est_total_harvest(effort_est, cpue_est)
result <- aggregate_cpue(interviews, design, species_values = c("bass", "pike"),
                         group_name = "predators")
```

**Named column access is safe:**

``` r
# All these still work
result$estimate
result$se
result$ci_low
result$ci_high
result$n
```

### What May Break ⚠️

**Positional column access:**

``` r
# ❌ May break
result[[5]]  # Column order changed

# ✅ Fix
result$ci_high
```

**Exact column matching:**

``` r
# ❌ May break
expect_equal(ncol(result), 7)  # Now 9 columns

# ✅ Fix
expect_true(all(c("estimate", "se", "ci_low", "ci_high") %in% names(result)))
```

**Selecting all-but-one column:**

``` r
# ❌ May break
result %>% select(-diagnostics)  # Still has variance_info

# ✅ Fix
result %>% select(estimate, se, ci_low, ci_high, n, method)
```

------------------------------------------------------------------------

## Testing Your Code

### Automated Checks

``` r
# Check for positional column access
grep("\\[\\[[0-9]+\\]\\]", your_code.R)  # Search for [[n]] patterns

# Check for est_effort_aerial
grep("est_effort_aerial\\(", your_code.R)  # Search for old function

# Check for .interview_id columns
grep("\\.interview_id", your_data_prep.R)  # Search for reserved name
```

### Manual Testing

``` r
# Run your existing workflows
source("your_analysis.R")

# Check results still make sense
summary(results)

# Verify new columns don't break downstream code
print(names(results))  # Should see deff, variance_info
```

------------------------------------------------------------------------

## FAQ

### Q: Do I need to update my code immediately?

**A:** Only if you use: 1. Positional column access (`result[[n]]`) 2.
`est_effort_aerial()` function 3. Data with a `.interview_id` column in
[`aggregate_cpue()`](reference/aggregate_cpue.md)

Otherwise, your code should work but will return extra columns you can
ignore.

### Q: Should I start using the new variance methods?

**A:** The default `variance_method = "survey"` maintains previous
behavior. Consider bootstrap/jackknife for: - Complex survey designs
with many strata - Small sample sizes in some groups - When you need
more accurate variance estimates

### Q: What is the `deff` column for?

**A:** Design effect measures how much the survey design inflates
variance compared to simple random sampling. `deff > 1` indicates design
effects from clustering, stratification, or unequal weighting.

### Q: What’s in the `variance_info` list-column?

**A:** - `method`: Actual variance method used - `requested_method`:
Method you requested (may differ if fallback occurred) -
`method_details`: Method-specific information (e.g., number of
replicates) - `decomposition`: Variance component decomposition (if
requested) - `diagnostics_survey`: Design diagnostics (if requested)

### Q: How do I know if a fallback occurred?

**A:**

``` r
var_info <- result$variance_info[[1]]

# Check if fallback happened
if (!is.null(var_info$method_details$fallback)) {
  cat("Requested:", var_info$requested_method, "\n")
  cat("Actually used:", var_info$method, "\n")
  cat("Reason:", var_info$method_details$fallback_from, "\n")
}
```

------------------------------------------------------------------------

## Getting Help

- **Issues**: Report problems at
  <https://github.com/chrischizinski/tidycreel/issues>
- **Questions**: Use GitHub Discussions
- **Documentation**: See function help files
  ([`?est_cpue`](reference/est_cpue.md), etc.)

------------------------------------------------------------------------

## Checklist for Migration

- Search code for positional column access (`[[n]]`)
- Replace `est_effort_aerial()` with
  [`est_effort.aerial()`](reference/est_effort.aerial.md)
- Check for `.interview_id` in your data
- Run your test suite
- Update any assertions about column counts/names
- Consider trying new variance methods on test data
- Update your documentation if you describe output schema

------------------------------------------------------------------------

**Last updated**: 2025-10-27 **Version**: 0.4.0
