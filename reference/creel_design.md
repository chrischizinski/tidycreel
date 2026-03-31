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
  visibility_correction = NULL
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

  Optional numeric scalar in `(0, 1]` specifying the proportion of
  anglers on the water that are detectable from the aircraft. Used only
  when `survey_type = "aerial"`. Defaults to `1.0` (all anglers visible)
  when `NULL`. A value of 0.85 means 85% of anglers are detected; the
  effort estimate is scaled up by \\1 / 0.85\\.

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
