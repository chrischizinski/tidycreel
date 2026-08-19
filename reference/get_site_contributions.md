# Extract per-site effort contributions from a bus-route estimate

Returns the per-site calculation table (eᵢ, πᵢ, eᵢ/πᵢ) stored as an
attribute on effort estimate objects returned by
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
for bus-route survey designs. This table enables traceability of the
Horvitz-Thompson estimator (Jones & Pollock 2012, Eq. 19.4) and supports
validation against published examples (Malvestuto 1996, Box 20.6).

## Usage

``` r
get_site_contributions(x)
```

## Arguments

- x:

  A creel_estimates object returned by
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  for a bus-route design.

## Value

A tibble with columns:

- site:

  Site identifier (from sampling frame)

- circuit:

  Circuit identifier (from sampling frame)

- e_i:

  Enumeration-expanded effort at site i (effort \* expansion)

- pi_i:

  Inclusion probability for site i (p_site \* p_period)

- e_i_over_pi_i:

  Site contribution to Horvitz-Thompson estimate

## References

Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
estimating effort, harvest, and abundance. In A. V. Zale, D. L. Parrish,
& T. M. Sutton (Eds.), *Fisheries Techniques* (3rd ed., pp. 883-919).
American Fisheries Society.

## See also

[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`get_sampling_frame()`](https://chrischizinski.github.io/tidycreel/reference/get_sampling_frame.md),
[`get_inclusion_probs()`](https://chrischizinski.github.io/tidycreel/reference/get_inclusion_probs.md),
[`get_enumeration_counts()`](https://chrischizinski.github.io/tidycreel/reference/get_enumeration_counts.md)

Other "Bus-Route Helpers":
[`get_enumeration_counts()`](https://chrischizinski.github.io/tidycreel/reference/get_enumeration_counts.md),
[`get_inclusion_probs()`](https://chrischizinski.github.io/tidycreel/reference/get_inclusion_probs.md),
[`get_sampling_frame()`](https://chrischizinski.github.io/tidycreel/reference/get_sampling_frame.md)

## Examples

``` r
# (Bus-route design + add_interviews() required — see estimate_effort() docs)
# After: result <- estimate_effort(design_with_br_interviews)
# site_table <- get_site_contributions(result)
```
