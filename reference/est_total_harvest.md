# Estimate Total Harvest/Catch Using Product Estimator (REBUILT)

Estimates total harvest, catch, or releases by multiplying effort and
CPUE estimates with proper variance propagation using the delta method.

## Usage

``` r
est_total_harvest(
  effort_est,
  cpue_est,
  by = NULL,
  response = c("catch_total", "catch_kept", "catch_released"),
  method = c("product", "separate_ratio"),
  correlation = NULL,
  conf_level = 0.95,
  diagnostics = TRUE
)
```

## Arguments

- effort_est:

  Tibble from [`est_effort()`](est_effort.md) with effort estimates

- cpue_est:

  Tibble from [`est_cpue()`](est_cpue.md) or
  [`aggregate_cpue()`](aggregate_cpue.md) with CPUE estimates

- by:

  Character vector of grouping variables (must match between inputs).

- response:

  Type of catch: `"catch_total"`, `"catch_kept"`, or `"catch_released"`.

- method:

  Estimation method: `"product"` (default) or `"separate_ratio"`.

- correlation:

  Correlation between effort and CPUE estimates (default `NULL`):

  - `NULL`: Independent (conservative)

  - Numeric (-1 to 1): Specified correlation

  - `"auto"`: Estimate from data (not implemented)

- conf_level:

  Confidence level for Wald CIs (default 0.95)

- diagnostics:

  Include diagnostic information (default `TRUE`)

## Value

Tibble with grouping columns, `estimate`, `se`, `ci_low`, `ci_high`,
`deff` (design effect propagated from inputs), `n`, `method`,
`diagnostics` list-column, and `variance_info` list-column.

## Details

**REBUILT**: Enhanced output structure with design effects and
comprehensive variance information, matching the native survey
integration architecture.

### Statistical Method

Combines effort (E) and CPUE (C): H = E x C

### Variance Propagation (Delta Method)

Independent (default): Var(H) = E^2 x Var(C) + C^2 x Var(E) Correlated:
Var(H) = E^2 x Var(C) + C^2 x Var(E) + 2 x E x C x Cov(E,C)

### Species Aggregation

Use [`aggregate_cpue()`](aggregate_cpue.md) BEFORE this function for
proper variance:

    # CORRECT
    cpue_black_bass <- aggregate_cpue(interviews, svy_int,
      species_values = c("largemouth_bass", "smallmouth_bass"),
      group_name = "black_bass")
    harvest <- est_total_harvest(effort_est, cpue_black_bass)

    # WRONG (ignores covariance)
    harvest <- sum(est_total_harvest(effort, cpue_lmb)$estimate,
                   est_total_harvest(effort, cpue_smb)$estimate)

## References

Pollock, K.H., C.M. Jones, and T.L. Brown. 1994. Angler Survey Methods.
American Fisheries Society Special Publication 25.

## See also

[`est_effort()`](est_effort.md), [`est_cpue()`](est_cpue.md),
[`aggregate_cpue()`](aggregate_cpue.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# BACKWARD COMPATIBLE
harvest <- est_total_harvest(effort_est, cpue_est)

# NEW: Enhanced output with deff and variance_info
harvest <- est_total_harvest(effort_est, cpue_est)
harvest$deff  # Design effect propagated from inputs
harvest$variance_info[[1]]  # Delta method details
} # }
```
