# Create a creel survey design

Constructs a `creel_design` object from calendar data with tidy column
selection. This is the entry point for all creel survey analysis
workflows. The design object stores the survey structure (date, strata,
optional site), validates input data (Tier 1 validation), and serves as
the foundation for adding count data and estimating effort.

For bus-route surveys with nonuniform site selection probabilities, use
`survey_type = "bus_route"` and supply a `sampling_frame` data frame
specifying sites, circuits, and their sampling probabilities.

## Usage

``` r
creel_design(
  calendar,
  date,
  strata,
  site = NULL,
  design_type = "instantaneous",
  survey_type = design_type,
  sampling_frame = NULL,
  p_site = NULL,
  p_period = NULL,
  circuit = NULL,
  effort_type = NULL,
  camera_mode = NULL,
  h_open = NULL,
  visibility_correction = NULL,
  visibility_se = NULL,
  angler_ratio = NULL,
  angler_ratio_se = NULL,
  open_start = NULL
)
```

## Arguments

- calendar:

  A data frame containing calendar data with date and strata columns.
  Must have at least one Date column and one character/factor column
  (validated via internal schema check).

- date:

  Tidy selector for the date column. Must select exactly one column of
  class Date. Accepts bare column names or tidyselect helpers (e.g.,
  `starts_with("date")`).

- strata:

  Tidy selector for strata columns. Can select one or more columns of
  class character or factor. Accepts bare column names or tidyselect
  helpers (e.g., `c(day_type, season)` or `starts_with("day")`).

- site:

  Optional tidy selector for a site column. For instantaneous designs,
  selects from `calendar`. For bus-route designs
  (`survey_type = "bus_route"`), selects the site ID column from
  `sampling_frame`. Must select exactly one column of class character or
  factor. Default is `NULL` (single-site survey for instantaneous
  designs; required for bus-route designs).

- design_type:

  Character string specifying the survey design type. Default is
  `"instantaneous"`. Kept for backward compatibility; use `survey_type`
  for new code.

- survey_type:

  Character string specifying the survey type. Default inherits from
  `design_type` (`"instantaneous"`). Use `"bus_route"` for nonuniform
  probability bus-route surveys (BUSRT-06, BUSRT-07). Both `survey_type`
  and `design_type` refer to the same concept; `survey_type` is the
  canonical parameter for new designs.

- sampling_frame:

  Data frame with site, circuit, and probability columns. Required when
  `survey_type = "bus_route"`. Each row represents one site-circuit
  sampling unit with its inclusion probability components (`p_site` and
  `p_period`).

- p_site:

  Tidy selector for the site sampling probability column in
  `sampling_frame`. Required when `survey_type = "bus_route"`. Values
  must be in `(0, 1]` and must sum to `1.0` within each circuit
  (tolerance 1e-6).

- p_period:

  Tidy selector for the period sampling probability column in
  `sampling_frame`, OR a scalar numeric value in `(0, 1]` that applies
  globally to all rows. Required when `survey_type = "bus_route"`.

- circuit:

  Optional tidy selector for the circuit ID column in `sampling_frame`.
  A circuit is a route x period combination. If omitted, all rows are
  treated as belonging to a single unnamed circuit (`".default"`).
  Required only for multi-circuit designs.

- effort_type:

  Character string specifying the type of effort measured in ice fishing
  surveys. Required when `survey_type = "ice"`. Must be one of
  `"time_on_ice"` (total hours the angler was on the ice) or
  `"active_fishing_time"` (hours actively fishing, excluding
  travel/setup). The value controls the column name in
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  output: `total_effort_hr_on_ice` or `total_effort_hr_active`.

- camera_mode:

  Character string specifying the camera sub-mode. Required when
  `survey_type = "camera"`. Must be one of `"counter"` (camera records a
  daily ingress total) or `"ingress_egress"` (camera records individual
  arrival/departure timestamps, which should be preprocessed with
  [`preprocess_camera_timestamps()`](https://chrischizinski.github.io/tidycreel/reference/preprocess_camera_timestamps.md)
  before calling
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)).

- h_open:

  Positive numeric scalar specifying the number of hours the fishery is
  open per day. Required when `survey_type = "aerial"`. Used as the
  expansion factor in the aerial effort estimator: \\\hat{E} = N\_{obs}
  \times h\_{open} / v\\.

- visibility_correction:

  Detection probability for the aerial count: the proportion of anglers
  present that are detected from the aircraft, as a numeric scalar in
  `(0, 1]`. **Required** when `survey_type = "aerial"`; pass the string
  `"none"` to state explicitly that no visibility correction is applied.
  Used only when `survey_type = "aerial"`. A value of 0.85 means 85% of
  anglers are detected; the effort estimate is scaled up by \\1 /
  0.85\\.

  **This is the reciprocal of the ratio published by field studies.**
  The standard ground-truthing method reports \\r\\ = (ground count) /
  (aerial count), which is **greater than 1** whenever the aircraft
  undercounts: Smucker et al. (2010) report \\r = 2.69\\ for shore
  anglers. `visibility_correction` is a *probability*, so convert with
  \\v = 1 / r\\ — \\r = 2.69\\ becomes
  `visibility_correction = 1 / 2.69 = 0.372`. The estimator divides by
  \\v\\, which scales effort up by \\1 / 0.372 = 2.69\\ as intended.
  Passing the published \\r\\ directly is rejected by the `(0, 1]`
  check.

- visibility_se:

  Optional positive numeric scalar: the standard error of
  `visibility_correction`, on the same detection-probability scale. Used
  only when `survey_type = "aerial"`. `visibility_correction` is
  estimated from paired air–ground counts, not known, and the standard
  field method reports its SE as routine output (Smucker et al. 2010,
  equations 6 and 7); supplying it here propagates that uncertainty into
  the effort SE (GH \#135). All-or-none: `visibility_se` requires a
  numeric `visibility_correction`, and cannot be combined with `"none"`.

  To convert an SE published on the ground-truthing-ratio scale, use the
  delta method for a reciprocal: \\SE(v) = SE(r) / r^2\\.

  When omitted, the correction is treated as supplied without a measured
  uncertainty and the component is reported as absent — never as zero,
  which would be indistinguishable from having propagated it.

  Note the three distinct claims, which the package keeps separate:

  `visibility_correction = "none"`

  :   No correction was studied. The point estimate divides by 1 and
      `visibility_se` is `NA`, so the reported SE is `NA` — the
      uncertainty is unpropagated, not zero.

  `visibility_correction = v` alone

  :   A correction was measured but its SE was not supplied. The
      component is reported as absent.

  `visibility_correction = v, visibility_se = 0`

  :   The correction is asserted to be known exactly. This is the only
      way to obtain a numeric SE with no visibility uncertainty, and it
      must be stated deliberately — e.g.
      `visibility_correction = 1, visibility_se = 0` for a fishery where
      every angler is genuinely detectable.

- angler_ratio:

  The proportion of the people recorded in the aerial count that are
  anglers, as a numeric scalar in `(0, 1]`. **Required** when
  `survey_type = "aerial"`; pass the string `"none"` to state explicitly
  that no such correction is applied.

  An aerial count column is a **raw observer count**, and observers
  cannot reliably tell anglers from non-anglers from the air. Smucker et
  al. (2010) apply an angler-to-people ratio of 0.404 alongside their
  visibility correction; omitting it overstates shore effort by roughly
  2.5x. The two corrections push in **opposite** directions (0.404 down,
  2.69 up), so applying only the visibility correction is not
  conservative — it is biased in the direction of the correction that
  was kept (GH \#158).

  If the count column already records anglers rather than people, say so
  with `angler_ratio = 1, angler_ratio_se = 0`, which asserts the ratio
  is known exactly. That is a claim about how the data were recorded,
  and only the surveyor can make it.

  For a count of **boats** rather than people, do not use this argument:
  expand the boat count to anglers with
  [`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md)
  before
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
  which attaches the party-size multiplier and its standard error as
  expansion carrier columns that the estimator reads.

- angler_ratio_se:

  Optional positive numeric scalar: the standard error of
  `angler_ratio`. All-or-none — it requires a numeric `angler_ratio` and
  cannot be combined with `"none"`. Like the visibility correction, the
  angler-to-people ratio is estimated from ground observation and is a
  **shared** multiplier, so its contribution enters once at the total.
  Omitted means the component is reported as absent, never as zero.

- open_start:

  Optional non-negative numeric scalar specifying the hour of day
  (decimal, 24-hour clock) when the fishery opens. Used only when
  `survey_type = "aerial"` and only by
  [`estimate_effort_aerial_glmm()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort_aerial_glmm.md)
  to anchor the numerical integration window. If `NULL` (default), the
  GLMM estimator derives the window start from the earliest observed
  flight time minus 0.5 hours, with an informational message. Supplying
  `open_start` fixes the window across surveys for consistent
  comparisons. Example: `open_start = 5.5` means fishing begins at 5:30
  AM.

## Value

A `creel_design` S3 object (list) with components:

- calendar:

  The original calendar data frame

- date_col:

  Character name of the date column

- strata_cols:

  Character vector of strata column names

- site_col:

  Character name of site column, or NULL

- design_type:

  Character design type

- counts:

  NULL (populated by
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  in future)

- survey:

  NULL (populated internally during estimation)

- bus_route:

  List with resolved sampling frame data and column mappings, or NULL
  for non-bus-route designs. Contains: `$data` (sampling frame with
  `.pi_i` column added), `$site_col`, `$circuit_col`, `$p_site_col`,
  `$p_period_col`, `$pi_i_col` (always `".pi_i"`).

## Tier 1 Validation

The constructor performs fail-fast validation:

- Date column is class Date (not character, numeric, POSIXct)

- Date column contains no NA values

- Strata columns are character or factor (not numeric, logical)

- Site column (if provided) is character or factor

- (bus_route only) All `p_site` and `p_period` values are in `(0, 1]`

- (bus_route only) `p_site` values sum to 1.0 within each circuit
  (tolerance 1e-6)

- (bus_route only) `p_period` values are constant within each circuit
  (tolerance 1e-10)

## References

Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
estimating effort, harvest, and abundance. In A. V. Zale, D. L. Parrish,
& T. M. Sutton (Eds.), *Fisheries Techniques* (3rd ed., pp. 883–919).
American Fisheries Society. Eq. 19.4 and 19.5 define the bus-route
estimators; pp. 883–884 define the inclusion probability \\\pi_i =
p\_{\text{site}} \times p\_{\text{period}}\\.

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
[`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md),
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
# Basic design with single stratum
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
  day_type = c("weekday", "weekend", "weekend")
)
design <- creel_design(calendar, date = date, strata = day_type)

# Multiple strata
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02")),
  day_type = c("weekday", "weekend"),
  season = c("summer", "summer")
)
design <- creel_design(calendar, date = date, strata = c(day_type, season))

# With site column for multi-site survey
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02")),
  day_type = c("weekday", "weekend"),
  lake = c("lake_a", "lake_b")
)
design <- creel_design(calendar, date = date, strata = day_type, site = lake)

# Using tidyselect helpers
calendar <- data.frame(
  survey_date = as.Date(c("2024-06-01", "2024-06-02")),
  day_type = c("weekday", "weekend"),
  day_period = c("morning", "evening")
)
design <- creel_design(
  calendar,
  date = starts_with("survey"),
  strata = starts_with("day")
)

# Bus-route design with scalar p_period
calendar_br <- data.frame(
  date = as.Date("2024-06-01"),
  day_type = "weekday"
)
sf <- data.frame(
  site = c("A", "B", "C"),
  p_site = c(0.3, 0.4, 0.3),
  p_period = 0.5
)
design_br <- creel_design(
  calendar_br,
  date = date,
  strata = day_type,
  survey_type = "bus_route",
  sampling_frame = sf,
  site = site,
  p_site = p_site,
  p_period = p_period
)
```
