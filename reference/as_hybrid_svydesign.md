# Construct a hybrid access + roving survey design

**\[experimental\]**

## Usage

``` r
as_hybrid_svydesign(
  access_data,
  roving_data,
  date_col = "date",
  strata_col = "day_type",
  count_col = "count",
  access_fraction = NULL,
  roving_fraction = NULL,
  trips_disjoint = NULL,
  fpc = TRUE
)
```

## Arguments

- access_data:

  Data frame of access-point count observations. Must contain the
  columns named by `date_col`, `strata_col`, and `count_col`.

- roving_data:

  Data frame of roving-route count observations. Must contain the same
  columns as `access_data`.

- date_col:

  Character scalar. Name of the date column (shared by both tables).
  Default `"date"`. Used to cluster observations into PSUs.

- strata_col:

  Character scalar. Name of the stratum column (shared by both tables).
  Default `"day_type"`.

- count_col:

  Character scalar. Name of the count column (shared by both tables).
  Default `"count"`.

- access_fraction:

  Named numeric vector. Sampling fraction per stratum for the
  access-point component (proportion of access points sampled on each
  sampled day; must be in (0, 1\]). Names must match stratum values in
  `access_data`.

- roving_fraction:

  Named numeric vector. Sampling fraction per stratum for the
  roving-route component. Names must match stratum values in
  `roving_data`.

- trips_disjoint:

  Logical scalar. Required, with no default. Set to `TRUE` to affirm
  that the access and roving components sample disjoint sets of angler
  trips, the precondition under which their totals may be added.
  tidycreel cannot verify this from the data; see the "Disjointness
  precondition" section above.

- fpc:

  Logical. Apply finite-population correction? Default `TRUE`.

## Value

A [`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html)
object with an additional class attribute `"creel_hybrid_svydesign"`.
The design data contains a `component` column (`"access"` or
`"roving"`), a `weight` column derived from the sampling fractions, and
a `.hybrid_stratum` column holding the stratum-by-component interaction
the design is stratified on.

## Details

Combines count data from access-point and roving survey components into
a single
[`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html)
object. The two components are treated as **strata**, each carrying its
own sampling fraction and its own population size, so the design total
is the stratified sum of the component totals.

**Disjointness precondition.** Adding the two component totals is valid
if and only if the components sample **disjoint sets of angler trips** –
no angler trip may be observed by both. What produces that disjointness
is a property of the survey protocol (angler type, geography, access
mode, or a rule the designer imposes); tidycreel cannot infer it from
the counts, the dates, the strata, or the method label, so you must
affirm it with `trips_disjoint = TRUE`. The design cannot be constructed
otherwise. A boat angler intercepted on the water by a roving route and
again at the ramp on the same trip belongs to both frames, and the total
double counts that trip.

`component` names a survey **method**, not an angler population: an
access point may intercept bank anglers at a pier or boat anglers at a
ramp, and a roving route may be walked or run by boat. Either method can
cover either angler type, so disjointness is a fact about the protocol
and never about the labels.

**Estimation route.** The returned object is a `survey.design2`, not a
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
so
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
does not accept it. Estimate from it with
[`survey::svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
and the other `survey` functions directly, as in the examples below.

**Design structure.** Rows are stratified on the interaction of
`strata_col` and `component`, so each component carries its own
population size at its own sampling fraction, and clustered on
`date_col`, so several counts taken on one date form one primary
sampling unit rather than several independent ones. A component that
sampled only one date within a stratum leaves that stratum with a single
PSU: the design still constructs, but `survey` refuses to compute a
variance for it.

**PSU alignment requirement:** Both `access_data` and `roving_data` must
share the same date and stratum columns. Mismatched column names, or
dates present in one component but absent in the other, trigger an error
rather than a silent expansion; a warning is issued when stratum-date
combinations are asymmetric, because both components should sample the
same days. That is a requirement about *when* each component samples,
not *where* – two components covering different water is the condition
that makes their sum valid, not a source of bias.

## See also

Other "Survey Design":
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md),
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md),
[`as_creel_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_creel_svydesign.md),
[`compute_angler_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_angler_effort.md),
[`compute_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_effort.md),
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
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
access <- data.frame(
  date     = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  count    = c(12L, 15L, 30L, 28L)
)
roving <- data.frame(
  date     = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  count    = c(8L, 10L, 22L, 25L)
)
design <- as_hybrid_svydesign(
  access_data      = access,
  roving_data      = roving,
  access_fraction  = c(weekday = 0.5, weekend = 0.5),
  roving_fraction  = c(weekday = 0.4, weekend = 0.4),
  trips_disjoint   = TRUE
)

# estimate_effort() does not accept this object; use survey directly
survey::svytotal(~count, design)
#>       total     SE
#> count 332.5 8.6458
```
