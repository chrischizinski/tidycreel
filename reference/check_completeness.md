# Check post-season data completeness for a creel design

Dispatches by survey_type to avoid false-positive warnings on aerial and
camera designs that do not collect interview data.

## Usage

``` r
check_completeness(design, n_min = 10L)
```

## Arguments

- design:

  A creel_design object with counts (and optionally interviews)
  attached.

- n_min:

  Integer scalar \>= 1. Interview threshold below which a stratum is
  flagged as low-n. Default 10L.

## Value

A creel_completeness_report object (S3 list) with:

- \$missing_days:

  data.frame of calendar rows with no count data

- \$low_n_strata:

  data.frame of strata below n_min, or NULL for aerial/camera

- \$refusals:

  creel_summary_refusals object or NULL

- \$n_min:

  integer threshold used

- \$survey_type:

  character

- \$passed:

  logical – TRUE if no missing days and no low-n strata
