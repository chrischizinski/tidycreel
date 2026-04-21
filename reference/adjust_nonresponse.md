# Adjust a creel design for nonresponse bias

Applies nonresponse weighting to a `creel_design` object by scaling
survey weights within each stratum by the inverse of the observed
response rate. The adjustment uses
[`postStratify`](https://rdrr.io/pkg/survey/man/postStratify.html)
(default) or
[`calibrate`](https://rdrr.io/pkg/survey/man/calibrate.html) to update
the internal
[`svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html) object, so
all downstream estimators
([`estimate_effort`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_catch_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
etc.) automatically use the corrected weights.

## Usage

``` r
adjust_nonresponse(
  design,
  response_rates,
  method = c("postStratify", "calibrate"),
  stratum_col = "stratum"
)
```

## Arguments

- design:

  A `creel_design` object with at least one survey sub-object already
  attached
  ([`add_counts`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  or
  [`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)).

- response_rates:

  A data frame or tibble with one row per stratum, containing at minimum
  the columns:

  stratum

  :   Character or factor. Stratum identifier matching the values in the
      design's strata column.

  n_sampled

  :   Integer. Number of units approached for interview in the stratum.

  n_responded

  :   Integer. Number of units that actually responded. Must be
      `<= n_sampled`.

- method:

  Character. Weighting method to apply. Either `"postStratify"`
  (default, adjusts weights to match known stratum totals inversely
  proportional to response rate) or `"calibrate"` (calibration estimator
  via
  [`survey::calibrate`](https://rdrr.io/pkg/survey/man/calibrate.html);
  requires stratum population totals in `response_rates`).

- stratum_col:

  Character. Name of the stratum column in `response_rates` (default:
  `"stratum"`).

## Value

The input `creel_design` with adjusted weights. The updated design
includes an attribute `"nonresponse_diagnostics"` (a tibble with columns
`stratum`, `n_sampled`, `n_responded`, `response_rate`,
`weight_adjustment`) that can be retrieved with
`attr(result, "nonresponse_diagnostics")`.

## Adjustment method

For each stratum \\h\\: \$\$response\\rate_h = n\\responded_h /
n\\sampled_h\$\$ \$\$weight\\adjustment_h = 1 / response\\rate_h\$\$

The original weights are multiplied by `weight_adjustment_h`, which
upweights respondents to represent non-respondents (Armstrong & Overton
1977). This assumes that respondents and non-respondents are
exchangeable within strata (a missing-at-random assumption). When this
is implausible, a sensitivity analysis comparing pre- and
post-adjustment estimates is recommended.

## References

Armstrong, B.G. and Overton, W.S. 1977. Estimating nonresponse bias in
mail surveys. Journal of Marketing Research 14:396–402.

Pollock, K.H., Jones, C.M. and Brown, T.L. 1994. Angler Survey Methods
and Their Applications in Fisheries Management. American Fisheries
Society, Bethesda, MD.

## See also

Other "Reporting & Diagnostics":
[`check_completeness()`](https://chrischizinski.github.io/tidycreel/reference/check_completeness.md),
[`compare_variance()`](https://chrischizinski.github.io/tidycreel/reference/compare_variance.md),
[`flag_outliers()`](https://chrischizinski.github.io/tidycreel/reference/flag_outliers.md),
[`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md),
[`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md),
[`summarize_by_angler_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_angler_type.md),
[`summarize_by_day_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_day_type.md),
[`summarize_by_method()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_method.md),
[`summarize_by_species_sought()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_species_sought.md),
[`summarize_by_trip_length()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_trip_length.md),
[`summarize_cws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_cws_rates.md),
[`summarize_hws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_hws_rates.md),
[`summarize_length_freq()`](https://chrischizinski.github.io/tidycreel/reference/summarize_length_freq.md),
[`summarize_refusals()`](https://chrischizinski.github.io/tidycreel/reference/summarize_refusals.md),
[`summarize_successful_parties()`](https://chrischizinski.github.io/tidycreel/reference/summarize_successful_parties.md),
[`summarize_trips()`](https://chrischizinski.github.io/tidycreel/reference/summarize_trips.md),
[`summary.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/summary.creel_estimates.md),
[`validate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_data.md),
[`validate_design()`](https://chrischizinski.github.io/tidycreel/reference/validate_design.md),
[`validate_incomplete_trips()`](https://chrischizinski.github.io/tidycreel/reference/validate_incomplete_trips.md),
[`validation_report()`](https://chrischizinski.github.io/tidycreel/reference/validation_report.md),
[`write_estimates()`](https://chrischizinski.github.io/tidycreel/reference/write_estimates.md)

## Examples

``` r
data("example_counts", package = "tidycreel")
data("example_interviews", package = "tidycreel")
cal <- unique(example_counts[, c("date", "day_type")])
design <- creel_design(cal, date = date, strata = day_type)
design <- suppressWarnings(add_counts(design, example_counts))
design <- suppressWarnings(add_interviews(
  design, example_interviews,
  catch = catch_total, effort = hours_fished,
  trip_status = trip_status, trip_duration = trip_duration
))
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)

resp <- data.frame(
  stratum     = c("weekday", "weekend"),
  n_sampled   = c(80L, 60L),
  n_responded = c(72L, 48L)
)
adj_design <- adjust_nonresponse(design, resp)
attr(adj_design, "nonresponse_diagnostics")
#> # A tibble: 2 × 5
#>   stratum n_sampled n_responded response_rate weight_adjustment
#>   <chr>       <int>       <int>         <dbl>             <dbl>
#> 1 weekday        80          72           0.9              1.11
#> 2 weekend        60          48           0.8              1.25
```
