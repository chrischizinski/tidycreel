# Attach age data to a creel design

`add_ages()` attaches a data frame of individual fish age records (from
scale, fin ray, or otolith samples) to a `creel_design` object. The age
data are linked to interviews via a shared identifier, analogous to
[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md).

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
  [`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md)).

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

[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md)

## Examples

``` r
if (FALSE) { # \dontrun{
design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_interviews(design, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status
)
design <- add_ages(design, my_ages,
  age_uid       = interview_id,
  interview_uid = interview_id,
  species       = species,
  age           = estimated_age,
  age_type      = fish_fate
)
} # }
```
