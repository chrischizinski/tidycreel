# Construct a hybrid access + roving survey design

Combines count data from access-point and roving survey components into
a single
[`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html)
object suitable for effort estimation via
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md).

## Usage

``` r
as_hybrid_svydesign(
  access_data,
  roving_data,
  date_col = "date",
  strata_col = "day_type",
  count_col = "count",
  access_fraction = NULL,
  roving_fraction = NULL,
  fpc = TRUE
)
```

## Arguments

- access_data:

  Data frame of access-point count observations. Must contain the
  columns named by `date_col`, `strata_col`, and `count_col`.

- roving_data:

  Data frame of roving-route count observations. Must contain the same
  columns as `access_data`.

- date_col:

  Character scalar. Name of the date column (shared by both tables).
  Default `"date"`.

- strata_col:

  Character scalar. Name of the stratum column (shared by both tables).
  Default `"day_type"`.

- count_col:

  Character scalar. Name of the count column (shared by both tables).
  Default `"count"`.

- access_fraction:

  Named numeric vector. Sampling fraction per stratum for the
  access-point component (proportion of access points sampled on each
  sampled day; must be in (0, 1\]). Names must match stratum values in
  `access_data`.

- roving_fraction:

  Named numeric vector. Sampling fraction per stratum for the
  roving-route component. Names must match stratum values in
  `roving_data`.

- fpc:

  Logical. Apply finite-population correction? Default `TRUE`.

## Value

A [`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html)
object with an additional class attribute `"creel_hybrid_svydesign"`.
The design data contains a `component` column (`"access"` or `"roving"`)
and a `weight` column derived from the sampling fractions.

## Details

A hybrid design is appropriate when a survey uses both fixed
access-point counts (e.g., boat-launch interviews with angler counts)
and roving-route counts (e.g., progressive counts along a shoreline
transect) within the same sampling frame. The two components are
stacked, with a `component` column distinguishing them, and inclusion
probabilities are derived from the user-supplied sampling fractions per
stratum.

**PSU alignment requirement:** Both `access_data` and `roving_data` must
share the same date and stratum columns. Mismatched column names, or
dates present in one component but absent in the other, trigger an error
rather than a silent expansion. If PSU boundaries differ (e.g., access
routes cover different sections than roving routes), the estimates will
be biased; a warning is issued when stratum-date combinations are
asymmetric.

## Examples

``` r
if (FALSE) { # \dontrun{
access <- data.frame(
  date     = as.Date(c("2024-06-01", "2024-06-02")),
  day_type = c("weekday", "weekend"),
  count    = c(12L, 30L)
)
roving <- data.frame(
  date     = as.Date(c("2024-06-01", "2024-06-02")),
  day_type = c("weekday", "weekend"),
  count    = c(8L, 22L)
)
design <- as_hybrid_svydesign(
  access_data      = access,
  roving_data      = roving,
  access_fraction  = c(weekday = 0.5, weekend = 0.5),
  roving_fraction  = c(weekday = 0.4, weekend = 0.4)
)
survey::svytotal(~count, design)
} # }
```
