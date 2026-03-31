# Attach interview data to a creel design

Attaches interview data (catch, effort, and optionally harvest per
completed fishing trip) to a creel_design object and constructs the
internal interview survey design object eagerly. This enables catch rate
and harvest rate estimation from angler interviews. Follows the same
tidy selector API pattern as
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).

## Usage

``` r
add_interviews(
  design,
  interviews,
  catch,
  effort,
  harvest = NULL,
  trip_status,
  trip_duration = NULL,
  trip_start = NULL,
  interview_time = NULL,
  n_counted = NULL,
  n_interviewed = NULL,
  angler_type = NULL,
  angler_method = NULL,
  species_sought = NULL,
  n_anglers = 1L,
  refused = NULL,
  date_col = NULL,
  interview_type = c("access", "roving"),
  allow_invalid = FALSE
)
```

## Arguments

- design:

  A creel_design object (created with
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md))

- interviews:

  Data frame containing interview data. Must have:

  - A Date column matching the design's date_col

  - Numeric catch column (total fish caught per trip)

  - Numeric effort column (fishing time per trip, e.g., hours)

  - Character trip status column ("complete" or "incomplete")

  - Optional numeric harvest column (fish kept per trip)

  - Optional numeric trip duration column (hours) OR trip_start +
    interview_time columns (POSIXct)

- catch:

  Tidy selector for total catch column (required). Use bare column names
  (e.g., `catch = catch_total`) or tidyselect helpers.

- effort:

  Tidy selector for fishing effort column (required, e.g.,
  `effort = hours_fished`). Should represent time spent fishing per
  trip.

- harvest:

  Tidy selector for harvest (kept fish) column (optional, default NULL).
  If provided, will be validated for consistency (harvest \<= catch).

- trip_status:

  Tidy selector for trip completion status column (required). Must
  contain "complete" or "incomplete" (case-insensitive). This is
  essential for downstream incomplete trip estimators.

- trip_duration:

  Tidy selector for trip duration column in hours (optional, default
  NULL). Provide either trip_duration OR trip_start + interview_time,
  not both. Duration values must be positive and \>= 1/60 hours (1
  minute).

- trip_start:

  Tidy selector for trip start time column (optional, default NULL).
  Must be POSIXct or POSIXlt. Requires interview_time to calculate
  duration. Use when duration needs to be calculated from timestamps.

- interview_time:

  Tidy selector for interview time column (optional, default NULL). Must
  be POSIXct or POSIXlt. Requires trip_start to calculate duration.
  Duration is calculated as interview_time - trip_start in hours.

- n_counted:

  Tidy selector for the count of all anglers observed at the site during
  the sampling period (required for bus-route designs, ignored for other
  designs). Values must be non-negative integers. Must satisfy n_counted
  \>= n_interviewed.

- n_interviewed:

  Tidy selector for the count of anglers actually interviewed at the
  site (required for bus-route designs, ignored for other designs).
  Values of 0 are valid (no anglers came off the water).

- angler_type:

  Tidy selector for angler type column (optional, default NULL). Use
  bare column names (e.g., `angler_type = angler_type`). Common values
  are "bank" and "boat". Not validated in Phase 28; downstream summary
  functions use this field.

- angler_method:

  Tidy selector for angler method column (optional, default NULL). Use
  bare column names (e.g., `angler_method = method_code`). Records the
  fishing technique employed (e.g., "fly", "spin", "bait").

- species_sought:

  Tidy selector for species sought column (optional, default NULL). Use
  bare column names (e.g., `species_sought = target_species`). Records
  the species the angler was targeting during the interview.

- n_anglers:

  Tidy selector for the number of anglers in the party (default 1L –
  individual-level interviews). When omitted, a `cli_inform()` message
  notes the assumption. Use bare column names (e.g.,
  `n_anglers = party_size`).

- refused:

  Tidy selector for the refused interview flag column (optional, default
  NULL). Use bare column names (e.g., `refused = refused_flag`). Values
  should be logical (TRUE/FALSE) or coercible to logical.

- date_col:

  Character name of date column in interviews (default NULL, which uses
  the design's date_col). Specify explicitly if interview data uses a
  different date column name than the design calendar.

- interview_type:

  Character: "access" (complete trips at access point) or "roving"
  (incomplete trips during fishing). Default is "access". This affects
  how catch rates are calculated in estimation functions.

- allow_invalid:

  Logical flag for validation behavior. If FALSE (default), validation
  failures abort with detailed error messages. If TRUE, validation
  failures generate warnings and attach interviews anyway (use with
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

  Count data frame (if previously attached, or NULL)

- interviews:

  The interview data frame (newly attached)

- catch_col:

  Character name of catch column

- effort_col:

  Character name of effort column

- harvest_col:

  Character name of harvest column, or NULL

- trip_status_col:

  Character name of trip status column

- trip_duration_col:

  Character name of trip duration column, or NULL

- trip_start_col:

  Character name of trip start time column, or NULL

- interview_time_col:

  Character name of interview time column, or NULL

- interview_type:

  Character interview type

- interview_survey:

  Internal survey.design2 object (newly constructed)

- validation:

  creel_validation object with Tier 1 results

## Immutability

add_interviews() follows functional programming patterns and returns a
new creel_design object. The original design object is not modified.
This prevents accidental data loss and makes the workflow explicit:
`design2 <- add_interviews(design, interviews, ...)` not
`add_interviews(design, interviews, ...)`

## Validation

add_interviews() performs Tier 1 validation:

- Interview data schema (Date column, numeric columns) via
  validate_interview_schema()

- Design column presence (date_col exists in interview data)

- No NA values in date column

- Interview dates exist in design calendar

- Catch and effort columns exist and are numeric

- Harvest column exists and is numeric (if provided)

- Harvest \<= catch consistency (if harvest provided)

- Trip status valid ("complete" or "incomplete", case-insensitive)

- Trip status has no NA values

- Trip duration/time inputs are mutually exclusive (error if both
  provided)

- Trip duration is positive, \>= 1 minute, warns if \> 48 hours

- Trip start + interview_time are POSIXct/POSIXlt, calculate valid
  duration

- Interview survey construction (catches stratification issues)

## Calendar Integration

Interview dates are automatically linked to the design calendar via date
matching. Strata from the calendar are inherited by the interview data,
enabling stratified estimation of catch rates.

## Examples

``` r
# Basic usage - with trip status and duration
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend")
)
design <- creel_design(calendar, date = date, strata = day_type)

interviews <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  catch_total = c(5, 3, 7, 2),
  hours_fished = c(2.0, 2.5, 3.0, 1.5),
  trip_status = c("complete", "complete", "incomplete", "complete"),
  trip_duration = c(2.0, 2.5, 1.5, 1.5)
)

design_with_interviews <- add_interviews(
  design, interviews,
  catch = catch_total,
  effort = hours_fished,
  trip_status = trip_status,
  trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> Warning: 2 strata have fewer than 3 interviews:
#> • Stratum weekday: 2 interviews
#> • Stratum weekend: 2 interviews
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.
#> ℹ Added 4 interviews: 3 complete (75%), 1 incomplete (25%)
print(design_with_interviews)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 4 days (2024-06-01 to 2024-06-04)
#> day_type: 2 levels
#> Counts: "none"
#> Interviews: 4 observations
#> Type: "access"
#> Catch: catch_total
#> Effort: hours_fished
#> Trip status: 3 complete, 1 incomplete
#> Survey: <survey.design2> (constructed)
#> Sections: "none"

# With harvest column and calculated duration from timestamps
interviews2 <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  catch_total = c(5, 3, 7, 2),
  catch_kept = c(2, 1, 5, 2),
  hours_fished = c(2.0, 2.5, 3.0, 1.5),
  trip_status = c("complete", "incomplete", "complete", "complete"),
  trip_start = as.POSIXct(c(
    "2024-06-01 08:00", "2024-06-02 09:00",
    "2024-06-03 07:00", "2024-06-04 10:00"
  )),
  interview_time = as.POSIXct(c(
    "2024-06-01 10:00", "2024-06-02 11:30",
    "2024-06-03 10:00", "2024-06-04 11:30"
  ))
)

design2 <- add_interviews(
  design, interviews2,
  catch = catch_total,
  effort = hours_fished,
  harvest = catch_kept,
  trip_status = trip_status,
  trip_start = trip_start,
  interview_time = interview_time
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> Warning: 2 strata have fewer than 3 interviews:
#> • Stratum weekday: 2 interviews
#> • Stratum weekend: 2 interviews
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.
#> ℹ Added 4 interviews: 3 complete (75%), 1 incomplete (25%)
```
