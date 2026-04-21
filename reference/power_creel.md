# Unified sample-size and power interface for creel surveys

A single tidy entry point for pre-survey sample-size planning that wraps
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
[`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md),
and
[`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md)
and returns a consistent tibble.

## Usage

``` r
power_creel(
  mode = c("effort_n", "cpue_n", "power"),
  target_rse = NULL,
  strata = NULL,
  N_h = NULL,
  ybar_h = NULL,
  s2_h = NULL,
  cv_catch = NULL,
  cv_effort = NULL,
  rho = 0,
  n = NULL,
  cv_historical = NULL,
  delta_pct = NULL,
  alpha = 0.05,
  alternative = c("two.sided", "one.sided")
)
```

## Arguments

- mode:

  Character scalar. One of `"effort_n"`, `"cpue_n"`, or `"power"`.
  Selects the planning formula.

- target_rse:

  Numeric scalar in (0, 1\]. Target relative standard error (= target
  CV). Required for `mode %in% c("effort_n", "cpue_n")`.

- strata:

  Character vector of stratum names. Required for `mode = "effort_n"`.
  Length must match `N_h`, `ybar_h`, and `s2_h`.

- N_h:

  Numeric vector. Total sampling days available per stratum. Required
  for `mode = "effort_n"`.

- ybar_h:

  Numeric vector. Pilot mean effort per day per stratum. Required for
  `mode = "effort_n"`.

- s2_h:

  Numeric vector. Pilot variance of effort per day per stratum. Required
  for `mode = "effort_n"`.

- cv_catch:

  Numeric scalar. Pilot CV of catch per interview. Required for
  `mode %in% c("cpue_n", "power")`.

- cv_effort:

  Numeric scalar. Pilot CV of effort per interview. Required for
  `mode = "cpue_n"`.

- rho:

  Numeric scalar in \[-1, 1\]. Pilot correlation between catch and
  effort. Default `0` (conservative). Used for
  `mode %in% c("cpue_n", "power")`.

- n:

  Integerish scalar. Sample size (interviews) for `mode = "power"`.

- cv_historical:

  Numeric scalar. Historical CV of CPUE for `mode = "power"`. If `NULL`,
  `cv_catch` is used as a proxy.

- delta_pct:

  Numeric scalar (\> 0). Fractional change to detect. Required for
  `mode = "power"`.

- alpha:

  Numeric scalar in (0, 0.5\]. Type I error rate. Default `0.05`. Used
  for `mode = "power"`.

- alternative:

  Character. `"two.sided"` (default) or `"one.sided"`. Used for
  `mode = "power"`.

## Value

A tibble (data frame) with columns varying by mode:

**`mode = "effort_n"`** (one row per stratum plus a `"total"` row):

- `stratum`:

  Stratum name.

- `n_required`:

  Sampling days required.

- `target_rse`:

  The requested target RSE.

**`mode = "cpue_n"`** (one row):

- `n_required`:

  Interviews required.

- `target_rse`:

  The requested target RSE.

- `cv_catch`:

  Input CV of catch.

- `cv_effort`:

  Input CV of effort.

- `rho`:

  Input correlation.

**`mode = "power"`** (one row):

- `power`:

  Estimated statistical power.

- `n`:

  Input sample size.

- `delta_pct`:

  Input fractional change.

- `cv_historical`:

  Historical CV used.

- `alpha`:

  Input significance level.

- `alternative`:

  Input test direction.

## Details

Three `mode` values are supported:

- `"effort_n"`:

  Required sampling *days* per stratum to achieve `target_rse` on the
  effort estimate (calls
  [`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md)).

- `"cpue_n"`:

  Required *interviews* to achieve `target_rse` on the CPUE estimate
  (calls
  [`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md)).

- `"power"`:

  Statistical power to detect a fractional change in CPUE at a given
  sample size (calls
  [`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md)).

## See also

[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
[`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md),
[`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md)

Other "Planning & Sample Size":
[`compare_designs()`](https://chrischizinski.github.io/tidycreel/reference/compare_designs.md),
[`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md),
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
[`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md),
[`cv_from_n()`](https://chrischizinski.github.io/tidycreel/reference/cv_from_n.md)

## Examples

``` r
# Effort: sampling days needed for 20 percent RSE
power_creel(
  mode       = "effort_n",
  target_rse = 0.20,
  strata     = c("weekday", "weekend"),
  N_h        = c(65, 28),
  ybar_h     = c(50, 60),
  s2_h       = c(400, 500)
)
#>   stratum n_required target_rse
#> 1 weekday          3        0.2
#> 2 weekend          2        0.2
#> 3   total          4        0.2

# CPUE: interviews needed for 20 percent RSE
power_creel(
  mode       = "cpue_n",
  target_rse = 0.20,
  cv_catch   = 0.8,
  cv_effort  = 0.5
)
#>   n_required target_rse cv_catch cv_effort rho
#> 1         23        0.2      0.8       0.5   0

# Power: detect a 20 percent change with n = 80 interviews
power_creel(
  mode          = "power",
  n             = 80L,
  cv_historical = 0.5,
  delta_pct     = 0.20
)
#>       power  n delta_pct cv_historical alpha alternative
#> 1 0.7156166 80       0.2           0.5  0.05   two.sided
```
