# Add each interview's catch, harvest and release totals from a catch table

[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
needs a per-interview total catch column, but most agencies record catch
as a long table – one row per interview, species and fate – which is
what
[`add_catch()`](https://chrischizinski.com/tidycreel/dev/reference/add_catch.md)
takes. `prep_interview_totals()` sums that table back to one row per
interview, so the two never have to be reconciled by hand (GH \#560).

Totals follow the catch-type model
[`add_catch()`](https://chrischizinski.com/tidycreel/dev/reference/add_catch.md)
documents, per species-interview pair: a pair's own `"caught"` row when
it has one, otherwise harvested + released. Harvest sums the
`"harvested"` rows and release the `"released"` rows.

## Usage

``` r
prep_interview_totals(
  interviews,
  catch,
  interview_uid,
  catch_uid,
  species,
  count,
  catch_type,
  absent
)
```

## Arguments

- interviews:

  Interview table, one row per interview.

- catch:

  Long catch table: one row per interview, species and catch type.

- interview_uid:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Interview id column in `interviews`.

- catch_uid:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Interview id column in `catch`.

- species, count, catch_type:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Species, fish count and fate (`"caught"`, `"harvested"` or
  `"released"`, any case) columns in `catch`.

- absent:

  What an interview with no catch rows means: `"zero"` or `"unknown"`.
  Required; see the section above.

## Value

`interviews` with three numeric columns added: `catch_total`,
`harvest_total` and `release_total`.

## An interview with no catch rows

Whether that means "caught nothing" or "catch not recorded" depends on
the field sheet, so `absent` has no default. On a sheet that records a
row for every species caught, no row means zero fish: `absent = "zero"`.
If a missing row can mean the catch was never written down,
`absent = "unknown"` gives `NA`, which
[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
then asks you to resolve rather than scoring as zero.

## See also

[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md),
[`add_catch()`](https://chrischizinski.com/tidycreel/dev/reference/add_catch.md),
[`prep_interview_catch()`](https://chrischizinski.com/tidycreel/dev/reference/prep_interview_catch.md)

Other "Survey Design":
[`add_catch()`](https://chrischizinski.com/tidycreel/dev/reference/add_catch.md),
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md),
[`add_lengths()`](https://chrischizinski.com/tidycreel/dev/reference/add_lengths.md),
[`add_sections()`](https://chrischizinski.com/tidycreel/dev/reference/add_sections.md),
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
iv <- data.frame(id = c("a", "b", "c"))
ct <- data.frame(
  id = c("a", "a", "b"), sp = c("walleye", "walleye", "bass"),
  n = c(2, 3, 1), fate = c("harvested", "released", "caught")
)
prep_interview_totals(iv, ct,
  interview_uid = id, catch_uid = id, species = sp,
  count = n, catch_type = fate, absent = "zero"
)
#>   id catch_total harvest_total release_total
#> 1  a           5             2             3
#> 2  b           1             0             0
#> 3  c           0             0             0
```
