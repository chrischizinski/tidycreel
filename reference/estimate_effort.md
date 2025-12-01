# Estimate Fishing Effort

Estimates total fishing effort (angler-hours or party-hours) by strata
and overall, using the survey design weights. Supports both access-point
and roving survey designs.

## Usage

``` r
estimate_effort(design, by = NULL, total = TRUE, level = 0.95)
```

## Arguments

- design:

  A creel design object created by [`design_access`](design_access.md),
  [`design_roving`](design_roving.md), or
  [`design_repweights`](design-constructors.md).

- by:

  Character vector of variables to group estimates by. Default is the
  strata variables defined in the design.

- total:

  Logical, whether to include overall total estimate in addition to
  grouped estimates. Default TRUE.

- level:

  Confidence level for confidence intervals. Default 0.95.

## Value

A tibble with columns:

- group_vars:

  Grouping variables as a list column

- n:

  Number of interviews in group

- effort_estimate:

  Estimated total effort

- effort_se:

  Standard error of effort estimate

- effort_lower:

  Lower confidence limit

- effort_upper:

  Upper confidence limit

- design_type:

  Type of survey design used

- estimation_method:

  Method used for estimation

## Examples

``` r
if (FALSE) { # \dontrun{
# Create design
interviews <- readr::read_csv(system.file("extdata/toy_interviews.csv",
  package = "tidycreel"
))
calendar <- readr::read_csv(system.file("extdata/toy_calendar.csv",
  package = "tidycreel"
))

design <- design_access(interviews = interviews, calendar = calendar)

# Estimate effort by date
effort_by_date <- estimate_effort(design, by = "date")

# Estimate effort by location and mode
effort_by_location_mode <- estimate_effort(design, by = c("location", "mode"))
} # }
```
