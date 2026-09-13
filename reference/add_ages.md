# Attach age data to a creel design

`add_ages()` attaches a data frame of individual fish age records (from
scale, fin ray, or otolith samples) to a `creel_design` object. The age
data are linked to interviews via a shared identifier, analogous to
[`add_lengths()`](https://chrischizinski.com/tidycreel/reference/add_lengths.md).

## Usage

``` r
add_ages(design, data, age_uid, interview_uid, species, age, age_type)
```

## Arguments

- design:

  A `creel_design` object with interviews attached.

- data:

  A data frame of age records. One row per aged fish.

- age_uid:

  Unquoted column in `data` — the column that holds the interview
  identifier, linking each age record to its interview (the foreign key;
  analogous to `length_uid` in
  [`add_lengths()`](https://chrischizinski.com/tidycreel/reference/add_lengths.md)).

- interview_uid:

  Unquoted column in `design$interviews` — the interview identifier
  column in the design, used as the join target.

- species:

  Unquoted column in `data` — species name or code.

- age:

  Unquoted column in `data` — estimated age (integer or numeric).

- age_type:

  Unquoted column in `data` — fate of the fish: `"harvest"` or
  `"release"`.

## Value

A `creel_design` object with age data attached in `design$ages` and
associated column-name slots.

## See also

[`add_lengths()`](https://chrischizinski.com/tidycreel/reference/add_lengths.md)

## Examples

``` r
data(example_calendar)
data(example_interviews)
data(example_ages)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_interviews(design, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status
)
#> Warning: ! No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ If the interviews really are one angler each, pass `n_anglers = 1` to state
#>   that and silence this warning.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
design <- add_ages(design, example_ages,
  age_uid       = interview_id,
  interview_uid = interview_id,
  species       = species,
  age           = age,
  age_type      = age_type
)
head(design$ages)
#>   interview_id species age age_type
#> 1            1 walleye   4  harvest
#> 2            1 walleye   3  harvest
#> 3            1 walleye   5  harvest
#> 4            2    bass   2  harvest
#> 5            2    bass   3  harvest
#> 6            6 walleye   6  harvest
```
