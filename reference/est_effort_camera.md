# Estimate angler effort from camera/time-lapse count data

Estimates total angler-hours from a camera-based creel survey design.
Two estimation modes are supported:

## Usage

``` r
est_effort_camera(
  design,
  interviews = NULL,
  effort_col = "hours_fished",
  intercept_col = NULL,
  h_open = NULL,
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

- intercept_col:

  Character scalar or `NULL`. Column in the count data representing the
  camera count during the interview interception period. Default `NULL`
  (auto-detects the first numeric count column).

- h_open:

  Numeric scalar. Fishable hours per day. Required when
  `interviews = NULL`. Default `NULL`.

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

## References

Hartill, B.W., Cryer, M., and Morrison, M.A. 2020. Camera-based creel
surveys: estimating fishing effort and catch rates from ingress-egress
camera counts. Fisheries Research 231:105706.
[doi:10.1016/j.fishres.2020.105706](https://doi.org/10.1016/j.fishres.2020.105706)

## Examples

``` r
if (FALSE) { # \dontrun{
library(tidycreel)
data(example_camera_counts)
data(example_camera_interviews)

cal <- data.frame(
  date     = unique(example_camera_counts$date),
  day_type = unique(example_camera_counts[, c("date","day_type")])[["day_type"]]
)
design <- creel_design(cal, date = date, strata = day_type,
  survey_type = "camera", camera_mode = "counter")

# Filter to operational rows
ops <- example_camera_counts[
  example_camera_counts$camera_status == "operational", ]
design <- add_counts(design, ops)

# Ratio calibration using interview hours
est <- est_effort_camera(design, interviews = example_camera_interviews)
print(est)
} # }
```
