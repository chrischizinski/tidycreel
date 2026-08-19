# Aggregate CPUE Across Species (REBUILT with Native Survey Integration)

Combines CPUE estimates for multiple species into a single aggregate,
properly accounting for survey design and covariance between species
with NATIVE support for advanced variance methods.

## Usage

``` r
aggregate_cpue(
  cpue_data,
  svy_design,
  species_col = "species",
  species_values,
  group_name,
  by = NULL,
  response = c("catch_total", "catch_kept", "catch_released"),
  effort_col = "hours_fished",
  mode = "ratio_of_means",
  conf_level = 0.95,
  variance_method = "survey",
  decompose_variance = FALSE,
  design_diagnostics = FALSE,
  n_replicates = 1000
)
```

## Arguments

- cpue_data:

  Interview data (raw, before estimation) containing catch by species

- svy_design:

  Survey design object (`svydesign` or `svrepdesign`) built on
  `cpue_data`

- species_col:

  Column name containing species identifier

- species_values:

  Character vector of species to aggregate

- group_name:

  Name for the aggregated group (e.g., "black_bass", "panfish")

- by:

  Additional grouping variables (e.g., `c("location", "date")`)

- response:

  Type of catch: `"catch_total"`, `"catch_kept"`, or `"catch_released"`

- effort_col:

  Effort column for denominator (default `"hours_fished"`)

- mode:

  Estimation mode: `"auto"`, `"ratio_of_means"`, or `"mean_of_ratios"`.
  Defaults to `"ratio_of_means"` for robustness.

- conf_level:

  Confidence level for Wald CIs (default 0.95)

- variance_method:

  **NEW** Variance estimation method (default "survey")

- decompose_variance:

  **NEW** Logical, decompose variance (default FALSE)

- design_diagnostics:

  **NEW** Logical, compute diagnostics (default FALSE)

- n_replicates:

  **NEW** Bootstrap/jackknife replicates (default 1000)

## Value

Tibble with grouping columns (including `species_group`), `estimate`,
`se`, `ci_low`, `ci_high`, `deff` (design effect), `n`, `method`,
`diagnostics` list-column, and `variance_info` list-column.

## Details

**NEW**: Native support for multiple variance methods, variance
decomposition, and design diagnostics without requiring wrapper
functions.

**Statistical Approach:**

This function performs survey-design-based aggregation, which is
CRITICAL for proper variance estimation. It works by:

1.  Creating an aggregated catch variable by summing catch across
    specified species

2.  Updating the survey design with this aggregated variable

3.  Estimating CPUE for the aggregate using standard survey methods

4.  Properly accounting for covariance between species

**Why This Matters:**

Simply adding species-specific harvest estimates ignores covariance
between species. This function ensures proper variance by aggregating at
the CPUE level.

## See also

[`est_cpue()`](est_cpue.md),
[`est_total_harvest()`](est_total_harvest.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# BACKWARD COMPATIBLE
cpue_black_bass <- aggregate_cpue(
  interviews, svy_int,
  species_values = c("largemouth_bass", "smallmouth_bass"),
  group_name = "black_bass"
)

# NEW: Advanced features
cpue_black_bass <- aggregate_cpue(
  interviews, svy_int,
  species_values = c("largemouth_bass", "smallmouth_bass"),
  group_name = "black_bass",
  variance_method = "bootstrap",
  decompose_variance = TRUE,
  design_diagnostics = TRUE
)
} # }
```
