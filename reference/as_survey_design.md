# Extract internal survey design object (deprecated)

**\[deprecated\]**

`as_survey_design()` was renamed to
[`as_creel_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_creel_svydesign.md)
in tidycreel 5.0.0. The old name collided with
`srvyr::as_survey_design()`, srvyr's principal entry point: attaching
both packages masked one with the other depending on load order, and a
user who loaded srvyr second got srvyr's generic failing to dispatch on
`creel_design` with an error that said nothing about masking. The new
name also matches the sibling
[`as_hybrid_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_hybrid_svydesign.md)
and is more accurate – the function extracts the internal `survey`
object rather than constructing a design.

## Usage

``` r
as_survey_design(design)
```

## Arguments

- design:

  A creel_design object with counts attached via
  [`add_counts`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)

## Value

A survey.design2 object, identical to
[`as_creel_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_creel_svydesign.md).
