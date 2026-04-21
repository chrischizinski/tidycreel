# Extract internal survey design object for advanced use

Provides power users with direct access to the internal survey.design2
object for advanced analysis using survey package functions. This is an
escape hatch for workflows not yet wrapped by tidycreel. Most users
should use
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
instead.

The function issues a once-per-session warning to educate users that
this is an advanced feature with risks if the returned object is
modified incorrectly.

## Usage

``` r
as_survey_design(design)
```

## Arguments

- design:

  A creel_design object with counts attached via
  [`add_counts`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)

## Value

A survey.design2 object (from survey::svydesign). Due to R's
copy-on-modify semantics, modifications to the returned object will not
affect the internal design\$survey object.

## Warning

This function issues a once-per-session warning explaining:

- This is an advanced feature for power users

- Most users should use
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  instead

- Modifying the survey design may produce incorrect variance estimates

## See also

Other "Survey Design":
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md),
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md),
[`as_hybrid_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_hybrid_svydesign.md),
[`compute_angler_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_angler_effort.md),
[`compute_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_effort.md),
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md),
[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
[`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md),
[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)

## Examples

``` r
# Basic workflow
library(survey)
#> Loading required package: grid
#> Loading required package: Matrix
#> Loading required package: survival
#> 
#> Attaching package: ‘survey’
#> The following object is masked from ‘package:graphics’:
#> 
#>     dotchart
cal <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend")
)
design <- creel_design(cal, date = date, strata = day_type)

counts <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  count = c(15, 23, 45, 52)
)

design2 <- add_counts(design, counts)
#> Warning: No weights or probabilities supplied, assuming equal probability

# Extract survey object for advanced use
svy <- as_survey_design(design2)
#> Warning: Accessing internal survey design object.
#> ℹ This is an advanced feature. Most users should use {.fn estimate_effort} instead.
#> ! Modifying the survey design may produce incorrect variance estimates.
#> This warning is displayed once per session.

# Use with survey package functions
survey::svytotal(~count, svy)
#>       total    SE
#> count   135 10.63
survey::svymean(~count, svy)
#>        mean     SE
#> count 33.75 2.6575
```
