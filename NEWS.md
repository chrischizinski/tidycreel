# tidycreel (development version)

## New features

* `day_length()` computes hours between sunrise and sunset for a latitude and
  date using the CBM model of Forsythe et al. (1995). Closed form — no lookup
  table, no network access, no location database. Only latitude is needed:
  longitude and time zone shift when sunrise and sunset occur, not the interval
  between them. `horizon` selects the depression angle, by name (`"sunset"`,
  `"civil"`, `"nautical"`, `"astronomical"`) or in degrees. Days inside the
  polar circles saturate at 0 or 24 hours rather than returning `NaN`.

  Day length is astronomical and is not the same quantity as the estimators'
  \eqn{T_d}, which is the period the counts were randomised within — a property
  of the survey design, set by regulation, access hours, or field protocol. Use
  `day_length()` for simulation and planning; pass the period your protocol
  actually used to `add_counts()`.

* `simulate_creel_data()` gains `lat` and `daylight_hours`, either of which adds
  `daylight_hours` and `angler_hours` columns to the simulated counts table.
  `lat` derives the daily period per date via `day_length()`; `daylight_hours`
  sets it directly, as a scalar or a named monthly vector, for surveys whose
  fishing day is fixed by regulation. Supplying both is an error.

  Supplying neither leaves both columns off, so the default output is unchanged.
  There is no honest default latitude, and substituting one would put a
  plausible number where the caller gave none.

## Bug fixes

* The product totals now warn when the rate and the effort they multiply are in
  different units. Without `n_anglers`, `add_interviews()` leaves `.angler_effort`
  equal to the raw effort column, so every rate is fish per *party*-hour while
  count-derived effort is angler-hours; both operands are individually correct but
  the product is not, unless every party is a single angler. `add_interviews()`
  informed at construction, but `design$angler_effort_col` was `".angler_effort"`
  either way, so nothing downstream could tell the two apart and nothing spoke up
  where the units actually collide. Designs now carry `n_anglers_supplied`, and
  `estimate_total_catch()`, `estimate_total_harvest()` and
  `estimate_total_release()` warn on the product path when it is `FALSE`.
  Bus-route and ice designs are unaffected: their totals are Horvitz–Thompson sums
  over interviews with no rate multiplication. The package's own examples now pass
  `n_anglers` (#112).

* `estimate_total_release()` and `estimate_release_rate()` had no bus-route
  dispatch, so on a bus-route or ice design they ran the count-based product
  path and ignored the inclusion probabilities entirely. The interview-derived
  release counts were divided by a `svytotal()` over count rows — a different
  effort basis from the one `estimate_effort()` reports for the same design,
  with no warning. On a fixture whose catch records set the released count equal
  to the harvest column interview by interview, so that the true release total
  *equals* the true harvest total, `estimate_total_harvest()` returned 465.4 and
  `estimate_total_release()` returned 51.1; the two now agree to machine
  precision. Bus-route designs carrying no counts aborted demanding
  `add_counts()`, which they do not need. `estimate_total_release_br()` had been
  correct and unreachable since it was written (#110).

* `estimate_release_rate()` on a bus-route design reaches the same estimators as
  `estimate_harvest_rate()`. `use_trips` accepts `"incomplete"` — the truncated,
  Hájek-weighted mean of ratios of Hoenig et al. (1997), reported as
  `method = "mean-of-ratios-rpue"` — and `"diagnostic"`, alongside the existing
  complete-trip ratio of Horvitz–Thompson totals
  (`method = "ratio-of-means-rpue"`). Both are releases per angler-hour (#110).

* `prep_counts_daily_effort()` and `prep_counts_boat_party()` emitted
  `n_counts` and `within_day_var` columns that `add_counts()` never read, so a
  within-day variance component supplied through the documented preferred seam
  was silently dropped and the reported SE omitted it entirely — biased
  **downward**, the dangerous direction. On an eight-day fixture with three
  counts per day the prep seam reported SE 6.93 where the equivalent
  `add_counts(count_time_col = )` route reported 9.52. `add_counts()` now reads
  both columns into `design$within_day_var`, and the two seams agree exactly
  (#109).

  The columns are also rescaled into `daily_effort` squared units on output —
  by `correction_factor^2`, and additionally by `mean_party_size^2` in the boat
  path. `daily_effort` is scaled by those factors but the sum of squares was
  passed through untouched, so wiring the slot up without rescaling would have
  left the within-day term a factor of `cf^2` away from the between-day term it
  is added to.

  `within_day_var` is now documented unambiguously as a **sum of squares**, not
  a variance: the estimator supplies the divisor itself, forming
  `sum(ss_d) / (n_sampled * (k_bar - 1))`, so a variance understates the
  component by a factor of `k_d - 1`. To make that contract enforceable,
  `within_day_var` now requires `n_counts`, must be non-negative, and must be
  `0` wherever `n_counts` is 1. Supplying the component through both the
  columns and `add_counts(count_time_col = )` is an error rather than a
  double count. Counts tables carrying neither column are unaffected.

## Breaking changes

* Bus-route and ice totals now count **completed trips only**, in all three
  quantities. `estimate_total_harvest()` already filtered; `estimate_total_catch()`
  and `estimate_total_release()` did not, so on one design the three totals were
  computed over different row sets and could not be compared. On a 24-interview
  fixture split 12 complete / 12 incomplete, total catch was 1089.81 over 24 rows
  where the completed-trip figure is 512.31 over 12 — a factor of 2.13.

  These are access-point estimators (Malvestuto 1996, §20.3.1.2), and §20.5.1
  builds them by summing completed-trip quantities over interviews. An uncompleted
  trip breaks that in two directions at once: the observed count is catch *so far*
  rather than the trip's catch, biasing the sum **down**, while \eqn{\pi_i} is the
  inclusion probability of a *completed* trip and an uncompleted one is intercepted
  with probability proportional to its length (length-of-stay bias, §20.3.1.1),
  biasing it **up**. The two do not cancel predictably. Incomplete trips support a
  rate — the truncated Hájek mean of ratios of Hoenig et al. (1997), reachable via
  `estimate_catch_rate(use_trips = "incomplete")` — never a total (#112).

* `estimate_total_catch(use_trips = "all")` now **aborts** on bus-route and ice
  designs. It was previously accepted and silently discarded: `"all"` and
  `"complete"` returned the same unfiltered number, so the argument documented as
  selecting trips did nothing at all on these designs. `"complete"` is the default
  and is unaffected, so callers passing nothing see no change beyond the
  completed-trip filter above (#112).

* `estimate_angler_trips()` and `estimate_effort_per_acre()` now reject any
  `creel_estimates` whose `method` is outside the effort family (`"total"`,
  `"total-sections"`). Both are documented as taking angler-hours but guarded only
  on class, so a CPUE object passed straight through: fish per hour divided by
  hours per trip, relabelled `"angler-trips"`, no warning. A fish-valued bus-route
  total was accepted the same way (#112).

* `estimate_total_catch()`, `estimate_total_harvest()` and
  `estimate_total_release()` on a bus-route or ice design now report
  `method = "ht-total-catch"`, `"ht-total-harvest"` and `"ht-total-release"`
  respectively, in place of the bare `"total"` all three returned. `"total"` is
  the string the labelling code maps to *effort*, so a fish-valued total plotted
  with a y-axis and title reading "Total Effort" and exported a CSV whose
  provenance header read `Method: total` — nothing in the returned object said
  which quantity it held. On an eight-day bus-route fixture the catch total of
  1089.81 fish and the harvest total of 464.77 fish both plotted as "Total
  Effort" beside a genuine effort total of 2513.38 angler-hours. The estimates
  themselves are unchanged; only the method string and the labels derived from
  it move. `estimate_effort()` still returns `"total"`, which was correct for it
  all along.

  The `ht-` prefix names the estimator as well as the quantity, following the
  existing `product-total-*` convention, so a bus-route Horvitz–Thompson total
  is no longer indistinguishable from the standard design's effort × rate
  product in either the object or the exported file (#111).

* `estimate_release_rate()` gains `truncate_at`, defaulting to `0.5` hours, with
  the same meaning, units, and `NULL` behaviour it has on
  `estimate_harvest_rate()`. It applies only to the bus-route incomplete-trip
  path (#110).

* `estimate_total_release(design, by = species)` and
  `estimate_release_rate(design, by = species)` on a bus-route or ice design now
  abort with `Column 'species' doesn't exist` rather than returning a number
  from the standard path. The bus-route Horvitz–Thompson estimators take no
  species argument, and `by` resolves against the interview table, where a
  species column does not exist. `estimate_total_harvest()` and
  `estimate_harvest_rate()` have behaved this way since their own dispatches
  landed; per-species release on these designs was never estimated from the
  sampling frame (#110).

* `estimate_harvest_rate()` on a bus-route or ice design now returns a rate. It
  dispatched to the Horvitz–Thompson harvest **total** of Jones & Pollock (2012)
  Eq. 19.5 and returned it with `method = "total"`, so it produced a number
  identical to `estimate_total_harvest()` under a function documented as
  returning fish per angler-hour (#107).

  Jones & Pollock give bus-route effort and harvest as HT totals and define no
  rate estimator, so the rate this design supports is the ratio of those two
  totals, `H_hat / E_hat` — the ratio-of-means form, and the same quantity and
  `method` string (`"ratio-of-means-hpue"`) the standard designs already return.
  The ratio is computed with `survey::svyratio()` rather than by dividing two
  separately estimated totals: the numerator and denominator come from the same
  interviews and are strongly correlated, and treating them as independent
  overstates the SE by roughly eightfold on the package's own fixture.

  Grouped results no longer carry a `proportion` column. A share-of-total is
  meaningful for a total and meaningless for a rate.

* `estimate_harvest_rate(use_trips = "incomplete")` on a bus-route design now
  returns a rate. It computed a per-angler ratio, divided that ratio by the
  inclusion probability, and summed. Inverse-probability weights apply to
  totals, not to ratios, so the result was neither the population rate nor a
  total: it **grew linearly with the number of interviews**. On a fixture where
  every angler harvests at 1 fish per angler-hour it returned 19.2, 38.3, and
  76.7 as the same population was sampled with 4, 8, and 16 interviews. It also
  dropped the `.expansion` factor the complete-trip path applies, and divided by
  the party's elapsed hours rather than angler-hours, so the underlying ratio
  was fish per party-hour (#108).

  The path now returns the estimator this trip type supports: the truncated
  mean of ratios of Hoenig, Jones, Pollock, Robson & Wade (1997, *Biometrics*
  53:306–317), reported as `method = "mean-of-ratios-hpue"`. For anglers
  intercepted mid-trip they show ratio-of-means weights individual rates by the
  *square* of completed trip length and so "does not provide an estimate of
  catch rate that can be used with an independent estimate of total effort to
  provide an unbiased estimate of total catch"; the mean of ratios has the
  correct expectation. Because interviews are not equally likely under a
  bus-route design, the mean is weighted by `.expansion / .pi_i` — a Hájek mean
  rather than the paper's plain average — and computed with `survey::svyratio()`
  so the variance is linearised over numerator and denominator together.

* `estimate_harvest_rate()` gains `truncate_at`, defaulting to `0.5` hours.
  The mean-of-ratios estimator has *infinite* asymptotic variance, because
  `1/L` has infinite expectation as trip length approaches zero; Hoenig et al.
  (1997) recommend discarding trips shorter than 30 minutes. The threshold
  applies to elapsed trip duration, not to angler-hours — it is the short clock
  interval that makes the reciprocal explode, and a large party fishing briefly
  clears an angler-hour threshold while still being the unstable case.
  `truncate_at = NULL` disables truncation and warns. The argument is ignored on
  every other path, including `use_trips = "complete"`.

* `use_trips = "diagnostic"` on a bus-route design now compares like with like.
  Its two slots held a harvest total and a quantity that grew with sample size,
  so the gap read as enormous incomplete-trip bias when it was a change of
  physical units. Both slots now report fish per angler-hour. They remain
  different estimators — ratio of HT totals for complete trips, truncated mean
  of ratios for incomplete ones — because each is the estimator its trip type
  supports. A design carrying only one trip type now aborts with a clear message
  instead of failing inside `survey` with "all arguments must have the same
  length", and the `verbose` dispatch message names the estimator actually used
  rather than always announcing the complete-trip one.

* Bus-route and ice `estimate_effort()` now return angler-hours. They read the
  raw per-party trip duration, so the estimate was party-hours reported under an
  angler-hours label — invariant to party size, and understated by exactly the
  mean party size in any boat fishery. They now read the angler-effort column
  (duration × `n_anglers`) that every other rate estimator already used. On the
  same design CPUE is fish per angler-hour, so the old behaviour also mixed
  denominators in any effort × CPUE product (#106).

  Surveys recording one angler per party are unaffected: with no `n_anglers`,
  angler-effort equals the raw effort, and `add_interviews()` already warns.
  Anything with parties larger than one will see totals rise by roughly the mean
  party size. The ice output column `total_effort_hr_on_ice` is affected on the
  same terms.

* `add_counts()` gains a `count_col` argument and no longer picks the count
  column by position. Previously the count variable was taken as the first
  numeric column that was not design metadata, so a counts table carrying more
  than one numeric column could have a row index, a daylight-hours column, or a
  boat count silently expanded and reported as "Total Effort" — off by an order
  of magnitude, with no warning. When more than one numeric column qualifies,
  `add_counts()` now aborts and lists the candidates; name the intended column
  with `count_col`. Tables with a single count column are unaffected (#105).

  The resolved name is stored on the design as `$count_col` and used by
  `estimate_effort()`, the sections and grouped effort paths, the aerial and
  aerial-GLMM estimators, camera effort, `audit_strata()`, and `autoplot()`,
  all of which previously repeated the same positional guess.

  Callers of `tidycreel.connect::fetch_counts()` are affected: it returns
  `bank_anglers`, `angler_boats`, and `non_ang_boats`, so `add_counts()` now
  requires `count_col` to be named.

## Documentation

* `vignettes/flexible-count-estimation.Rmd`: the instantaneous baseline built an
  `open_hours` column that no tidycreel function reads, so the example looked
  like it accounted for the length of the fishing day while reporting 135 where
  its own stated formula gives 1350 — a 10x understatement in the vignette
  teaching this exact topic. The inert column is removed and the units of the
  instantaneous estimate (angler-days, not angler-hours) are now stated
  explicitly (#113).

* `vignettes/progressive-count-surveys.Rmd`: the "Multiple Periods per Day"
  example built `open_hours` and `shift_hours` and passed neither, so it
  demonstrated the instantaneous multi-count path inside the progressive
  article. Both inert columns are removed and the text now says the chunk shows
  the within-day variance decomposition only, without the progressive `T_d`
  expansion (#113).

# tidycreel 2.5.0 "Creek Chub" (2026-06-30)

## New features

* `generate_progressive_start()` schedules randomised circuit start times for
  progressive count surveys following Hoenig et al. (1993). Two strategies
  supported: `"discrete"` (start drawn from valid τ-aligned offsets; avoids
  mid-day bias from the common `U[0, T−τ]` error) and `"wraparound"` (start
  drawn from `U[0, T)` with wrap detection). Returns a `creel_schedule` with
  `circuit_start`, `circuit_end`, `is_wrapped`, and `direction` columns.

## Bug fixes

* `add_counts()` with `count_type = "progressive"`: multi-circuit designs
  (multiple counts per day via `count_time_col`) were previously blocked with
  an error. Now supported — daily effort is estimated as `mean(C_k) × T_d`
  across circuits.

* `add_counts()` multi-circuit progressive: within-day variance `ss_d` was
  in count² units but `compute_within_day_var_contribution()` requires effort²
  units. `ss_d` is now scaled by `T_d²` per PSU before the progressive effort
  computation, correcting variance estimates for multi-circuit designs.

* `add_counts()` progressive: `period_length_col` was incorrectly included in
  the numeric column scan used to auto-detect the count variable, causing it to
  be misidentified as the count. Now excluded from the scan.

* `simulate_creel_data()`: minimum trip effort floor raised from 0.05 h to
  0.1 h to reduce implausibly short simulated fishing trips.

# tidycreel 2.4.0 "Bowfin" (2026-06-25)

## New features

* `est_age_distribution()` estimates proportional age structure with SE and
  confidence intervals from age-frequency interview data, fully integrated with
  the `creel_design` workflow. Stratified and grouped estimation supported.

* `est_mean_age()` estimates mean age (± SE, CI) from structured interview
  data. Complements `est_age_distribution()` for reporting age-structured
  harvest results.

* `example_ages` — new built-in dataset of simulated age observations for use
  in examples and tests.

* `estimate_harvest_rate()` gains species-level dispatch: pass a species column
  and the function routes harvest-rate estimation independently per species,
  returning a tidy multi-species result in a single call.

* `creel_design()` gains `open_start` parameter for GLMM aerial designs,
  allowing the survey window to be anchored to the count time rather than
  requiring a fixed open time.

## Bug fixes

### Statistical correctness

* `estimate_total_catch()`, `estimate_total_harvest()`,
  `estimate_total_release()`: strata with effort but no interview coverage were
  silently dropped by an inner join in `compute_stratum_product_sum()`, biasing
  season totals low. Fixed to warn and retain all effort strata (#Tier1-Bug1).

* `estimate_angler_trips()`: `stats::sd()` on a single-interview stratum
  returned `NA`, propagating silently into SE and CI. Guard added for `n < 2`;
  emits `cli_warn()` and returns `NA_real_` for SE so the point estimate
  remains usable (#Tier1-Bug2).

* `estimate_effort()`: finite population correction (FPC) was not applied to
  the expanded effort `svydesign`, causing inflated SE for designs with high
  sampling fractions. Fixed (#Tier1-Bug5-adjacent).

* `optimal_n()`: named `cost_ratio` vectors were applied positionally instead
  of by stratum name, producing wrong allocations when stratum order differed.
  Zero variance (`all s2_h = 0`) and zero total (`all ybar_h = 0`) produced
  silent `NaN`; both now abort with informative errors. `n_total` floored at 1
  to prevent degenerate zero-sample result.

* `adjust_nonresponse()`: `method = "calibrate"` was accepted and matched but
  silently ignored — both methods used direct weight rescaling. Now aborts with
  an informative error directing users to `survey::calibrate()` directly
  (#Tier1-Bug4).

* `adjust_nonresponse()` replicate-design path: `svy$scale` (a variance
  formula constant) was multiplied by `mean(wt_multipliers)`, affecting only
  variance and using an average instead of per-observation values. Fixed to
  scale `svy$pweights` per-observation and `svy$repweights` row-wise
  (#Tier1-Bug5).

### Validation and scheduling

* `new_creel_validation()`: `all(logical(0)) == TRUE` caused a 0-row results
  object to silently report `passed = TRUE`. Fixed with `nrow > 0` guard;
  empty validation results now correctly return `passed = FALSE`.

* `design-validator`: `ybar_h`, `s2_h`, and `n_proposed` were consumed
  positionally against named `N_h`, producing wrong stratum indexing when order
  differed. All three now rekeyed by `strata_names` before indexing.

* `validate_incomplete_trips()`: `perform_tost()` crashed or silently passed
  when `se_diff == 0` (identical SEs) or `df <= 0` (`n = 1` group). Early-
  return guards added for both degenerate cases; `isTRUE()` used in grouped-
  passed aggregation to prevent `NA` propagating into `if()`.

* `schedule_generators()`: `inclusion_prob` could silently exceed 1 when
  `p_site * (crew / n_circuits) > 1`. Now aborts with an actionable message.

### Reporting helpers

* `creel_palette(n)`: modular recycling used 0-based index at palette-length
  multiples, returning `NA` at those positions. Fixed to 1-based modular
  arithmetic.

* `coerce_schedule_columns()`: unconditional `as.integer(period_id)` silently
  coerced character labels (`"AM"` / `"PM"`) to all-`NA`, filtering all
  downstream rows. Now only coerces when all non-`NA` values are numeric
  strings; character period labels are preserved unchanged.

* `compare_variance()`: Taylor and replicate SEs were paired by row position
  rather than stratum key. If the two estimators returned rows in different
  orders, divergence ratios were computed for mismatched strata. Fixed with a
  keyed join; group-column detection now derived from `x$by_vars` rather than
  a hardcoded exclusion list that would misclassify new output columns.

* `validation_report()`, `standardize_species()`, `hybrid_design()`: second
  positional string to `cli_abort()` / `cli_warn()` was silently dropped by
  cli's argument handling. Merged into single message or named vector.

### Age and length estimators

* `est_age_distribution()` and `est_length_distribution()`: per-group `n` was
  reporting the global interview count (`nrow(design$interviews)`) instead of
  the within-group count. Fixed to `nrow(wide)` per group, consistent with
  `estimate_total_catch()` and `estimate_total_harvest()`.

* `est_age_distribution()` and `est_length_distribution()`: `left_join()` was
  called inside the per-group loop against the full interviews table (constant
  across iterations). Replaced with `match()` lookup and direct column
  assignment, eliminating repeated dplyr overhead.

## Documentation

* Added a Quarto Creel Report starter template under
  `inst/quarto/templates/creel-report/`. The template demonstrates a full
  season workflow — design, validation, estimation, and plotting — using
  `tidycreel` helpers end to end.

# tidycreel 2.3.0 "Northern Pike" (2026-06-22)

## Breaking changes

* `estimate_harvest_rate()` and `estimate_release_rate()` now default to
  `use_trips = "complete"` (previously `use_trips = "all"`). For standard
  (non-bus-route) designs that supply `trip_status`, HPUE and RPUE are now
  estimated from completed-trip interviews only. This is the statistically
  preferred default: incomplete-trip rates underestimate harvest and release
  when anglers keep or release additional fish after being interviewed (Hansen &
  Van Kirk 2010). The previous all-interview behavior is no longer the default
  but remains fully available.

  **To restore the previous behavior**, pass `use_trips = "all"` explicitly:

  ```r
  estimate_harvest_rate(design, use_trips = "all")
  estimate_release_rate(design, use_trips = "all")
  ```

  Designs without a `trip_status` column are unaffected (the argument has no
  effect). Bus-route designs already defaulted to `"complete"` and are
  unchanged. Closes #69.

## Documentation

* Added a Quarto Creel Report starter template scaffold that uses the
  `tidycreel` design, validation, summary, and plotting helpers end to end.

# tidycreel 2.2.0 "Goldeye" (2026-06-17)

## New features

* `simulate_creel_data()` now returns a `$schedule` component — a full-season
  calendar (one row per season day) with columns `date` (Date), `day_type`
  (character), and `sampled` (logical). Pass directly to `creel_design()` as
  the `calendar` argument for a complete round-trip simulation pipeline with no
  manual column construction. Unsampled days receive a `day_type` drawn
  proportionally from the `day_types` distribution. Closes #68.

  ```r
  sim <- simulate_creel_data(params = my_params, day_types = c(weekday = 5/7, weekend = 2/7))
  design <- creel_design(sim$schedule, date = date, strata = day_type) |>
    add_counts(sim$counts) |>
    add_interviews(sim$interviews,
      catch = "catch_total", effort = "hours_fished", harvest = "catch_kept",
      trip_status = "trip_status", n_anglers = "n_anglers", interview_type = "roving")
  ```

  **Note:** this changes the return structure from three components
  (`interviews`, `counts`, `catch`) to four (`schedule`, `interviews`,
  `counts`, `catch`). Code that checks names by position should switch to
  name-based access.

## Documentation

* `simulate_creel_data()` `day_types` parameter now explicitly documents that
  the argument must be a named **numeric** vector (not a character vector), with
  a worked example showing the correct form `c(weekday = 5/7, weekend = 2/7)`.
* `@examples` block expanded with a multi-stratum simulation and the full
  round-trip pipeline from `simulate_creel_data()` through `creel_design()`,
  `add_counts()`, and `add_interviews()`.

## Bug fixes / closed issues

* `standardize_species()`: added `custom_codes` argument (named character vector
  applied as a second AFS-NA pass), expanded AFS lookup table with Freshwater
  Drum (`"FRD"`), and corrected misleading "supply a custom code map"
  documentation that implied a non-existent function argument. Closes #66.
* `estimate_harvest_rate()` / `estimate_release_rate()`: added `use_trips`
  argument (`"all"` default, `"complete"` to restrict) with `cli_inform` notice
  showing trip-status breakdown. Documented livewell-observable rationale and
  downward-bias risk (Hansen & Van Kirk 2010). Closes #65. Future default flip
  to `"complete"` tracked as #69.

# tidycreel 2.1.0 "Sauger" (2026-06-17)

## New features

* `estimate_catch_rate()` now auto-routes roving designs: when
  `add_interviews(..., interview_type = "roving")` is set and `use_trips` /
  `estimator` are not explicitly supplied, the function defaults to
  `use_trips = "all"` and `estimator = "mor"` (Hoenig et al. 1997), using all
  interviewed trips via mean-of-ratios rather than restricting to complete trips.
  Access-point designs (`interview_type = "access"`, the default) are unaffected.
  Explicit `use_trips` or `estimator` arguments always override the auto-route.
  Closes #67.

* New `use_trips = "all"` option for `estimate_catch_rate()`: uses every
  interview (complete + incomplete) with the MOR estimator. Previously only
  `"complete"`, `"incomplete"`, and `"diagnostic"` were accepted.

## Bug fixes

* `estimate_catch_rate(by = species)` returned all-zero estimates when catch
  data contained only `"harvested"` and `"released"` rows (no `"caught"` rows).
  Fix was in source since v2.0.0 but the installed binary at the site-library
  was stale; reinstalling now picks up the correct aggregation logic. Closes #64.

## Documentation

* `add_interviews()` `interview_type` parameter description corrected: now
  accurately states that `"roving"` triggers automatic estimator routing rather
  than carrying the false claim that the flag was "stored metadata only".
* `estimate_catch_rate()` `use_trips` parameter and Details section updated to
  document `"all"`, roving auto-routing, and the access vs. roving distinction.

## Versioning

Starting with this release, tidycreel follows semantic versioning
(MAJOR.MINOR.PATCH) and names each MINOR release after a fish species native to
Nebraska or the Great Plains. v2.1.0 is named for the Sauger
(*Sander canadensis*), a walleye relative common in Nebraska's large rivers.

# tidycreel 1.9.0 (2026-05-25)

## New features

* `estimate_angler_trips()` — estimates angler trip counts (angler days) from effort and mean trip length using Delta Method variance propagation.
* `estimate_effort_per_acre()` — computes effort density (angler-hours per acre) by stratum from an extrapolated effort estimate and supplied acreage.
* `summarize_boat_composition()` — returns percent angler boats by month and day type, computed from raw count fields c_AnglerBoats and c_NonAngBoats.
* `summarize_by_zip()` — tabulates interview count and percentage by zip code from the ii_ZipCode interview field.
* `summarize_by_county()` — maps zip codes to counties via zipcodeR and returns interview count and percentage by county; emits an informative error when zipcodeR is not installed.

## Documentation

* pkgdown site rebuilt at v1.9.0; all new functions appear in the reference index.
* tidycreel.connect bridge vignette updated: install block added (remotes::install_github), stale "not yet public" availability language removed throughout.
* GitHub bug report issue template gains an R version field (required).

## Tech debt

* WRITE-11: write_estimates() xlsx export path now covered by a passing round-trip test guarded with skip_if_not_installed("writexl") (TD-01 carry-forward from v1.8.0).

# tidycreel 1.4.0 (2026-04-23)

## Quality, testing, and release readiness

* Closed the priority rOpenSci blocker set for the current release line:
  named condition classes at the key `cli_abort()` sites, formal lifecycle
  badges on experimental APIs, a valid `inst/CITATION`, and removal of the
  `scales` dependency from the package surface.
* Demoted `lubridate` from `Imports` to `Suggests` and added runtime install
  guards at user-facing schedule entry points.
* Threaded `rlang::caller_env()` through the top-level bus-route estimator
  internals and relocated `get_site_contributions()` into the estimation layer
  to tighten call-frame quality and layering.
* Added `@family` tags across the exported surface so the pkgdown reference is
  grouped by workflow topic rather than a flat function list.
* Added snapshot regression coverage for `print.creel_design()`,
  `print.creel_estimates_mor()`, and `print.creel_schedule()`.
* Added `quickcheck`-based property tests and generator helpers covering the
  highest-value implemented invariants: INV-01, INV-02, INV-03, INV-04, and
  INV-06.
* Added a CI-backed coverage gate with a documented local baseline of `86.27%`,
  Codecov configuration, and a project target of `85%`.

# tidycreel 1.3.0

## New features

* `estimate_catch_rate()` now accepts `estimator = "mortr"` for truncated
  mean-of-ratios (MORtr), which applies `truncate_at` as a mandatory threshold
  and labels the method `"mean-of-ratios-truncated-cpue"`.
* `estimate_catch_rate()` gains a `targeted` argument (default `TRUE`). Setting
  `targeted = FALSE` excludes zero-catch trips before MOR/MORtr estimation for
  incidental species workflows.
* `power_creel()` provides a unified tidy entry point for pre-survey
  sample-size planning, wrapping `creel_n_effort()`, `creel_n_cpue()`, and
  `creel_power()` into a single consistent interface with `mode = "effort_n"`,
  `"cpue_n"`, or `"power"`.
* `compare_designs()` compares multiple survey designs side by side from a
  named list of `creel_estimates` objects. An `autoplot()` method renders a
  forest plot of point estimates with confidence intervals.
* `as_hybrid_svydesign()` constructs a hybrid access + roving survey design
  from combined access-point and roving-route count data.
* `compare_variance()` computes Taylor linearization vs. replicate (bootstrap
  or jackknife) standard errors side-by-side for any `creel_estimates` object.
* `adjust_nonresponse()` applies nonresponse weighting to a `creel_design` and
  records per-stratum diagnostics.
* `est_effort_camera()` adds ratio-calibrated camera/time-lapse effort indexing.
* `est_length_distribution()` adds weighted catch-at-length / size-structure
  estimation from attached length data.
* `autoplot.creel_length_distribution()` adds a plotting surface for weighted
  size-structure estimates.
* `theme_creel()` and `creel_palette()` add package-standard plot styling.

## Data validation and cleaning

* `validate_creel_data()` adds field-level schema validation for creel inputs.
* `standardize_species()` adds canonical species-code standardisation helpers.
* `validation_report()` adds formatted validation summaries that can be exported
  alongside other report-ready outputs.
* `creel_counts_toy` and `creel_interviews_toy` are now bundled example datasets
  for examples, tests, and documentation.

## Documentation and reporting

* Added a glossary vignette for package terminology and workflow language.
* Added a survey design toolbox vignette covering planning and pre-season tools.
* Added a flexdashboard report template scaffold under
  `inst/rmarkdown/templates/creel-dashboard/`.
* Expanded pkgdown/reference discoverability for the newer estimation,
  visualisation, and reporting surfaces.
* The full pkgdown site now rebuilds cleanly after normalizing older vignette
  header/title inconsistencies.

## Improvements

* `plot_design()` now supports multi-strata designs.
* Main estimator `autoplot()` methods now support opt-in
  `theme = "creel"` styling without changing default behavior.
* Single-PSU strata produce a structured, actionable error instead of an opaque
  `survey:::onestrat` message.
* Fixed a bug in the `aerial-glmm` vignette downstream estimation chunk where
  `example_aerial_interviews` was paired with the wrong design object.

## Dependencies

* **ggplot2** added to `Imports` to support the `autoplot.*` methods.
* **flexdashboard** added to `Suggests` for the optional report template.

## Tests

* Expanded test coverage for the newer estimation, validation, plotting, and
  reporting surfaces shipped through the current 1.3.0 development line.

# tidycreel 1.2.0 (2026-04-08)

## New features

* `summary.creel_estimates()` converts any estimate object to a `creel_summary`
  with human-readable column names (`Estimate`, `SE`, `CI Lower`, `CI Upper`,
  `N`). Includes `print.creel_summary()` and `as.data.frame.creel_summary()`
  methods. Works for effort, CPUE, harvest rate, total catch, and grouped
  variants.

* `flag_outliers()` identifies extreme values in a numeric column using
  Tukey's IQR fence (`k = 1.5` default). Returns the input data frame with
  `is_outlier`, `outlier_reason`, `fence_low`, and `fence_high` columns
  appended, and emits a `cli` summary of flagged rows. Handles `n < 4`,
  empty input, and zero-row data frames gracefully.

* `ggplot2::autoplot.creel_estimates()` produces a point-and-errorbar plot
  from any `creel_estimates` object. Ungrouped estimates show a single point
  with confidence interval; grouped estimates show one point per group level,
  colour-coded.

* `ggplot2::autoplot.creel_schedule()` produces a monthly tile calendar from
  a `creel_schedule` object. Sampled dates are coloured by day type (weekday
  blue / weekend red); unsampled dates are shown in grey. Multiple months are
  displayed as vertically stacked facet panels.

## Improvements

* Single-PSU strata now produce a structured, actionable error instead of an
  opaque `survey:::onestrat` message. The error names the problematic stratum
  and suggests increasing the sampling rate or combining sparse strata.

* Fixed a bug in the `aerial-glmm` vignette downstream estimation chunk where
  `example_aerial_interviews` was paired with the GLMM design (built from
  `example_aerial_glmm_counts`). The chunk now uses the correct matching
  dataset (`example_aerial_counts` + `example_aerial_interviews`).

## Dependencies

* **ggplot2** added to `Imports` to support the new `autoplot.*` methods.

# tidycreel 1.1.0 (2026-04-02)

## New features

* `generate_count_times()` adds three sampling strategies for allocating
  interview periods within a survey day: random, systematic, and
  fixed-interval. Supports a `seed` argument for reproducibility; returns a
  `creel_schedule` object compatible with `write_schedule()`.

* The `survey-scheduling` vignette now covers the full pre- and post-season
  planning workflow: `generate_count_times()` through `validate_design()`,
  `check_completeness()`, and `season_summary()`.

## Documentation

* GitHub issue templates now use structured forms with
  `blank_issues_enabled: false`, routing how-to questions to GitHub Discussions
  to keep answers searchable for all users.

* `CONTRIBUTING.md` has been rewritten with current workflow guidance,
  contribution types, and community norms for the v1.x release line.

# tidycreel 1.0.0 (2026-03-31)

* Launched the pkgdown documentation site at
  https://chrischizinski.github.io/tidycreel with a custom Bootstrap 5 theme,
  full function reference index (46 exports + 15 datasets), and a
  workflow-driven navbar.

* Added a GitHub Actions CI/CD workflow to deploy the pkgdown site
  automatically on every push to main.
