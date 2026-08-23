# Canonical vocabularies for the coded columns

The exact values `tidycreel` matches on for the three columns whose
meaning is a fixed vocabulary rather than a number: `trip_status`,
`catch_type` and `length_type`. Every downstream filter compares against
these literals, so a source that codes one of these columns has to be
translated before its values can be trusted — see the `value_maps`
argument of
[`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md).

Exported because `tidycreel.connect` translates source codes at the
fetch and has to check its targets against the same list this package
filters on; a second copy of the vocabulary would be free to drift from
this one.

## Usage

``` r
creel_vocabulary(column = NULL)
```

## Arguments

- column:

  Optional canonical column name. When `NULL` (default) the whole named
  list is returned; otherwise the character vector for that column.

## Value

A named list of character vectors, or one character vector when `column`
is given.

## See also

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
[`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md),
[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
[`impute_camera_counts()`](https://chrischizinski.github.io/tidycreel/reference/impute_camera_counts.md),
[`mean_party_size()`](https://chrischizinski.github.io/tidycreel/reference/mean_party_size.md),
[`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md),
[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)

## Examples

``` r
creel_vocabulary()
#> $trip_status
#> [1] "complete"   "incomplete"
#> 
#> $catch_type
#> [1] "caught"    "harvested" "released" 
#> 
#> $length_type
#> [1] "harvest" "release"
#> 
creel_vocabulary("trip_status")
#> [1] "complete"   "incomplete"
```
