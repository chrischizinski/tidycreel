# Register spatial sections for a creel survey design

Attaches a sections registry to a `creel_design` object. Once sections
are registered, all subsequent calls to
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
and
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
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
  shoreline_col = NULL
)
```

## Arguments

- design:

  A `creel_design` object (created with
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)).

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

## Value

A new `creel_design` object with `$sections` and `$section_col`
populated. The input `design` is not modified.

## Validation performed by downstream functions

After `add_sections()` is called,
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
and
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
check that every row's section value is present in
`design$sections[[design$section_col]]`. An unrecognised value produces
a `cli_abort()` naming the bad values and listing valid section names.

## See also

[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)

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
