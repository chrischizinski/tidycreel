# Estimate angler effort from camera/time-lapse count data

Estimates total angler-hours from a camera-based creel survey design.
Two estimation modes are supported:

## Usage

``` r
est_effort_camera(
  design,
  interviews = NULL,
  effort_col = "hours_fished",
  n_anglers = NULL,
  intercept_col = NULL,
  h_open = NULL,
  calibration = NULL,
  variance = c("taylor", "replicate"),
  conf_level = 0.95
)
```

## Arguments

- design:

  A `creel_design` object created with
  `creel_design(..., survey_type = "camera")` and counts attached via
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).

- interviews:

  Optional data frame of angler interview records for ratio calibration.
  Must contain the columns named by `strata_col` (matching
  `design$strata_cols[1]`) and `effort_col`. When `NULL`, falls back to
  raw count expansion and `h_open` is required.

- effort_col:

  Character scalar. Column in `interviews` containing per-trip effort in
  hours. Default `"hours_fished"`.

- n_anglers:

  Optional party size for the ratio-calibration path. Either a character
  scalar naming a column in `interviews`, or a single positive number
  stating a constant party size (`n_anglers = 1` for individual-level
  interviews).

  The calibration ratio cancels the camera counts, so the estimate
  inherits whatever unit `effort_col` holds. Supplying `n_anglers` makes
  this function perform the party-size multiplication, so the result is
  angler-hours and is labelled as such. Omitting it leaves the estimate
  in the unit of the column you supplied, which the package cannot
  identify: the unit is reported as unknown and a warning names the
  ambiguity. Default `NULL`.

- intercept_col:

  Character scalar or `NULL`. Column in the count data representing the
  camera count during the interview interception period. Default `NULL`
  (auto-detects the first numeric count column).

- h_open:

  Numeric scalar. Fishable hours per day. Required when
  `interviews = NULL`. Default `NULL`.

- calibration:

  Pass the string `"none"` to run the raw-count expansion path without
  any calibration. Required to reach that path, because expanding a raw
  camera count by `h_open` alone silently assumes each counted object
  contributes exactly one angler-hour per hour open — a calibration of 1
  that was never measured (GH \#158).

  Under the opt-out the point estimate uses that assumption and the
  reported SE is `NA`: the `calibration` component is
  present-and-unknown rather than absent, because the correction applies
  and was simply not measured. It is never `0`, which would be
  indistinguishable from having propagated the calibration's uncertainty
  and found none.

  Supplying `interviews` instead uses the ratio-calibration path, which
  estimates hours of effort per camera count per stratum and propagates
  that ratio's variance. Prefer it whenever interview data exist.

- variance:

  Character. Variance method: `"taylor"` (default) or `"replicate"`.

- conf_level:

  Numeric confidence level. Default `0.95`.

## Value

A `creel_estimates` object with columns `estimate`, `se`, `se_between`,
`se_within`, `ci_lower`, `ci_upper`, `n`.

## Details

- **Ratio calibration** (recommended, when interview data are
  available): Per-stratum calibration ratios (mean interview effort /
  mean camera count during the interview period) scale raw camera counts
  to angler-hours. Variance is estimated via Taylor linearisation or
  replicate weights.

- **Raw count expansion** (fallback): Camera ingress counts are
  multiplied by `h_open` (fishable hours per day). Use when no interview
  data are available.

## Uncertainty the standard error does not cover

Two cases are reported rather than absorbed, because in both the
returned standard error would otherwise understate what is known:

- A stratum with a single paired interview/count day gives its
  calibration ratio no measurable spread. That variance is unknown
  rather than zero, so it is carried as `NA` and the combined standard
  error and confidence interval are `NA` too; a warning names the
  stratum. Add a second matched interview day in that stratum to recover
  a standard error.

- Counts flagged `.imputed` by
  [`impute_camera_counts()`](https://chrischizinski.github.io/tidycreel/reference/impute_camera_counts.md)
  enter the estimator as observations. The imputation model's prediction
  uncertainty is not propagated, and model predictions vary less than
  real counts, so the between-day component is understated as well. A
  warning reports how many days were imputed; the standard error is a
  lower bound.

## One count row per day on the calibration path

Ratio calibration pairs each interview day to that day's camera count,
so it requires the counts table to hold exactly one row per day (per
stratum). A repeated day is refused rather than averaged: two counts on
one date are either sub-period snapshots or a data error, and the
estimator cannot tell which. Before this was checked, a repeated date
entered both sides of the calibration ratio twice and **moved the point
estimate**, not merely the standard error.

If the counts are genuine sub-daily observations, pass `count_time_col`
to
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
which averages them into one row per day and retains the within-day
variance. Otherwise remove the repeated rows. Raw count expansion
(`interviews = NULL`) does no pairing and is not subject to this
requirement.

## References

Hartill, B.W., Cryer, M., and Morrison, M.A. 2020. Camera-based creel
surveys: estimating fishing effort and catch rates from ingress-egress
camera counts. Fisheries Research 231:105706.
[doi:10.1016/j.fishres.2020.105706](https://doi.org/10.1016/j.fishres.2020.105706)

## See also

Other "Survey Design":
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md),
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md),
[`as_creel_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_creel_svydesign.md),
[`as_hybrid_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_hybrid_svydesign.md),
[`compute_angler_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_angler_effort.md),
[`compute_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_effort.md),
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md),
[`creel_vocabulary()`](https://chrischizinski.github.io/tidycreel/reference/creel_vocabulary.md),
[`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md),
[`impute_camera_counts()`](https://chrischizinski.github.io/tidycreel/reference/impute_camera_counts.md),
[`mean_party_size()`](https://chrischizinski.github.io/tidycreel/reference/mean_party_size.md),
[`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md),
[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(tidycreel)
data(example_camera_counts)
data(example_camera_interviews)

cal <- data.frame(
  date     = unique(example_camera_counts$date),
  day_type = unique(example_camera_counts[, c("date", "day_type")])[["day_type"]]
)
design <- creel_design(cal,
  date = date, strata = day_type,
  survey_type = "camera", camera_mode = "counter"
)

# Filter to operational rows
ops <- example_camera_counts[
  example_camera_counts$camera_status == "operational",
]
design <- add_counts(design, ops)

# Ratio calibration using interview hours. `example_camera_interviews` has no
# party-size column, so this warns and reports an unknown unit: the estimate
# is in whatever unit `hours_fished` holds, which the package cannot tell.
est <- est_effort_camera(design, interviews = example_camera_interviews)
print(est)

# With party sizes the function does the normalisation itself, so the result
# is angler-hours and is labelled as such.
ints <- example_camera_interviews
ints$party_size <- 2
est_ah <- est_effort_camera(design, interviews = ints, n_anglers = "party_size")
print(est_ah)
} # }
```
