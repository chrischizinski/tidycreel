# Validate a creel_schema object

Checks that all columns required for the schema's `survey_type` are
mapped (non-NULL). Aborts with an informative `cli_abort()` listing each
missing column and its table.

## Usage

``` r
validate_creel_schema(schema)
```

## Arguments

- schema:

  A `creel_schema` object created by
  [`creel_schema()`](https://chrischizinski.com/tidycreel/reference/creel_schema.md).

## Value

`invisible(schema)` if all required columns are mapped.

## See also

Other "Survey Design":
[`add_catch()`](https://chrischizinski.com/tidycreel/reference/add_catch.md),
[`add_counts()`](https://chrischizinski.com/tidycreel/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.com/tidycreel/reference/add_interviews.md),
[`add_lengths()`](https://chrischizinski.com/tidycreel/reference/add_lengths.md),
[`add_sections()`](https://chrischizinski.com/tidycreel/reference/add_sections.md),
[`as_creel_svydesign()`](https://chrischizinski.com/tidycreel/reference/as_creel_svydesign.md),
[`as_hybrid_svydesign()`](https://chrischizinski.com/tidycreel/reference/as_hybrid_svydesign.md),
[`compute_angler_effort()`](https://chrischizinski.com/tidycreel/reference/compute_angler_effort.md),
[`compute_effort()`](https://chrischizinski.com/tidycreel/reference/compute_effort.md),
[`creel_design()`](https://chrischizinski.com/tidycreel/reference/creel_design.md),
[`creel_schema()`](https://chrischizinski.com/tidycreel/reference/creel_schema.md),
[`creel_vocabulary()`](https://chrischizinski.com/tidycreel/reference/creel_vocabulary.md),
[`derive_angler_count()`](https://chrischizinski.com/tidycreel/reference/derive_angler_count.md),
[`est_effort_camera()`](https://chrischizinski.com/tidycreel/reference/est_effort_camera.md),
[`impute_camera_counts()`](https://chrischizinski.com/tidycreel/reference/impute_camera_counts.md),
[`mean_party_size()`](https://chrischizinski.com/tidycreel/reference/mean_party_size.md),
[`prep_counts_boat_party()`](https://chrischizinski.com/tidycreel/reference/prep_counts_boat_party.md),
[`prep_counts_daily_effort()`](https://chrischizinski.com/tidycreel/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.com/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.com/tidycreel/reference/prep_interviews_trips.md)

## Examples

``` r
# A schema names the source columns for each table its survey type needs.
schema <- creel_schema(
  survey_type      = "instantaneous",
  interview_uid_col = "interview_id",
  date_col          = "date",
  trip_status_col   = "trip_status",
  effort_col        = "hours_fished",
  catch_col         = "catch_total",
  catch_uid_col     = "catch_id",
  species_col       = "species",
  catch_count_col   = "count",
  catch_type_col    = "catch_type",
  length_uid_col    = "length_id",
  length_mm_col     = "length",
  length_type_col   = "length_type",
  count_time_col    = "count_time",
  bank_anglers_col  = "bank_anglers",
  count_col         = "angler_count"
)
validate_creel_schema(schema)

# An incomplete schema is refused here rather than failing later at a join.
try(validate_creel_schema(creel_schema(survey_type = "instantaneous")))
#> Error in validate_creel_schema(creel_schema(survey_type = "instantaneous")) : 
#>   creel_schema validation failed for survey_type "instantaneous":
#> ✖ date (interviews table) is missing
#> ✖ catch (interviews table) is missing
#> ✖ effort (interviews table) is missing
#> ✖ trip_status (interviews table) is missing
#> ✖ date (counts table) is missing
#> ✖ count (counts table) is missing
#> ✖ catch_uid (catch table) is missing
#> ✖ interview_uid (catch table) is missing
#> ✖ species (catch table) is missing
#> ✖ catch_count (catch table) is missing
#> ✖ catch_type (catch table) is missing
#> ✖ length_uid (lengths table) is missing
#> ✖ interview_uid (lengths table) is missing
#> ✖ species (lengths table) is missing
#> ✖ length_mm (lengths table) is missing
#> ✖ length_type (lengths table) is missing
```
