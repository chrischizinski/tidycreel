# Column-mapping contract for tidycreel data sources

`creel_schema()` constructs a `creel_schema` S3 object that maps
canonical tidycreel column names to actual column and table names in a
data source. The schema is the full connection contract consumed by
`creel_connect()` and `fetch_*()` functions in the tidycreel.connect
companion package.

Construction is permissive — all column arguments default to `NULL`. Use
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)
to check that required columns for the given survey type are mapped.

## Usage

``` r
creel_schema(
  survey_type = c("instantaneous", "bus_route", "ice", "camera", "aerial"),
  interviews_table = NULL,
  counts_table = NULL,
  catch_table = NULL,
  lengths_table = NULL,
  date_col = NULL,
  strata_cols = NULL,
  value_maps = NULL,
  catch_col = NULL,
  effort_col = NULL,
  trip_status_col = NULL,
  count_col = NULL,
  count_time_col = NULL,
  catch_uid_col = NULL,
  interview_uid_col = NULL,
  species_col = NULL,
  catch_count_col = NULL,
  catch_type_col = NULL,
  length_uid_col = NULL,
  length_mm_col = NULL,
  length_bin_col = NULL,
  length_count_col = NULL,
  length_type_col = NULL,
  harvest_col = NULL,
  trip_duration_col = NULL,
  trip_start_col = NULL,
  interview_time_col = NULL,
  n_anglers_col = NULL,
  n_counted_col = NULL,
  n_interviewed_col = NULL,
  bank_anglers_col = NULL,
  angler_boats_col = NULL,
  non_ang_boats_col = NULL,
  angler_type_col = NULL,
  site_col = NULL,
  circuit_col = NULL,
  angler_method_col = NULL,
  species_sought_col = NULL,
  refused_col = NULL
)
```

## Arguments

- survey_type:

  Survey type. One of `"instantaneous"`, `"bus_route"`, `"ice"`,
  `"camera"`, or `"aerial"`. Validated at construction via
  [`match.arg()`](https://rdrr.io/r/base/match.arg.html).

- interviews_table:

  Name of the interviews table in the data source.

- counts_table:

  Name of the counts table in the data source.

- catch_table:

  Name of the catch table in the data source.

- lengths_table:

  Name of the lengths table in the data source.

- date_col:

  Column name for survey date.

- strata_cols:

  Stratum columns to carry through from the source, as a named character
  vector whose names are the columns the design refers to and whose
  values are the source columns holding them —
  `c(day_type = "DayType")`. An unnamed entry, `c("day_type")`, means
  the source already uses the design's name. Unlike every other field
  here, a stratum has no canonical tidycreel name:
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  matches `design$strata_cols` — the caller's own calendar column names
  — against the names of the counts frame, so the mapping has to be
  two-sided. Without it a fetched counts frame reaches
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  with no stratum label and any design built with `strata =` aborts (GH
  \#171).

- value_maps:

  Source vocabularies for the coded columns, as a named list keyed by
  canonical column — `trip_status`, `catch_type`, `length_type`. Each
  entry is a fully named character vector mapping the source's own codes
  to canonical values: `c("1" = "complete", "2" = "incomplete")`. Names
  are what the source writes, values what tidycreel means.

  Every downstream filter matches the canonical literals, so a source
  that codes these columns has to declare what its codes mean. Values
  already canonical pass through untouched; anything neither mapped nor
  canonical aborts at the fetch, where the source is still in view,
  rather than being recoded by hand afterwards — a hand recode folds an
  undeclared third code (`"refused"`, `"unknown"`) into complete or
  incomplete silently (GH \#128).

- catch_col:

  Column name for catch count in interviews.

- effort_col:

  Column name for effort (hours) in interviews.

- trip_status_col:

  Column name for trip status in interviews.

- count_col:

  Column name for total angler count in counts (legacy single-column
  format).

- count_time_col:

  Column name for the time of a count observation, such as `"16:30"` or
  `"am"`. Optional. Map it whenever the source records more than one
  count per sampled day: the fetched `count_time` column is what
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)'s
  `count_time_col` argument groups on, and without it those rows reach
  the design as separate sampled days rather than as repeat looks at
  one, which sums the day's effort instead of averaging it and leaves
  the within-day variance component uncomputed (GH \#129). Carried
  through as character: it is a label that distinguishes observations,
  not a quantity, and a source may write a clock time in any format.

- catch_uid_col:

  Column name for catch unique identifier.

- interview_uid_col:

  Column name for interview unique identifier.

- species_col:

  Column name for species.

- catch_count_col:

  Column name for catch count in the catch table.

- catch_type_col:

  Column name for catch type (harvest/release).

- length_uid_col:

  Column name for length unique identifier.

- length_mm_col:

  Column name for fish length (mm). Map it only for individually
  measured fish; a bin label belongs in `length_bin_col`, whose name
  does not assert a unit.

- length_bin_col:

  Column name for a length-bin label, such as `"300-350"`. Optional, and
  mutually exclusive with `length_mm_col` on any given row: a fish is
  either measured or binned. Pass the fetched `length_bin` column as
  [`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md)'s
  `length` argument together with `release_format = "binned"` (GH
  \#127).

- length_count_col:

  Column name for the number of fish a binned length row represents.
  Optional, but required by
  [`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md)
  whenever binned release rows are present: a binned row is
  frequency-weighted, so dropping the count weights the length
  distribution by row multiplicity instead of by fish (GH \#127). `NA`
  on individually measured rows.

- length_type_col:

  Column name for length type.

- harvest_col:

  Column name for harvest count.

- trip_duration_col:

  Column name for trip duration.

- trip_start_col:

  Column name for trip start time.

- interview_time_col:

  Column name for interview time.

- n_anglers_col:

  Column name for number of anglers.

- n_counted_col:

  Column name for number of anglers counted.

- n_interviewed_col:

  Column name for number of anglers interviewed.

- bank_anglers_col:

  Column name for bank (shore) angler count in counts.

- angler_boats_col:

  Column name for boats carrying anglers in counts.

- non_ang_boats_col:

  Column name for boats carrying no anglers in counts. Recorded by some
  agencies and not others; leave `NULL` where it is not.

- angler_type_col:

  Column name for angler type.

- site_col:

  Column name for the site an interview was taken at. Bus-route designs
  need it to join the site inclusion probability; without it
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  cannot build the \\\pi_i\\ term (GH \#126).

- circuit_col:

  Column name for the bus-route circuit an interview belongs to.
  Required alongside `site_col` for the bus-route expansion (GH \#126).

- angler_method_col:

  Column name for fishing method.

- species_sought_col:

  Column name for target species.

- refused_col:

  Column name for refused interviews indicator.

## Value

A `creel_schema` S3 object.

## See also

Other "Survey Design":
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md),
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md),
[`as_hybrid_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_hybrid_svydesign.md),
[`as_survey_design()`](https://chrischizinski.github.io/tidycreel/reference/as_survey_design.md),
[`compute_angler_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_angler_effort.md),
[`compute_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_effort.md),
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`creel_vocabulary()`](https://chrischizinski.github.io/tidycreel/reference/creel_vocabulary.md),
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
s <- creel_schema(
  survey_type      = "instantaneous",
  interviews_table = "vwInterviews",
  counts_table     = "vwCounts",
  date_col         = "SurveyDate",
  catch_col        = "TotalCatch",
  effort_col       = "EffortHours",
  trip_status_col  = "TripStatus",
  count_col        = "AnglerCount"
)
print(s)
#> <creel_schema: instantaneous>
#> 
#> ── interviews: vwInterviews ──
#> 
#> date -> SurveyDate
#> catch -> TotalCatch
#> effort -> EffortHours
#> trip_status -> TripStatus
#> 
#> ── counts: vwCounts ──
#> 
#> count -> AnglerCount
```
