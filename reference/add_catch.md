# Attach species-level catch data to a creel design

Attaches a long-format data frame of species-level catch data to a
`creel_design` object. Each row in `data` represents a
species-catch-type combination for a single interview. Data is validated
at attach time and stored on the design for use by downstream summary
and estimation functions.

## Usage

``` r
add_catch(design, data, catch_uid, interview_uid, species, count, catch_type)
```

## Arguments

- design:

  A `creel_design` object created by
  [`creel_design`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md).

- data:

  A data frame in long format: one row per species per catch type per
  interview.

- catch_uid:

  \<[tidyselect](https://tidyselect.r-lib.org/reference/tidyselect-package.html)\>
  Column in `data` containing interview IDs (the catch-side join key).

- interview_uid:

  \<[tidyselect](https://tidyselect.r-lib.org/reference/tidyselect-package.html)\>
  Column in `design$interviews` containing the matching interview IDs.

- species:

  \<[tidyselect](https://tidyselect.r-lib.org/reference/tidyselect-package.html)\>
  Column in `data` containing species names or codes.

- count:

  \<[tidyselect](https://tidyselect.r-lib.org/reference/tidyselect-package.html)\>
  Column in `data` containing fish counts (non-negative integer or
  numeric).

- catch_type:

  \<[tidyselect](https://tidyselect.r-lib.org/reference/tidyselect-package.html)\>
  Column in `data` containing catch fate: one of `"caught"`,
  `"harvested"`, or `"released"`. Values are normalized to lowercase
  before validation.

## Value

A new `creel_design` object with `$catch` and associated `$catch_*_col`
fields attached.

## Details

**Catch type model:** Each species-interview row carries one of three
catch types. `"caught"` is the total; `"harvested"` and `"released"` are
subsets. A `"caught"` row is optional — when absent, total catch is
inferred as `harvested + released`. When a `"caught"` row is present,
`caught >= harvested + released` is enforced (CATCH-04).

**Interview ID validation:** Every interview ID appearing in `data` must
appear in `design$interviews[[interview_uid]]`. Interviews with no catch
rows are valid (anglers who caught nothing need not appear in catch
data).

**Immutability:** Returns a new `creel_design` — the input is not
modified. Calling `add_catch()` on a design that already has `$catch` is
an error.

## See also

Other "Survey Design":
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md),
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md),
[`as_hybrid_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_hybrid_svydesign.md),
[`as_survey_design()`](https://chrischizinski.github.io/tidycreel/reference/as_survey_design.md),
[`compute_angler_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_angler_effort.md),
[`compute_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_effort.md),
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md),
[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
[`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md),
[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)

## Examples

``` r
data(example_calendar)
data(example_interviews)
data(example_catch)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_interviews(design, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status, trip_duration = trip_duration
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
