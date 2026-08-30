# Construct a hybrid access + roving survey design

**\[experimental\]**

## Usage

``` r
as_hybrid_svydesign(
  access_data,
  roving_data,
  calendar = NULL,
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

  Data frame of count observations for the frame labelled `"access"` in
  the returned design. Must contain the columns named by `date_col`,
  `strata_col`, and `count_col`, with at most one row per date within a
  stratum. See "What `component` names" above: the label is inherited
  from the interview vocabulary and does not describe a count method.

- roving_data:

  Data frame of count observations for the frame labelled `"roving"`.
  Must contain the same columns as `access_data`.

- calendar:

  Data frame giving the population of days the totals expand to,
  carrying the columns named by `date_col` and `strata_col`. Required:
  the `NULL` default is rejected, and exists only so the error can say
  what is missing.

  The stratum population size \\N_h\\ is the number of **distinct**
  dates the stratum holds, counted the way
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
  counts it. One row per day is the natural form, but a duplicated row
  is tolerated rather than refused, precisely because the count is over
  distinct dates and a repeat changes nothing.

  Two things are required. Every sampled date must appear in `calendar`
  under the same stratum, or the population is smaller than the sample.
  And each date must belong to **exactly one** stratum – a day listed
  under two lengthens the season by a day in each, and the period total
  then expands to a calendar larger than the one that exists.

- date_col:

  Character scalar. Name of the date column (shared by both tables and
  by `calendar`). Default `"date"`. Used to cluster observations into
  PSUs. Must be of class `Date`, with no missing values in any of the
  three tables.

- strata_col:

  Character scalar. Name of the stratum column (shared by both tables
  and by `calendar`). Default `"day_type"`. Must have no missing values
  in any of the three tables: dates and strata are the join keys, and a
  missing key matches every other missing key rather than being refused.

- count_col:

  Character scalar. Name of the count column (shared by both tables).
  Default `"count"`.

- access_fraction:

  Named numeric vector. **Within-day** sampling fraction per stratum for
  the `"access"` component: the proportion of that component's frame the
  count enumerated on each sampled day, in (0, 1\]. Expands a sampled
  day to a whole day; it is not a fraction of the season and does not
  drive the finite-population correction. Names must match stratum
  values in `access_data`.

- roving_fraction:

  Named numeric vector. Within-day sampling fraction per stratum for the
  `"roving"` component, with the same meaning as `access_fraction`.
  Names must match stratum values in `roving_data`.

- trips_disjoint:

  Logical scalar. Required: the `NULL` default is rejected, and exists
  only so the error can say what is missing. Set to `TRUE` to affirm
  that the access and roving components sample disjoint sets of angler
  trips, the precondition under which their totals may be added.
  tidycreel cannot verify this from the data; see the "Disjointness
  precondition" section above.

- fpc:

  Logical scalar. Apply the day-level finite-population correction \\n_h
  / N_h\\? Default `TRUE`. Set to `FALSE` for the conservative
  with-replacement variance. `NA` and vectors of length other than one
  are refused.

## Value

A [`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html)
object with an additional class attribute `"creel_hybrid_svydesign"`.
The design data contains a `component` column (`"access"` or
`"roving"`), a `weight` column carrying both the within-day and the
day-to-season expansion, a `.hybrid_stratum` column holding the
stratum-by-component interaction the design is stratified on, and a
`.pop_days` column holding the stratum population \\N_h\\ the
finite-population correction is taken against.

## Details

Combines two count series covering disjoint parts of one fishery into a
single
[`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html)
object. The two components are treated as **strata**, each carrying its
own within-day sampling fraction, and both expanded to the same
population of days, so the design total is the stratified sum of the
component totals over the season.

**Estimand.** The design estimates a **period total** – the total over
every day in `calendar`, not over the days that happened to be sampled.
Two expansions get it there, and both live in the row weight: the
within-day fraction expands the part of the component's frame that the
count enumerated to the whole of it, and `N_h / n_h` expands the sampled
days to the days the stratum holds. Only the second is a stage-1
sampling fraction, so only the second drives the finite-population
correction.

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

**What `component` names, and what it does not.** The two components are
two **count frames**: two disjoint parts of the fishery, each enumerated
by its own count. In the protocol this design was built for they are
angler-type domains – boat anglers, and bank anglers dispersed along a
shoreline with no well-defined access site (Malvestuto 1996).

The labels `"access"` and `"roving"` are borrowed from the **interview**
vocabulary and describe these frames only obliquely, by which interview
mode happens to cover each. In the creel literature access and roving
describe how anglers are *interviewed*: access interviews intercept
completed trips as anglers leave, roving interviews intercept incomplete
trips while anglers are still fishing, and the two require different
catch-rate estimators (Pollock et al. 1994). A survey mixing the two is
a **hybrid interview** design. Counts are not described that way at all
– they are instantaneous, progressive, bus-route, camera or aerial, the
values
[`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md)
accepts for `survey_type`, none of which is "access" or "roving".
tidycreel carries the interview axis on
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)'s
`interview_type` argument, which is where it belongs. These argument
names are inherited and are under review; what the design requires of
the two components is disjointness, not a method label.

**Estimation route.** The returned object is a `survey.design2`, not a
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
so
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
does not accept it. Estimate from it with
[`survey::svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
and the other `survey` functions directly, as in the examples below.

**Design structure.** Rows are stratified on the interaction of
`strata_col` and `component`, so each count frame carries its own
sampled-day count at its own within-day fraction, and clustered on
`date_col`, so the date is the primary sampling unit. The population
size is taken from `calendar` and is shared by both components: one
stratum is one span of the season, whichever method observed it. A
component that sampled only one date within a stratum leaves that
stratum with a single PSU: the design still constructs, but `survey`
refuses to compute a variance for it.

**One count row per component-day.** A day-level expansion is only
defined when a sampled day is one row per component, so repeated counts
on one date are refused. Two counts on a date are two looks at that
date, not two sampled days; summed, they multiply the total by the
number of counts, and the day expansion then multiplies that again.
Average them to one row per date before constructing the design, or
model them on a path that keeps the count time.

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
calendar <- data.frame(
  date = seq(as.Date("2024-06-01"), as.Date("2024-06-30"), by = "day")
)
calendar$day_type <- ifelse(
  format(calendar$date, "%u") %in% c("6", "7"), "weekend", "weekday"
)

access <- data.frame(
  date     = as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  count    = c(12L, 15L, 30L, 28L)
)
roving <- data.frame(
  date     = as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  count    = c(8L, 10L, 22L, 25L)
)
design <- as_hybrid_svydesign(
  access_data      = access,
  roving_data      = roving,
  calendar         = calendar,
  access_fraction  = c(weekday = 0.5, weekend = 0.5),
  roving_fraction  = c(weekday = 0.4, weekend = 0.4),
  trips_disjoint   = TRUE
)

# estimate_effort() does not accept this object; use survey directly
survey::svytotal(~count, design)
#>        total     SE
#> count 2157.5 83.277
```
