# Extract internal survey design object (deprecated)

**\[deprecated\]**

`as_survey_design()` was renamed to
[`as_creel_svydesign()`](https://chrischizinski.com/tidycreel/reference/as_creel_svydesign.md)
in tidycreel 5.0.0. The old name collided with
`srvyr::as_survey_design()`, srvyr's principal entry point: attaching
both packages masked one with the other depending on load order, and a
user who loaded srvyr second got srvyr's generic failing to dispatch on
`creel_design` with an error that said nothing about masking. The new
name also matches the sibling
[`as_hybrid_svydesign()`](https://chrischizinski.com/tidycreel/reference/as_hybrid_svydesign.md)
and is more accurate – the function extracts the internal `survey`
object rather than constructing a design.

## Usage

``` r
as_survey_design(design)
```

## Arguments

- design:

  A creel_design object with counts attached via
  [`add_counts`](https://chrischizinski.com/tidycreel/reference/add_counts.md)

## Value

A survey.design2 object, identical to
[`as_creel_svydesign()`](https://chrischizinski.com/tidycreel/reference/as_creel_svydesign.md).

## Examples

``` r
data(example_calendar)
data(example_counts)
design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_counts(design, example_counts)
#> Warning: No weights or probabilities supplied, assuming equal probability
# Deprecated: as_creel_svydesign() is the current name.
svy <- suppressWarnings(as_survey_design(design))
class(svy)
#> [1] "survey.design2" "survey.design" 
```
