# Validate a proposed creel survey design against sample size targets

Pre-season design check: runs creel_n_effort() and creel_n_cpue() per
stratum and returns a pass/warn/fail status report.

## Usage

``` r
validate_design(
  N_h,
  ybar_h,
  s2_h,
  n_proposed,
  cv_target,
  type = c("effort", "cpue"),
  cv_catch = NULL,
  cv_effort = NULL,
  rho = 0
)
```

## Arguments

- N_h:

  Named numeric vector. Total available sampling days per stratum.

- ybar_h:

  Numeric vector (same length as N_h). Pilot mean effort per day per
  stratum.

- s2_h:

  Numeric vector (same length as N_h). Pilot variance of effort per
  stratum.

- n_proposed:

  Named integer vector (same length as N_h). Proposed sampling days per
  stratum.

- cv_target:

  Numeric scalar. Target CV for the effort estimate.

- type:

  Character. One of "effort" or "cpue". Default "effort".

- cv_catch:

  Numeric scalar. Required when type = "cpue".

- cv_effort:

  Numeric scalar. Required when type = "cpue".

- rho:

  Numeric scalar. Correlation between catch and effort. Default 0.

## Value

A creel_design_report object (S3 list) with:

- \$results:

  tibble with columns stratum, status, n_proposed, n_required,
  cv_actual, cv_target, message

- \$passed:

  logical – TRUE if all strata status == "pass"

- \$survey_type:

  character
