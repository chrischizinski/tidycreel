# tidycreel Survey-First Design Architecture

_Last updated: 2025-10-13_

## Core Principle

**tidycreel uses the `survey` package as its backbone** for all design-based inference. We don't reinvent the wheel—we leverage 20+ years of proven survey methodology.

## Design Philosophy

### Survey-First Workflow

1. **Prepare data**: interviews, counts, sampling calendar
2. **Create survey designs**: Use `as_day_svydesign()` → `survey::svydesign`
3. **Estimate**: Pass survey designs to estimators
4. **Analyze**: Use `survey`/`srvyr` for further analysis

### What tidycreel Provides

- **Creel-specific helpers**: `as_day_svydesign()` computes weights from `target_sample / actual_sample`
- **Domain-specific estimators**: Instantaneous, progressive, aerial, bus-route methods
- **Standard error extraction**: Unified SE handling across all estimators
- **Data validation**: Schema checking for interviews, counts, calendar

### What tidycreel Does NOT Do

- ❌ Custom survey design algorithms (use `survey::svydesign()` directly)
- ❌ Custom variance estimators (use `survey::svytotal()`, `survey::svyratio()`, etc.)
- ❌ Replicate weight generation (use `survey::as.svrepdesign()`)
- ❌ Post-stratification/calibration (use `survey::postStratify()`, `survey::calibrate()`)

## Key Function: `as_day_svydesign()`

This is the primary bridge between tidycreel and the survey package:

```r
# Create a day-level survey design from your calendar
svy_day <- as_day_svydesign(
  calendar,
  day_id = "date",
  strata_vars = c("day_type", "month")
)

# Returns a survey::svydesign object with:
# - Days as PSUs (primary sampling units)
# - Weights = target_sample / actual_sample per stratum
# - Proper stratification if strata_vars provided
# - lonely.psu = "adjust" for single-PSU strata
```

### What it does

1. **Validates** calendar has `day_id`, `target_sample`, `actual_sample`
2. **Filters** to sampled days (`actual_sample > 0`)
3. **Computes weights** per stratum: `target / actual`
4. **Creates design** using `survey::svydesign()` with:
   - `ids = ~day_id` (days as PSUs)
   - `strata = ~strata_vars` (if provided)
   - `weights = ~.w` (computed weights)
   - `nest = TRUE`, `lonely.psu = "adjust"`

## Estimation Workflow

### Effort Estimation

All effort estimators accept a `svy` parameter (survey design object):

```r
# 1. Create day-level design
svy_day <- as_day_svydesign(calendar, day_id = "date", strata_vars = c("day_type"))

# 2. Estimate effort from counts
est_effort.instantaneous(
  counts = counts,
  by = c("location"),
  svy = svy_day,
  day_id = "date"
)

# 3. Or with progressive counts
est_effort.progressive(
  counts = counts,
  by = c("location"),
  svy = svy_day,
  day_id = "date",
  route_minutes_col = "route_minutes",
  pass_id = "pass_id"
)
```

**Under the hood**, estimators:
1. Aggregate counts to day×group totals
2. Join day-level weights from `svy`
3. Call `survey::svyby()` or `survey::svytotal()` for totals
4. Extract SE using `survey::SE()` (not custom variance formulas)

### CPUE/Catch Estimation

```r
# 1. Create interview-level design
# (Join day weights to interviews first)
interviews_weighted <- interviews %>%
  left_join(svy_day$variables %>% select(date, .w), by = "date")

svy_interview <- survey::svydesign(
  ids = ~1,
  weights = ~.w,
  data = interviews_weighted
)

# 2. Estimate CPUE (ratio-of-means)
est_cpue(
  svy_interview,
  by = c("target_species"),
  response = "catch_total",
  mode = "ratio_of_means"
)

# 3. Estimate catch totals
est_catch(
  svy_interview,
  by = c("target_species"),
  response = "catch_kept"
)
```

**Under the hood**:
- Uses `survey::svyratio()` for CPUE (ratio-of-means)
- Uses `survey::svymean()` for CPUE (mean-of-ratios)
- Uses `survey::svytotal()` for catch totals
- Extracts SE using `survey::SE()` and `survey::vcov()`

## Replicate Designs

For robust variance estimation, convert to replicate weights:

```r
# Use survey package's replicate design conversion
svy_rep <- survey::as.svrepdesign(
  svy_day,
  type = "bootstrap",  # or "JK1", "BRR", etc.
  replicates = 50,
  mse = TRUE
)

# Pass to estimators just like regular designs
est_effort.instantaneous(counts, svy = svy_rep, ...)
```

tidycreel estimators automatically detect replicate designs and use `survey::svrepdesign` methods for variance.

## Advanced Survey Techniques

Since all estimators return standard survey objects, you can use the full power of the `survey` package:

### Post-Stratification

```r
# Create base design
svy_day <- as_day_svydesign(calendar, ...)

# Post-stratify to known population
pop_table <- data.frame(
  day_type = c("weekday", "weekend"),
  Freq = c(250, 100)
)
svy_post <- survey::postStratify(
  svy_day,
  ~day_type,
  pop_table
)

# Use post-stratified design
est_effort.instantaneous(counts, svy = svy_post, ...)
```

### Calibration

```r
# Calibrate to known totals
svy_cal <- survey::calibrate(
  svy_day,
  formula = ~day_type + season,
  population = known_totals,
  calfun = survey::cal.linear
)

# Use calibrated design
est_effort.instantaneous(counts, svy = svy_cal, ...)
```

### Domain Estimation

```r
# Subset design for specific domains
svy_subset <- subset(svy_day, region == "North")
est_effort.instantaneous(counts_north, svy = svy_subset, ...)
```

## Design Assumptions

All creel survey designs rely on:

1. **Random sampling within stratum**: Each unit selected randomly
2. **Correct stratification**: Strata reflect true variation
3. **Known inclusion probabilities**: From sampling calendar
4. **Random or corrected nonresponse**: Accounted for in weights
5. **Accurate reporting**: Anglers provide truthful information
6. **No double-counting**: Each angler counted once per unit

**Always** review and document assumptions. Use sensitivity analyses if violations suspected.

## Diagnostics

### Check Survey Design

```r
# Examine weights
summary(weights(svy_day))

# Check stratification
table(svy_day$variables$strata)

# Look for lonely PSUs
summary(svy_day$strata)

# Check effective sample size
survey::degf(svy_day)
```

### Check Estimation Results

```r
# Look for unreasonably large SEs
result <- est_effort.instantaneous(counts, svy = svy_day, ...)
result %>% mutate(cv = se / estimate) %>% filter(cv > 0.5)

# Check for NA standard errors (data/design issue)
result %>% filter(is.na(se))

# Compare designs
result_srs <- est_effort.instantaneous(counts, svy = NULL, ...)  # No design
result_complex <- est_effort.instantaneous(counts, svy = svy_day, ...)
```

## Best Practices

1. **Always use `as_day_svydesign()`** for day-level designs
2. **Pass `svy` to all estimators** for proper variance
3. **Use `survey::as.svrepdesign()`** for replicate weights
4. **Leverage `survey` functions** for post-stratification, calibration
5. **Document assumptions** in your analysis scripts
6. **Check diagnostics** before reporting estimates
7. **Use `srvyr`** for dplyr-style survey analysis if preferred

## Why This Approach?

### Advantages

- ✅ **Proven methodology**: Survey package has 20+ years of development
- ✅ **Correct variance**: Design-based inference with proper SE/CI
- ✅ **No reinventing**: We use what works
- ✅ **Flexibility**: Full survey package functionality available
- ✅ **Integration**: Works with srvyr, survey, and other R survey tools
- ✅ **Transparency**: Clear where tidycreel stops and survey begins

### When to Use Custom Code

Only write custom code for:
- Creel-specific data transformations
- Domain-specific weight calculations (e.g., `target_sample / actual_sample`)
- Convenience wrappers that delegate to survey functions
- Data validation and schema checking

**Never** write custom code for:
- Survey design construction (use `survey::svydesign`)
- Variance estimation (use `survey::svytotal`, `survey::SE`, etc.)
- Replicate weights (use `survey::as.svrepdesign`)
- Post-stratification/calibration (use `survey::postStratify`, `survey::calibrate`)

## Examples

### Complete Workflow

```r
library(tidycreel)
library(survey)
library(dplyr)

# 1. Load data
calendar <- read.csv("calendar.csv")
counts <- read.csv("counts.csv")
interviews <- read.csv("interviews.csv")

# 2. Create day-level survey design
svy_day <- as_day_svydesign(
  calendar,
  day_id = "date",
  strata_vars = c("day_type", "month")
)

# 3. Estimate effort
effort_est <- est_effort.instantaneous(
  counts = counts,
  by = c("location"),
  svy = svy_day,
  day_id = "date",
  minutes_col = "interval_minutes",
  total_minutes_col = "total_day_minutes"
)

# 4. Estimate CPUE
interviews_weighted <- interviews %>%
  left_join(svy_day$variables %>% select(date, .w), by = "date")

svy_interview <- survey::svydesign(
  ids = ~1,
  weights = ~.w,
  data = interviews_weighted
)

cpue_est <- est_cpue(
  svy_interview,
  by = c("target_species"),
  response = "catch_total"
)

# 5. Report
effort_est %>%
  mutate(cv = se / estimate) %>%
  select(location, estimate, se, ci_low, ci_high, cv)
```

### With Replicate Weights

```r
# Convert to bootstrap design
svy_rep <- survey::as.svrepdesign(
  svy_day,
  type = "bootstrap",
  replicates = 100,
  mse = TRUE
)

# Estimate with replicate design
effort_rep <- est_effort.instantaneous(
  counts = counts,
  by = c("location"),
  svy = svy_rep,
  day_id = "date"
)

# Compare standard vs replicate SEs
comparison <- bind_rows(
  effort_est %>% mutate(method = "standard"),
  effort_rep %>% mutate(method = "replicate")
)
```

## References

- Lumley, T. (2004). *Analysis of complex survey samples*. Journal of Statistical Software, 9(1), 1-19.
- Lumley, T. (2010). *Complex surveys: A guide to analysis using R*. Wiley.
- Pollock, K. H., Jones, C. M., & Brown, T. L. (1994). *Angler survey methods and their applications in fisheries management*. American Fisheries Society.

---

For questions or issues with this approach, see:
- `vignette("getting-started")` - Introduction to survey-first workflow
- `vignette("effort_survey_first")` - Detailed effort estimation
- `vignette("aerial")` - Aerial survey methods
- [tidycreel GitHub Issues](https://github.com/chrischizinski/tidycreel/issues)
