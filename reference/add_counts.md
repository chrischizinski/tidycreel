# Attach count data to a creel design

Attaches count-side effort data to a creel_design object and constructs
the internal survey design object eagerly. The preferred workflow is to
standardize raw count-process data into sampled-day effort rows with
[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md)
(or another `prep_counts_*()` helper) before calling `add_counts()`.
This keeps survey-specific count reconstruction logic out of the core
estimator path.

Compatibility paths for raw-ish count inputs remain supported:
`add_counts()` can still aggregate multiple within-day observations via
`count_time_col` and can still compute progressive-count daily effort
from `circuit_time` and `period_length_col`. Eager construction catches
design errors at add_counts() time when users have context about what
data they are adding.

## Usage

``` r
add_counts(
  design,
  counts,
  psu = NULL,
  count_time_col = NULL,
  count_type = "instantaneous",
  circuit_time = NULL,
  period_length_col = NULL,
  allow_invalid = FALSE
)
```

## Arguments

- design:

  A creel_design object (created with
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md))

- counts:

  Data frame containing count-side effort data. Preferred input:
  sampled-day effort rows that already have a Date column matching the
  design's date_col, all strata columns from the design's strata_cols,
  at least one numeric effort column, and a PSU column (specified via
  `psu`, defaults to date_col). Use
  [`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md)
  to build this form from raw source data.

  Compatibility input paths remain available for raw-ish count workflows
  with multiple within-day observations or progressive counts.

- psu:

  Character string naming the PSU (Primary Sampling Unit) column in the
  count data. Defaults to NULL, which uses the design's date_col as the
  PSU (day-as-PSU is the most common creel design). For other designs,
  specify the PSU column explicitly (e.g., "site_day" for day-site
  PSUs).

- count_time_col:

  Tidy selector for a column that identifies distinct sub-PSU count
  observations (e.g., `count_time_col = count_time` where count_time
  contains "am" / "pm"). When supplied, multiple rows per PSU are
  aggregated to a single PSU-level mean (C-bar_d) and within-day
  variance components (SS_d, K_d) are stored in `design$within_day_var`.
  When NULL (default), a single row per PSU is expected; duplicate PSU
  rows emit a CNT-06 warning.

- count_type:

  Character string specifying the count method. Must be
  `"instantaneous"` (default) or `"progressive"`. When `"progressive"`,
  `circuit_time` and `period_length_col` are required.

- circuit_time:

  Numeric. Circuit duration τ in hours — the time required to complete
  one roving count circuit of the water body. Required when
  `count_type = "progressive"` (CNT-05). Used to compute κ = T_d / τ and
  Ê_d = C × τ × κ. Ignored (with a warning) when
  `count_type = "instantaneous"`.

- period_length_col:

  Tidy selector for the column containing T_d — the total fishable shift
  duration in hours for each PSU. Required when
  `count_type = "progressive"` (CNT-05). Values must be positive and
  finite. The column is dropped from `design$counts` after Ê_d is
  computed (it must not be passed to
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  as a count variable).

- allow_invalid:

  Logical flag for validation behavior. If FALSE (default), validation
  failures abort with detailed error messages. If TRUE, validation
  failures generate warnings and attach counts anyway (use with
  caution).

## Value

A new creel_design object (list) with components:

- calendar:

  Original calendar data frame

- date_col:

  Character name of date column

- strata_cols:

  Character vector of strata column names

- site_col:

  Character name of site column, or NULL

- design_type:

  Character design type

- counts:

  The count data frame (newly attached)

- psu_col:

  Character name of PSU column

- survey:

  Internal survey.design2 object (newly constructed)

- validation:

  creel_validation object with Tier 1 results

## Immutability

add_counts() follows functional programming patterns and returns a new
creel_design object. The original design object is not modified. This
prevents accidental data loss and makes the workflow explicit:
`design2 <- add_counts(design, counts)` not `add_counts(design, counts)`

## Validation

add_counts() performs Tier 1 validation:

- Count data schema (Date column, numeric column) via
  validate_count_schema()

- Design column presence (date_col, strata_cols, PSU in count data)

- No NA values in design-critical columns (date, strata, PSU)

- Survey construction (catches lonely PSU errors, stratification issues)

## PSU Specification

Per user decision (clarified 2026-02-08), PSU is specified only in
add_counts(), not in creel_design() constructor. PSU is only meaningful
when count data is present, making add_counts() the correct abstraction
boundary. This design allows the same creel_design calendar to be used
with different PSU structures.

## See also

Other "Survey Design":
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md),
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
# Preferred workflow: standardize sampled-day effort before attachment
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend")
)
design <- creel_design(calendar, date = date, strata = day_type)

raw_counts <- data.frame(
  sample_date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  effort_kind = c("bank", "bank", "bank", "bank"),
  effort_value = c(15, 23, 45, 52)
)

counts_ready <- prep_counts_daily_effort(
  raw_counts,
  date = sample_date,
  strata = day_type,
  effort_type = effort_kind,
  daily_effort = effort_value
)

design_with_counts <- add_counts(design, counts_ready)
#> Warning: No weights or probabilities supplied, assuming equal probability
print(design_with_counts)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 4 days (2024-06-01 to 2024-06-04)
#> day_type: 2 levels
#> Counts: 4 observations
#> PSU column: date
#> Count type: "instantaneous"
#> Survey: <survey.design2> (constructed)
#> Interviews: "none"
#> Sections: "none"

# Compatibility path: raw count rows with a custom PSU column
counts_with_site_psu <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  site_day = paste0("site_", 1:4),
  count = c(15, 23, 45, 52)
)

design2 <- add_counts(design, counts_with_site_psu, psu = "site_day")
#> Warning: No weights or probabilities supplied, assuming equal probability

# Compatibility path: multiple counts per day (within-day variance via count_time_col)
# Two circuits per day: "am" and "pm"
calendar2 <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend")
)
design3 <- creel_design(calendar2, date = date, strata = day_type)

multi_counts <- data.frame(
  date = as.Date(rep(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04"), each = 2)),
  day_type = rep(c("weekday", "weekday", "weekend", "weekend"), each = 2),
  count_time = rep(c("am", "pm"), 4),
  n_anglers = c(12, 18, 20, 26, 40, 50, 48, 56)
)
design_multi <- add_counts(design3, multi_counts,
  count_time_col = count_time # nolint: object_usage_linter
)
#> Warning: No weights or probabilities supplied, assuming equal probability

# Compatibility path: progressive count type (Ê_d = C x circuit_time x kappa)
calendar3 <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend")
)
design4 <- creel_design(calendar3, date = date, strata = day_type)

prog_counts <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  n_anglers = c(15L, 23L, 45L, 52L),
  shift_hours = rep(8, 4)
)
design_prog <- add_counts(
  design4, prog_counts,
  count_type = "progressive",
  circuit_time = 2,
  period_length_col = shift_hours # nolint: object_usage_linter
)
#> Warning: No weights or probabilities supplied, assuming equal probability
```
