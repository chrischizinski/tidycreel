# Example species catch data for creel survey

Long-format species-level catch data linked to
[example_interviews](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md).
Contains catch, harvest, and release counts per species per interview
for 12 of the 22 interviews. Interviews with zero total catch have no
rows in this dataset (zero-catch anglers are represented by absence).

## Usage

``` r
example_catch
```

## Format

A data frame with columns:

- interview_id:

  Integer, foreign key to
  [example_interviews](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md)`$interview_id`

- species:

  Character species name: `"walleye"`, `"bass"`, or `"panfish"`

- count:

  Integer fish count for this species and catch type

- catch_type:

  Character catch disposition: `"caught"` (total observed),
  `"harvested"` (kept), or `"released"`

## Source

Simulated data for package examples

## See also

[example_interviews](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md)
for the corresponding interview-level data,
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md)
to attach species catch to a design

## Examples

``` r
data(example_calendar)
data(example_interviews)
data(example_catch)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_interviews(design, example_interviews,
  catch = catch_total,
  effort = hours_fished,
  harvest = catch_kept,
  trip_status = trip_status,
  trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
design <- add_catch(design, example_catch,
  catch_uid = interview_id,
  interview_uid = interview_id,
  species = species,
  count = count,
  catch_type = catch_type
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
#> Catch Data: 42 rows, 3 species
#> caught: 8, harvested: 17, released: 17
#> Sections: "none"
```
