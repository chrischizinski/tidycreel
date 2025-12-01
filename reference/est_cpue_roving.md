# Estimate CPUE for Roving Creel Surveys (Pollock et al. 1997)

Design-based CPUE estimation for roving (incomplete trip) interviews
with length-biased sampling correction. Uses Pollock et al. (1997)
methods specifically designed for roving surveys where anglers are
intercepted during their fishing trips.

## Usage

``` r
est_cpue_roving(
  design,
  by = NULL,
  response = c("catch_total", "catch_kept", "catch_released"),
  effort_col = "hours_fished",
  min_trip_hours = 0.5,
  length_bias_correction = c("none", "pollock"),
  total_trip_effort_col = NULL,
  conf_level = 0.95,
  diagnostics = TRUE
)
```

## Arguments

- design:

  A `svydesign`/`svrepdesign` built on interview data with incomplete
  trips (roving surveys).

- by:

  Character vector of grouping variables (e.g.,
  `c("location", "species")`).

- response:

  One of `"catch_total"`, `"catch_kept"`, `"catch_released"`.

- effort_col:

  Interview effort column (default `"hours_fished"`). For incomplete
  trips, this is **observed effort at time of interview**.

- min_trip_hours:

  Minimum trip duration for inclusion. Trips shorter than this threshold
  are excluded to avoid unstable ratios. Default 0.5 hours (Hoenig et
  al. 1997 recommendation).

- length_bias_correction:

  Apply length-biased sampling correction (Pollock et al. 1997).
  Options:

  - `"none"`: No correction (assumes complete trips or no length bias)

  - `"pollock"`: Pollock et al. (1997) correction (recommended for
    roving)

- total_trip_effort_col:

  Column containing **total planned trip effort** (only needed if
  `length_bias_correction = "pollock"`). For incomplete trips, this is
  the angler's stated total planned fishing time.

- conf_level:

  Confidence level for confidence intervals (default 0.95).

- diagnostics:

  Include diagnostic information in output (default `TRUE`).

## Value

Tibble with standard tidycreel schema:

- Grouping columns (from `by` parameter)

- `estimate`: CPUE estimate (catch per unit effort)

- `se`: Standard error

- `ci_low`, `ci_high`: Confidence interval bounds

- `n`: Sample size (after truncation)

- `method`: Method identifier

- `diagnostics`: List-column with diagnostic information

## Details

### Statistical Method

Roving surveys interview anglers **during their trips**, creating two
issues:

1.  **Incomplete catch data** - Trip not yet finished

2.  **Length-biased sampling** - Longer trips more likely intercepted

#### Mean-of-Ratios Estimator (Pollock et al. 1997)

For each interview \\i\\, calculate individual catch rate: \$\$r_i =
\frac{c_i}{e_i}\$\$

where:

- \\c_i\\ = catch at time of interview

- \\e_i\\ = effort at time of interview

Mean catch rate: \$\$\bar{r} = \frac{1}{n} \sum\_{i=1}^n r_i\$\$

Variance (mean-of-ratios): \$\$Var(\bar{r}) = \frac{1}{n(n-1)}
\sum\_{i=1}^n (r_i - \bar{r})^2\$\$

#### Length-Biased Sampling Correction

When `length_bias_correction = "pollock"`:

Correction factor for each observation: \$\$w_i = \frac{1}{T_i}\$\$

where \\T_i\\ is total planned trip duration.

Corrected estimator: \$\$\bar{r}\_{corrected} = \frac{\sum\_{i=1}^n w_i
r_i}{\sum\_{i=1}^n w_i}\$\$

### When to Use This Function

**Use `est_cpue_roving()` when:**

- Conducting roving (on-water, circuit) surveys

- Interviewing anglers **during their trips** (incomplete)

- Trip completion times unknown at interview

- Need length-bias correction for accurate estimates

**Use [`est_cpue()`](est_cpue.md) instead when:**

- Access-point interviews with **completed trips**

- Trip duration and catch fully observed

- No length-biased sampling concerns

## References

Pollock, K.H., C.M. Jones, and T.L. Brown. 1994. Angler Survey Methods
and Their Applications in Fisheries Management. American Fisheries
Society Special Publication 25. Bethesda, Maryland.

Hoenig, J.M., C.M. Jones, K.H. Pollock, D.S. Robson, and D.L. Wade.
1997. Calculation of catch rate and total catch in roving and access
point surveys. Biometrics 53:306-317.

## See also

[`est_cpue()`](est_cpue.md), [`est_effort()`](est_effort.md),
[`aggregate_cpue()`](aggregate_cpue.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(tidycreel)
library(survey)

# Roving survey data (incomplete trips)
# hours_fished = observed so far, catch_kept = current

# Create survey design
svy_roving <- svydesign(
  ids = ~1,
  strata = ~location,
  data = roving_interviews
)

# Estimate CPUE with Pollock correction (requires total_trip_effort)
cpue_roving <- est_cpue_roving(
  design = svy_roving,
  by = c("location", "species"),
  response = "catch_kept",
  effort_col = "hours_fished",
  total_trip_effort_col = "planned_hours",  # Stated total trip duration
  length_bias_correction = "pollock",
  min_trip_hours = 0.5
)

# Without length-bias correction (assumes no bias or complete trips)
cpue_simple <- est_cpue_roving(
  design = svy_roving,
  by = "location",
  response = "catch_total",
  length_bias_correction = "none"
)
} # }
```
