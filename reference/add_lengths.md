# Attach fish length frequency data to a creel design

Attaches a long-format data frame of fish length measurements to a
`creel_design` object. Supports both individual measurements (harvest)
and binned counts (release). Data is validated at attach time and stored
on the design for use by downstream summary and estimation functions.

## Usage

``` r
add_lengths(
  design,
  data,
  length_uid,
  interview_uid,
  species,
  length,
  length_type,
  count = NULL,
  release_format = "individual"
)
```

## Arguments

- design:

  A `creel_design` object created by
  [`creel_design`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md).

- data:

  A data frame in long format: one row per fish measurement or length
  bin per species per interview.

- length_uid:

  \<[tidyselect](https://tidyselect.r-lib.org/reference/tidyselect-package.html)\>
  Column in `data` containing interview IDs (the length-side join key).

- interview_uid:

  \<[tidyselect](https://tidyselect.r-lib.org/reference/tidyselect-package.html)\>
  Column in `design$interviews` containing the matching interview IDs.

- species:

  \<[tidyselect](https://tidyselect.r-lib.org/reference/tidyselect-package.html)\>
  Column in `data` containing species names or codes.

- length:

  \<[tidyselect](https://tidyselect.r-lib.org/reference/tidyselect-package.html)\>
  Column in `data` containing length values. For harvest rows (when
  `release_format = "individual"`), must be numeric (mm). For release
  rows when `release_format = "binned"`, may be a character bin label
  such as `"300-350"`.

- length_type:

  \<[tidyselect](https://tidyselect.r-lib.org/reference/tidyselect-package.html)\>
  Column in `data` containing the measurement fate: one of `"harvest"`
  or `"release"`. Values are normalized to lowercase before validation.

- count:

  \<[tidyselect](https://tidyselect.r-lib.org/reference/tidyselect-package.html)\>
  Optional. Column in `data` containing fish counts for binned release
  rows. Required when `release_format = "binned"` and release rows are
  present. Harvest rows should have `NA` in this column. Omit (or pass
  `NULL`) when all length data are individual measurements.

- release_format:

  Character scalar: `"individual"` (default) or `"binned"`. Controls how
  release rows are validated and how the length range is computed for
  display.

## Value

A new `creel_design` object with `$lengths` and associated
`$lengths_*_col` fields attached.

## Details

**Mixed column type footgun:** The `length` column may contain both
numeric values (harvest rows) and character bin labels (release rows). R
will coerce the entire column to character when mixing types in a
`data.frame`. `add_lengths()` validates harvest row lengths by
subsetting to harvest rows first, then attempting
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) coercion, to avoid
errors from the mixed-type column.

**Interview ID validation:** Every interview ID appearing in `data` must
appear in `design$interviews[[interview_uid]]`. Interviews with no
length rows are valid.

**Immutability:** Returns a new `creel_design` — the input is not
modified. Calling `add_lengths()` on a design that already has
`$lengths` is an error.

## Examples

``` r
data(example_calendar)
data(example_interviews)
data(example_lengths)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_interviews(design, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status, trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
design <- add_lengths(design, example_lengths,
  length_uid = interview_id,
  interview_uid = interview_id,
  species = species,
  length = length,
  length_type = length_type,
  count = count,
  release_format = "binned"
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
#> Length Data: 20 rows, 3 species, length: 155–512 mm
#> harvest: 14 individual
#> release: 6 binned
#> Sections: "none"
```
