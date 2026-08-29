# Changelog

## tidycreel (development version)

### Documentation

- Corrected five references that named papers which do not exist, or
  whose DOI resolved to an unrelated paper. Found by checking every DOI
  in the package against Crossref after the camera citation turned out
  to be wrong.

  - **Hartill et al. 2020**, cited by
    [`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
    `estimate_effort_camera()` and
    [`impute_camera_counts()`](https://chrischizinski.github.io/tidycreel/reference/impute_camera_counts.md),
    gave a title, an author list and a journal that belong to no paper,
    and a DOI (`10.1016/j.fishres.2020.105706`) that resolves to a study
    of age determination in sawsharks. The real reference is Hartill,
    Taylor, Keller and Weltersbach 2020, *Digital camera monitoring of
    recreational fishing effort: applications and challenges*, Fish and
    Fisheries 21:204-215, .
  - **De Lury 1958**, cited by
    [`estimate_angler_n()`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_n.md)
    and the mark-recapture vignette, used `10.1139/f58-002`, which is
    *The Abundance and Distribution of the Northern Sea Lion*. The
    correct DOI is `10.1139/f58-003`; it is one article later in the
    same issue.
  - **Askey et al. 2018**, cited by
    [`estimate_effort_aerial_glmm()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort_aerial_glmm.md),
    `example_aerial_glmm_counts` and the aerial GLMM vignette, had the
    right DOI but an invented title and the wrong pages, and the
    vignette named four authors none of whom wrote it. It is *Angler
    effort estimates from instantaneous aerial counts*, NAFM 38:194-209.
  - **Su and Clapp**, cited by
    [`simulate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/simulate_creel_data.md),
    is in Transactions of the American Fisheries Society 142:234-246
    under the title *Evaluation of sample design and estimation methods
    for Great Lakes angler surveys*, not in NAFM 33:895-909 under the
    title given.
  - **Feltz and Middaugh 2025**, cited by
    [`creel_n_camera()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_camera.md),
    was recorded as in press under a title the paper does not carry. It
    is published as *Improving efficiency of estimating angler effort
    using low-frequency time-lapse camera data*, NAFM 45:322-332.

  No estimator changed. What changed is that following a reference now
  reaches the work it claims to. Two related questions are tracked
  separately: the provenance of the
  [`creel_n_camera()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_camera.md)
  camera-day minimums, which were attributed to the Feltz and Middaugh
  title that does not exist
  ([\#234](https://github.com/chrischizinski/tidycreel/issues/234)), and
  the unverified Greene 1995 citation in
  [`simulate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/simulate_creel_data.md)
  ([\#233](https://github.com/chrischizinski/tidycreel/issues/233)).

### Breaking changes

- The within-day variance component is now keyed by the sampling unit
  rather than by the PSU alone
  ([\#227](https://github.com/chrischizinski/tidycreel/issues/227)).
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  keys `design$within_day_var` by the full unit key – the section, the
  site, or whatever `unit_cols` named – and two consumers rebuilt a
  narrower `c(psu_col, strata_cols)` key from the design instead of
  reading the one the table was built with.

  Nothing errored, because a join on too few columns does not fail: it
  returns more rows than it was given. On a three-section design each
  section’s 12 count rows matched three within-day rows apiece and
  became 36, so every section summed the lake-wide sum of squares, and
  the inflated row count also became `n_sampled` in the variance
  divisor. On a fixture where two of three sections are counted
  identically at both count times – no within-day variation whatsoever –
  all three reported the same `se_within` of 849.9, roughly 85% of each
  section’s total standard error, against between-day components of 110
  to

  228. 

  The same wrong key scaled the component to effort units. `ss_d` is
  multiplied by `T_d^2`, and
  [`match()`](https://rdrr.io/r/base/match.html) on the date returned
  the first row carrying it, so every section of a date was scaled by
  whichever section sorted first. A section open 6 hours sitting
  alongside sections open 12 was scaled by `12^2` instead of `6^2`:
  fourfold too large, silently. Sections with different open hours is an
  ordinary field situation.

  **This moves standard errors, confidence intervals and every
  downstream product** for any design whose unit key is wider than
  `(psu, strata)`: sectioned designs, site-structured designs, and any
  use of `unit_cols`. Point estimates are unchanged.
  [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  and
  [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
  all build products from `estimate_effort_total()` and inherit the
  correction.

  The same defect crashed rather than lying when the extra unit-key
  column came from `unit_cols` and the caller grouped by it: the narrow
  join renamed the duplicated column and the estimator died inside base
  R with `replacement has 0 rows`. That path now returns per-group
  within-day variance.

  Both consumers now read the key off the table itself, via the new
  internal `within_day_key_cols()`, so a key written one way and read
  another cannot recur.

  Found by the sectioned/hybrid seam audit; the `.lake_total` row’s
  standard error omitted this component too, corrected separately below
  ([\#228](https://github.com/chrischizinski/tidycreel/issues/228)).

- The `.lake_total` row of a sectioned effort estimate now reports the
  same variance components as the section rows above it
  ([\#228](https://github.com/chrischizinski/tidycreel/issues/228)).
  Section rows come from `estimate_effort_total()`, whose `se` is
  `sqrt(var_between + var_within)`. The lake row came from a pure
  [`survey::svyby()`](https://rdrr.io/pkg/survey/man/svyby.html) +
  [`svycontrast()`](https://rdrr.io/pkg/survey/man/svycontrast.html)
  aggregation, which carries the between-day component and its
  across-section covariance and nothing else – two definitions of
  variance in one column.

  The result was a lake-wide standard error smaller than that of every
  section it contained. On a fixture whose three sections have genuine
  within-day variation the sections reported 405.6, 698.8 and 186.8
  while the total reported 472.3, and that figure did not move at all
  when a section’s within-day spread was widened from 0.1 to 0.9.

  `se_between` and `se_within` were reported as `NA` on that row. The
  package’s convention is that `NA` means unknown, so a missing
  component read as a decomposition that could not be performed rather
  than one that was never added; both are now reported.

  The within-day component is second-stage sampling error inside one
  unit, so on a shared day it is independent across sections and the
  per-section components add; the between-day covariance the sections do
  share is already inside the
  [`svycontrast()`](https://rdrr.io/pkg/survey/man/svycontrast.html)
  figure. A present section carrying an unknown component propagates to
  an `NA` lake `se` rather than to the between-day figure alone.

  **This widens the lake-wide standard error and confidence interval**
  for any sectioned design with more than one count per day. Point
  estimates are unchanged, and a design with a single count per day is
  unaffected: its within-day component is a true zero. Applies to both
  `method = "correlated"` and `method = "independent"`.

  Found by the sectioned/hybrid seam audit. Depended on
  [\#227](https://github.com/chrischizinski/tidycreel/issues/227): the
  correct per-section components are its input.

## tidycreel 5.2.0 “River Carpsucker” (2026-08-28)

### Breaking changes

- [`summarize_by_day_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_day_type.md)
  and
  [`summarize_boat_composition()`](https://chrischizinski.github.io/tidycreel/reference/summarize_boat_composition.md)
  now resolve the day type column instead of assuming it is the first
  stratum
  ([\#221](https://github.com/chrischizinski/tidycreel/issues/221)).
  Both read `design$strata_cols[1]` and labelled whatever they found
  there `day_type`. But
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
  preserves the order the caller declared their strata in, so that index
  is a declaration order, not a definition: a design declaring
  `strata = c(site, day_type)` produced a table of site names under a
  `day_type` header, with no warning, and the real weekday / weekend
  breakdown absent entirely.

  Resolution order is now an explicit `day_type_col` argument, then a
  stratum actually named `day_type`, then the first stratum – which
  warns and names the column it chose when the design declares more than
  one. A single-stratum design resolves silently and is unaffected, so
  the documented `strata = day_type` workflow does not change.

  **This moves numbers for multi-stratum designs.** On a six-day
  two-site fixture whose boat composition is driven by site,
  [`summarize_boat_composition()`](https://chrischizinski.github.io/tidycreel/reference/summarize_boat_composition.md)
  reported 90% / 10% – the per-site means under a `day_type` header –
  where the per-day-type figures are 63.3% / 36.7%.
  [`summarize_by_day_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_day_type.md)
  moves labels rather than counts in the balanced case, which is what
  made it invisible: the 6 / 6 site split and the 6 / 6 weekday /
  weekend split are the same numbers.

  A stratum has no canonical name in this package – the caller names
  their own calendar columns – so this is a resolution with a documented
  fallback, not a lookup. Pass `day_type_col` when neither inference
  applies.

  This is the same defect class as
  [\#216](https://github.com/chrischizinski/tidycreel/issues/216), which
  was the identical `strata_cols[1]` shortcut on the camera calibration
  path. Found while fixing that issue and recorded rather than fixed
  inline.

- [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  and the three total estimators now refuse camera designs
  ([\#214](https://github.com/chrischizinski/tidycreel/issues/214)). A
  camera count is a daily ingress total – a count of arrivals – not an
  instantaneous count of anglers present. The dispatch chain in
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  branches on `bus_route`, `ice` and `aerial`, and camera had no branch,
  so it fell through to the instantaneous path and its counts were
  summed as though they were snapshots of how many anglers were present.
  The result was a plausible number with a plausible standard error: on
  the package’s own example data, 613 “angler visits” where the
  calibrated estimator returns 111 angler-hours.

  The camera vignette documented that route. It called
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  for both sub-modes, stated that camera designs “feed into the same
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  … pipeline – no changes”, never mentioned
  [`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
  and wrapped every call in
  [`suppressWarnings()`](https://rdrr.io/r/base/warning.html). So the
  guards added by
  [\#136](https://github.com/chrischizinski/tidycreel/issues/136),
  [\#137](https://github.com/chrischizinski/tidycreel/issues/137),
  [\#142](https://github.com/chrischizinski/tidycreel/issues/142) and
  [\#158](https://github.com/chrischizinski/tidycreel/issues/158) all
  sit in a function the documentation never reached: a design carrying
  imputed counts, a stratum with one paired interview day, a repeated
  count date, and an uncalibrated raw expansion each went unreported on
  the documented path.

  The refusal is raised at all four entry points, not only in
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
  because
  [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  and
  [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
  call `estimate_effort_total()` directly and never pass through it.
  Guarding only
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  would have left the totals building a product from the same arrival
  count – multiplying a rate per angler-hour by a count of arrivals and
  reporting it as fish.

  Refusing rather than dispatching is deliberate.
  [`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md)
  already implements the calibrated estimator and carries the guards;
  giving those guards a second caller to be right about is how the split
  arose. It also takes arguments the generic signature has nowhere to
  put – `interviews`, `n_anglers`, `h_open`, `calibration` – so a silent
  dispatch would have to guess them.

  To fix an affected analysis, call
  `est_effort_camera(design, interviews = , n_anglers = )` for the
  calibrated estimate, or
  `est_effort_camera(design, calibration = "none", h_open = )` to expand
  the raw counts under a declared assumption of one angler-hour per
  count per hour open. Catch rates are unaffected – they come from the
  interviews and never touch the camera – but there is no camera catch
  **total**, and the vignette now says so rather than demonstrating one.

- `estimate_angler_n(method = "schumacher", ci_method = "bootstrap")` is
  now refused rather than silently ignored
  ([\#209](https://github.com/chrischizinski/tidycreel/issues/209)). The
  Schumacher-Eschmeyer branch appended no `ci_lo_boot`/`ci_hi_boot`
  columns and attached no `boot_samples`, and raised nothing at all – so
  an explicitly requested inference method vanished, and
  `estimate_mr_harvest(ci_method = "bootstrap")` then aborted telling
  the caller to do what they had already done.

  The bootstrap is not implemented for this estimator on statistical
  grounds rather than for want of effort. The other three methods
  resample recaptures, `m_k ~ Binomial(n_k, m_k/n_k)`, which is coherent
  where the recaptures are the random component. Schumacher-Eschmeyer’s
  published variance is the residual mean square of a weighted
  regression through the origin (Seber 1982 eq. 4.17) – the scatter of
  the observed points about the fitted line, which is a different
  quantity from binomial noise in `m`. Resampling `m_k` alone would
  report a narrower, differently-defined uncertainty under the same
  column names.

  This breaks any call that combined the two. Such a call previously
  returned a correct point estimate and a correct regression interval,
  so the fix is to drop `ci_method = "bootstrap"`, which changes nothing
  about the numbers returned. `"logit"` and `"delta"` both give that
  interval. Use `method = "schnabel"` where a bootstrap interval is
  genuinely required.

- Repeated sampling units with no count time are now refused at
  estimation rather than warned about
  ([\#193](https://github.com/chrischizinski/tidycreel/issues/193)). Two
  counts on one day are two looks at that day, not two sampled days: the
  day’s effort is the mean of its counts, and the spread between them is
  the within-day variance component. That averaging has always been what
  `count_time_col` triggers – but rows repeating a unit *without* one
  bypassed it entirely and reached
  [`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html),
  which sums them. The reported effort came back multiplied by the
  number of counts per unit (measured at exactly k-fold for k = 1..4)
  and propagated undiminished into catch, harvest and release totals,
  while `se_within` was reported as `0`, indistinguishable from a
  within-day component that had been evaluated and found to be nil.

  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  warned about this, and its sibling check already *aborted* on rows
  identical in every column – so the harmless case (a double entry) was
  refused while the dangerous one (a genuine second count) was merely
  announced. The package cannot tell the two apart from the table: rows
  sharing a unit key are either repeat counts, which average, or
  undeclared distinct units, which sum, and only the surveyor knows
  which. It now asks rather than guesses.

  To fix an affected analysis, say what separates the rows –
  `count_time_col` for repeat counts, or `unit_cols` for distinct units
  – after which they are aggregated correctly and the within-day spread
  is retained.

  The refusal is raised by
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
  not
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
  so estimators that never sum these rows are unaffected:
  [`estimate_effort_aerial_glmm()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort_aerial_glmm.md)
  models counts against their flight time and keeps its several rows per
  day.
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  still warns, so the problem is reported next to the call that
  introduced it.

- [`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md)
  now estimates the calibration ratio within every stratum the design
  declares, not within the first stratum column only
  ([\#216](https://github.com/chrischizinski/tidycreel/issues/216)). A
  design created with `strata = c(day_type, site)` has strata `day_type`
  x `site`, but the camera ratio path read `design$strata_cols[1]` and
  keyed both the calibration and the count total on it. One pooled
  hours-per-count ratio was formed over the coarser partition and
  applied to counts belonging to a stratum that never contributed to it.

  Multi-column-stratified camera estimates change. On an eight-day
  two-site fixture where north fishes 40 h on 10 counts and south 10 h
  on 100 counts, with interviews on three north days and one south day,
  the estimate was `440` against a per-stratum truth of `200` – a 2.2x
  overestimate with no warning. The factor is set by how unevenly
  interview effort is allocated across the dropped columns, so it is
  unbounded in principle.

  Where every day is an interview day the ratio of sums telescopes and
  the point estimate is unchanged, but the standard error still moves:
  on the balanced version of that fixture the calibration component was
  `107.2` against a within-stratum truth of `0`, because pooling two
  dissimilar site regimes inflates the ratio residuals.

  Estimating within the declared strata puts fewer paired days in each
  stratum, so
  [`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md)
  may now report an `NA` standard error where it previously reported a
  number: a stratum with one paired interview/count day has no
  measurable ratio variance
  ([\#136](https://github.com/chrischizinski/tidycreel/issues/136)), and
  a sum missing an unknown term is a lower bound rather than a standard
  error. The warning names the stratum. Adding a second matched
  interview day in that stratum recovers the SE.

  `interviews` must now contain every column in `design$strata_cols`. A
  missing one is an error naming the column, where before the
  calibration proceeded on whichever columns the table happened to
  carry.

  Single-column-stratified camera designs – every fixture in the
  package’s own examples and tests – are bit-identical.

- [`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md)
  no longer treats a missing camera count as a zero-effort day on the
  ratio-calibration path
  ([\#215](https://github.com/chrischizinski/tidycreel/issues/215)).
  `na.rm = TRUE` was passed to `svytotal` through `svyby`, so an outage
  day’s count was dropped from the numerator while its population day
  stayed in the frame – making it contribute exactly zero hours to the
  total, with no error, no warning and no message.

  On the package’s own five-day fixture, setting one non-interview day’s
  count to `NA` moved the estimate from `18.97` to `15.00`, a 21%
  undercount. That `15.00` was bit-identical to the estimate obtained by
  deleting the row outright, which is the demonstration: the missing day
  contributed nothing while `n` still reported `5`.

  The raw-count branch of the same function passed no `na.rm` and
  already returned `NA` for the same input, so one function answered one
  input two opposite ways depending on which branch it took. Both now
  return `NA`, and both now warn – naming the affected dates, the
  `camera_status` values that explain them, and
  [`impute_camera_counts()`](https://chrischizinski.github.io/tidycreel/reference/impute_camera_counts.md)
  as the remedy. The count is not imputed or reweighted here: which day
  is missing is informative, so the treatment is the caller’s to choose.

  Because missing rows are no longer dropped,
  [`survey::SE()`](https://rdrr.io/pkg/survey/man/SE.html) can now
  report `NaN` for a stratum whose total is `NA`. That is normalised to
  `NA_real_`, since the calibration component already uses `NA` for the
  same condition
  ([\#136](https://github.com/chrischizinski/tidycreel/issues/136)) and
  one function should not report one unknown two ways.

  The [`suppressWarnings()`](https://rdrr.io/r/base/warning.html) around
  the stratified count total is removed, so `survey`’s own diagnostics
  reach the caller. It previously swallowed every warning `svyby`
  raised, which is half of why an outage produced a confident wrong
  number. It was also unnecessary: the benign “No weights or
  probabilities supplied” note it was presumably there for comes from
  [`svydesign()`](https://rdrr.io/pkg/survey/man/svydesign.html) when
  the design is built, not from
  [`svyby()`](https://rdrr.io/pkg/survey/man/svyby.html), and removing
  the wrapper surfaces no new warnings across the test suite.

  Camera surveys with complete counts are unaffected.

- The three total estimators now derive the reported `unit` from their
  two factors instead of writing the literal `"fish"`
  ([\#213](https://github.com/chrischizinski/tidycreel/issues/213)). A
  total is `"fish"` only when a per-angler-hour rate multiplies an
  effort in angler-hours; anything else reports `NA_character_`.

  There are two ways to fail to cancel, and both were labelled `"fish"`:

  - The effort unit is unknown. `design$effort_unit` is `NA` whenever
    [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
    received no `period_length_col`, because a bare count column may be
    an instantaneous head count or effort the caller already expanded,
    and nothing can tell the two apart. Unknown times known is unknown.
  - The denominators disagree. A rate per party-hour times an effort in
    angler-hours is not a count of fish. `warn_party_hours_product()`
    already reported that seam, but the result still carried a confident
    label through it.

  **This changes the reported unit for the common workflow.** The
  package’s own `example_counts` has no period-length column, so a
  design built from it now reports `unit = NA` on its totals where it
  previously reported `"fish"`. Point estimates, standard errors and
  confidence intervals are unchanged – only the label moves. Supply
  `period_length_col` to
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
  and `n_anglers` to
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
  to make the unit derivable.

  The same literal appeared three more times on the bus-route and ice
  total paths (`R/creel-estimates-bus-route.R`), which reach a different
  constructor. Those are keyed on `interview_effort_unit()` rather than
  `design$effort_unit`, since that is the effort those totals are built
  from. Bus-route designs whose interviews carry a party size are
  unaffected: their units already cancelled, and now they are shown to.

  This follows the rule
  [`estimate_effort_per_acre()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort_per_acre.md)
  already used – compose the unit from its inputs, and an unknown input
  yields an unknown result.

- [`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md)
  now reports the within-day variance component instead of a literal `0`
  ([\#217](https://github.com/chrischizinski/tidycreel/issues/217)).
  `add_counts(count_time_col = )` averages several counts on one day
  into a daily mean and stores the within-day components (`ss_d`, `k_d`)
  on the design; the camera estimators never read them. The standard and
  aerial estimators have always called
  `compute_within_day_var_contribution()` for exactly this, so the
  machinery existed and only the call was missing.

  On a five-day fixture with two counts per day, widening the within-day
  spread from zero to +/-30 counts – holding every daily mean, and
  therefore the point estimate, fixed – moved
  `design$within_day_var$ss_d` from `0` to `1800` per day and left the
  reported SE bit-identical at `3.266133`. It is now `5.991888`, with
  `se_within` of `5.023454` where it was `0`.

  The component is scaled by the stratum’s calibration ratio on the
  ratio path and by `h_open` on the raw path, because the stored
  quantity is a variance of the stratum count total and each path
  multiplies that total by a different factor. It is combined with the
  between-day component at the variance level rather than by adding two
  standard errors in quadrature, so a within-day variance of exactly
  zero leaves existing estimates bit-identical.

  `se_within` remains `0` for a design with one count per day. That is
  the one case where a zero is right: there is no within-day variation
  to measure, so the component is nil by construction rather than
  unknown. Designs built without `count_time_col` are therefore
  unaffected.

### Bug fixes

- [`estimate_exploitation_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_exploitation_rate.md)
  requires `se_C` when `C` is a bare number
  ([\#208](https://github.com/chrischizinski/tidycreel/issues/208)). It
  previously reached `if (se_C < 0)` holding a `NULL` and failed as
  `argument is of length zero` – loud, so no wrong number ever escaped,
  but uninformative on an entirely plausible call. The error now names
  the argument and points at the object route added in
  [\#206](https://github.com/chrischizinski/tidycreel/issues/206), which
  supplies the standard error itself. Defaulting the absent case to `0`
  was rejected: a zero standard error cannot be told apart from a
  variance that never propagated.

- The `reporting_rate` documentation said the correction adjusts the
  exploitation rate *downward*, contradicting the formula printed beside
  it ([\#207](https://github.com/chrischizinski/tidycreel/issues/207)).
  It adjusts **upward**: under-reporting means the recoveries actually
  observed understate how many tagged fish were removed, so dividing by
  `lambda < 1` restores them and at `lambda = 0.5` the estimate doubles.
  The code was correct throughout and is unchanged; only the wording was
  wrong. The direction is now also asserted in the test suite, so prose
  and arithmetic cannot drift apart again silently.

- [`estimate_exploitation_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_exploitation_rate.md)
  now accepts the
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  result itself for `C`, and checks it
  ([\#206](https://github.com/chrischizinski/tidycreel/issues/206)).
  `u = (C/T)(m/n)/lambda` is the fraction of the tagged cohort removed
  *over the whole season*, so `C` must be a period total while `T` is
  the full cohort – but
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  defaults to `target = "sampled_days"`, and `C` arrived as a bare
  number with its estimand stripped off. The shortest correct-looking
  pipeline was therefore the wrong one, and it failed silently: on a
  survey sampling 6 of 30 days the exploitation rate came back
  understated five-fold, inside `[0, 1]` so the range guard never fired,
  with a standard error that scaled down with it. The factor is the
  sampling fraction, so sparser surveys were wrong by more.

  Passing the object lets the target be read and a sampled-day total
  refused. It also makes the catch-for-harvest substitution detectable –
  released fish were never removed from the tagged cohort, and while
  both totals are counts of fish, the method is recorded on the object.
  A stratum total warns rather than aborting, since it is correct when
  `T` is that stratum’s cohort. Supplying `se_C` alongside an object is
  an error; the standard error is read from it.

  Bare numeric `C` keeps working unchanged and now reports that its
  target could not be verified. No estimate changes on any existing call
  – the object and numeric paths return identical results for the same
  total.

- [`read_schedule()`](https://chrischizinski.github.io/tidycreel/reference/read_schedule.md)
  restored only four column types, so `window_id` came back as character
  ([\#194](https://github.com/chrischizinski/tidycreel/issues/194)). The
  column is added by
  [`attach_count_times()`](https://chrischizinski.github.io/tidycreel/reference/attach_count_times.md)
  rather than by
  [`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md),
  and `coerce_schedule_columns()` matches an allow-list by name, so a
  [`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md)
  -\>
  [`read_schedule()`](https://chrischizinski.github.io/tidycreel/reference/read_schedule.md)
  round trip was not type-stable for it: a join against an integer
  `window_id`, an arithmetic comparison, or an
  [`identical()`](https://rdrr.io/r/base/identical.html) check silently
  saw a character vector. `window_id` is now restored to integer using
  the same guard `period_id` already used, so numeric ids become
  integers while character window labels are preserved. No estimate
  changes – schedules carry no quantities that reach an estimator.

- The `aerial-glmm` vignette compared the GLMM against the simple aerial
  estimator on one design holding four overflights per day, with no
  count time declared. The simple estimator sums, so the figure it
  published was four times the correct one (roughly 20,370 angler-hours
  against 5,092.5). The comparison now builds a second design that
  declares the flights via `count_time_col`, aggregating them to daily
  means; the GLMM continues to read the individual flights, which is
  what it fits the diurnal curve against.

- [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  now records `unit_cols` on the design. It was previously validated and
  discarded, leaving the design unable to distinguish a declared
  multi-column sampling unit from an undeclared repeat.

- [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  on an ice design renamed its `estimate` column to record the effort
  type, so `tidy()` returned `total_effort_hr_on_ice` (or
  `total_effort_hr_active`) and no `estimate` at all
  ([\#199](https://github.com/chrischizinski/tidycreel/issues/199)). Ice
  was the only design to do this – including the degenerate bus route,
  which is what an ice design is. Generic code reading the documented
  accessor, `tidy(x)$estimate`, a rollup across strata or species, or a
  report template, received `NULL`, and `sum(NULL)` is `0`: a season
  total came back as zero rather than as an error. The effort-type
  column is now an alias rather than a replacement, so both names are
  present and agree.

- Bus-route and ice standard errors were computed over interview rows
  rather than over the sampling unit
  ([\#198](https://github.com/chrischizinski/tidycreel/issues/198)).
  `build_interview_survey()` passed `ids = ~1`, declaring every
  interview its own PSU. Malvestuto (1996, section 20.2.3) defines this
  design as stratified two-stage probability sampling – fishing days are
  the primary sampling units, and secondary units are chosen within them
  – so several anglers contacted on one day are not independent draws
  from the frame.

  Reported precision was therefore a function of interview-recording
  convention. Splitting one interview into two half-effort rows at the
  same site left the Horvitz-Thompson estimate exactly unchanged and
  shrank the standard error by `1/sqrt(2)`: an agency recording one row
  per angler looked more precise than one recording one row per party
  for the same survey.

  The bus-route and ice estimators now use the ultimate-cluster
  estimator, taking the variance between PSU totals, so partitioning
  interview rows within a day leaves both the estimate and the standard
  error unchanged. Access-point and roving designs are untouched – there
  the interview genuinely is the sampling unit and `ids = ~1` is
  correct.

  **No point estimate changes.** Standard errors and confidence
  intervals on bus-route and ice designs do change, and not all in one
  direction: on the Calamus 2016 fixture `catch_total` falls by more
  than half while `effort_total` roughly doubles. Direction is a
  property of the data.

- The stratified sample-size functions reported a `total` that was not
  the sum of the per-stratum values, and
  [`power_creel()`](https://chrischizinski.github.io/tidycreel/reference/power_creel.md)
  rendered it as though it were
  ([\#195](https://github.com/chrischizinski/tidycreel/issues/195)).
  `total` is Cochran’s *n*, solved from the variance equation before
  allocation; each stratum is then rounded up from it independently, so
  the parts sum to as much as `k - 1` more for `k` strata. Printed
  beneath rows named after strata, in a column named `n_required`, that
  row read as their sum and under-booked the survey by the difference.

  `total` is unchanged — it is a real quantity and was documented as
  such.
  [`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
  [`optimal_n()`](https://chrischizinski.github.io/tidycreel/reference/optimal_n.md)
  and
  [`creel_n_camera()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_camera.md)
  now additionally return `allocated`, the sum of the per-stratum
  values, which is what the returned allocation commits to and the
  number to budget against.
  [`power_creel()`](https://chrischizinski.github.io/tidycreel/reference/power_creel.md)
  reports both rows. Code reading these results by name is unaffected;
  code depending on the length or exact names of the returned vector
  will see one more element.

  No estimate changes. This is a planning-stage reporting fix — the
  per-stratum values were correct throughout, and rounding each up is
  deliberate, keeping every stratum at or better than its share of
  `cv_target`.

## tidycreel 5.1.0 “Sturgeon Chub” (2026-08-23)

### Bug fixes

- Expanded effort targets (`target = "stratum_total"` and
  `"period_total"`) understated the total whenever a sampled day carried
  more than one count row
  ([\#183](https://github.com/chrischizinski/tidycreel/issues/183)). The
  two sides of the expansion factor `N_h / n_h` counted different
  things: the numerator counted calendar rows, the denominator counted
  rows of the attached counts table. A day holding k rows — two shift
  periods, three spatial sections — therefore divided every weight by k,
  and the season total came back low by exactly that factor, with no
  error and no warning.

  Both sides now count distinct sampling units, so the ratio is days
  over days however many rows a day carries. Rows sharing a day are
  summed into it before the expansion, which is what the
  Horvitz-Thompson estimator intends.

  Two configurations change value, and both were wrong before: a design
  whose counts carry a within-day dimension (the shipped
  `example_sections_counts` expanded to 282 where the hand calculation
  gives 846), and one whose calendar lists the frame at a finer
  resolution than the day, which expanded as though the season held more
  days than it does. A design with one count row per sampled day — the
  shape of every existing test — is unaffected.

  Estimates now report when a day carries several rows, so the reader
  can see that the quantity being expanded is a day rather than a row.

  Registered sectioned designs never reached this:
  [`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md)
  refuses expanded targets outright.

## tidycreel 5.0.0 “Pallid Sturgeon” (2026-08-22)

### New features

- [`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md)
  gains `count_time_col`, naming the time a count was taken
  ([\#129](https://github.com/chrischizinski/tidycreel/issues/129)). A
  count row is one observation at one moment, not a day’s total, and
  sources routinely record several on a sampled day; the time is the
  only thing that tells those rows apart. Map it whenever the source
  records one and pass the fetched `count_time` to
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)’s
  `count_time_col`. Optional, and carried through as character rather
  than parsed — it is a label that distinguishes observations, not a
  quantity, and a source may write a clock time in any format.

- [`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md)
  gains `length_bin_col` and `length_count_col`, the pair a source needs
  when it reports released fish as length groups rather than
  measurements
  ([\#127](https://github.com/chrischizinski/tidycreel/issues/127)). A
  binned row is frequency-weighted — “350-400, 5 fish” is five fish — so
  the count has to travel with the label. Both are optional and absent
  from the required-column set: a source that measures every fish maps
  neither and is unaffected. Map the label to `length_bin_col` rather
  than `length_mm_col`, whose name asserts a unit the label does not
  carry.

- [`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md)
  gains `value_maps`, declaring what a source’s codes mean for the three
  columns whose meaning is a fixed vocabulary rather than a number —
  `trip_status`, `catch_type`, `length_type`
  ([\#128](https://github.com/chrischizinski/tidycreel/issues/128)).
  Each entry maps the source’s own codes to canonical values,
  `c("1" = "complete", "2" = "incomplete")`. `tidycreel.connect` applies
  the map at the fetch, so a coded source reaches
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  speaking the vocabulary every downstream filter matches. Map targets
  are checked against the canonical vocabulary at construction, so a
  typo’d target is caught where the map is written rather than several
  stages later against the data.

- New
  [`creel_vocabulary()`](https://chrischizinski.github.io/tidycreel/reference/creel_vocabulary.md)
  returns those canonical vocabularies. Exported because
  `tidycreel.connect` translates source codes and must check its targets
  against the same list this package filters on — a second copy would be
  free to drift from this one.

- [`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md)
  gains `strata_cols`, naming the stratum columns to carry through from
  the source
  ([\#171](https://github.com/chrischizinski/tidycreel/issues/171)). It
  is the one mapping here with no canonical tidycreel name on the other
  side:
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  matches `design$strata_cols` — the caller’s own calendar column names
  — against the names of the counts frame, so the mapping is two-sided.
  Names are the column the design refers to, values the source column
  holding it: `strata_cols = c(day_type = "DayType")`. An unnamed entry,
  `c("day_type")`, means the source already uses the design’s name.

### Bug fixes

- The advanced-use warning issued by
  [`as_creel_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_creel_svydesign.md)
  (formerly
  [`as_survey_design()`](https://chrischizinski.github.io/tidycreel/reference/as_survey_design.md))
  no longer prints unevaluated cli markup. It was raised with
  [`rlang::warn()`](https://rlang.r-lib.org/reference/abort.html), which
  does not interpolate cli fields, so the line reached users as
  `Most users should use {.fn estimate_effort} instead.` It now uses
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html),
  as every other warning in the file already did. The test covering the
  message could not have caught this: its assertions sat behind an
  `if (!is.null(result))` that was never entered once the
  once-per-session warning had been consumed by an earlier test, and it
  closed with `expect_true(TRUE)`. It now resets that state and asserts
  unconditionally.

- The Calamus 2016 validation script now runs
  ([\#130](https://github.com/chrischizinski/tidycreel/issues/130)).
  `inst/validation/calamus-2016-validation.R` aborted at
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  — the fixture carries three numeric count columns and the call named
  none of them — so the package’s only end-to-end validation of its own
  reference outputs had not executed at all. It also called
  [`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md),
  which returns HPUE (0.4226 here), where `reference-outputs.csv`
  records the Horvitz–Thompson total that
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  produces; a comment argued explicitly for the wrong one. Both fixed,
  and the script now reports 3/3 estimands within tolerance.

- `tests/testthat/test-validation-guard.R` can now fail when that script
  is broken
  ([\#130](https://github.com/chrischizinski/tidycreel/issues/130)). It
  previously accepted any error that was not the working-directory guard
  — its comment said “any other error (e.g. from load_all or estimators)
  is acceptable” — so it stayed green for the entire period the script
  was aborting. It now asserts the script runs to completion and that no
  estimand reports FAIL.

- [`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md)
  now accepts a `length` column whose name is not literally `length`
  ([\#127](https://github.com/chrischizinski/tidycreel/issues/127)).
  `length` is one of this function’s own arguments, so an unqualified
  [`length()`](https://rdrr.io/r/base/length.html) call in its body made
  R force that argument while searching for a function of that name, and
  any other column aborted with `object 'length_mm' not found` before a
  row was read. Every example and test passed `length = length`, which
  resolves to [`base::length`](https://rdrr.io/r/base/length.html) and
  hid it — while the two names `tidycreel.connect`’s fetch layer
  actually produces, `length_mm` and `length_bin`, both failed. The
  documented connect-to-design handoff for length data could not be run
  as written.

- Bus-route and ice totals now refuse a design with no complete trips by
  name
  ([\#128](https://github.com/chrischizinski/tidycreel/issues/128)).
  [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
  [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
  and the bus-route rate estimators filter to completed trips, and a
  Horvitz–Thompson assembly handed a zero-row frame does not notice: it
  failed several calls later inside
  [`rowSums()`](https://rdrr.io/pkg/Matrix/man/colSums-methods.html)
  with `all arguments must have the same length`, which names nothing
  the caller can act on and reads like a package bug. The standard
  designs already aborted by name here; these now say the same thing,
  name the quantity that could not be produced, and point at
  `use_trips = "incomplete"` or `"diagnostic"` — never `"all"`, which a
  bus-route design does not accept, because an uncompleted trip supports
  a rate but never a total. No estimate changes: every affected call
  already failed, just unreadably.

- [`print()`](https://rdrr.io/r/base/print.html) on a `creel_schema` now
  groups `n_counted_col` under **interviews** rather than counts
  ([\#170](https://github.com/chrischizinski/tidycreel/issues/170)).
  Both enumeration columns live on the interviews table —
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  resolves them against the interviews frame and
  [`get_enumeration_counts()`](https://chrischizinski.github.io/tidycreel/reference/get_enumeration_counts.md)
  reads them back off it — so a bus-route user reading the printed
  schema was told the enumeration count belonged to a table it is not
  in, while its own denominator was listed under another. Display only;
  no estimate was affected.

### Breaking changes

- [`summarize_by_zip()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_zip.md)
  and
  [`summarize_by_county()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_county.md)
  gain a `zip_col` argument, defaulting to `"zip_code"`. Both previously
  required a hardcoded raw field name from one agency’s database, which
  no general-purpose package should assume. Rename the column, or pass
  `zip_col`, to keep existing code working.

- [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  now **warns** rather than informs when `n_anglers` is omitted
  ([\#126](https://github.com/chrischizinski/tidycreel/issues/126)). The
  assumption it states is a claim about the data, not a note about a
  default: with any party larger than one, `.angler_effort` is
  party-hours while count-derived effort is angler-hours, so every rate
  denominator is wrong by the mean party size with no error raised. Pass
  `n_anglers = 1` to declare that the interviews really are one angler
  each; that silences the warning and, unlike omission, marks the effort
  as genuine angler-hours.

- [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  refuses a counts table containing rows identical in every column
  ([\#152](https://github.com/chrischizinski/tidycreel/issues/152)).
  [`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html) sums
  the rows of `design$counts`, so a repeated row was counted twice: a
  six-day table rose from 65 to 77 angler-days and its standard error
  from 5.26 to 15.61, with only a warning. Previously CNT-06 warned; it
  now aborts, naming the affected rows.

  The check is on the whole row, not the sampling-unit key, and is
  deliberately independent of `unit_cols`. Two rows sharing a key are
  ordinary structure — two sections, two effort types, two counts within
  a day — and differ somewhere. Two rows differing in **no** column
  carry nothing that could distinguish one unit from another, so the
  table is malformed under every key, including a key that is wrong (as
  it has twice been:
  [\#155](https://github.com/chrischizinski/tidycreel/issues/155),
  [\#162](https://github.com/chrischizinski/tidycreel/issues/162)).

  Tables where the repeat is a genuine second observation are
  unaffected, since the counts themselves differ; CNT-06 still warns
  about those.

- [`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md)
  now removes the columns it consumed (`bank`, `boat_anglers`,
  `boat_count`) from its result. They are superseded by the derived
  count and by `expansion_basis`, and leaving them in produced a table
  that varied between sub-counts of one sampling unit —
  indistinguishable, to
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
  from a structural dimension it had not been told about
  ([\#162](https://github.com/chrischizinski/tidycreel/issues/162)). The
  destination column is never dropped, even when it is also an input.
  Code reading a raw component off the result must read it from the
  input table instead.

- [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  aborts, rather than silently taking a first value, when within-day
  aggregation would collapse rows that differ in a column the
  sampling-unit key does not contain
  ([\#162](https://github.com/chrischizinski/tidycreel/issues/162)). The
  error names the column and supplies a ready-made `unit_cols` call.

### Deprecated

- [`as_survey_design()`](https://chrischizinski.github.io/tidycreel/reference/as_survey_design.md)
  is renamed to
  [`as_creel_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_creel_svydesign.md)
  ([\#167](https://github.com/chrischizinski/tidycreel/issues/167)). The
  old name is srvyr’s principal entry point, and srvyr is the natural
  companion for tidy survey work, so attaching both packages masked one
  with the other depending on load order. A user who loaded srvyr second
  and called `as_survey_design(design)` got srvyr’s generic failing to
  dispatch on `creel_design`, with an error that said nothing about
  masking. The new name also matches the sibling
  [`as_hybrid_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_hybrid_svydesign.md)
  and states what the function does: it extracts the internal `survey`
  object rather than constructing a design.
  [`as_survey_design()`](https://chrischizinski.github.io/tidycreel/reference/as_survey_design.md)
  keeps working and now warns; it delegates to
  [`as_creel_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_creel_svydesign.md),
  so the two cannot diverge.

### Statistical correctness

- The `calamus-2016` reference outputs record a re-baselined
  `catch_total` standard error, 55.7239 becoming 52.9963
  ([\#178](https://github.com/chrischizinski/tidycreel/issues/178)). The
  point estimate is unchanged and always was. The file was written once
  at v1.7.0 and never regenerated, so it had gone on recording a number
  the package stopped producing at v3.0.0, when the dimensional seam
  audit routed all three bus-route totals through
  `br_complete_trips_only()` — a filter the harvest total had always
  applied and the catch total never had.

  Nothing about the estimator changed here; only the record of what it
  produces. The fixture’s two incomplete-trip rows both carry
  `catch_count = 0`, so dropping them cannot move a Horvitz-Thompson sum
  — it moves only the interview count behind the variance, 24 to 22.
  That is worth stating plainly, because the divergence was first
  misread as evidence *against* the trip filter on the grounds that the
  point estimate was invariant to it: with zero-catch rows, invariance
  is guaranteed by construction and says nothing about the SE.

  The row was regenerated only after the responsible release was
  identified from the source history and the pre-v3.0.0 value reproduced
  exactly by disabling the filter on current code.
  `inst/extdata/calamus-2016/README.md` is new and records that
  reasoning, together with the standing rule that these outputs are not
  re-baselined to match current behaviour without it. `effort_total` and
  `harvest_total` are untouched and have reproduced bit-for-bit since
  v1.7.0.

- `inst/validation/calamus-2016-validation.R` now compares standard
  errors as well as point estimates — six comparisons where there were
  three
  ([\#178](https://github.com/chrischizinski/tidycreel/issues/178)).
  Comparing estimates alone is the reason the stale SE above survived
  three major versions: the script is the only thing that exercises the
  reference outputs, and the one quantity that had moved was the one it
  never looked at.

  Its guard test gains two related fixes. It now asserts *which*
  comparisons ran, not merely that none failed — a script that quietly
  stopped checking standard errors would otherwise still report no
  failure, which is the original blind spot one level up. And it no
  longer wraps the script in
  [`suppressMessages()`](https://rdrr.io/r/base/message.html): the
  script reports through
  [`message()`](https://rdrr.io/r/base/message.html), so suppressing
  them left the captured output empty and the existing “no FAIL in
  output” check passing on a zero-length vector, testing nothing.

- The sampling unit is now declarable:
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  gains `unit_cols`
  ([\#162](https://github.com/chrischizinski/tidycreel/issues/162)).
  Until now the unit was inferred from the design alone — the PSU column
  plus strata, section, and site — so a counts table carrying a
  dimension the design does not model was read as repeated units. That
  is exactly what
  [`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md)
  produces: it emits one row per `(date, strata, effort_type)`, and bank
  and boat counts on the same day are two units, not one day counted
  twice.

  With `count_time_col` supplied, the consequence was a wrong number and
  no warning. All rows for a day collapsed into one, so the effort types
  were **averaged rather than summed** and the surviving row kept the
  first row’s label: a four-day example whose true total is 121
  angler-days reported 60.5, and the rows that vanished were labelled
  `bank`. With `k` effort types the estimate was off by a factor of `k`.

  Inference is kept as the default, so existing correct code is
  untouched, but it can no longer fail quietly: where the unit is
  ambiguous the call now aborts. This is the third appearance of one
  root cause — the key omitted `section`
  ([\#155](https://github.com/chrischizinski/tidycreel/issues/155)),
  then `effort_type`
  ([\#162](https://github.com/chrischizinski/tidycreel/issues/162)) —
  which is why the fix stops enumerating dimensions and lets the caller
  state the unit instead.

- [`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md)
  gains `site_col` and `circuit_col`
  ([\#126](https://github.com/chrischizinski/tidycreel/issues/126)). A
  bus-route interview has to name the site and circuit it was taken at,
  or
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  cannot join the site inclusion probability — but the schema had no way
  to say which source columns hold them, so the connect layer dropped
  them and the join aborted with an error that pointed nowhere near the
  cause. Both default to `NULL`; nothing else changes.

## tidycreel 4.0.0 “Paddlefish” (2026-08-18)

The second major bump. It closes one defect class opened by the
2026-08-14 seam audits: a parameter estimated from data, then consumed
as though it were known. Six issues
([\#135](https://github.com/chrischizinski/tidycreel/issues/135),
[\#137](https://github.com/chrischizinski/tidycreel/issues/137),
[\#138](https://github.com/chrischizinski/tidycreel/issues/138),
[\#139](https://github.com/chrischizinski/tidycreel/issues/139),
[\#157](https://github.com/chrischizinski/tidycreel/issues/157),
[\#158](https://github.com/chrischizinski/tidycreel/issues/158)) turned
out to be one bug wearing six hats — a visibility correction, an
angler-to-people ratio, a camera calibration, a harvest rate, a
reporting rate, and an imputed count were each divided or multiplied
into an estimate while contributing nothing to its standard error. Every
one of them produced a plausible number and no warning.

Read the **Breaking changes** section before upgrading. Aerial and
camera designs must now state their corrections or they abort, and
several standard errors move upward — including some that were
previously smaller than the single term they had omitted.

### Breaking changes

- **Aerial designs must supply `visibility_correction` and
  `angler_ratio`.** Both arguments previously defaulted silently to 1.0.
  Not supplying a correction is not the same claim as declaring that
  none applies, and only one of those should be silent. To declare that
  none applies, pass the string `"none"`: the point estimate uses 1 and
  the corresponding standard-error component is reported as `NA`, never
  0, because a zero is indistinguishable from a term that never
  propagated. To assert instead that a multiplier is known exactly,
  supply its standard error as 0 deliberately
  (`visibility_correction = 1, visibility_se = 0`).

- **[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md)
  without `interviews` must pass `calibration = "none"`, and then
  reports `NA` standard error.** Expanding a raw camera count by
  `h_open` alone assumes each counted object contributes exactly one
  angler-hour per hour open — a calibration of 1 that was never
  measured. Reaching that path now requires saying so. The `calibration`
  component becomes present-and-unknown rather than absent, because the
  correction genuinely applies and simply was not measured. `COMP-05`
  asserted the opposite and is inverted deliberately, with the reason
  recorded in the test.

- **Breaking (numeric): `estimate_effort_aerial()` standard errors move
  upward wherever a boat count was expanded by
  [`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md).**
  The function never called `compute_expansion_var_contribution()`, so a
  count carrying a `party_size_se` reached
  [`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html) with
  its multiplier’s uncertainty discarded — the carrier columns survived
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  and were simply not read. Measured on a fixture, the dropped component
  was 560 against a reported standard error of 236: the missing term was
  larger than the entire standard error being reported.

- **Breaking (numeric):
  [`impute_camera_counts()`](https://chrischizinski.github.io/tidycreel/reference/impute_camera_counts.md)
  returns a different object when `m > 1`.** It now yields a
  `camera_imputations` object of `m` completed data sets rather than
  one. `m = 1` is unchanged and still returns a plain data frame.

- **Breaking (numeric):
  [`estimate_mr_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_mr_harvest.md)
  confidence intervals are no longer built by scaling the endpoints of
  the abundance interval** when the harvest rate is estimated. That
  identity is exact only while the rate is a known positive constant;
  once it is estimated the endpoints are themselves random. An estimated
  rate now falls back to a symmetric interval built from the full
  product standard error.

### Statistical correctness

- `visibility_correction` gains `visibility_se`
  ([\#135](https://github.com/chrischizinski/tidycreel/issues/135)). The
  correction is estimated from paired air-ground counts and the standard
  field method reports its standard error as routine output (Smucker et
  al. 2010, eq. 6–7); tidycreel had no argument that could accept that
  number. The delta term `E * se_v / v` is added **once at the total,
  never per stratum**: `v` is a shared multiplier, perfectly correlated
  across flights, and summing it per stratum in quadrature would treat
  it as independent and understate it. On the GLMM bootstrap path `v` is
  resampled once per replicate, outside the model refit, for the same
  reason — drawing it per flight would shrink its contribution like
  `1/sqrt(n_flights)`.

- Aerial designs gain `angler_ratio` and `angler_ratio_se`
  ([\#158](https://github.com/chrischizinski/tidycreel/issues/158)).
  Smucker et al. (2010) apply **two** corrections to a raw observer
  count — a visibility correction and an angler-to-people ratio of 0.404
  — and tidycreel implemented only the first, overstating shore effort
  by roughly 2.5×. The two push in opposite directions (0.404 down, 2.69
  up), so applying only the visibility correction is not conservative:
  it is biased in the direction of the correction that was kept.

- [`estimate_mr_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_mr_harvest.md)
  gains `harvest_rate_se`
  ([\#138](https://github.com/chrischizinski/tidycreel/issues/138)). It
  computed `se_H <- harvest_rate * se_N`, which is
  `product_total_variance()` with `r_se = 0` — the package already
  implemented Goodman (1960) and made it the default in all three
  `creel-estimates-total-*.R` files; this function simply never called
  it. Rasmussen et al. (1998) draw the distinction in the package’s own
  cited literature: the subtractive form is for terms “estimated from a
  sample”, and differs from the population formula “used when the terms
  in the product are known, not estimated”. The bootstrap path now draws
  the rate once per replicate rather than holding it fixed.

- [`estimate_exploitation_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_exploitation_rate.md)
  gains `reporting_rate_se` and the third delta term
  `(u/lambda)^2 var(lambda)`
  ([\#139](https://github.com/chrischizinski/tidycreel/issues/139)),
  since `d(u)/d(lambda) = -u/lambda`. It enters **once at the total**:
  lambda is a single estimate dividing every stratum, so adding it per
  stratum and summing in quadrature would treat a shared divisor as
  independent. On the stratified path it is applied to the aggregate,
  deliberately not inside `var_u_h`.

  Its `reporting_rate = 1.0` default is **kept**, unlike the aerial
  corrections. It is a visible, documented default on an exported
  argument the caller opts into adjusting, not a value substituted
  invisibly inside an estimator. That asymmetry is recorded in the
  `@param` text rather than left to be rediscovered.

- Multiple imputation for camera outages
  ([\#137](https://github.com/chrischizinski/tidycreel/issues/137)).
  [`impute_camera_counts()`](https://chrischizinski.github.io/tidycreel/reference/impute_camera_counts.md)
  filled every outage row with the model’s fitted mean and returned one
  completed data set. Inside
  [`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
  those predictions are indistinguishable from observations, so the
  imputation model’s own error was dropped; and fitted means are
  smoother than real counts, so the between-day component shrank as
  well. The reported standard error was biased downward twice over. Each
  of the `m` completed data sets is now drawn from the model’s
  **predictive** distribution — coefficients drawn from their sampling
  distribution, then counts drawn from the fitted family. Both draws are
  needed: drawing only the count treats the coefficients as known, and
  drawing only the coefficients still yields a smooth mean where a real
  count has sampling noise.

### New features

- [`est_effort_camera_mi()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera_mi.md)
  estimates once per completed data set and pools by Afrifa-Yamoah et
  al. (2020) eq. (5): the within-imputation mean variance plus the
  `(M+1)/(M(M-1))` between-imputation term — the quantity a single
  completed data set structurally cannot have. Their factor is Rubin’s
  `(1 + 1/M)` inflation written over the raw sum of squares; `MI-04`
  pins that the two forms agree. `M = 5` follows the paper’s stated
  bias-variance balance. Components are reported as `within_imputation`
  / `between_imputation` so a reader can see how much of the uncertainty
  came from imputing.

- `validate_shared_multiplier()` gives the four shared-multiplier
  arguments one validation shape — required, `"none"` opt-out yielding
  `NA` rather than 0, all-or-none standard error. The rule is documented
  once there rather than restated at each call site.

### Documentation

- `visibility_correction` is named a **detection probability** and
  documented as the reciprocal of the published ground-truthing ratio
  ([\#157](https://github.com/chrischizinski/tidycreel/issues/157)).
  Field studies report `r = ground/aerial`, which exceeds 1 exactly when
  the correction matters (`r = 2.69` for shore anglers); tidycreel wants
  `v = 1/r = 0.372`. The `> 1` abort branch now names the conversion,
  since that is where a reader of the source paper lands.

- The aerial GLMM’s variance composition is documented as tidycreel’s
  own reasoning and is **not** attributed to Askey et al. (2018). That
  paper, this estimator’s cited source, was read in full while
  specifying this work and contains no visibility correction and no
  bootstrap — it does not speak to `v` at all, and propagates
  uncertainty by cross-validation rather than analytically. Its
  `nAGQ = 0` is likewise not carried over: the paper warns the option is
  less accurate and used it only because their data set exceeded 250,000
  observations.

## tidycreel 3.4.0 “Flathead Chub” (2026-08-17)

### Statistical correctness

- **Breaking (numeric):** the per-section totals from
  [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
  and
  [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
  no longer aggregate to the `.lake_total` row as though the sections
  were independent when one party-size estimate spans them
  ([\#145](https://github.com/chrischizinski/tidycreel/issues/145)).
  This is
  [\#144](https://github.com/chrischizinski/tidycreel/issues/144) on a
  second partition: the sections path builds its frame by hand instead
  of routing through the shared stratum helper, so the strata correction
  never reached it. A multiplier estimated once and applied across
  sections is a single random quantity common to all of them, so its
  contributions add before squaring. **The lake-row standard error moves
  upward** on affected designs; the per-section rows and every point
  estimate are unchanged.

  The structure is now classified against the *section* partition rather
  than the strata, because sections may cross-cut strata — a group can
  be nested within strata while spanning sections. One consequence is
  visible: a party-size estimate keyed by a stratum (for example one per
  `day_type`) is nested within strata but straddles sections unevenly,
  so the lake row now reports `se = NA` with a warning rather than a
  number that quietly assumed one geometry or the other. As elsewhere in
  the package, an unknown standard error is `NA`, never a zero and never
  a plausible substitute.

- A sections total now reports the party-size component its standard
  error carries, per row, instead of `NULL`
  ([\#145](https://github.com/chrischizinski/tidycreel/issues/145),
  completing
  [\#134](https://github.com/chrischizinski/tidycreel/issues/134)).
  `NULL` means the component was never propagated, and the sections
  constructor was saying that while its `se` demonstrably contained the
  term.

- **Breaking (numeric):**
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  now keys the sampling unit on the PSU crossed with the section and
  site, not on the PSU column alone
  ([\#155](https://github.com/chrischizinski/tidycreel/issues/155)).
  Four places needed to know what “the same unit” means — duplicate
  detection, within-day aggregation, the supplied within-day-variance
  key, and the party-size constancy check — and they had drifted into
  three different answers, none of which carried the section. They now
  share one `psu_key_cols()` definition. Period enters through the
  strata, which is where this package models it
  (`strata = c(day_type, day_period)`).

  **A day sampled in two sections was treated as one unit**, with three
  consequences:

  - **Counts were averaged across sections.** Two days × two sections ×
    two count times collapsed to two rows instead of four: a section
    reporting ~100 anglers and one reporting ~10 became a single row of
    `58`, still labelled with the first section’s name, with the other
    section’s rows absorbed into it. **This moved the point estimate** —
    the daily total came out 58 where the truth was 116 — and nothing
    downstream could detect it, because the result looked like a clean
    frame with one section missing.
  - **The within-day variance measured the wrong quantity.** `ss_d` was
    dominated by the difference *between* sections rather than the
    spread *within* a day: 8888 where the true within-section sums of
    squares were 50 and 2.
  - **A section-specific party size was refused**, reporting
    `expansion_se varies within a single PSU` and blaming two
    [`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md)
    calls, on a single coherent call. Under sections the unit is the day
    within a section, and each such unit carries exactly one estimate.

  The CNT-06 warning also stops firing on ordinary multi-section days
  and now names the key it judged the repeat on. A genuine repeat — the
  same unit counted twice with no count time — still warns, and two
  different party-size estimates inside one unit still abort.

  Affects designs with sections or sites. Bus-route designs are
  untouched: they hold counts in `design$bus_route$data`, which never
  reaches these checks.

- The `"partial"` party-size geometry now returns a standard error
  instead of `NA`
  ([\#150](https://github.com/chrischizinski/tidycreel/issues/150)).
  When one party-size estimate spans some parts of the partition being
  summed over and another sits inside one, the combination needs the
  group-by-part decomposition — and
  `compute_expansion_var_contribution()` was squaring and summing the
  group index away before returning, so `add_expansion_covariance()` had
  nothing to combine and correctly refused. The decomposition is now
  carried alongside the scalar component, and the exact combination is
  `Var = Σ_g (Σ_p rate_p × basis_{g,p} × se_g)²`: contributions from one
  estimate add before squaring because its error is common to every part
  it covers, while contributions from different groups come from
  disjoint interview subsets and add as variances.

  **The `"nested"` and `"shared"` numbers do not move.** Both are
  special cases of that formula, but each keeps its own arithmetic
  rather than being re-derived through it, so their results are
  unchanged bit-for-bit. Only the case that previously returned `NA`
  produces a new number, and it lands strictly between the two shortcuts
  the old code refused to choose between — quadrature understates it,
  the linear sum overstates it.

  This matters most on the sections path introduced in
  [\#145](https://github.com/chrischizinski/tidycreel/issues/145), where
  `"partial"` is ordinary rather than exotic: sections cross-cut strata,
  so a party-size estimate keyed by `day_type` straddles sections
  unevenly and forced the `.lake_total` row to `NA`. The refusal is
  retained for the case where no decomposition was carried, since a
  combination that cannot be computed still must not be guessed.

- [`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md)
  gains `mean_party_size_se`, and emits the `expansion_*` carrier
  columns when it is supplied
  ([\#143](https://github.com/chrischizinski/tidycreel/issues/143)).
  This function performs the same boat-to-angler expansion as
  [`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md),
  but wrote no carriers and had no argument through which a party-size
  standard error could be given — so on this path the component was not
  merely omitted by default, it was unreachable, and no user action
  could recover it. Because this is the pipeline the documentation calls
  preferred, the two documented routes to one expansion were not
  statistically equivalent and nothing said so: the prep path reported
  the pre-3.2.0 understated standard error with `se_expansion = NULL` as
  the only signal.

  The emitted basis is `boat_count * correction_factor`, not the bare
  boat count, because this function applies the correction to the
  product — a bare basis would be the derivative of a quantity it never
  produces and would trip the
  [\#131](https://github.com/chrischizinski/tidycreel/issues/131) desync
  guard. `expansion_of` is `"daily_effort"` for the same reason.
  Omitting the argument still leaves the component absent rather than
  zero.

- The `creel_error_expansion_basis_desync` message now states that
  correct hand-rescaling reaches it too
  ([\#148](https://github.com/chrischizinski/tidycreel/issues/148)).
  `expansion_of` records a column name rather than a scale factor, so a
  basis correctly rescaled alongside its count is indistinguishable from
  one left behind, and both are refused. Refusing both remains the
  conservative and correct choice, but the message described only the
  mistake — and every instructional example in the companion book met it
  with arithmetic that was right. The wording changed; the check did
  not.

  Relatedly, the four carrier columns are now documented as
  package-written and not user inputs. Overwriting `expansion_of` to
  name a transformed column silences the guard whether or not the basis
  was actually rescaled, which re-enables the defect the guard exists to
  catch. Use `period_length_col`, which scales count and basis together
  and can be verified, rather than asserting the rescale.

- **Breaking (error):**
  [`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md)’s
  ratio-calibration path now refuses a counts table that holds more than
  one row for the same day, rather than silently double-counting it
  ([\#142](https://github.com/chrischizinski/tidycreel/issues/142)). The
  calibration pairs interview days to count rows by date membership and
  reads the day’s effort total once per matching row, so a repeated date
  entered `rho = sum(E_d) / sum(C_d)` twice on both sides, and the
  survey total of raw counts counted it again. **This moved the point
  estimate, not only the standard error** — 16 to 19.5 on the package’s
  own five-day test fixture, a 22% shift produced by a duplicated row
  carrying no new information.
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  only warns about repeated PSU rows (CNT-06), so such a table reached
  the estimator intact.

  The table is refused rather than averaged because two counts on one
  day are either sub-period snapshots or a data error, and nothing on
  this path can tell which. Callers with genuine sub-daily counts should
  pass `count_time_col` to
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
  which already collapses them to one row per day; the error names the
  offending dates and says so. The raw-count path (`h_open`, no
  interviews) is deliberately unchanged: expanding a duplicated PSU row
  through
  [`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html) has
  the same shape in every design, and that is a wider question than this
  fix.

## tidycreel 3.3.0 “Shovelnose Sturgeon” (2026-08-15)

### Statistical correctness

Three cases where a quantity that was unknown, malformed, or modelled
reached an estimator as though it were observed. All three were found by
the statistical seam audits of 2026-08-14; none produced an error, a
warning, or an implausible number.

- **Breaking (numeric):**
  [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
  and
  [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
  no longer combine a shared party-size estimate across strata as though
  the strata were independent
  ([\#144](https://github.com/chrischizinski/tidycreel/issues/144)). The
  stratified total variance adds per-stratum variances because strata
  are *sampled* independently (Pollock, Jones & Brown eq. 3.12–3.13); a
  multiplier estimated once and applied to every stratum is not
  stratum-independent error, and the covariance the sum omitted is
  `2 Σ_{h<k} R_h R_k s_h s_k`. Standard errors were understated by up to
  `sqrt(H)` on the expansion term for H strata. This is the default
  configuration, since
  [`mean_party_size()`](https://chrischizinski.github.io/tidycreel/reference/mean_party_size.md)
  without `by` returns one estimate. **Reported standard errors move
  upward** on affected designs; point estimates are unchanged, and
  designs whose party-size estimate is per-stratum are unchanged
  bit-for-bit. Where expansion groups straddle strata unevenly the
  combination is not recoverable from per-stratum components, so the
  standard error is `NA` with a
  `creel_warning_expansion_structure_unknown` warning rather than a
  silently chosen formula. The correction reaches the ungrouped,
  grouped, and per-species totals; the **per-section** path aggregates
  its lake row separately and is still affected — see
  [\#145](https://github.com/chrischizinski/tidycreel/issues/145).

- The three totals now report the party-size component they carry, as
  `se_expansion`
  ([\#134](https://github.com/chrischizinski/tidycreel/issues/134)).
  They routed through the effort estimators, whose standard error
  includes the term, but passed no `se_expansion` to their constructors
  — so a totals object whose `se` demonstrably contained the component
  reported `NULL`, the value documented to mean “never propagated”.
  Anyone applying that test to a total drew the opposite conclusion from
  the truth. The reported number is now produced by the same code that
  folds the term into the variance, so the two cannot drift apart. The
  per-section constructor is not covered; it builds its result frame by
  hand and still reports `NULL`
  ([\#145](https://github.com/chrischizinski/tidycreel/issues/145)).

- [`print()`](https://rdrr.io/r/base/print.html) on a `creel_design` now
  shows the count column and whether the party-size term is carried
  ([\#124](https://github.com/chrischizinski/tidycreel/issues/124)).
  Counts whose expansion carriers were dropped by an ordinary `select()`
  are indistinguishable from counts that never had them, so the design
  print is the last point at which the loss can be surfaced while the
  user can still act on it. Both lines print whenever counts are
  attached. This also closes the older note that the design never showed
  which column it used as the count.

- `tidy()` is documented as lossy for uncertainty components, with the
  reason: a tibble column cannot hold the `NULL`-versus-`NA` distinction
  the component contract depends on. `se_between` and `se_within` are
  likewise documented as not reconstructing `se` on expansion designs.

- [`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md)
  now writes a fourth carrier column, `expansion_of`, naming the column
  the expansion basis is the derivative of, and
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  aborts when the count column is not that column
  ([\#131](https://github.com/chrischizinski/tidycreel/issues/131)).
  `expansion_basis` is `d(count)/d(party_size)`, so a count transformed
  between the two calls — the documented
  `mutate(angler_hours = angler_count * shift_hours)` pattern, for one —
  scales the count and leaves the basis in the old units. The party-size
  variance component then came out understated by exactly the scale
  factor while remaining present and non-`NULL`, so it read as
  propagated: on a six-day design with a ×12 shift length,
  `se_expansion` was 3 where the same physics expressed through
  `period_length_col` gives 36. Point estimates were unaffected. Supply
  the untransformed count and `period_length_col`, which scales the
  count and the basis together. **Breaking:** pipelines that
  premultiplied the count while retaining the carriers now abort.

- [`mean_party_size()`](https://chrischizinski.github.io/tidycreel/reference/mean_party_size.md)
  now names its `"se"` attribute by the group key, and
  [`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md)
  addresses it by name
  ([\#133](https://github.com/chrischizinski/tidycreel/issues/133)). The
  attribute was matched by row order while the means were joined by key,
  so any length-preserving reordering of the lookup — an `arrange()`,
  most habitually — gave every stratum another stratum’s standard error,
  silently and with the point estimates unchanged. On a two-stratum
  design the weekday and weekend standard errors swapped outright. A
  `by`-form lookup whose `"se"` attribute has no names is now refused
  rather than matched positionally; single-row lookups and the scalar
  form are unaffected, having no order to go stale. The
  `expansion_group` attribute was checked for the same hazard and does
  not have it: it is built from the counts rows, never indexed into the
  lookup.

- [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  now aborts when `counts` carries some but not all of the `expansion_*`
  carrier columns
  ([\#132](https://github.com/chrischizinski/tidycreel/issues/132)).
  They are written together by
  [`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md),
  so a proper subset can only come from partial deletion. The gate
  previously required the full set and otherwise took the no-carriers
  path, which left an `expansion_se` sitting visibly in the table while
  the party-size variance component silently went missing. Point
  estimates were unaffected; `se_expansion` came back `NULL`. Dropping
  all of them is still undetectable at this seam — see
  [\#124](https://github.com/chrischizinski/tidycreel/issues/124).

- Camera ratio calibration reports `NA` rather than an exact ratio when
  a stratum has a single paired interview/count day
  ([\#136](https://github.com/chrischizinski/tidycreel/issues/136)). The
  calibration ratio has no measurable spread from one pair, so its
  variance is unknown, not zero; the delta term `T² × var(ρ)` previously
  vanished and the maximally uncertain calibration was reported with the
  same standard error as a perfectly known one. The `NA` propagates into
  the combined standard error and the confidence interval, and a warning
  names the stratum. Strata with two or more paired days are unchanged.

  The single-day test counts distinct paired dates rather than matched
  count rows, so a counts table holding two rows for one date — which
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  only warns about — cannot present one day’s information as two and
  restore the false-precision path. The variance denominator is
  unchanged, so no existing standard error moves. That such a table also
  shifts the point estimate is a separate and older defect, filed as
  [\#142](https://github.com/chrischizinski/tidycreel/issues/142).

- Camera effort estimation now warns when the counts carry `.imputed`
  rows
  ([\#137](https://github.com/chrischizinski/tidycreel/issues/137)),
  naming how many days contain imputed counts and what share of the
  total they are.
  [`impute_camera_counts()`](https://chrischizinski.github.io/tidycreel/reference/impute_camera_counts.md)
  flags rows it filled with model predictions, but nothing downstream
  read the flag: inside
  [`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
  predictions are indistinguishable from observations, so the imputation
  model’s prediction uncertainty is dropped and the between-day variance
  is further understated because predictions are smoother than real
  counts. The reported standard error is a lower bound. Propagating the
  prediction variance is still open under
  [\#137](https://github.com/chrischizinski/tidycreel/issues/137).

  `.imputed` now survives within-day aggregation by collapsing with
  [`any()`](https://rdrr.io/r/base/any.html), alongside the existing
  mean-collapse for the count and `expansion_basis`. A day is imputed if
  any of its sub-counts was; taking the first sub-count’s value, as
  every other column does, let a day whose first count was observed
  report itself as fully observed, and the warning above never fired for
  designs using `count_time_col`.

### Reporting of uncertainty components

- `creel_estimates` objects now carry `se_components`, a named list of
  the standard-error contributions that make up `se`, and
  [`print()`](https://rdrr.io/r/base/print.html) reports each one with
  its relationship to `se`
  ([\#141](https://github.com/chrischizinski/tidycreel/issues/141)). The
  contract is the one the party-size component has followed since 3.2.0,
  generalised: an absent name means the component does not apply to that
  path or was never propagated, `NA` means it applies and is unknown, a
  finite value is a contribution and never `se` itself, and none of them
  is ever `0` — a zero cannot be told apart from a component that never
  propagated. `se_expansion` is unchanged and still supported; the
  constructor now mirrors it into `se_components[["party_size"]]` so a
  reported component and the standard error containing it cannot drift
  apart, which is the defect
  [\#134](https://github.com/chrischizinski/tidycreel/issues/134) was.

- Camera effort estimation reports its two delta-method terms separately
  as the `count_sampling` and `calibration` components
  ([\#141](https://github.com/chrischizinski/tidycreel/issues/141)).
  Since 3.3.0 a stratum with one paired interview/count day gives its
  calibration ratio an unknown variance, which correctly makes the whole
  standard error `NA`
  ([\#136](https://github.com/chrischizinski/tidycreel/issues/136)) —
  `Var(E) = Σ_h [ρ_h² Var(T_h) + T_h² Var(ρ_h)]` is unknown if any
  `Var(ρ_k)` is, and reporting the measurable part as the standard error
  would publish a lower bound under the name of the real thing. That
  `NA` stays. What changes is that the count-sampling half is now
  reported as a finite component alongside it, so one thin stratum no
  longer hides everything that *is* known. The reported components
  reconstruct `se` exactly, and the raw-count path omits `calibration`
  entirely rather than reporting it as `NA`, because that path has no
  calibration ratio at all. No standard error changes value.

- `tidy()` remains lossy for these components, for the reason already
  documented: a tibble column collapses an absent component and an
  unknown one into the same `NA`.

## tidycreel 3.2.0 “Bigmouth Buffalo” (2026-08-13)

### New features

- The sampling error of an estimated party size now reaches the effort
  standard error
  ([\#121](https://github.com/chrischizinski/tidycreel/issues/121)). A
  mean party size taken from interviews multiplies the boat component of
  every count, so its error is one error applied many times rather than
  fresh noise per count: it does not shrink as counts accumulate.
  Treating it as known made every count-expanded effort standard error
  too small.

  [`mean_party_size()`](https://chrischizinski.github.io/tidycreel/reference/mean_party_size.md)
  now returns that standard error as a `"se"` attribute, and
  [`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md)
  reads it, so the usual pipeline propagates the term with no extra
  argument:

  ``` r

  counts |> derive_angler_count(
    bank       = bank_anglers,
    boat_count = angler_boats,
    party_size = mean_party_size(interviews, n_anglers, angler_type = angler_type)
  )
  ```

  Supply `party_size_se` directly to override it, in any of the three
  shapes `party_size` accepts (scalar, column, lookup).

  The component is reported as `se_expansion` on the returned estimates
  object and is included in `se`, so it reaches catch, harvest, and
  release totals as well. The estimates tibble keeps its existing seven
  columns.

- [`est_biomass()`](https://chrischizinski.github.io/tidycreel/reference/est_biomass.md)
  can now propagate the length-weight regression error
  ([\#117](https://github.com/chrischizinski/tidycreel/issues/117)). `a`
  and `b` are point estimates from a regression, and `a * L^b`
  multiplies every length bin, so their error is perfectly correlated
  across bins and does not shrink as bins are added.

  Supply `alpha_se`, `b_se`, and `L0` together — all three or none:

  ``` r

  est_biomass(ld, a = 0.0088, b = 3.1, alpha_se = 0.05, b_se = 0.03, L0 = 250)
  ```

  The allometry is rewritten about a pivot length `L0` as
  `W = alpha * (L / L0)^b`, and the delta method applied in
  `(alpha, b)`. The parameter covariance is then absent **by
  construction rather than by assumption**: on the raw `(a, b)` scale
  the two are typically correlated below -0.99, so dropping their
  covariance there would overstate the variance severalfold. `L0` should
  be the geometric mean length of the calibration sample, and `alpha_se`
  the intercept SE from a regression centred there — not the standard
  error of `a`.

  Reported as `attr(x, "biomass_se_params")` and included in
  `biomass_se`. Absent — `NULL`, not `0` — when the arguments are not
  supplied.

### Breaking changes

- Effort standard errors **increase** for designs that expand a boat
  count by
  [`mean_party_size()`](https://chrischizinski.github.io/tidycreel/reference/mean_party_size.md)
  output, because a variance component that was previously dropped is
  now carried. Estimates themselves are unchanged; only their
  uncertainty moves. Designs that pass a bare number or a column as
  `party_size` are unaffected, since no standard error is available for
  those.

### Notes

- When no party-size standard error is available the component is
  **omitted, not set to zero**. `se_expansion` is `NULL` rather than
  `0`, because a zero would produce a standard error identical to an
  unpropagated one while appearing to have been propagated. A party size
  estimated from a single interviewed party yields `NA`, which
  propagates to an `NA` standard error rather than being read as
  certainty.

- [`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md)
  writes three further columns — `expansion_basis`, `expansion_se`, and
  `expansion_group` — when a standard error is available.
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  recognises all three and excludes them from count-column detection, so
  they cannot make an otherwise unambiguous counts table look ambiguous.

## tidycreel 3.1.0 “Sauger” (2026-08-13)

### New features

- [`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md)
  builds the single angler-count column
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  needs from the columns a clerk actually records. Two forms, matching
  the two ways boat anglers reach the form:

  ``` r

  # Anglers aboard were counted directly
  counts |> derive_angler_count(bank = bank_anglers, boat_anglers = boat_anglers)

  # Boats were counted; anglers aboard were not
  counts |> derive_angler_count(
    bank       = bank_anglers,
    boat_count = angler_boats,
    party_size = mean_party_size(interviews, n_anglers, angler_type = angler_type)
  )
  ```

  `party_size` accepts a single number, a column of `counts`, or a
  lookup table keyed by stratum, so a party size that differs between
  weekdays and weekends can be applied per group rather than averaged
  away.

  `boat_count` and `boat_anglers` are separate arguments deliberately.
  `boat_count` counts **hulls**, and adding it to an angler total is a
  units error that produces a plausible-looking number; requiring
  `party_size` alongside it makes that impossible to do by accident.
  Supplying both boat forms is an error, since they are two routes to
  the same quantity.

  Components are added with `na.rm = FALSE`: a count that was not taken
  and a count of zero anglers are different observations and stay
  different.

  Until now this derivation was available only on the sampled-day
  `prep_counts_*` seam, via
  [`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md).
  The raw-count pipeline — the one that takes a within-day count
  schedule through `count_time_col` and derives the within-day variance
  component itself — had no equivalent, so callers there built the total
  by hand. Closes
  [\#119](https://github.com/chrischizinski/tidycreel/issues/119).

- [`mean_party_size()`](https://chrischizinski.github.io/tidycreel/reference/mean_party_size.md)
  returns the mean anglers per boat party from an interviews table,
  optionally by stratum. It filters to boat parties, and errors rather
  than returning `NaN` when no row matches — a silent `NaN` would
  propagate into every expanded count.

### Behaviour changes

- Bus-route estimators no longer report a confidence bound below zero.
  Every `ci_lower` produced by
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
  [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
  [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
  and
  [`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md)
  on a bus-route design is now clamped at zero, in both the ungrouped
  and `by`-grouped paths and in the bootstrap columns (`ci_lo_boot`).
  Bus-route was the last family of estimators in the package without
  this clamp; the product totals, exploitation rate and length
  compliance already had it.

  This changes reported numbers only where the old bound was outside the
  parameter space. Angler-hours, fish and fish-per-hour cannot be
  negative, so a symmetric Wald bound below zero was never a possible
  value for the quantity. It is reached whenever the coefficient of
  variation exceeds roughly 0.51 — routine for a bus-route survey with
  few sites, unequal inclusion probabilities, or catch concentrated in
  one interview. The package’s own bootstrap snapshot fixture was
  already in that regime:
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  reported an estimate of `115` with an SE of `78.3` and a lower bound
  of `-38.8`, which is now `0`. On a deliberately skewed two-site design
  with `p_site` of 0.05 and 0.95 the excursion is larger, with the
  total-catch bound moving from `-15999.40` to `0` and the harvest-rate
  bound from `-54.85` to `0`.

  A clamped bound of exactly zero means the interval is wide relative to
  the estimate. It is not a statement that the quantity could be zero,
  and the clamp does not narrow the interval or change the estimate or
  the standard error. See
  [`?creel_confidence_intervals`](https://chrischizinski.github.io/tidycreel/reference/creel_confidence_intervals.md).
  Closes part of
  [\#95](https://github.com/chrischizinski/tidycreel/issues/95).

### Documentation

- New topic
  [`?creel_confidence_intervals`](https://chrischizinski.github.io/tidycreel/reference/creel_confidence_intervals.md)
  states the two conventions the package follows when building
  intervals: transform where a principled transform for the quantity
  exists (logit for exploitation rate, Sadinle’s transformed logit for
  mark-recapture abundance, optional log for product totals) and clamp
  at the feasible limit otherwise; and use a t-quantile where an
  estimator has a design degrees-of-freedom to appeal to, a normal
  quantile where it does not. Written down so a new estimator does not
  have to pick by coin flip. Closes
  [\#95](https://github.com/chrischizinski/tidycreel/issues/95) and
  [\#99](https://github.com/chrischizinski/tidycreel/issues/99).

- [`est_biomass()`](https://chrischizinski.github.io/tidycreel/reference/est_biomass.md),
  [`est_mean_length()`](https://chrischizinski.github.io/tidycreel/reference/est_mean_length.md),
  [`est_compliance()`](https://chrischizinski.github.io/tidycreel/reference/est_compliance.md)
  and
  [`est_mean_age()`](https://chrischizinski.github.io/tidycreel/reference/est_mean_age.md)
  now record why they use a normal rather than a t quantile. Their
  standard error is propagated from the per-bin standard errors of a
  length or age distribution, so there is no local sample size to key
  degrees of freedom to: the row count is the number of bins, which is
  the caller’s binning choice, and the row totals are expanded estimates
  rather than counts of measured fish. Keying a t-quantile to either
  would make the interval narrow as bins got finer, with no additional
  fish measured. Closes
  [\#99](https://github.com/chrischizinski/tidycreel/issues/99).

- [`est_biomass()`](https://chrischizinski.github.io/tidycreel/reference/est_biomass.md)
  now states that the length-weight parameters `a` and `b` are treated
  as known constants, so `biomass_se` omits their estimation error and
  should be read as a lower bound. Because `a * L^b` multiplies every
  bin, that error is perfectly correlated across bins and does not
  shrink as bins are added. Measured on the documented example it adds
  roughly 2–11% to a coefficient of variation of 40–65% — minor there,
  but material for a survey precise enough to reach a count CV near 10%,
  or when `a`/`b` are borrowed from a system whose fish differ in size.
  Propagating the term needs an API that can accept the regression’s
  standard errors and their covariance; tracked in
  [\#117](https://github.com/chrischizinski/tidycreel/issues/117).

### Bug fixes

- Argument guards on `truncate_at` and `conf_level` now reject a value
  whose length is not 1, rather than letting it reach the comparison.
  Passing `truncate_at = c(0.5, 1)` to
  [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
  raised base R’s `'length = 2' in coercion to 'logical(1)'`, and
  `numeric(0)` raised `missing value where TRUE/FALSE needed` — both of
  which name neither the argument nor the constraint it violated. The
  intended error, which cites the argument and its default, now fires
  instead. Affects
  [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
  the bus-route incomplete-trip path, and
  [`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md).

  A `conf_level` or `truncate_at` of `NA_real_` still reaches base R’s
  “missing value where TRUE/FALSE needed”. That gap predates this change
  and is shared by the six other guards written to the same pattern; it
  is left for a single pass over all of them rather than fixed at three
  sites only.

## tidycreel 3.0.0 “Blue Sucker” (2026-08-12)

The first major bump since the package adopted semantic versioning. It
closes the dimensional seam audit opened 2026-08-07: 27 findings, ten of
them breaking changes to what an estimator returns. Estimates now carry
the unit of the quantity they report, derived from the arithmetic the
package performed rather than declared by the caller.

Read the **Breaking changes** section before upgrading — bus-route, ice,
instantaneous, aerial and camera designs all report different numbers
than 2.5.0 did, because 2.5.0’s numbers were wrong.

### New features

- Estimates now carry the unit of the quantity they report.
  `creel_estimates` objects gain a `unit` field,
  [`print()`](https://rdrr.io/r/base/print.html) shows a `Unit:` line,
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  puts it on the y-axis, and
  [`write_estimates()`](https://chrischizinski.github.io/tidycreel/reference/write_estimates.md)
  records it in the CSV header. This replaces hardcoded axis and header
  strings, which could not tell that the number underneath them had
  changed dimension.

  The unit is **derived, never declared**. A unit the caller types is
  exactly as trustworthy as the axis label on the poster — a second
  place to write the wrong thing — so tidycreel asserts one only where
  it performed the arithmetic that produces it: angler-hours on the
  count side when
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  multiplied by T_d, angler-hours on the interview side when
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  multiplied trip hours by a supplied party size, and party-hours when
  it did not.

  Everywhere else the unit is `NA`, meaning unknown — deliberately
  **not** “angler-days”. A bare numeric count column may be an
  instantaneous head count or effort the caller already expanded, and
  `example_counts` is the latter; guessing between them would put a
  confident label on a number that may be in either unit, which is the
  failure this machinery exists to prevent. An absent `Unit:` line is
  the claim that tidycreel does not know, which is a different statement
  from a default.

- [`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md)
  gains `n_anglers`, which makes the ratio-calibration path’s unit
  derivable instead of unknown. The calibration ratio is a ratio of
  sums, so the camera counts cancel and the estimate inherits whatever
  unit the interview effort column holds — angler-hours and party-hours
  were indistinguishable, a factor of roughly two apart on the shipped
  example and reported identically. Passing `n_anglers`, either a column
  in `interviews` or a constant party size, makes the function perform
  the normalisation itself, which is what earns the `angler-hours`
  label.

  Omitting it now warns and names the ambiguity. That warning is only
  worth raising because the argument exists to answer it: before, it
  would have reported a gap the caller had no means to close.

  The party-size rule is not reimplemented. This path calls the same
  exported
  [`compute_angler_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_angler_effort.md)
  that
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  uses, so a party size of zero is refused at both seams for the same
  reason, and they cannot drift apart. `n_anglers` here takes a column
  *name* or a constant rather than a tidyselect symbol, matching its
  neighbouring `effort_col` and `intercept_col` arguments.

- Unit propagation now reaches the rate and total estimators outside the
  standard CPUE spine. Species, sections, grouped, bus-route and
  regression rates carry `fish/<denominator>`; species, sections and
  bus-route totals carry `fish`. These paths reach different
  constructors than the ungrouped ones, which is why they were still
  reporting `NA` after the first pass.

  `NA` is not a neutral default: it reads as “tidycreel does not know
  what this number is”, and it suppresses the unit from
  [`print()`](https://rdrr.io/r/base/print.html),
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  and the CSV header, so the number travels bare. Saying `NA` where the
  package does know is as much a false claim as guessing.

  The denominator is a property of the interviews rather than of which
  rate was asked for, so every rate estimator on one design now reports
  the same one — asserted between estimators in the tests rather than
  against a hardcoded string, since a wrong constant can satisfy a
  literal but cannot make two independent estimators agree.

  Visible change:
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  y-axis labels on these paths now read e.g. “Total Catch (fish)” where
  they previously read “Total Catch”.

- Unit propagation now covers the effort family, where the same quantity
  is derived three different ways and so takes its unit from three
  different places.

  Bus-route effort reports the **interview** denominator, not the count
  side: `E_hat = sum(e_i / pi_i)` is built entirely from interview
  contributions, so labelling it from the counts would assert a
  provenance the number does not have. Aerial effort is angler-hours
  unconditionally — an aerial design refuses `period_length_col`, which
  makes `h_open` the sole period source.

  Camera effort splits by path. The raw-count path is angler-hours for
  the same reason as aerial. The ratio-calibration path is `NA`: its
  ratio carries the unit of the `effort_col` column in a caller-supplied
  data frame, which nothing normalises by party size, so angler-hours
  and party-hours are indistinguishable there. Unknown is the honest
  answer, and the same one
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  gives a bare count column.

- [`estimate_angler_trips()`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_trips.md)
  and
  [`estimate_effort_per_acre()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort_per_acre.md)
  now carry units, and both **inherit** rather than assert them. These
  two take a `creel_estimates` rather than a design, so they cannot ask
  a design what anything is in; each transforms a quantity whose unit it
  was handed.

  Trips are effort divided by mean trip length, and the divisor is hours
  per trip, so the count comes back in whichever actor the effort was
  measured in: angler-hours give `angler-trips`, party-hours give
  `party-trips`. The method name is `"angler-trips"` for every caller,
  which is precisely why the unit cannot be read off it — a bus-route
  design with no `n_anglers` produces a party-level count that a fixed
  label would have reported as angler trips.

  Effort per acre composes its unit from the effort’s, keeping
  `party-hours/acre` distinguishable from `angler-hours/acre`. An
  unknown effort unit stays unknown through both: dividing an unknown
  quantity does not make it known, and `"NA/acre"` would read as a real
  unit on a plot axis.

- Unit propagation now reaches the mark-recapture and exploitation-rate
  estimators, the last group without units, and the honest answer for
  most of them is `NA`.

  [`estimate_exploitation_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_exploitation_rate.md)
  reports `"proportion"` on both the stratified and unstratified paths.
  It is the one estimator in the package whose unit no input can change:
  divides fish by fish twice, so both actors cancel for every design.

  [`estimate_angler_n()`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_n.md)
  reports `NA`, **not** `"anglers"`. Its `M`, `n` and `m` arrive as bare
  numerics that nothing inspects, and the arithmetic divides counts by
  counts, so carries whatever actor the marking protocol marked —
  anglers on some surveys, boats or parties on others. Asserting
  `"anglers"` would restate the function’s name rather than derive
  anything.
  [`estimate_mr_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_mr_harvest.md)
  inherits that unknown for the same reason: its product is in fish only
  if counted anglers.

- [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  and
  [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
  abort with class `creel_error_unit_mismatch` when the effort unit and
  the rate’s denominator are both known and disagree. Their product is
  not a catch.

  Two seams are deliberately excluded. A per-party-hour rate meeting
  angler-hour effort keeps `warn_party_hours_product()`’s existing
  warning rather than becoming an error, since that would break every
  caller who omits `n_anglers`. An unknown effort unit is reported by
  the T_d warning below rather than a second message, so one defect
  produces one diagnosis.

- [`day_length()`](https://chrischizinski.github.io/tidycreel/reference/day_length.md)
  computes hours between sunrise and sunset for a latitude and date
  using the CBM model of Forsythe et al. (1995). Closed form — no lookup
  table, no network access, no location database. Only latitude is
  needed: longitude and time zone shift when sunrise and sunset occur,
  not the interval between them. `horizon` selects the depression angle,
  by name (`"sunset"`, `"civil"`, `"nautical"`, `"astronomical"`) or in
  degrees. Days inside the polar circles saturate at 0 or 24 hours
  rather than returning `NaN`.

  Day length is astronomical and is not the same quantity as the
  estimators’ , which is the period the counts were randomised within —
  a property of the survey design, set by regulation, access hours, or
  field protocol. Use
  [`day_length()`](https://chrischizinski.github.io/tidycreel/reference/day_length.md)
  for simulation and planning; pass the period your protocol actually
  used to
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).

- [`simulate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/simulate_creel_data.md)
  gains `lat` and `daylight_hours`, either of which adds
  `daylight_hours` and `angler_hours` columns to the simulated counts
  table. `lat` derives the daily period per date via
  [`day_length()`](https://chrischizinski.github.io/tidycreel/reference/day_length.md);
  `daylight_hours` sets it directly, as a scalar or a named monthly
  vector, for surveys whose fishing day is fixed by regulation.
  Supplying both is an error.

  Supplying neither leaves both columns off, so the default output is
  unchanged. There is no honest default latitude, and substituting one
  would put a plausible number where the caller gave none.

### Bug fixes

- [`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md)
  warns when a binned release row carries a fractional `count`. The
  guard’s own error message had always said “a positive integer count”
  while nothing checked integrality, so `count = 3.5` was accepted
  silently and reached `estimate_length_distribution()`, which
  aggregates that column as a per-bin fish count. A fraction of a fish
  then entered the distribution and every proportion computed from it.

  Warned rather than rejected, matching how `n_anglers` treats the same
  category error: a fractional count of discrete things signals the
  wrong column was supplied, not that the data are unusable, and
  aborting would break tables that have always been accepted. The `NA`
  message now says “a positive count; non-integer values warn”, so what
  it claims and what it enforces agree.

- [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  warns, once per session, when an instantaneous design carries no
  `period_length_col`. Without T_d the estimator expands the count
  column to the season and returns it, which is not angler-hours. The
  warning states the reading rather than asserting the unit: tidycreel
  cannot tell an instantaneous head count from a column that already
  holds angler-hours, since both arrive as a numeric column, so it says
  that *if* the column is a count the result is in angler-days. Numbers
  are unchanged for these callers.

  The three product totals raise the same warning. They call
  `estimate_effort_total()` directly rather than
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
  so without this a caller who only ever asks for a total never heard
  that the count column had no T_d applied.

  Output from the `prep_counts_*()` helpers is exempt. That seam
  resolves counts into sampled-day effort before
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  sees them, so there is no instantaneous count left to expand and no
  T_d to ask for — warning there would fire on the documented preferred
  workflow. The marker is carried as an attribute, so a table piped
  through intervening dplyr verbs degrades to “unknown”, which is the
  safe direction.

- [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  and
  [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
  now accept `by = species` on bus-route and ice designs, and answer on
  the Horvitz–Thompson path. All three resolved `by` against the
  interview columns, which carry no species column, so the call aborted
  with `` Column `species` doesn't exist `` on both design types — six
  combinations, none of them reachable. The species-level total
  estimators they would otherwise have reached are stratum product sums
  built on the standard interview survey, so routing there instead would
  have reproduced the previous entry’s defect in the totals: a species
  total contradicting the all-species total on the same object.

  The falsifier is the same partition identity, and it is exact for a
  Horvitz–Thompson sum because that sum is linear in its numerator. All
  six combinations now satisfy it, and each species’ total over the HT
  effort equals that species’ rate to machine precision — the
  cross-check tying the totals to the rates. The reported method names
  the estimator and the quantity (`ht-total-release-species`).

  `use_trips = "all"` is still rejected: the completed-trip guard runs
  ahead of the species branch, because an incomplete trip contributes
  catch-so-far under a completed trip’s inclusion probability whether or
  not the numerator is one species.

- Species-level rates (`by = species`) now take the Horvitz–Thompson
  path on bus-route and ice designs. `estimate_cpue_species()` and its
  harvest and release siblings build a per-species interview table and
  hand it to the *standard* interview-survey estimators, so on these two
  design types they ignored `.pi_i` and `.expansion` — the defect the
  previous entry removed from the all-species rates, one estimator over.
  Fixing the all-species side first is what made it visible: one design
  object then returned both answers, each under a method string naming
  the same quantity.

  The falsifier is a partition identity rather than a reference value.
  Species partition the catch and every species shares the same effort
  denominator, so the species rates must sum to the all-species rate
  exactly. Before the fix the species sum matched the standard-path rate
  to the last digit:

  | design    | rate | all-species | species sum | gap     |
  |-----------|------|-------------|-------------|---------|
  | bus-route | CPUE | 0.748339    | 0.937805    | +25.32% |
  | bus-route | RPUE | 0.421378    | 0.494953    | +17.46% |
  | ice       | HPUE | 0.919685    | 0.862944    | −6.17%  |
  | ice       | RPUE | 0.909720    | 0.964467    | +6.02%  |
  | ice       | CPUE | 1.829405    | 1.827411    | −0.11%  |

  All five now reconcile exactly. Per species the estimator repoints the
  numerator at that species’ counts and delegates to the bus-route
  estimator the all-species rates already use, so the two can no longer
  drift apart, and the reported method gains the `-species` suffix on
  both trip paths (`ratio-of-means-rpue-species` where the standard path
  still reports `ratio-of-means-rpue`). `use_trips = "diagnostic"` is
  refused with species grouping: the diagnostic pair returns two
  estimates per species, and returning either half under one label is
  the mislabelling this release is removing.

  Also fixes a regression introduced by the previous entry: that
  dispatch resolved `by` against the interview columns, where there is
  no species column, so `by = species` aborted on ice designs where it
  had previously worked, and on bus-route designs where it had never
  worked.

  **Breaking:** every species-level rate on a bus-route or ice design
  moves.

- The three rate estimators now dispatch to the Horvitz–Thompson path on
  **ice** designs as well as bus-route ones, and
  [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
  gains the bus-route dispatch it never had.
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  and all three totals already treated ice as the degenerate bus route
  it is documented to be; the rate estimators were the outliers, so a
  single design object returned a rate that its own totals contradict.
  Both paths reported the same `method` string, so nothing in the
  returned object distinguished them.

  A ratio of HT totals must equal total ÷ effort exactly, which is what
  says which of the two answers was wrong rather than merely that they
  differed:

  | design    | rate | before   | totals imply | after              |
  |-----------|------|----------|--------------|--------------------|
  | ice       | HPUE | 0.514328 | 0.478561     | 0.478561           |
  | ice       | CPUE | —        | —            | reconciles exactly |
  | bus-route | CPUE | 0.466438 | 0.433603     | 0.433603           |

  Ice designs consequently take the bus-route `use_trips` set —
  `"complete"`, `"incomplete"`, `"diagnostic"` — instead of the standard
  path’s, so they now accept the two values their own design type is
  built on and reject `"all"`, which is not an estimator on this path.
  For
  [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
  the roving auto-route to `"all"` + MOR does not apply on these
  designs.

  **Breaking:** ice HPUE, ice RPUE, ice CPUE and bus-route CPUE all
  move.

- [`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md)
  and
  [`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md)
  now validate `use_trips` on the bus-route path. The bus-route dispatch
  runs before the standard path’s check and handed the string straight
  to the estimator, which branches on `"diagnostic"`, then `"complete"`,
  then `"incomplete"` with no final `else` — so an unrecognised value
  reached the complete-trip code with the trip-status filter switched
  off and returned the all-trips answer under the complete-trip method
  string, silently. The dangerous input was not a nonsense string but a
  *valid* value typed with the wrong case: on a fixture of four complete
  and four incomplete trips, `"Complete"` returned 2.816514 over all
  eight rows where `"complete"` returns 2.642202 over four. The standard
  path rejected the same input, so whether a typo aborted depended on
  the design type.

  The valid set on the bus-route rate path is `"complete"`,
  `"incomplete"` or `"diagnostic"`, as documented. It is deliberately
  not the standard path’s set: `"incomplete"` is a legitimate rate here
  (Hoenig et al. 1997) and is not offered there, and `"all"` is
  legitimate there and is not an estimator here, because pooling the two
  kinds of trip applies the complete-trip ratio of Horvitz–Thompson
  totals to numerators that are catch so far. Matching is exact —
  `"comp"` is an error, not `"complete"`.

- The product totals now warn when the rate and the effort they multiply
  are in different units. Without `n_anglers`,
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  leaves `.angler_effort` equal to the raw effort column, so every rate
  is fish per *party*-hour while count-derived effort is angler-hours;
  both operands are individually correct but the product is not, unless
  every party is a single angler.
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  informed at construction, but `design$angler_effort_col` was
  `".angler_effort"` either way, so nothing downstream could tell the
  two apart and nothing spoke up where the units actually collide.
  Designs now carry `n_anglers_supplied`, and
  [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  and
  [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
  warn on the product path when it is `FALSE`. Bus-route and ice designs
  are unaffected: their totals are Horvitz–Thompson sums over interviews
  with no rate multiplication. The package’s own examples now pass
  `n_anglers`
  ([\#112](https://github.com/chrischizinski/tidycreel/issues/112)).

- [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
  and
  [`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md)
  had no bus-route dispatch, so on a bus-route or ice design they ran
  the count-based product path and ignored the inclusion probabilities
  entirely. The interview-derived release counts were divided by a
  [`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html) over
  count rows — a different effort basis from the one
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  reports for the same design, with no warning. On a fixture whose catch
  records set the released count equal to the harvest column interview
  by interview, so that the true release total *equals* the true harvest
  total,
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  returned 465.4 and
  [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
  returned 51.1; the two now agree to machine precision. Bus-route
  designs carrying no counts aborted demanding
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
  which they do not need. `estimate_total_release_br()` had been correct
  and unreachable since it was written
  ([\#110](https://github.com/chrischizinski/tidycreel/issues/110)).

- [`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md)
  on a bus-route design reaches the same estimators as
  [`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md).
  `use_trips` accepts `"incomplete"` — the truncated, Hájek-weighted
  mean of ratios of Hoenig et al. (1997), reported as
  `method = "mean-of-ratios-rpue"` — and `"diagnostic"`, alongside the
  existing complete-trip ratio of Horvitz–Thompson totals
  (`method = "ratio-of-means-rpue"`). Both are releases per angler-hour
  ([\#110](https://github.com/chrischizinski/tidycreel/issues/110)).

- [`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md)
  and
  [`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md)
  emitted `n_counts` and `within_day_var` columns that
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  never read, so a within-day variance component supplied through the
  documented preferred seam was silently dropped and the reported SE
  omitted it entirely — biased **downward**, the dangerous direction. On
  an eight-day fixture with three counts per day the prep seam reported
  SE 6.93 where the equivalent `add_counts(count_time_col = )` route
  reported 9.52.
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  now reads both columns into `design$within_day_var`, and the two seams
  agree exactly
  ([\#109](https://github.com/chrischizinski/tidycreel/issues/109)).

  The columns are also rescaled into `daily_effort` squared units on
  output — by `correction_factor^2`, and additionally by
  `mean_party_size^2` in the boat path. `daily_effort` is scaled by
  those factors but the sum of squares was passed through untouched, so
  wiring the slot up without rescaling would have left the within-day
  term a factor of `cf^2` away from the between-day term it is added to.

  `within_day_var` is now documented unambiguously as a **sum of
  squares**, not a variance: the estimator supplies the divisor itself,
  forming `sum(ss_d) / (n_sampled * (k_bar - 1))`, so a variance
  understates the component by a factor of `k_d - 1`. To make that
  contract enforceable, `within_day_var` now requires `n_counts`, must
  be non-negative, and must be `0` wherever `n_counts` is 1. Supplying
  the component through both the columns and
  `add_counts(count_time_col = )` is an error rather than a double
  count. Counts tables carrying neither column are unaffected.

### Breaking changes

- [`estimate_angler_n()`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_n.md)
  now defaults to Sadinle’s (2009) 0.5 transformed logit confidence
  interval on the Chapman and Petersen branches, via a new
  `ci_method = "logit"`. **Every Chapman and Petersen bound moves.**
  Pass `ci_method = "delta"` to reproduce the previous symmetric Wald
  interval exactly.
  [`estimate_mr_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_mr_harvest.md)
  inherits the change, rebuilding its interval from the same capture
  table.

  The Wald interval is symmetric while is a ratio with a small integer
  denominator and is strongly right-skewed, so it leaves the parameter
  space in the regime Chapman exists for. At `M = 200`, `n = 50`,
  `m = 3` it reported `ci_lower = -2124.8`; at `m = 5` it reported
  `48.7` against 245 individuals actually observed. Evans et al. (1996)
  measured Wald coverage failing on one side 27.9% of the time against a
  2.5% nominal rate.

  Sadinle compared nine intervals and found the 0.5 transformed logit
  “the best of the intervals reported here”, with near-nominal coverage
  even for small populations and capture probabilities near 0 or 1,
  where profile-likelihood and Monte Carlo intervals both degrade. Its
  lower limit cannot fall below the number of individuals observed. It
  is closed-form, deterministic, and adds no dependency.

  | `m` | before                | after               |
  |-----|-----------------------|---------------------|
  | 2   | `[-17486.6, 24318.6]` | `[1319.1, 14085.6]` |
  | 3   | `[-2124.8, 7248.3]`   | `[1143.1, 8259.6]`  |
  | 5   | `[48.7, 3366.3]`      | `[903.9, 4211.2]`   |
  | 10  | `[406.9, 1454.9]`     | `[605.4, 1715.0]`   |

  The Schnabel branch is unchanged — it already inverted Poisson
  quantiles and could not produce a negative bound.

  One boundary behaviour is worth knowing: when `m == n`, every
  individual in the second sample was already marked, the estimator
  saturates at , and the logit lower limit sits fractionally *above* the
  point estimate because the data imply . Use `ci_method = "delta"` if a
  bound that brackets the point estimate matters more than coverage.

- [`estimate_mr_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_mr_harvest.md)
  now derives its interval from the angler-population interval instead
  of rebuilding a symmetric one, so a positive angler bound can no
  longer become a negative harvest bound. On the `ci_method = "delta"`
  path this is not a numeric change: the old code used the same degrees
  of freedom and `se_H = harvest_rate * se_N`, so its bounds already
  equalled the scaled angler bounds to machine precision.

- `estimate_angler_n(method = "schnabel")` now builds its large-sample
  confidence interval on degrees of freedom, where is the number of
  sampling occasions. It previously used , the recapture total. **Every
  Schnabel interval with widens**; the point estimate and `se` are
  unchanged.

  Hansen & Van Kirk (2018) eq. (A.5) uses , as does
  `fishmethods::schnabel()`, the implementation they modified. The
  estimator has one observation per occasion regardless of how many
  recaptures land in it, so keying df to treats recaptures within an
  occasion as independent and understates the interval. On five
  occasions with the reported interval was `[1504.28, 2665.02]` where
  the source gives `[1388.48, 3127.07]` — 33% too narrow.

  The `se` itself was checked against the same sources and is correct as
  it stands. Only the quantile changed.

- `estimate_angler_n(method = "schnabel")` now applies Chapman’s (1952)
  small-sample correction by default, dividing by instead of . **Every
  Schnabel point estimate falls**, by exactly in relative terms: 33% at
  , 1.9% at 52, 0.2% at 500. Pass `bias_adjust = FALSE` for the previous
  form, which is also what `fishmethods::schnabel()` computes.

  Dettloff (2023) eq. (6) simulated both forms across population sizes
  from to . The unadjusted estimator turns biased *high* at moderate
  sample sizes before settling, which propagates into an inflated
  [`estimate_mr_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_mr_harvest.md);
  the adjusted form’s bias “approaches zero as the sample size increases
  without ever becoming positive”, at lower variance and no cost in
  large samples. He recommends the adjusted estimators “in place of the
  originals in all scenarios”.

  The consistency argument is the other half. Schnabel reduces exactly
  to Lincoln-Petersen at , so the unadjusted form meant that
  `method = "schnabel"` on two occasions returned the estimator the
  package already declines to default to at `method = "petersen"` — bias
  handling depended on how many occasions had been sampled rather than
  on the data.

  The `se` moves only through the delta-method Jacobian, which is
  evaluated at the reported . shifts by the constant , so is unchanged
  and `invSE` still matches `fishmethods`. The Poisson interval ()
  inverts the distribution of rather than centring on , so **its bounds
  do not move**; the large-sample interval is built around and does.

- [`estimate_angler_n()`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_n.md)
  gains `method = "schumacher"`, the Schumacher-Eschmeyer regression
  estimator, for occasions. It takes the same inputs as `"schnabel"` and
  fits against through the origin with slope , giving . The interval is
  Seber (1982) eq. (4.17) on degrees of freedom, and `bias_adjust`
  (default `TRUE`) applies Dettloff’s (2023) eq. (8) small-sample
  correction. With `bias_adjust = FALSE` the point estimate, `invSE` and
  both bounds match `fishmethods::schnabel()`’s Schumacher-Eschmeyer row
  to printed precision, and the formulas were checked against Seber’s
  own worked example (Ricker’s red-ear sunfish: = 423, = 0.1935).

  Two details differ from the Schnabel branch on purpose. Degrees of
  freedom are , not : Seber excludes the first occasion because is
  identically zero when and so “is not strictly a random observation”.
  And Dettloff’s eq. (8) numerator sums from explicitly — is the one
  term here that does *not* vanish at , so occasion 1 has to be dropped
  by hand rather than by the algebra.

  **tidycreel deliberately does not implement the “pick the narrower CI”
  rule.** Hansen & Van Kirk (2018) computed both estimators and
  “selected the mark-recapture estimator that produced the smallest 95%
  CI”. Choosing the narrower of two intervals after seeing them
  conditions on the luckier draw, so the reported interval does not have
  its nominal coverage. Choose between the estimators on design grounds,
  or report both.

- `estimate_angler_n(method = "schnabel")` no longer returns
  `ci_upper = Inf` when the recapture total is very small. The Poisson
  interval divides by the lower quantile , which is **zero** for at the
  95% level. Hansen & Van Kirk (2018) eq. (A.4) substitute
  Ilienko’s (2013) continuous Poisson, , in exactly that case; it is
  positive there and yields a finite bound. The substitution fires only
  where the discrete quantile is zero — from the continuous quantile
  sits just above the discrete one, so the bound stays monotone across
  the seam.

  **The bound is an interpolation, and the warning that announces it is
  deliberate.** It rests on a continuous interpolation of a discrete
  distribution at one to three total recaptures; it stands in for “the
  data do not bound this above” rather than measuring anything.

  Implementers should note two traps. The quantile lives in the *shape*
  argument of [`pgamma()`](https://rdrr.io/r/stats/GammaDist.html), so
  it must be root-found — there is no
  [`qgamma()`](https://rdrr.io/r/stats/GammaDist.html) call that
  produces it. And **the source paper’s own worked example is wrong**:
  it reports the 0.025 quantile at as 0.24 and draws Figure A.1 to
  match, but 0.24 is `qgamma(0.025, shape = 2)`, a Gamma(2, 1) quantile.
  Inverting their eq. (A.4) gives **0.3292**. Equation A.4 transcribes
  Ilienko’s Definition 3.1 faithfully; the example does not. Tests pin
  the implementation against Ilienko’s eq. (1) identity with
  [`ppois()`](https://rdrr.io/r/stats/Poisson.html), never against the
  printed example.

- [`estimate_mr_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_mr_harvest.md)
  now keys its Wald interval to the number of sampling occasions when
  the input came from `method = "schnabel"`, matching the change to
  [`estimate_angler_n()`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_n.md)
  above. It read `angler_n$estimates$n`, which for Schnabel is , so the
  degrees-of-freedom defect fixed in the estimator survived one function
  downstream: with five occasions and the harvest interval used where ,
  28% too narrow. **Schnabel harvest intervals widen**; Chapman and
  Petersen are unaffected and still use .

- `add_counts(count_type = "progressive")` now **errors** when a day’s
  shift is shorter than `circuit_time`, with condition class
  `creel_error_circuit_exceeds_shift`. It previously warned and then
  returned an estimate anyway.

  The progressive estimator is Hoenig et al. (1993) eq. 3, with the
  number of whole circuits in the day. When no circuit completed, so the
  count is not a progressive count of that shift and there is nothing
  for to expand.
  [`generate_progressive_start()`](https://chrischizinski.github.io/tidycreel/reference/generate_progressive_start.md)
  already refused such a design, so the only way to reach the old
  warning was a hand-built schedule — precisely the case with no other
  guard in front of it.

  () is unaffected: that is Robson’s (1961) all-day circuit and remains
  valid.

- `estimate_mr_harvest(harvest_rate = )` is harvest **per angler**, in
  fish per angler, and is no longer bounded above. It was documented as
  the “proportion of anglers that harvested fish” and guarded to
  `(0, 1]`.

  Those two readings produce different quantities from the same
  arithmetic. with a dimensionless proportion is a count of *anglers who
  kept a fish*; the function returns it as `total_harvest`, from
  [`estimate_mr_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_mr_harvest.md),
  with `method = "mark-recapture-harvest"`. The per-angler-rate reading
  is the one the output has always claimed, and the one that makes the
  product fish.

  The `(0, 1]` guard did more than mislabel — it enforced the wrong
  reading. A fishery averaging 1.4 kept fish per angler is ordinary, and
  the guard made total harvest unreachable for exactly those fisheries
  by erroring on the correct input.

  **No numeric result changes.** Every previously legal call returns
  what it always did, because the multiplication is untouched. What
  changes is which quantity you are told to supply, and that values
  above 1 are now accepted. If you were passing a proportion of anglers,
  your input was answering a different question than the output claimed
  to ask, and it should be replaced with mean fish kept per angler.

- [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  now aborts with class `creel_error_aerial_period_length` when
  `period_length_col` is supplied on an aerial design, and
  [`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md)
  aborts with class `creel_error_camera_period_length` when its
  raw-count branch is handed counts that already carry T_d.

  Both estimators already have a period-length term of their own: aerial
  scales the count by `h_open / v` (Pollock Eq. 15.4) and camera’s
  raw-count fallback scales by a supplied `h_open`. Once
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  began applying `period_length_col` for any count type (see the
  previous entry), a design carrying both multiplied by time twice — on
  a 4-day fixture with `h_open = 14` and T_d = 2 the aerial total went
  from 1400 to 2800, and the unit spine labelled that 2800
  “angler-hours”.

  This is a regression in the development version only; no released
  version applied T_d on those paths, so callers of released tidycreel
  are unaffected. Anyone who added `period_length_col` since that change
  should remove it and set the period length through `h_open` instead.
  Camera’s ratio-calibration path is deliberately unaffected: it divides
  by `mean(count)` before multiplying by `count`, so a constant T_d
  cancels out of the estimate.

- [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  now applies `period_length_col` to instantaneous counts instead of
  discarding it. Supplying the column on an instantaneous design used to
  be accepted, recorded in `design$period_length_col`, and then ignored
  — the estimate came back as the bare counts summed over days, with the
  T_d column left sitting unread in `design$counts`. Effort estimates
  move for anyone who passed it: on an 8-day fixture with T_d of 8–14
  hours the total went from 140 to 1780.

  An instantaneous count is a snapshot of how many anglers were present
  at one moment, not effort. Effort is that count times the length of
  the period it was randomised within, Ê_d = C̄\_d × T_d (Hoenig et
  al. 1993). The multiplication happens per PSU at attach time, so the
  ungrouped, grouped, sectioned and within-day-variance paths all
  inherit it, and multi-count PSUs get their `ss_d` scaled by T_d² so
  the within-day variance stays in effort² units.

  Applying T_d per date rather than after aggregation is deliberate: the
  collapsed form computes C̄ × T̄ where the target is the mean of C × T,
  and the two differ by Cov(C, T). Anglers fish more on long days, so
  that covariance is positive and the collapsed form biases low.
  Multiplying per date makes the term exactly zero at any stratum width,
  which removes the constraint on stratum design that would otherwise
  follow from T varying within a stratum.

  The positive-and-finite check on `period_length_col` now runs wherever
  the column is supplied. It previously lived inside the
  progressive-only block, so a zero or negative period passed unchecked
  on an instantaneous design.

- `n_anglers` now means a party size, not a tidyselect column position.
  It was resolved through
  [`tidyselect::eval_select()`](https://tidyselect.r-lib.org/reference/eval_select.html),
  where a bare integer selects a *column by position*, so
  `n_anglers = 1L` — the literal in
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)’s
  own signature — selected column 1 and multiplied effort by whatever it
  held. On interviews whose first column is numeric that silently
  produced `.angler_effort = hours × <that column>`; on the shipped
  column order it failed with `* not defined for "Date" objects`, naming
  neither the argument nor the column it chose. Which of the two you got
  depended on your column order. It also set
  `n_anglers_supplied = TRUE`, switching off the warning that exists to
  catch exactly this mismatch.

  A bare number is now a constant party size: `n_anglers = 1` states
  that every interview is a single angler, and `n_anglers = 3` that
  every party held three. Bare column names are unaffected. This is also
  the only way to declare a genuinely solo-angler survey, and therefore
  to silence the party-hours warning above without inventing a constant
  column.

  Party sizes are now validated wherever they come from. Zero, negative
  and non-finite values abort — a party of no anglers would silently
  zero out that interview’s effort — missing values abort as a stated
  constant but warn as a column, and non-integer values warn.
  [`compute_angler_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_angler_effort.md)
  follows the same contract; it is the other exported entry point that
  writes `.angler_effort`.

- Bus-route and ice totals now count **completed trips only**, in all
  three quantities.
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  already filtered;
  [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
  and
  [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
  did not, so on one design the three totals were computed over
  different row sets and could not be compared. On a 24-interview
  fixture split 12 complete / 12 incomplete, total catch was 1089.81
  over 24 rows where the completed-trip figure is 512.31 over 12 — a
  factor of 2.13.

  These are access-point estimators (Malvestuto 1996, §20.3.1.2), and
  §20.5.1 builds them by summing completed-trip quantities over
  interviews. An uncompleted trip breaks that in two directions at once:
  the observed count is catch *so far* rather than the trip’s catch,
  biasing the sum **down**, while is the inclusion probability of a
  *completed* trip and an uncompleted one is intercepted with
  probability proportional to its length (length-of-stay bias,
  §20.3.1.1), biasing it **up**. The two do not cancel predictably.
  Incomplete trips support a rate — the truncated Hájek mean of ratios
  of Hoenig et al. (1997), reachable via
  `estimate_catch_rate(use_trips = "incomplete")` — never a total
  ([\#112](https://github.com/chrischizinski/tidycreel/issues/112)).

- `estimate_total_catch(use_trips = "all")` now **aborts** on bus-route
  and ice designs. It was previously accepted and silently discarded:
  `"all"` and `"complete"` returned the same unfiltered number, so the
  argument documented as selecting trips did nothing at all on these
  designs. `"complete"` is the default and is unaffected, so callers
  passing nothing see no change beyond the completed-trip filter above
  ([\#112](https://github.com/chrischizinski/tidycreel/issues/112)).

- [`estimate_angler_trips()`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_trips.md)
  and
  [`estimate_effort_per_acre()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort_per_acre.md)
  now reject any `creel_estimates` whose `method` is outside the effort
  family (`"total"`, `"total-sections"`). Both are documented as taking
  angler-hours but guarded only on class, so a CPUE object passed
  straight through: fish per hour divided by hours per trip, relabelled
  `"angler-trips"`, no warning. A fish-valued bus-route total was
  accepted the same way
  ([\#112](https://github.com/chrischizinski/tidycreel/issues/112)).

- [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  and
  [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
  on a bus-route or ice design now report `method = "ht-total-catch"`,
  `"ht-total-harvest"` and `"ht-total-release"` respectively, in place
  of the bare `"total"` all three returned. `"total"` is the string the
  labelling code maps to *effort*, so a fish-valued total plotted with a
  y-axis and title reading “Total Effort” and exported a CSV whose
  provenance header read `Method: total` — nothing in the returned
  object said which quantity it held. On an eight-day bus-route fixture
  the catch total of 1089.81 fish and the harvest total of 464.77 fish
  both plotted as “Total Effort” beside a genuine effort total of
  2513.38 angler-hours. The estimates themselves are unchanged; only the
  method string and the labels derived from it move.
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  still returns `"total"`, which was correct for it all along.

  The `ht-` prefix names the estimator as well as the quantity,
  following the existing `product-total-*` convention, so a bus-route
  Horvitz–Thompson total is no longer indistinguishable from the
  standard design’s effort × rate product in either the object or the
  exported file
  ([\#111](https://github.com/chrischizinski/tidycreel/issues/111)).

- [`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md)
  gains `truncate_at`, defaulting to `0.5` hours, with the same meaning,
  units, and `NULL` behaviour it has on
  [`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md).
  It applies only to the bus-route incomplete-trip path
  ([\#110](https://github.com/chrischizinski/tidycreel/issues/110)).

- `estimate_total_release(design, by = species)` and
  `estimate_release_rate(design, by = species)` on a bus-route or ice
  design now abort with `Column 'species' doesn't exist` rather than
  returning a number from the standard path. The bus-route
  Horvitz–Thompson estimators take no species argument, and `by`
  resolves against the interview table, where a species column does not
  exist.
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  and
  [`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md)
  have behaved this way since their own dispatches landed; per-species
  release on these designs was never estimated from the sampling frame
  ([\#110](https://github.com/chrischizinski/tidycreel/issues/110)).

- [`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md)
  on a bus-route or ice design now returns a rate. It dispatched to the
  Horvitz–Thompson harvest **total** of Jones & Pollock (2012) Eq. 19.5
  and returned it with `method = "total"`, so it produced a number
  identical to
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  under a function documented as returning fish per angler-hour
  ([\#107](https://github.com/chrischizinski/tidycreel/issues/107)).

  Jones & Pollock give bus-route effort and harvest as HT totals and
  define no rate estimator, so the rate this design supports is the
  ratio of those two totals, `H_hat / E_hat` — the ratio-of-means form,
  and the same quantity and `method` string (`"ratio-of-means-hpue"`)
  the standard designs already return. The ratio is computed with
  [`survey::svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html)
  rather than by dividing two separately estimated totals: the numerator
  and denominator come from the same interviews and are strongly
  correlated, and treating them as independent overstates the SE by
  roughly eightfold on the package’s own fixture.

  Grouped results no longer carry a `proportion` column. A
  share-of-total is meaningful for a total and meaningless for a rate.

- `estimate_harvest_rate(use_trips = "incomplete")` on a bus-route
  design now returns a rate. It computed a per-angler ratio, divided
  that ratio by the inclusion probability, and summed.
  Inverse-probability weights apply to totals, not to ratios, so the
  result was neither the population rate nor a total: it **grew linearly
  with the number of interviews**. On a fixture where every angler
  harvests at 1 fish per angler-hour it returned 19.2, 38.3, and 76.7 as
  the same population was sampled with 4, 8, and 16 interviews. It also
  dropped the `.expansion` factor the complete-trip path applies, and
  divided by the party’s elapsed hours rather than angler-hours, so the
  underlying ratio was fish per party-hour
  ([\#108](https://github.com/chrischizinski/tidycreel/issues/108)).

  The path now returns the estimator this trip type supports: the
  truncated mean of ratios of Hoenig, Jones, Pollock, Robson & Wade
  (1997, *Biometrics* 53:306–317), reported as
  `method = "mean-of-ratios-hpue"`. For anglers intercepted mid-trip
  they show ratio-of-means weights individual rates by the *square* of
  completed trip length and so “does not provide an estimate of catch
  rate that can be used with an independent estimate of total effort to
  provide an unbiased estimate of total catch”; the mean of ratios has
  the correct expectation. Because interviews are not equally likely
  under a bus-route design, the mean is weighted by `.expansion / .pi_i`
  — a Hájek mean rather than the paper’s plain average — and computed
  with
  [`survey::svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html)
  so the variance is linearised over numerator and denominator together.

- [`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md)
  gains `truncate_at`, defaulting to `0.5` hours. The mean-of-ratios
  estimator has *infinite* asymptotic variance, because `1/L` has
  infinite expectation as trip length approaches zero; Hoenig et al.

  1997. recommend discarding trips shorter than 30 minutes. The
        threshold applies to elapsed trip duration, not to angler-hours
        — it is the short clock interval that makes the reciprocal
        explode, and a large party fishing briefly clears an angler-hour
        threshold while still being the unstable case.
        `truncate_at = NULL` disables truncation and warns. The argument
        is ignored on every other path, including
        `use_trips = "complete"`.

- `use_trips = "diagnostic"` on a bus-route design now compares like
  with like. Its two slots held a harvest total and a quantity that grew
  with sample size, so the gap read as enormous incomplete-trip bias
  when it was a change of physical units. Both slots now report fish per
  angler-hour. They remain different estimators — ratio of HT totals for
  complete trips, truncated mean of ratios for incomplete ones — because
  each is the estimator its trip type supports. A design carrying only
  one trip type now aborts with a clear message instead of failing
  inside `survey` with “all arguments must have the same length”, and
  the `verbose` dispatch message names the estimator actually used
  rather than always announcing the complete-trip one.

- Bus-route and ice
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  now return angler-hours. They read the raw per-party trip duration, so
  the estimate was party-hours reported under an angler-hours label —
  invariant to party size, and understated by exactly the mean party
  size in any boat fishery. They now read the angler-effort column
  (duration × `n_anglers`) that every other rate estimator already used.
  On the same design CPUE is fish per angler-hour, so the old behaviour
  also mixed denominators in any effort × CPUE product
  ([\#106](https://github.com/chrischizinski/tidycreel/issues/106)).

  Surveys recording one angler per party are unaffected: with no
  `n_anglers`, angler-effort equals the raw effort, and
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  already warns. Anything with parties larger than one will see totals
  rise by roughly the mean party size. The ice output column
  `total_effort_hr_on_ice` is affected on the same terms.

- [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  gains a `count_col` argument and no longer picks the count column by
  position. Previously the count variable was taken as the first numeric
  column that was not design metadata, so a counts table carrying more
  than one numeric column could have a row index, a daylight-hours
  column, or a boat count silently expanded and reported as “Total
  Effort” — off by an order of magnitude, with no warning. When more
  than one numeric column qualifies,
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  now aborts and lists the candidates; name the intended column with
  `count_col`. Tables with a single count column are unaffected
  ([\#105](https://github.com/chrischizinski/tidycreel/issues/105)).

  The resolved name is stored on the design as `$count_col` and used by
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
  the sections and grouped effort paths, the aerial and aerial-GLMM
  estimators, camera effort,
  [`audit_strata()`](https://chrischizinski.github.io/tidycreel/reference/audit_strata.md),
  and
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html),
  all of which previously repeated the same positional guess.

  Callers of `tidycreel.connect::fetch_counts()` are affected: it
  returns `bank_anglers`, `angler_boats`, and `non_ang_boats`, so
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  now requires `count_col` to be named.

### Documentation

- The progressive count articles now state the conditions under which is
  unbiased. `vignettes/progressive-count-surveys.Rmd` gains a
  *Conditions for an Unbiased Estimate* section covering Hoenig et al.’s

  1993. three requirements — random starting location, randomly chosen
        direction of travel, and an observer who outpaces the anglers —
        plus two cautions from the same paper: do not interrupt the
        circuit to interview, and do not read the count as a number of
        trips, which “results in a negative bias that can be severe.”

  None of these are checkable from the counts table, which is why they
  belong in prose rather than in a guard.

  `vignettes/effort-pipeline.Rmd` previously derived the cancellation
  through an unmotivated that returned the expression to . It now
  follows the source’s two-step argument — expand the sampled block by ,
  then scale by the blocks in the day — which reaches the same formula
  and shows why cancels: it defines the blocks the count was scheduled
  within, so it has done its work before the estimator runs.

  Also corrected: the “circuit time \< 30% of ” rule of thumb was not
  from Hoenig et al. and is not the paper’s condition.

- [`estimate_mr_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_mr_harvest.md)
  attributed its known-constant harvest rate to Hansen & Van Kirk
  (2018), which does the opposite: both factors of that rate are
  estimated there, given log-normal sampling distributions, and
  resampled alongside in the bootstrap behind every harvest CI. The
  simplification is this package’s, so the reported `se` is a lower
  bound on the true uncertainty, and `@details` now says so rather than
  crediting a source.

  `harvest_rate` also gains the period it was missing. In the paper’s
  the multiplier on the angler population is — days fished per angler
  times daily harvest per angler — so the argument must cover the same
  period `angler_n` counts anglers for. “Fish per angler” alone did not
  pin that down, and the daily rate is the wrong one.

- [`estimate_angler_n()`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_n.md)
  documents that its Chapman and Petersen confidence intervals are
  symmetric and can fall below zero. is a ratio with a small integer
  denominator, so it is right-skewed; at `M = 200`, `n = 50`, `m = 3`
  the reported `ci_lower` is `-2124.8`, and
  [`estimate_mr_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_mr_harvest.md)
  inherits the shape. Chapman is recommended precisely when recaptures
  are few, so the docs now direct small- users to
  `ci_method = "bootstrap"`, whose percentile bounds respect the skew.
  The Schnabel branch already inverts Poisson quantiles and is
  unaffected. The interval arithmetic is unchanged in this release —
  correcting it moves every shipped Chapman and Petersen bound.

- [`estimate_exploitation_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_exploitation_rate.md)
  described `C` as a harvest total while pointing at
  [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
  to produce it. Catch includes released fish, which were never removed
  from the tagged cohort, so a catch total inflates by the release
  fraction. `@param C`, `@param strata` and
  `vignettes/mark-recapture.Rmd` now point at
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  and say why. The estimator is unchanged; only the cross-reference was
  wrong.

  Noted in the docs because no check can catch it: both totals are
  counts of fish and both carry `unit = "fish"`, so the expression is
  dimensionally coherent. The actor matches and the quantity does not.

- `vignettes/flexible-count-estimation.Rmd`: the instantaneous baseline
  built an `open_hours` column that no tidycreel function reads, so the
  example looked like it accounted for the length of the fishing day
  while reporting 135 where its own stated formula gives 1350 — a 10x
  understatement in the vignette teaching this exact topic. The inert
  column is removed and the units of the instantaneous estimate
  (angler-days, not angler-hours) are now stated explicitly
  ([\#113](https://github.com/chrischizinski/tidycreel/issues/113)).

- `vignettes/progressive-count-surveys.Rmd`: the “Multiple Periods per
  Day” example built `open_hours` and `shift_hours` and passed neither,
  so it demonstrated the instantaneous multi-count path inside the
  progressive article. Both inert columns are removed and the text now
  says the chunk shows the within-day variance decomposition only,
  without the progressive `T_d` expansion
  ([\#113](https://github.com/chrischizinski/tidycreel/issues/113)).

- Inert `open_hours` calendar columns are removed from the six remaining
  places they appeared — `vignettes/progressive-count-surveys.Rmd`,
  `vignettes/effort-pipeline.Rmd` and
  `vignettes/temporal-extrapolation.Rmd`.
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
  reads only the date and the strata, so the column was never consulted
  anywhere it was written. The progressive article additionally listed
  the calendar’s `open_hours` as the the estimator applies; the real
  travels with the count data and is passed as `period_length_col`
  ([\#113](https://github.com/chrischizinski/tidycreel/issues/113)).

- `vignettes/tidycreel.Rmd`: two reported values had drifted from what
  the chunks print. The total effort estimate is 372.5 angler-hours, not
  the 358 claimed, and the grouped estimates are 201.9 weekend / 170.6
  weekday, not 250 / 108. The grouped comparison now notes that the
  calendar holds 10 weekdays to 4 weekend days, so a weekend total 18%
  higher is a per-day rate about three times higher. The article also
  called `example_counts` “instantaneous count observations” when the
  column holds angler-hours already accumulated over the day
  ([\#113](https://github.com/chrischizinski/tidycreel/issues/113)).

- `example_counts` and `example_sections_counts` documented their
  `effort_hours` column as an instantaneous count *of angler-hours*,
  which is two different quantities at once. Both now state that the
  column holds angler-hours, and that
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  expands whatever column it is given without converting units — raw
  counts in, angler-days out
  ([\#113](https://github.com/chrischizinski/tidycreel/issues/113)).

- `vignettes/glossary.Rmd` sanctioned the same ambiguity by defining
  count data as “the observed angler count or angler-hours”. It now
  states that both are accepted, that no conversion happens, and which
  unit each choice returns
  ([\#113](https://github.com/chrischizinski/tidycreel/issues/113)).

- `vignettes/ice-fishing.Rmd` described
  [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
  as CPUE times effort over all interviews. On ice designs it is a
  Horvitz–Thompson sum with no CPUE term and no effort term, over
  complete trips only — 60 of the vignette’s 72 interviews — and
  `use_trips = "all"` is refused. The standard error comes from Taylor
  linearization, not the delta method the text credited
  ([\#113](https://github.com/chrischizinski/tidycreel/issues/113)).

## tidycreel 2.5.0 “Creek Chub” (2026-06-30)

### New features

- [`generate_progressive_start()`](https://chrischizinski.github.io/tidycreel/reference/generate_progressive_start.md)
  schedules randomised circuit start times for progressive count surveys
  following Hoenig et al. (1993). Two strategies supported: `"discrete"`
  (start drawn from valid τ-aligned offsets; avoids mid-day bias from
  the common `U[0, T−τ]` error) and `"wraparound"` (start drawn from
  `U[0, T)` with wrap detection). Returns a `creel_schedule` with
  `circuit_start`, `circuit_end`, `is_wrapped`, and `direction` columns.

### Bug fixes

- [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  with `count_type = "progressive"`: multi-circuit designs (multiple
  counts per day via `count_time_col`) were previously blocked with an
  error. Now supported — daily effort is estimated as `mean(C_k) × T_d`
  across circuits.

- [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  multi-circuit progressive: within-day variance `ss_d` was in count²
  units but `compute_within_day_var_contribution()` requires effort²
  units. `ss_d` is now scaled by `T_d²` per PSU before the progressive
  effort computation, correcting variance estimates for multi-circuit
  designs.

- [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  progressive: `period_length_col` was incorrectly included in the
  numeric column scan used to auto-detect the count variable, causing it
  to be misidentified as the count. Now excluded from the scan.

- [`simulate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/simulate_creel_data.md):
  minimum trip effort floor raised from 0.05 h to 0.1 h to reduce
  implausibly short simulated fishing trips.

## tidycreel 2.4.0 “Bowfin” (2026-06-25)

### New features

- [`est_age_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_age_distribution.md)
  estimates proportional age structure with SE and confidence intervals
  from age-frequency interview data, fully integrated with the
  `creel_design` workflow. Stratified and grouped estimation supported.

- [`est_mean_age()`](https://chrischizinski.github.io/tidycreel/reference/est_mean_age.md)
  estimates mean age (± SE, CI) from structured interview data.
  Complements
  [`est_age_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_age_distribution.md)
  for reporting age-structured harvest results.

- `example_ages` — new built-in dataset of simulated age observations
  for use in examples and tests.

- [`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md)
  gains species-level dispatch: pass a species column and the function
  routes harvest-rate estimation independently per species, returning a
  tidy multi-species result in a single call.

- [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
  gains `open_start` parameter for GLMM aerial designs, allowing the
  survey window to be anchored to the count time rather than requiring a
  fixed open time.

### Bug fixes

#### Statistical correctness

- [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
  [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md):
  strata with effort but no interview coverage were silently dropped by
  an inner join in `compute_stratum_product_sum()`, biasing season
  totals low. Fixed to warn and retain all effort strata (#Tier1-Bug1).

- [`estimate_angler_trips()`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_trips.md):
  [`stats::sd()`](https://rdrr.io/r/stats/sd.html) on a single-interview
  stratum returned `NA`, propagating silently into SE and CI. Guard
  added for `n < 2`; emits `cli_warn()` and returns `NA_real_` for SE so
  the point estimate remains usable (#Tier1-Bug2).

- [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md):
  finite population correction (FPC) was not applied to the expanded
  effort `svydesign`, causing inflated SE for designs with high sampling
  fractions. Fixed (#Tier1-Bug5-adjacent).

- [`optimal_n()`](https://chrischizinski.github.io/tidycreel/reference/optimal_n.md):
  named `cost_ratio` vectors were applied positionally instead of by
  stratum name, producing wrong allocations when stratum order differed.
  Zero variance (`all s2_h = 0`) and zero total (`all ybar_h = 0`)
  produced silent `NaN`; both now abort with informative errors.
  `n_total` floored at 1 to prevent degenerate zero-sample result.

- [`adjust_nonresponse()`](https://chrischizinski.github.io/tidycreel/reference/adjust_nonresponse.md):
  `method = "calibrate"` was accepted and matched but silently ignored —
  both methods used direct weight rescaling. Now aborts with an
  informative error directing users to
  [`survey::calibrate()`](https://rdrr.io/pkg/survey/man/calibrate.html)
  directly (#Tier1-Bug4).

- [`adjust_nonresponse()`](https://chrischizinski.github.io/tidycreel/reference/adjust_nonresponse.md)
  replicate-design path: `svy$scale` (a variance formula constant) was
  multiplied by `mean(wt_multipliers)`, affecting only variance and
  using an average instead of per-observation values. Fixed to scale
  `svy$pweights` per-observation and `svy$repweights` row-wise
  (#Tier1-Bug5).

#### Validation and scheduling

- `new_creel_validation()`: `all(logical(0)) == TRUE` caused a 0-row
  results object to silently report `passed = TRUE`. Fixed with
  `nrow > 0` guard; empty validation results now correctly return
  `passed = FALSE`.

- `design-validator`: `ybar_h`, `s2_h`, and `n_proposed` were consumed
  positionally against named `N_h`, producing wrong stratum indexing
  when order differed. All three now rekeyed by `strata_names` before
  indexing.

- [`validate_incomplete_trips()`](https://chrischizinski.github.io/tidycreel/reference/validate_incomplete_trips.md):
  `perform_tost()` crashed or silently passed when `se_diff == 0`
  (identical SEs) or `df <= 0` (`n = 1` group). Early- return guards
  added for both degenerate cases;
  [`isTRUE()`](https://rdrr.io/r/base/Logic.html) used in grouped-
  passed aggregation to prevent `NA` propagating into `if()`.

- `schedule_generators()`: `inclusion_prob` could silently exceed 1 when
  `p_site * (crew / n_circuits) > 1`. Now aborts with an actionable
  message.

#### Reporting helpers

- `creel_palette(n)`: modular recycling used 0-based index at
  palette-length multiples, returning `NA` at those positions. Fixed to
  1-based modular arithmetic.

- `coerce_schedule_columns()`: unconditional `as.integer(period_id)`
  silently coerced character labels (`"AM"` / `"PM"`) to all-`NA`,
  filtering all downstream rows. Now only coerces when all non-`NA`
  values are numeric strings; character period labels are preserved
  unchanged.

- [`compare_variance()`](https://chrischizinski.github.io/tidycreel/reference/compare_variance.md):
  Taylor and replicate SEs were paired by row position rather than
  stratum key. If the two estimators returned rows in different orders,
  divergence ratios were computed for mismatched strata. Fixed with a
  keyed join; group-column detection now derived from `x$by_vars` rather
  than a hardcoded exclusion list that would misclassify new output
  columns.

- [`validation_report()`](https://chrischizinski.github.io/tidycreel/reference/validation_report.md),
  [`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md),
  `hybrid_design()`: second positional string to `cli_abort()` /
  `cli_warn()` was silently dropped by cli’s argument handling. Merged
  into single message or named vector.

#### Age and length estimators

- [`est_age_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_age_distribution.md)
  and
  [`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md):
  per-group `n` was reporting the global interview count
  (`nrow(design$interviews)`) instead of the within-group count. Fixed
  to `nrow(wide)` per group, consistent with
  [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
  and
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md).

- [`est_age_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_age_distribution.md)
  and
  [`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md):
  `left_join()` was called inside the per-group loop against the full
  interviews table (constant across iterations). Replaced with
  [`match()`](https://rdrr.io/r/base/match.html) lookup and direct
  column assignment, eliminating repeated dplyr overhead.

### Documentation

- Added a Quarto Creel Report starter template under
  `inst/quarto/templates/creel-report/`. The template demonstrates a
  full season workflow — design, validation, estimation, and plotting —
  using `tidycreel` helpers end to end.

## tidycreel 2.3.0 “Northern Pike” (2026-06-22)

### Breaking changes

- [`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md)
  and
  [`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md)
  now default to `use_trips = "complete"` (previously
  `use_trips = "all"`). For standard (non-bus-route) designs that supply
  `trip_status`, HPUE and RPUE are now estimated from completed-trip
  interviews only. This is the statistically preferred default:
  incomplete-trip rates underestimate harvest and release when anglers
  keep or release additional fish after being interviewed (Hansen & Van
  Kirk 2010). The previous all-interview behavior is no longer the
  default but remains fully available.

  **To restore the previous behavior**, pass `use_trips = "all"`
  explicitly:

  ``` r

  estimate_harvest_rate(design, use_trips = "all")
  estimate_release_rate(design, use_trips = "all")
  ```

  Designs without a `trip_status` column are unaffected (the argument
  has no effect). Bus-route designs already defaulted to `"complete"`
  and are unchanged. Closes
  [\#69](https://github.com/chrischizinski/tidycreel/issues/69).

### Documentation

- Added a Quarto Creel Report starter template scaffold that uses the
  `tidycreel` design, validation, summary, and plotting helpers end to
  end.

## tidycreel 2.2.0 “Goldeye” (2026-06-17)

### New features

- [`simulate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/simulate_creel_data.md)
  now returns a `$schedule` component — a full-season calendar (one row
  per season day) with columns `date` (Date), `day_type` (character),
  and `sampled` (logical). Pass directly to
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
  as the `calendar` argument for a complete round-trip simulation
  pipeline with no manual column construction. Unsampled days receive a
  `day_type` drawn proportionally from the `day_types` distribution.
  Closes [\#68](https://github.com/chrischizinski/tidycreel/issues/68).

  ``` r

  sim <- simulate_creel_data(params = my_params, day_types = c(weekday = 5/7, weekend = 2/7))
  design <- creel_design(sim$schedule, date = date, strata = day_type) |>
    add_counts(sim$counts) |>
    add_interviews(sim$interviews,
      catch = "catch_total", effort = "hours_fished", harvest = "catch_kept",
      trip_status = "trip_status", n_anglers = "n_anglers", interview_type = "roving")
  ```

  **Note:** this changes the return structure from three components
  (`interviews`, `counts`, `catch`) to four (`schedule`, `interviews`,
  `counts`, `catch`). Code that checks names by position should switch
  to name-based access.

### Documentation

- [`simulate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/simulate_creel_data.md)
  `day_types` parameter now explicitly documents that the argument must
  be a named **numeric** vector (not a character vector), with a worked
  example showing the correct form `c(weekday = 5/7, weekend = 2/7)`.
- `@examples` block expanded with a multi-stratum simulation and the
  full round-trip pipeline from
  [`simulate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/simulate_creel_data.md)
  through
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
  and
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).

### Bug fixes / closed issues

- [`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md):
  added `custom_codes` argument (named character vector applied as a
  second AFS-NA pass), expanded AFS lookup table with Freshwater Drum
  (`"FRD"`), and corrected misleading “supply a custom code map”
  documentation that implied a non-existent function argument. Closes
  [\#66](https://github.com/chrischizinski/tidycreel/issues/66).
- [`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md)
  /
  [`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md):
  added `use_trips` argument (`"all"` default, `"complete"` to restrict)
  with `cli_inform` notice showing trip-status breakdown. Documented
  livewell-observable rationale and downward-bias risk (Hansen & Van
  Kirk 2010). Closes
  [\#65](https://github.com/chrischizinski/tidycreel/issues/65). Future
  default flip to `"complete"` tracked as
  [\#69](https://github.com/chrischizinski/tidycreel/issues/69).

## tidycreel 2.1.0 “Sauger” (2026-06-17)

### New features

- [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
  now auto-routes roving designs: when
  `add_interviews(..., interview_type = "roving")` is set and
  `use_trips` / `estimator` are not explicitly supplied, the function
  defaults to `use_trips = "all"` and `estimator = "mor"` (Hoenig et
  al. 1997), using all interviewed trips via mean-of-ratios rather than
  restricting to complete trips. Access-point designs
  (`interview_type = "access"`, the default) are unaffected. Explicit
  `use_trips` or `estimator` arguments always override the auto-route.
  Closes [\#67](https://github.com/chrischizinski/tidycreel/issues/67).

- New `use_trips = "all"` option for
  [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md):
  uses every interview (complete + incomplete) with the MOR estimator.
  Previously only `"complete"`, `"incomplete"`, and `"diagnostic"` were
  accepted.

### Bug fixes

- `estimate_catch_rate(by = species)` returned all-zero estimates when
  catch data contained only `"harvested"` and `"released"` rows (no
  `"caught"` rows). Fix was in source since v2.0.0 but the installed
  binary at the site-library was stale; reinstalling now picks up the
  correct aggregation logic. Closes
  [\#64](https://github.com/chrischizinski/tidycreel/issues/64).

### Documentation

- [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  `interview_type` parameter description corrected: now accurately
  states that `"roving"` triggers automatic estimator routing rather
  than carrying the false claim that the flag was “stored metadata
  only”.
- [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
  `use_trips` parameter and Details section updated to document `"all"`,
  roving auto-routing, and the access vs. roving distinction.

### Versioning

Starting with this release, tidycreel follows semantic versioning
(MAJOR.MINOR.PATCH) and names each MINOR release after a fish species
native to Nebraska or the Great Plains. v2.1.0 is named for the Sauger
(*Sander canadensis*), a walleye relative common in Nebraska’s large
rivers.

## tidycreel 1.9.0 (2026-05-25)

### New features

- [`estimate_angler_trips()`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_trips.md)
  — estimates angler trip counts (angler days) from effort and mean trip
  length using Delta Method variance propagation.
- [`estimate_effort_per_acre()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort_per_acre.md)
  — computes effort density (angler-hours per acre) by stratum from an
  extrapolated effort estimate and supplied acreage.
- [`summarize_boat_composition()`](https://chrischizinski.github.io/tidycreel/reference/summarize_boat_composition.md)
  — returns percent angler boats by month and day type, computed from
  the angler-boat and non-angler-boat count columns.
- [`summarize_by_zip()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_zip.md)
  — tabulates interview count and percentage by zip code from the
  interview zip code column.
- [`summarize_by_county()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_county.md)
  — maps zip codes to counties via zipcodeR and returns interview count
  and percentage by county; emits an informative error when zipcodeR is
  not installed.

### Documentation

- pkgdown site rebuilt at v1.9.0; all new functions appear in the
  reference index.
- tidycreel.connect bridge vignette updated: install block added
  (remotes::install_github), stale “not yet public” availability
  language removed throughout.
- GitHub bug report issue template gains an R version field (required).

### Tech debt

- WRITE-11: write_estimates() xlsx export path now covered by a passing
  round-trip test guarded with skip_if_not_installed(“writexl”) (TD-01
  carry-forward from v1.8.0).

## tidycreel 1.4.0 (2026-04-23)

### Quality, testing, and release readiness

- Closed the priority rOpenSci blocker set for the current release line:
  named condition classes at the key `cli_abort()` sites, formal
  lifecycle badges on experimental APIs, a valid `inst/CITATION`, and
  removal of the `scales` dependency from the package surface.
- Demoted `lubridate` from `Imports` to `Suggests` and added runtime
  install guards at user-facing schedule entry points.
- Threaded
  [`rlang::caller_env()`](https://rlang.r-lib.org/reference/stack.html)
  through the top-level bus-route estimator internals and relocated
  [`get_site_contributions()`](https://chrischizinski.github.io/tidycreel/reference/get_site_contributions.md)
  into the estimation layer to tighten call-frame quality and layering.
- Added `@family` tags across the exported surface so the pkgdown
  reference is grouped by workflow topic rather than a flat function
  list.
- Added snapshot regression coverage for
  [`print.creel_design()`](https://chrischizinski.github.io/tidycreel/reference/print.creel_design.md),
  [`print.creel_estimates_mor()`](https://chrischizinski.github.io/tidycreel/reference/print.creel_estimates_mor.md),
  and
  [`print.creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/print.creel_schedule.md).
- Added `quickcheck`-based property tests and generator helpers covering
  the highest-value implemented invariants: INV-01, INV-02, INV-03,
  INV-04, and INV-06.
- Added a CI-backed coverage gate with a documented local baseline of
  `86.27%`, Codecov configuration, and a project target of `85%`.

## tidycreel 1.3.0

### New features

- [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
  now accepts `estimator = "mortr"` for truncated mean-of-ratios
  (MORtr), which applies `truncate_at` as a mandatory threshold and
  labels the method `"mean-of-ratios-truncated-cpue"`.
- [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
  gains a `targeted` argument (default `TRUE`). Setting
  `targeted = FALSE` excludes zero-catch trips before MOR/MORtr
  estimation for incidental species workflows.
- [`power_creel()`](https://chrischizinski.github.io/tidycreel/reference/power_creel.md)
  provides a unified tidy entry point for pre-survey sample-size
  planning, wrapping
  [`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
  [`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md),
  and
  [`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md)
  into a single consistent interface with `mode = "effort_n"`,
  `"cpue_n"`, or `"power"`.
- [`compare_designs()`](https://chrischizinski.github.io/tidycreel/reference/compare_designs.md)
  compares multiple survey designs side by side from a named list of
  `creel_estimates` objects. An
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  method renders a forest plot of point estimates with confidence
  intervals.
- [`as_hybrid_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_hybrid_svydesign.md)
  constructs a hybrid access + roving survey design from combined
  access-point and roving-route count data.
- [`compare_variance()`](https://chrischizinski.github.io/tidycreel/reference/compare_variance.md)
  computes Taylor linearization vs. replicate (bootstrap or jackknife)
  standard errors side-by-side for any `creel_estimates` object.
- [`adjust_nonresponse()`](https://chrischizinski.github.io/tidycreel/reference/adjust_nonresponse.md)
  applies nonresponse weighting to a `creel_design` and records
  per-stratum diagnostics.
- [`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md)
  adds ratio-calibrated camera/time-lapse effort indexing.
- [`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md)
  adds weighted catch-at-length / size-structure estimation from
  attached length data.
- [`autoplot.creel_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_length_distribution.md)
  adds a plotting surface for weighted size-structure estimates.
- [`theme_creel()`](https://chrischizinski.github.io/tidycreel/reference/theme_creel.md)
  and
  [`creel_palette()`](https://chrischizinski.github.io/tidycreel/reference/creel_palette.md)
  add package-standard plot styling.

### Data validation and cleaning

- [`validate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_data.md)
  adds field-level schema validation for creel inputs.
- [`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md)
  adds canonical species-code standardisation helpers.
- [`validation_report()`](https://chrischizinski.github.io/tidycreel/reference/validation_report.md)
  adds formatted validation summaries that can be exported alongside
  other report-ready outputs.
- `creel_counts_toy` and `creel_interviews_toy` are now bundled example
  datasets for examples, tests, and documentation.

### Documentation and reporting

- Added a glossary vignette for package terminology and workflow
  language.
- Added a survey design toolbox vignette covering planning and
  pre-season tools.
- Added a flexdashboard report template scaffold under
  `inst/rmarkdown/templates/creel-dashboard/`.
- Expanded pkgdown/reference discoverability for the newer estimation,
  visualisation, and reporting surfaces.
- The full pkgdown site now rebuilds cleanly after normalizing older
  vignette header/title inconsistencies.

### Improvements

- [`plot_design()`](https://chrischizinski.github.io/tidycreel/reference/plot_design.md)
  now supports multi-strata designs.
- Main estimator
  [`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
  methods now support opt-in `theme = "creel"` styling without changing
  default behavior.
- Single-PSU strata produce a structured, actionable error instead of an
  opaque `survey:::onestrat` message.
- Fixed a bug in the `aerial-glmm` vignette downstream estimation chunk
  where `example_aerial_interviews` was paired with the wrong design
  object.

### Dependencies

- **ggplot2** added to `Imports` to support the `autoplot.*` methods.
- **flexdashboard** added to `Suggests` for the optional report
  template.

### Tests

- Expanded test coverage for the newer estimation, validation, plotting,
  and reporting surfaces shipped through the current 1.3.0 development
  line.

## tidycreel 1.2.0 (2026-04-08)

### New features

- [`summary.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/summary.creel_estimates.md)
  converts any estimate object to a `creel_summary` with human-readable
  column names (`Estimate`, `SE`, `CI Lower`, `CI Upper`, `N`). Includes
  [`print.creel_summary()`](https://chrischizinski.github.io/tidycreel/reference/print.creel_summary.md)
  and
  [`as.data.frame.creel_summary()`](https://chrischizinski.github.io/tidycreel/reference/as.data.frame.creel_summary.md)
  methods. Works for effort, CPUE, harvest rate, total catch, and
  grouped variants.

- [`flag_outliers()`](https://chrischizinski.github.io/tidycreel/reference/flag_outliers.md)
  identifies extreme values in a numeric column using Tukey’s IQR fence
  (`k = 1.5` default). Returns the input data frame with `is_outlier`,
  `outlier_reason`, `fence_low`, and `fence_high` columns appended, and
  emits a `cli` summary of flagged rows. Handles `n < 4`, empty input,
  and zero-row data frames gracefully.

- `ggplot2::autoplot.creel_estimates()` produces a point-and-errorbar
  plot from any `creel_estimates` object. Ungrouped estimates show a
  single point with confidence interval; grouped estimates show one
  point per group level, colour-coded.

- `ggplot2::autoplot.creel_schedule()` produces a monthly tile calendar
  from a `creel_schedule` object. Sampled dates are coloured by day type
  (weekday blue / weekend red); unsampled dates are shown in grey.
  Multiple months are displayed as vertically stacked facet panels.

### Improvements

- Single-PSU strata now produce a structured, actionable error instead
  of an opaque `survey:::onestrat` message. The error names the
  problematic stratum and suggests increasing the sampling rate or
  combining sparse strata.

- Fixed a bug in the `aerial-glmm` vignette downstream estimation chunk
  where `example_aerial_interviews` was paired with the GLMM design
  (built from `example_aerial_glmm_counts`). The chunk now uses the
  correct matching dataset (`example_aerial_counts` +
  `example_aerial_interviews`).

### Dependencies

- **ggplot2** added to `Imports` to support the new `autoplot.*`
  methods.

## tidycreel 1.1.0 (2026-04-02)

### New features

- [`generate_count_times()`](https://chrischizinski.github.io/tidycreel/reference/generate_count_times.md)
  adds three sampling strategies for allocating interview periods within
  a survey day: random, systematic, and fixed-interval. Supports a
  `seed` argument for reproducibility; returns a `creel_schedule` object
  compatible with
  [`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md).

- The `survey-scheduling` vignette now covers the full pre- and
  post-season planning workflow:
  [`generate_count_times()`](https://chrischizinski.github.io/tidycreel/reference/generate_count_times.md)
  through
  [`validate_design()`](https://chrischizinski.github.io/tidycreel/reference/validate_design.md),
  [`check_completeness()`](https://chrischizinski.github.io/tidycreel/reference/check_completeness.md),
  and
  [`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md).

### Documentation

- GitHub issue templates now use structured forms with
  `blank_issues_enabled: false`, routing how-to questions to GitHub
  Discussions to keep answers searchable for all users.

- `CONTRIBUTING.md` has been rewritten with current workflow guidance,
  contribution types, and community norms for the v1.x release line.

## tidycreel 1.0.0 (2026-03-31)

- Launched the pkgdown documentation site at
  <https://chrischizinski.github.io/tidycreel> with a custom Bootstrap 5
  theme, full function reference index (46 exports + 15 datasets), and a
  workflow-driven navbar.

- Added a GitHub Actions CI/CD workflow to deploy the pkgdown site
  automatically on every push to main.
