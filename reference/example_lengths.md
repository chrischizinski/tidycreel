# Example fish length data for creel survey

Mixed-format length data containing individual harvest measurements
(numeric, in mm) and binned release counts (character bin labels) linked
to
[`example_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md).
Suitable for use with
[`add_lengths`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md).

## Usage

``` r
example_lengths
```

## Format

A data frame with 20 rows and 5 columns:

- interview_id:

  Integer interview identifier. Foreign key to
  `example_interviews$interview_id`.

- species:

  Character. Species name: `"walleye"`, `"bass"`, or `"panfish"`.

- length:

  Character. For harvest rows, a numeric length in mm (stored as
  character due to mixed column). For release rows, a bin label such as
  `"300-350"`.

- length_type:

  Character. Measurement fate: `"harvest"` or `"release"`.

- count:

  Integer. `NA_integer_` for harvest rows (individual measurements);
  positive integer count for release rows (binned format).

## Source

Simulated data for package examples.

## See also

[`example_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md),
[`example_catch`](https://chrischizinski.github.io/tidycreel/reference/example_catch.md),
[`add_lengths`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md)

## Examples

``` r
data(example_calendar)
data(example_interviews)
data(example_lengths)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_interviews(design, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status, trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
design <- add_lengths(design, example_lengths,
  length_uid = interview_id,
  interview_uid = interview_id,
  species = species,
  length = length,
  length_type = length_type,
  count = count,
  release_format = "binned"
)
print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 14 days (2024-06-01 to 2024-06-14)
#> day_type: 2 levels
#> Counts: "none"
#> Interviews: 22 observations
#> Type: "access"
#> Catch: catch_total
#> Effort: hours_fished
#> Harvest: catch_kept
#> Trip status: 17 complete, 5 incomplete
#> Survey: <survey.design2> (constructed)
#> Length Data: 20 rows, 3 species, length: 155–512 mm
#> harvest: 14 individual
#> release: 6 binned
#> Sections: "none"
```
