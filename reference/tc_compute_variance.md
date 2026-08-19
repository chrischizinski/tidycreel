# Compute Variance Using Survey Package Methods

Core variance calculation engine that ALL tidycreel estimators use.
Provides unified interface to multiple variance estimation methods.

## Usage

``` r
tc_compute_variance(
  design,
  response,
  method = "survey",
  by = NULL,
  conf_level = 0.95,
  n_replicates = 1000,
  calculate_deff = TRUE
)
```

## Arguments

- design:

  Survey design object (svydesign or svrepdesign)

- response:

  Response variable (formula or character)

- method:

  Variance estimation method:

  "survey"

  :   Standard survey package variance (default)

  "svyrecvar"

  :   survey:::svyrecvar internals (most accurate)

  "bootstrap"

  :   Bootstrap resampling variance

  "jackknife"

  :   Jackknife resampling variance

  "linearization"

  :   Taylor linearization (same as "survey")

- by:

  Optional grouping variables for stratified estimation

- conf_level:

  Confidence level for intervals (default 0.95)

- n_replicates:

  Number of replicates for bootstrap/jackknife (default 1000)

- calculate_deff:

  Whether to calculate design effects (default TRUE)

## Value

List with variance estimation results:

- estimate:

  Point estimate(s)

- variance:

  Variance estimate(s)

- se:

  Standard error(s)

- ci_lower:

  Lower confidence limit(s)

- ci_upper:

  Upper confidence limit(s)

- deff:

  Design effect(s) (if calculate_deff = TRUE)

- method:

  Variance method used

- method_details:

  Additional method-specific information

- conf_level:

  Confidence level used

## Details

This is the core variance calculation function used by ALL tidycreel
estimators. It provides a unified interface to multiple variance
estimation approaches:

**Standard Methods:**

- `"survey"`: Uses survey package public API (svymean, svytotal, svyby)

- `"linearization"`: Alias for "survey" (Taylor linearization is the
  default)

**Survey Package Internals:**

- `"svyrecvar"`: Direct access to survey:::svyrecvar for maximum
  accuracy

**Resampling Methods:**

- `"bootstrap"`: Bootstrap variance estimation with replicate weights

- `"jackknife"`: Jackknife variance estimation

**Design Effects:** When `calculate_deff = TRUE`, the function computes
design effects (DEFF) which measure the impact of the survey design on
variance compared to simple random sampling. DEFF values \> 1 indicate
design effects from clustering, stratification, or weighting.

## Examples

``` r
if (FALSE) { # \dontrun{
library(survey)
library(tidycreel)

# Create survey design
design <- svydesign(ids = ~1, data = creel_counts, weights = ~1)

# Standard variance
var_result <- tc_compute_variance(design, "anglers_count")

# Bootstrap variance
var_boot <- tc_compute_variance(
  design,
  "anglers_count",
  method = "bootstrap",
  n_replicates = 2000
)

# Survey internals (most accurate)
var_internals <- tc_compute_variance(
  design,
  "anglers_count",
  method = "svyrecvar"
)

# Grouped estimation
var_by_strata <- tc_compute_variance(
  design,
  "anglers_count",
  by = "stratum"
)
} # }
```
