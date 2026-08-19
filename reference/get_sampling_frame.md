# Extract the sampling frame from a bus-route creel design

Returns the sampling frame data frame stored in a bus-route
`creel_design` object. The data frame contains the user's original
columns plus a precomputed `.pi_i` column (pi_i = p_site \* p_period).
Aborts with an informative error for non-bus-route designs.

## Usage

``` r
get_sampling_frame(design)
```

## Arguments

- design:

  A `creel_design` object with `design_type = "bus_route"`.

## Value

A data frame: the `sampling_frame` as stored in the design, with the
addition of a `.pi_i` column and (if circuit was omitted) a `.circuit`
column.

## See also

Other "Bus-Route Helpers":
[`get_enumeration_counts()`](https://chrischizinski.github.io/tidycreel/reference/get_enumeration_counts.md),
[`get_inclusion_probs()`](https://chrischizinski.github.io/tidycreel/reference/get_inclusion_probs.md),
[`get_site_contributions()`](https://chrischizinski.github.io/tidycreel/reference/get_site_contributions.md)

## Examples

``` r
sf <- data.frame(
  site     = c("A", "B", "C"),
  p_site   = c(0.3, 0.4, 0.3),
  p_period = 0.5
)
calendar <- data.frame(
  date     = as.Date("2024-06-01"),
  day_type = "weekday"
)
design <- creel_design(calendar,
  date = date,
  strata = day_type,
  survey_type = "bus_route",
  sampling_frame = sf,
  site = site,
  p_site = p_site,
  p_period = p_period
)
get_sampling_frame(design)
#>   site p_site p_period .circuit .pi_i
#> 1    A    0.3      0.5 .default  0.15
#> 2    B    0.4      0.5 .default  0.20
#> 3    C    0.3      0.5 .default  0.15
```
