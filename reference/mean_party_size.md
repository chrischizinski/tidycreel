# Mean anglers per boat party from interviews

Returns the mean number of anglers per boat party, taken from an
interviews table. This is the multiplier used to expand a count of boats
into a count of anglers when the clerk counted boats rather than the
people aboard them.

Boats move, so a count of anglers aboard is often less reliable than a
count of hulls. Counting boats and expanding by the interviewed party
size trades an unreliable field count for a measured one, at the cost of
assuming the interviewed parties are representative of the boats that
were counted.

## Usage

``` r
mean_party_size(
  interviews,
  n_anglers,
  angler_type = NULL,
  boat_value = "boat",
  by = NULL
)
```

## Arguments

- interviews:

  A data frame of interviews, one row per party.

- n_anglers:

  Tidy selector for the numeric party-size column.

- angler_type:

  Optional tidy selector for the column recording whether a party fished
  from a boat or the bank. When supplied, only boat parties are used.

- boat_value:

  Value of `angler_type` marking a boat party. Defaults to `"boat"`.
  Ignored when `angler_type` is `NULL`.

- by:

  Optional tidy selector for one or more grouping columns. When
  supplied, a mean is returned for each group rather than one overall
  value.

## Value

When `by` is `NULL`, a single numeric value. Otherwise a tibble with the
grouping columns and a `mean_party_size` column.

Either way the return carries a `"se"` attribute holding the standard
error of the mean (`sd / sqrt(n)` over parties), one value per group for
the `by` form.
[`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md)
reads it, so the sampling error of the multiplier reaches the effort
standard error without being passed by hand.

The standard error is an attribute rather than a column so that the
scalar return stays usable directly as a multiplier, and so the `by`
form keeps exactly one numeric column and remains valid as a
`party_size` lookup.

For the `by` form the attribute is **named by the group key**, and
[`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md)
addresses it by name. Attributes do not follow the rows they describe
through a `dplyr` reordering, so a positional attribute would go stale
the moment the lookup were sorted — attributing each stratum's standard
error to a different stratum while the means, which join by key, stayed
correct. A `by`-form lookup whose `"se"` attribute has no names is
refused rather than matched by row order.

A group with a single party has no estimable standard error and gets
`NA_real_`, which propagates to an `NA` effort standard error rather
than being quietly treated as zero uncertainty.

## Details

Each row of `interviews` is assumed to be one party. A table carrying
several rows per party — one per species, say — will weight larger
parties more than once; reduce it to one row per party first.

Supply `by` when party size differs across the survey. Weekend parties
are commonly larger than weekday parties, and a single season-wide mean
applied to both then moves effort in opposite directions in the two
strata.

## See also

[`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md),
[`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md)

Other "Survey Design":
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md),
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md),
[`as_creel_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_creel_svydesign.md),
[`as_hybrid_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_hybrid_svydesign.md),
[`compute_angler_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_angler_effort.md),
[`compute_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_effort.md),
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md),
[`creel_vocabulary()`](https://chrischizinski.github.io/tidycreel/reference/creel_vocabulary.md),
[`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md),
[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
[`impute_camera_counts()`](https://chrischizinski.github.io/tidycreel/reference/impute_camera_counts.md),
[`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md),
[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)

## Examples

``` r
interviews <- data.frame(
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  type = c("boat", "bank", "boat", "boat"),
  n_anglers = c(2, 1, 3, 4)
)

# Overall, boat parties only
mean_party_size(interviews, n_anglers, angler_type = type)
#> [1] 3
#> attr(,"se")
#> [1] 0.5773503

# By stratum
mean_party_size(interviews, n_anglers, angler_type = type, by = day_type)
#> # A tibble: 2 × 2
#>   day_type mean_party_size
#>   <chr>              <dbl>
#> 1 weekday              2  
#> 2 weekend              3.5
```
