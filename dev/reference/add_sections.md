# Register spatial sections for a creel survey design

Attaches a sections registry to a `creel_design` object. Once sections
are registered, all subsequent calls to
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
and
[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
validate that every row's section value matches a registered section
name. Unrecognised section values abort with an informative error
identifying the bad values and listing valid options.

`add_sections()` is optional for single-section surveys. Call it when
your survey covers multiple named sections and you want early detection
of mislabelled data (e.g. "NRTH" instead of "NORTH").

## Usage

``` r
add_sections(
  design,
  sections,
  section_col,
  description_col = NULL,
  area_col = NULL,
  shoreline_col = NULL,
  shared_count_times = FALSE
)
```

## Arguments

- design:

  A `creel_design` object (created with
  [`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)).

- sections:

  A data frame with one row per section. Must contain the column
  identified by `section_col`. Optional metadata columns are identified
  by `description_col`, `area_col`, and `shoreline_col`.

- section_col:

  Tidy selector for the column in `sections` that holds section names or
  IDs. Must be character or factor. No duplicate values are permitted.

- description_col:

  Optional tidy selector for a free-text description column (e.g. "North
  inlet", "Main basin"). Stored for reporting only.

- area_col:

  Optional tidy selector for a surface area column (numeric, ha). All
  values must be strictly positive. Stored now; used in v0.8.0 aerial
  survey estimation.

- shoreline_col:

  Optional tidy selector for a shoreline length column (numeric, km).
  All values must be strictly positive. Stored now; used in v0.8.0
  aerial survey estimation.

- shared_count_times:

  Logical. `FALSE` (default) treats the sections' within-day sampling
  errors as independent. Set `TRUE` only when the sections' counts were
  taken at the **same randomly drawn count times**, so that a
  `count_time` label means the same moment in every section. The lake
  total's within-day SE then adds the sections up at each occasion
  before taking the variance, which keeps the covariance between
  sections that rise and fall together through the day. Requires
  `count_time_col` in
  [`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md).
  Never inferred from matching labels: one clerk driving a circuit
  counts "am" in each section at a different moment, and pairing those
  would be a modelling choice the data cannot confirm. Not supported
  together with count units finer than the section (`unit_cols` beyond
  the section), or when the section is also one of the design's strata;
  both combinations are refused. See the section below.

## Value

A new `creel_design` object with `$sections` and `$section_col`
populated. The input `design` is not modified.

## Validation performed by downstream functions

After `add_sections()` is called,
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
and
[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
check that every row's section value is present in
`design$sections[[design$section_col]]`. An unrecognised value produces
a `cli_abort()` naming the bad values and listing valid section names.

## Shared count times and the lake total's within-day SE

A section's within-day SE is the second-stage sampling error of the
count times drawn within its sampled days. Two sections have independent
errors when their times were drawn independently, and correlated errors
when the same drawn times were used in both – both rise on a busy
afternoon and fall on a quiet morning together. The lake total's
`se_within` is a sum over sections, so it needs the covariance in the
second case and not in the first. Which case holds is a fact about how
the counts were scheduled, so it is declared with `shared_count_times`
and never read off the labels.

With `shared_count_times = TRUE`, the per-section rows are unchanged;
only the `.lake_total` row's `se_within` (and so its `se`) changes. A
day on which the sections were not counted at the same known occasions
cannot be paired and is added as independent, with a message saying so.
Sections counted a different number of times on a day share the
unequal-count limitation noted in GH \#405: the pooled component
averages the counts per day across sections.

## How sections are named in results

Every sectioned estimate reports its sections in a column named after
`section_col`, as a design declaring `strata = day_type` reports a
`day_type` column. Register sections under `reach` and the result's
first column is `reach`, so it joins back to your own section table by
name. Read it as `est[[design$section_col]]` rather than assuming a
fixed name (#282).

The lake-wide aggregate row, where requested, is a *value* in that same
column – the reserved name `.lake_total` – not a separate column.

## See also

[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md),
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)

Other "Survey Design":
[`add_catch()`](https://chrischizinski.com/tidycreel/dev/reference/add_catch.md),
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md),
[`add_lengths()`](https://chrischizinski.com/tidycreel/dev/reference/add_lengths.md),
[`as_creel_svydesign()`](https://chrischizinski.com/tidycreel/dev/reference/as_creel_svydesign.md),
[`as_hybrid_svydesign()`](https://chrischizinski.com/tidycreel/dev/reference/as_hybrid_svydesign.md),
[`compute_angler_effort()`](https://chrischizinski.com/tidycreel/dev/reference/compute_angler_effort.md),
[`compute_effort()`](https://chrischizinski.com/tidycreel/dev/reference/compute_effort.md),
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md),
[`creel_schema()`](https://chrischizinski.com/tidycreel/dev/reference/creel_schema.md),
[`creel_vocabulary()`](https://chrischizinski.com/tidycreel/dev/reference/creel_vocabulary.md),
[`derive_angler_count()`](https://chrischizinski.com/tidycreel/dev/reference/derive_angler_count.md),
[`est_effort_camera()`](https://chrischizinski.com/tidycreel/dev/reference/est_effort_camera.md),
[`impute_camera_counts()`](https://chrischizinski.com/tidycreel/dev/reference/impute_camera_counts.md),
[`mean_party_size()`](https://chrischizinski.com/tidycreel/dev/reference/mean_party_size.md),
[`prep_counts_boat_party()`](https://chrischizinski.com/tidycreel/dev/reference/prep_counts_boat_party.md),
[`prep_counts_daily_effort()`](https://chrischizinski.com/tidycreel/dev/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.com/tidycreel/dev/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.com/tidycreel/dev/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.com/tidycreel/dev/reference/validate_creel_schema.md)

## Examples

``` r
cal <- data.frame(
  date = as.Date(c(
    "2024-06-01", "2024-06-02",
    "2024-06-03", "2024-06-04"
  )),
  day_type = c("weekday", "weekday", "weekend", "weekend")
)
design <- creel_design(cal, date = date, strata = day_type)

my_sections <- data.frame(
  section      = c("North Inlet", "Main Basin", "South Outlet"),
  description  = c("Tributary inlet", "Open water", "Dam outlet"),
  area_ha      = c(45.0, 820.0, 12.0),
  shoreline_km = c(8.2, 62.1, 3.4)
)

design2 <- add_sections(design, my_sections,
  section_col     = section,
  description_col = description,
  area_col        = area_ha,
  shoreline_col   = shoreline_km
)
```
