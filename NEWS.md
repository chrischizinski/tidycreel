# tidycreel 3.0.1 (development version)

## Documentation

* `est_biomass()` now states that the length-weight parameters `a` and `b` are
  treated as known constants, so `biomass_se` omits their estimation error and
  should be read as a lower bound. Because `a * L^b` multiplies every bin,
  that error is perfectly correlated across bins and does not shrink as bins are
  added. Measured on the documented example it adds roughly 2–11% to a
  coefficient of variation of 40–65% — minor there, but material for a survey
  precise enough to reach a count CV near 10%, or when `a`/`b` are borrowed from
  a system whose fish differ in size. Propagating the term needs an API that can
  accept the regression's standard errors and their covariance; tracked in #117.

## Bug fixes

* Argument guards on `truncate_at` and `conf_level` now reject a value whose
  length is not 1, rather than letting it reach the comparison. Passing
  `truncate_at = c(0.5, 1)` to `estimate_catch_rate()` raised base R's
  `'length = 2' in coercion to 'logical(1)'`, and `numeric(0)` raised
  `missing value where TRUE/FALSE needed` — both of which name neither the
  argument nor the constraint it violated. The intended error, which cites the
  argument and its default, now fires instead. Affects `estimate_catch_rate()`,
  the bus-route incomplete-trip path, and `est_effort_camera()`.

  A `conf_level` or `truncate_at` of `NA_real_` still reaches base R's
  "missing value where TRUE/FALSE needed". That gap predates this change and is
  shared by the six other guards written to the same pattern; it is left for a
  single pass over all of them rather than fixed at three sites only.

# tidycreel 3.0.0 "Blue Sucker" (2026-08-12)

The first major bump since the package adopted semantic versioning. It closes the
dimensional seam audit opened 2026-08-07: 27 findings, ten of them breaking changes
to what an estimator returns. Estimates now carry the unit of the quantity they
report, derived from the arithmetic the package performed rather than declared by
the caller.

Read the **Breaking changes** section before upgrading — bus-route, ice,
instantaneous, aerial and camera designs all report different numbers than 2.5.0 did,
because 2.5.0's numbers were wrong.

## New features

* Estimates now carry the unit of the quantity they report. `creel_estimates`
  objects gain a `unit` field, `print()` shows a `Unit:` line, `autoplot()` puts
  it on the y-axis, and `write_estimates()` records it in the CSV header. This
  replaces hardcoded axis and header strings, which could not tell that the
  number underneath them had changed dimension.

  The unit is **derived, never declared**. A unit the caller types is exactly as
  trustworthy as the axis label on the poster — a second place to write the wrong
  thing — so tidycreel asserts one only where it performed the arithmetic that
  produces it: angler-hours on the count side when `add_counts()` multiplied by
  T_d, angler-hours on the interview side when `add_interviews()` multiplied trip
  hours by a supplied party size, and party-hours when it did not.

  Everywhere else the unit is `NA`, meaning unknown — deliberately **not**
  "angler-days". A bare numeric count column may be an instantaneous head count
  or effort the caller already expanded, and `example_counts` is the latter;
  guessing between them would put a confident label on a number that may be in
  either unit, which is the failure this machinery exists to prevent. An absent
  `Unit:` line is the claim that tidycreel does not know, which is a different
  statement from a default.

* `est_effort_camera()` gains `n_anglers`, which makes the ratio-calibration
  path's unit derivable instead of unknown. The calibration ratio is a ratio of
  sums, so the camera counts cancel and the estimate inherits whatever unit the
  interview effort column holds — angler-hours and party-hours were
  indistinguishable, a factor of roughly two apart on the shipped example and
  reported identically. Passing `n_anglers`, either a column in `interviews` or a
  constant party size, makes the function perform the normalisation itself, which
  is what earns the `angler-hours` label.

  Omitting it now warns and names the ambiguity. That warning is only worth
  raising because the argument exists to answer it: before, it would have
  reported a gap the caller had no means to close.

  The party-size rule is not reimplemented. This path calls the same exported
  `compute_angler_effort()` that `add_interviews()` uses, so a party size of zero
  is refused at both seams for the same reason, and they cannot drift apart.
  `n_anglers` here takes a column *name* or a constant rather than a tidyselect
  symbol, matching its neighbouring `effort_col` and `intercept_col` arguments.

* Unit propagation now reaches the rate and total estimators outside the
  standard CPUE spine. Species, sections, grouped, bus-route and regression
  rates carry `fish/<denominator>`; species, sections and bus-route totals
  carry `fish`. These paths reach different constructors than the ungrouped
  ones, which is why they were still reporting `NA` after the first pass.

  `NA` is not a neutral default: it reads as "tidycreel does not know what this
  number is", and it suppresses the unit from `print()`, `autoplot()` and the
  CSV header, so the number travels bare. Saying `NA` where the package does
  know is as much a false claim as guessing.

  The denominator is a property of the interviews rather than of which rate was
  asked for, so every rate estimator on one design now reports the same one —
  asserted between estimators in the tests rather than against a hardcoded
  string, since a wrong constant can satisfy a literal but cannot make two
  independent estimators agree.

  Visible change: `autoplot()` y-axis labels on these paths now read e.g.
  "Total Catch (fish)" where they previously read "Total Catch".

* Unit propagation now covers the effort family, where the same quantity is
  derived three different ways and so takes its unit from three different
  places.

  Bus-route effort reports the **interview** denominator, not the count side:
  `E_hat = sum(e_i / pi_i)` is built entirely from interview contributions, so
  labelling it from the counts would assert a provenance the number does not
  have. Aerial effort is angler-hours unconditionally — an aerial design refuses
  `period_length_col`, which makes `h_open` the sole period source.

  Camera effort splits by path. The raw-count path is angler-hours for the same
  reason as aerial. The ratio-calibration path is `NA`: its ratio carries the
  unit of the `effort_col` column in a caller-supplied data frame, which nothing
  normalises by party size, so angler-hours and party-hours are
  indistinguishable there. Unknown is the honest answer, and the same one
  `add_counts()` gives a bare count column.

* `estimate_angler_trips()` and `estimate_effort_per_acre()` now carry units,
  and both **inherit** rather than assert them. These two take a
  `creel_estimates` rather than a design, so they cannot ask a design what
  anything is in; each transforms a quantity whose unit it was handed.

  Trips are effort divided by mean trip length, and the divisor is hours per
  trip, so the count comes back in whichever actor the effort was measured in:
  angler-hours give `angler-trips`, party-hours give `party-trips`. The method
  name is `"angler-trips"` for every caller, which is precisely why the unit
  cannot be read off it — a bus-route design with no `n_anglers` produces a
  party-level count that a fixed label would have reported as angler trips.

  Effort per acre composes its unit from the effort's, keeping
  `party-hours/acre` distinguishable from `angler-hours/acre`. An unknown
  effort unit stays unknown through both: dividing an unknown quantity does not
  make it known, and `"NA/acre"` would read as a real unit on a plot axis.

* Unit propagation now reaches the mark-recapture and exploitation-rate
  estimators, the last group without units, and the honest answer for most of
  them is `NA`.

  `estimate_exploitation_rate()` reports `"proportion"` on both the stratified
  and unstratified paths. It is the one estimator in the package whose unit no
  input can change: \eqn{u = (C/T) \times (m/n)} divides fish by fish twice, so
  both actors cancel for every design.

  `estimate_angler_n()` reports `NA`, **not** `"anglers"`. Its `M`, `n` and `m`
  arrive as bare numerics that nothing inspects, and the arithmetic divides
  counts by counts, so \eqn{\hat{N}} carries whatever actor the marking protocol
  marked — anglers on some surveys, boats or parties on others. Asserting
  `"anglers"` would restate the function's name rather than derive anything.
  `estimate_mr_harvest()` inherits that unknown for the same reason: its product
  is in fish only if \eqn{\hat{N}} counted anglers.

* `estimate_total_catch()`, `estimate_total_harvest()` and
  `estimate_total_release()` abort with class `creel_error_unit_mismatch` when
  the effort unit and the rate's denominator are both known and disagree. Their
  product is not a catch.

  Two seams are deliberately excluded. A per-party-hour rate meeting angler-hour
  effort keeps `warn_party_hours_product()`'s existing warning rather than
  becoming an error, since that would break every caller who omits `n_anglers`.
  An unknown effort unit is reported by the T_d warning below rather than a
  second message, so one defect produces one diagnosis.

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

* `add_lengths()` warns when a binned release row carries a fractional `count`.
  The guard's own error message had always said "a positive integer count" while
  nothing checked integrality, so `count = 3.5` was accepted silently and reached
  `estimate_length_distribution()`, which aggregates that column as a per-bin fish
  count. A fraction of a fish then entered the distribution and every proportion
  computed from it.

  Warned rather than rejected, matching how `n_anglers` treats the same category
  error: a fractional count of discrete things signals the wrong column was
  supplied, not that the data are unusable, and aborting would break tables that
  have always been accepted. The `NA` message now says "a positive count;
  non-integer values warn", so what it claims and what it enforces agree.

* `estimate_effort()` warns, once per session, when an instantaneous design
  carries no `period_length_col`. Without T_d the estimator expands the count
  column to the season and returns it, which is not angler-hours. The warning
  states the reading rather than asserting the unit: tidycreel cannot tell an
  instantaneous head count from a column that already holds angler-hours, since
  both arrive as a numeric column, so it says that *if* the column is a count the
  result is in angler-days. Numbers are unchanged for these callers.

  The three product totals raise the same warning. They call
  `estimate_effort_total()` directly rather than `estimate_effort()`, so without
  this a caller who only ever asks for a total never heard that the count column
  had no T_d applied.

  Output from the `prep_counts_*()` helpers is exempt. That seam resolves counts
  into sampled-day effort before `add_counts()` sees them, so there is no
  instantaneous count left to expand and no T_d to ask for — warning there would
  fire on the documented preferred workflow. The marker is carried as an
  attribute, so a table piped through intervening dplyr verbs degrades to
  "unknown", which is the safe direction.

* `estimate_total_catch()`, `estimate_total_harvest()` and
  `estimate_total_release()` now accept `by = species` on bus-route and ice
  designs, and answer on the Horvitz–Thompson path. All three resolved `by`
  against the interview columns, which carry no species column, so the call
  aborted with ``Column `species` doesn't exist`` on both design types — six
  combinations, none of them reachable. The species-level total estimators they
  would otherwise have reached are stratum product sums built on the standard
  interview survey, so routing there instead would have reproduced the previous
  entry's defect in the totals: a species total contradicting the all-species
  total on the same object.

  The falsifier is the same partition identity, and it is exact for a
  Horvitz–Thompson sum because that sum is linear in its numerator. All six
  combinations now satisfy it, and each species' total over the HT effort equals
  that species' rate to machine precision — the cross-check tying the totals to
  the rates. The reported method names the estimator and the quantity
  (`ht-total-release-species`).

  `use_trips = "all"` is still rejected: the completed-trip guard runs ahead of
  the species branch, because an incomplete trip contributes catch-so-far under a
  completed trip's inclusion probability whether or not the numerator is one
  species.

* Species-level rates (`by = species`) now take the Horvitz–Thompson path on
  bus-route and ice designs. `estimate_cpue_species()` and its harvest and
  release siblings build a per-species interview table and hand it to the
  *standard* interview-survey estimators, so on these two design types they
  ignored `.pi_i` and `.expansion` — the defect the previous entry removed from
  the all-species rates, one estimator over. Fixing the all-species side first is
  what made it visible: one design object then returned both answers, each under
  a method string naming the same quantity.

  The falsifier is a partition identity rather than a reference value. Species
  partition the catch and every species shares the same effort denominator, so
  the species rates must sum to the all-species rate exactly. Before the fix the
  species sum matched the standard-path rate to the last digit:

  | design | rate | all-species | species sum | gap |
  | ------ | ---- | ----------- | ----------- | --- |
  | bus-route | CPUE | 0.748339 | 0.937805 | +25.32% |
  | bus-route | RPUE | 0.421378 | 0.494953 | +17.46% |
  | ice | HPUE | 0.919685 | 0.862944 | −6.17% |
  | ice | RPUE | 0.909720 | 0.964467 | +6.02% |
  | ice | CPUE | 1.829405 | 1.827411 | −0.11% |

  All five now reconcile exactly. Per species the estimator repoints the
  numerator at that species' counts and delegates to the bus-route estimator the
  all-species rates already use, so the two can no longer drift apart, and the
  reported method gains the `-species` suffix on both trip paths
  (`ratio-of-means-rpue-species` where the standard path still reports
  `ratio-of-means-rpue`). `use_trips = "diagnostic"` is refused with species
  grouping: the diagnostic pair returns two estimates per species, and returning
  either half under one label is the mislabelling this release is removing.

  Also fixes a regression introduced by the previous entry: that dispatch
  resolved `by` against the interview columns, where there is no species column,
  so `by = species` aborted on ice designs where it had previously worked, and on
  bus-route designs where it had never worked.

  **Breaking:** every species-level rate on a bus-route or ice design moves.

* The three rate estimators now dispatch to the Horvitz–Thompson path on **ice**
  designs as well as bus-route ones, and `estimate_catch_rate()` gains the
  bus-route dispatch it never had. `estimate_effort()` and all three totals
  already treated ice as the degenerate bus route it is documented to be; the
  rate estimators were the outliers, so a single design object returned a rate
  that its own totals contradict. Both paths reported the same `method` string,
  so nothing in the returned object distinguished them.

  A ratio of HT totals must equal total ÷ effort exactly, which is what says
  which of the two answers was wrong rather than merely that they differed:

  | design | rate | before | totals imply | after |
  | ------ | ---- | ------ | ------------ | ----- |
  | ice | HPUE | 0.514328 | 0.478561 | 0.478561 |
  | ice | CPUE | — | — | reconciles exactly |
  | bus-route | CPUE | 0.466438 | 0.433603 | 0.433603 |

  Ice designs consequently take the bus-route `use_trips` set — `"complete"`,
  `"incomplete"`, `"diagnostic"` — instead of the standard path's, so they now
  accept the two values their own design type is built on and reject `"all"`,
  which is not an estimator on this path. For `estimate_catch_rate()` the roving
  auto-route to `"all"` + MOR does not apply on these designs.

  **Breaking:** ice HPUE, ice RPUE, ice CPUE and bus-route CPUE all move.

* `estimate_harvest_rate()` and `estimate_release_rate()` now validate
  `use_trips` on the bus-route path. The bus-route dispatch runs before the
  standard path's check and handed the string straight to the estimator, which
  branches on `"diagnostic"`, then `"complete"`, then `"incomplete"` with no
  final `else` — so an unrecognised value reached the complete-trip code with
  the trip-status filter switched off and returned the all-trips answer under
  the complete-trip method string, silently. The dangerous input was not a
  nonsense string but a *valid* value typed with the wrong case: on a fixture of
  four complete and four incomplete trips, `"Complete"` returned 2.816514 over
  all eight rows where `"complete"` returns 2.642202 over four. The standard
  path rejected the same input, so whether a typo aborted depended on the design
  type.

  The valid set on the bus-route rate path is `"complete"`, `"incomplete"` or
  `"diagnostic"`, as documented. It is deliberately not the standard path's set:
  `"incomplete"` is a legitimate rate here (Hoenig et al. 1997) and is not
  offered there, and `"all"` is legitimate there and is not an estimator here,
  because pooling the two kinds of trip applies the complete-trip ratio of
  Horvitz–Thompson totals to numerators that are catch so far. Matching is
  exact — `"comp"` is an error, not `"complete"`.

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

* `estimate_angler_n()` now defaults to Sadinle's (2009) 0.5 transformed logit
  confidence interval on the Chapman and Petersen branches, via a new
  `ci_method = "logit"`. **Every Chapman and Petersen bound moves.** Pass
  `ci_method = "delta"` to reproduce the previous symmetric Wald interval
  exactly. `estimate_mr_harvest()` inherits the change, rebuilding its interval
  from the same capture table.

  The Wald interval is symmetric while \eqn{\hat{N}} is a ratio with a small
  integer denominator and is strongly right-skewed, so it leaves the parameter
  space in the regime Chapman exists for. At `M = 200`, `n = 50`, `m = 3` it
  reported `ci_lower = -2124.8`; at `m = 5` it reported `48.7` against 245
  individuals actually observed. Evans et al. (1996) measured Wald coverage
  failing on one side 27.9% of the time against a 2.5% nominal rate.

  Sadinle compared nine intervals and found the 0.5 transformed logit "the best
  of the intervals reported here", with near-nominal coverage even for small
  populations and capture probabilities near 0 or 1, where profile-likelihood
  and Monte Carlo intervals both degrade. Its lower limit cannot fall below the
  number of individuals observed. It is closed-form, deterministic, and adds no
  dependency.

  | `m` | before | after |
  | --- | --- | --- |
  | 2 | `[-17486.6, 24318.6]` | `[1319.1, 14085.6]` |
  | 3 | `[-2124.8, 7248.3]` | `[1143.1, 8259.6]` |
  | 5 | `[48.7, 3366.3]` | `[903.9, 4211.2]` |
  | 10 | `[406.9, 1454.9]` | `[605.4, 1715.0]` |

  The Schnabel branch is unchanged — it already inverted Poisson quantiles and
  could not produce a negative bound.

  One boundary behaviour is worth knowing: when `m == n`, every individual in
  the second sample was already marked, the estimator saturates at
  \eqn{\hat{N} = M}, and the logit lower limit sits fractionally *above* the
  point estimate because the data imply \eqn{N > M}. Use `ci_method = "delta"`
  if a bound that brackets the point estimate matters more than coverage.

* `estimate_mr_harvest()` now derives its interval from the angler-population
  interval instead of rebuilding a symmetric one, so a positive angler bound can
  no longer become a negative harvest bound. On the `ci_method = "delta"` path
  this is not a numeric change: the old code used the same degrees of freedom
  and `se_H = harvest_rate * se_N`, so its bounds already equalled the scaled
  angler bounds to machine precision.

* `estimate_angler_n(method = "schnabel")` now builds its large-sample confidence
  interval on \eqn{S - 1} degrees of freedom, where \eqn{S} is the number of sampling
  occasions. It previously used \eqn{\sum m - 1}, the recapture total. **Every
  Schnabel interval with \eqn{\sum m \geq 50} widens**; the point estimate and `se`
  are unchanged.

  Hansen & Van Kirk (2018) eq. (A.5) uses \eqn{t_{\alpha/2,\,S-1}}, as does
  `fishmethods::schnabel()`, the implementation they modified. The estimator has one
  observation per occasion regardless of how many recaptures land in it, so keying df
  to \eqn{\sum m} treats recaptures within an occasion as independent and understates
  the interval. On five occasions with \eqn{\sum m = 52} the reported interval was
  `[1504.28, 2665.02]` where the source gives `[1388.48, 3127.07]` — 33% too narrow.

  The `se` itself was checked against the same sources and is correct as it stands.
  Only the quantile changed.

* `estimate_angler_n(method = "schnabel")` now applies Chapman's (1952)
  small-sample correction by default, dividing by \eqn{\sum m_k + 1} instead of
  \eqn{\sum m_k}. **Every Schnabel point estimate falls**, by exactly
  \eqn{1/(\sum m_k + 1)} in relative terms: 33% at \eqn{\sum m_k = 2}, 1.9% at 52,
  0.2% at 500. Pass `bias_adjust = FALSE` for the previous form, which is also
  what `fishmethods::schnabel()` computes.

  Dettloff (2023) eq. (6) simulated both forms across population sizes from
  \eqn{10^2} to \eqn{10^6}. The unadjusted estimator turns biased *high* at
  moderate sample sizes before settling, which propagates into an inflated
  `estimate_mr_harvest()`; the adjusted form's bias "approaches zero as the sample
  size increases without ever becoming positive", at lower variance and no cost in
  large samples. He recommends the adjusted estimators "in place of the originals
  in all scenarios".

  The consistency argument is the other half. Schnabel reduces exactly to
  Lincoln-Petersen at \eqn{K = 2}, so the unadjusted form meant that
  `method = "schnabel"` on two occasions returned the estimator the package
  already declines to default to at `method = "petersen"` — bias handling depended
  on how many occasions had been sampled rather than on the data.

  The `se` moves only through the delta-method Jacobian, which is evaluated at the
  reported \eqn{\hat{N}}. \eqn{1/\hat{N}} shifts by the constant \eqn{1/\sum M_k n_k},
  so \eqn{\mathrm{Var}(1/\hat{N})} is unchanged and `invSE` still matches
  `fishmethods`. The Poisson interval (\eqn{\sum m_k < 50}) inverts the distribution
  of \eqn{\sum m_k} rather than centring on \eqn{\hat{N}}, so **its bounds do not
  move**; the large-sample interval is built around \eqn{1/\hat{N}} and does.

* `estimate_angler_n()` gains `method = "schumacher"`, the Schumacher-Eschmeyer
  regression estimator, for \eqn{K \geq 3} occasions. It takes the same inputs as
  `"schnabel"` and fits \eqn{m_k/n_k} against \eqn{M_k} through the origin with
  slope \eqn{1/N}, giving \eqn{\hat{N} = \sum n_k M_k^2 / \sum m_k M_k}. The
  interval is Seber (1982) eq. (4.17) on \eqn{K - 2} degrees of freedom, and
  `bias_adjust` (default `TRUE`) applies Dettloff's (2023) eq. (8) small-sample
  correction. With `bias_adjust = FALSE` the point estimate, `invSE` and both
  bounds match `fishmethods::schnabel()`'s Schumacher-Eschmeyer row to printed
  precision, and the formulas were checked against Seber's own worked example
  (Ricker's red-ear sunfish: \eqn{\hat{N}} = 423, \eqn{\hat\sigma^2} = 0.1935).

  Two details differ from the Schnabel branch on purpose. Degrees of freedom are
  \eqn{K - 2}, not \eqn{K - 1}: Seber excludes the first occasion because
  \eqn{y_1} is identically zero when \eqn{M_1 = 0} and so "is not strictly a
  random observation". And Dettloff's eq. (8) numerator sums from \eqn{k = 2}
  explicitly — \eqn{(M_k + 1)^2 (n_k + 1)} is the one term here that does *not*
  vanish at \eqn{M_1 = 0}, so occasion 1 has to be dropped by hand rather than by
  the algebra.

  **tidycreel deliberately does not implement the "pick the narrower CI" rule.**
  Hansen & Van Kirk (2018) computed both estimators and "selected the
  mark-recapture estimator that produced the smallest 95% CI". Choosing the
  narrower of two intervals after seeing them conditions on the luckier draw, so
  the reported interval does not have its nominal coverage. Choose between the
  estimators on design grounds, or report both.

* `estimate_angler_n(method = "schnabel")` no longer returns
  `ci_upper = Inf` when the recapture total is very small. The Poisson interval
  divides by the lower quantile \eqn{q_{\alpha/2}(\sum m_k)}, which is **zero** for
  \eqn{\sum m_k \leq 3} at the 95\% level. Hansen & Van Kirk (2018) eq. (A.4)
  substitute Ilienko's (2013) continuous Poisson,
  \eqn{F(x) = \Gamma(x, \lambda)/\Gamma(x)}, in exactly that case; it is positive
  there and yields a finite bound. The substitution fires only where the discrete
  quantile is zero — from \eqn{\sum m_k \geq 4} the continuous quantile sits just
  above the discrete one, so the bound stays monotone across the seam.

  **The bound is an interpolation, and the warning that announces it is
  deliberate.** It rests on a continuous interpolation of a discrete distribution
  at one to three total recaptures; it stands in for "the data do not bound this
  above" rather than measuring anything.

  Implementers should note two traps. The quantile lives in the *shape* argument
  of `pgamma()`, so it must be root-found — there is no `qgamma()` call that
  produces it. And **the source paper's own worked example is wrong**: it reports
  the 0.025 quantile at \eqn{\lambda = 2} as 0.24 and draws Figure A.1 to match,
  but 0.24 is `qgamma(0.025, shape = 2)`, a Gamma(2, 1) quantile. Inverting their
  eq. (A.4) gives **0.3292**. Equation A.4 transcribes Ilienko's Definition 3.1
  faithfully; the example does not. Tests pin the implementation against Ilienko's
  eq. (1) identity with `ppois()`, never against the printed example.

* `estimate_mr_harvest()` now keys its Wald interval to the number of sampling
  occasions when the input came from `method = "schnabel"`, matching the change to
  `estimate_angler_n()` above. It read `angler_n$estimates$n`, which for Schnabel is
  \eqn{\sum m}, so the degrees-of-freedom defect fixed in the estimator survived one
  function downstream: with five occasions and \eqn{\sum m = 52} the harvest interval
  used \eqn{t = 2.008} where \eqn{t_{0.975,\,4} = 2.776}, 28% too narrow. **Schnabel
  harvest intervals widen**; Chapman and Petersen are unaffected and still use
  \eqn{m - 1}.

* `add_counts(count_type = "progressive")` now **errors** when a day's shift is
  shorter than `circuit_time`, with condition class
  `creel_error_circuit_exceeds_shift`. It previously warned and then returned an
  estimate anyway.

  The progressive estimator is Hoenig et al. (1993) eq. 3,
  \eqn{\hat{E}_d = C \tau K} with \eqn{K = T_d/\tau} the number of whole circuits
  in the day. When \eqn{T_d < \tau} no circuit completed, so the count is not a
  progressive count of that shift and there is nothing for \eqn{K} to expand.
  `generate_progressive_start()` already refused such a design, so the only way to
  reach the old warning was a hand-built schedule — precisely the case with no
  other guard in front of it.

  \eqn{\tau = T_d} (\eqn{K = 1}) is unaffected: that is Robson's (1961) all-day
  circuit and remains valid.

* `estimate_mr_harvest(harvest_rate = )` is harvest **per angler**, in fish per
  angler, and is no longer bounded above. It was documented as the "proportion
  of anglers that harvested fish" and guarded to `(0, 1]`.

  Those two readings produce different quantities from the same arithmetic.
  \eqn{\hat{H} = \hat{N} \times r} with a dimensionless proportion is a count of
  *anglers who kept a fish*; the function returns it as `total_harvest`, from
  `estimate_mr_harvest()`, with `method = "mark-recapture-harvest"`. The
  per-angler-rate reading is the one the output has always claimed, and the one
  that makes the product fish.

  The `(0, 1]` guard did more than mislabel — it enforced the wrong reading. A
  fishery averaging 1.4 kept fish per angler is ordinary, and the guard made
  total harvest unreachable for exactly those fisheries by erroring on the
  correct input.

  **No numeric result changes.** Every previously legal call returns what it
  always did, because the multiplication is untouched. What changes is which
  quantity you are told to supply, and that values above 1 are now accepted. If
  you were passing a proportion of anglers, your input was answering a different
  question than the output claimed to ask, and it should be replaced with mean
  fish kept per angler.

* `add_counts()` now aborts with class `creel_error_aerial_period_length` when
  `period_length_col` is supplied on an aerial design, and
  `est_effort_camera()` aborts with class `creel_error_camera_period_length`
  when its raw-count branch is handed counts that already carry T_d.

  Both estimators already have a period-length term of their own: aerial scales
  the count by `h_open / v` (Pollock Eq. 15.4) and camera's raw-count fallback
  scales by a supplied `h_open`. Once `add_counts()` began applying
  `period_length_col` for any count type (see the previous entry), a design
  carrying both multiplied by time twice — on a 4-day fixture with `h_open = 14`
  and T_d = 2 the aerial total went from 1400 to 2800, and the unit spine
  labelled that 2800 "angler-hours".

  This is a regression in the development version only; no released version
  applied T_d on those paths, so callers of released tidycreel are unaffected.
  Anyone who added `period_length_col` since that change should remove it and
  set the period length through `h_open` instead. Camera's ratio-calibration
  path is deliberately unaffected: it divides by `mean(count)` before
  multiplying by `count`, so a constant T_d cancels out of the estimate.

* `add_counts()` now applies `period_length_col` to instantaneous counts instead
  of discarding it. Supplying the column on an instantaneous design used to be
  accepted, recorded in `design$period_length_col`, and then ignored — the
  estimate came back as the bare counts summed over days, with the T_d column
  left sitting unread in `design$counts`. Effort estimates move for anyone who
  passed it: on an 8-day fixture with T_d of 8–14 hours the total went from 140
  to 1780.

  An instantaneous count is a snapshot of how many anglers were present at one
  moment, not effort. Effort is that count times the length of the period it was
  randomised within, Ê_d = C̄_d × T_d (Hoenig et al. 1993). The multiplication
  happens per PSU at attach time, so the ungrouped, grouped, sectioned and
  within-day-variance paths all inherit it, and multi-count PSUs get their `ss_d`
  scaled by T_d² so the within-day variance stays in effort² units.

  Applying T_d per date rather than after aggregation is deliberate: the
  collapsed form computes C̄ × T̄ where the target is the mean of C × T, and the
  two differ by Cov(C, T). Anglers fish more on long days, so that covariance is
  positive and the collapsed form biases low. Multiplying per date makes the term
  exactly zero at any stratum width, which removes the constraint on stratum
  design that would otherwise follow from T varying within a stratum.

  The positive-and-finite check on `period_length_col` now runs wherever the
  column is supplied. It previously lived inside the progressive-only block, so a
  zero or negative period passed unchecked on an instantaneous design.

* `n_anglers` now means a party size, not a tidyselect column position. It was
  resolved through `tidyselect::eval_select()`, where a bare integer selects a
  *column by position*, so `n_anglers = 1L` — the literal in `add_interviews()`'s
  own signature — selected column 1 and multiplied effort by whatever it held.
  On interviews whose first column is numeric that silently produced
  `.angler_effort = hours × <that column>`; on the shipped column order it failed
  with `* not defined for "Date" objects`, naming neither the argument nor the
  column it chose. Which of the two you got depended on your column order. It
  also set `n_anglers_supplied = TRUE`, switching off the warning that exists to
  catch exactly this mismatch.

  A bare number is now a constant party size: `n_anglers = 1` states that every
  interview is a single angler, and `n_anglers = 3` that every party held three.
  Bare column names are unaffected. This is also the only way to declare a
  genuinely solo-angler survey, and therefore to silence the party-hours warning
  above without inventing a constant column.

  Party sizes are now validated wherever they come from. Zero, negative and
  non-finite values abort — a party of no anglers would silently zero out that
  interview's effort — missing values abort as a stated constant but warn as a
  column, and non-integer values warn. `compute_angler_effort()` follows the same
  contract; it is the other exported entry point that writes `.angler_effort`.

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

* The progressive count articles now state the conditions under which
  \eqn{\hat{E}_d = C \times T_d} is unbiased. `vignettes/progressive-count-surveys.Rmd`
  gains a *Conditions for an Unbiased Estimate* section covering Hoenig et al.'s
  (1993) three requirements — random starting location, randomly chosen direction of
  travel, and an observer who outpaces the anglers — plus two cautions from the same
  paper: do not interrupt the circuit to interview, and do not read the count as a
  number of trips, which "results in a negative bias that can be severe."

  None of these are checkable from the counts table, which is why they belong in
  prose rather than in a guard.

  `vignettes/effort-pipeline.Rmd` previously derived the \eqn{\tau} cancellation
  through an unmotivated \eqn{\times\tau} that returned the expression to
  \eqn{C_d \times T_d}. It now follows the source's two-step argument — expand the
  sampled block by \eqn{\tau}, then scale by the \eqn{K = T_d/\tau} blocks in the
  day — which reaches the same formula and shows why \eqn{\tau} cancels: it defines
  the blocks the count was scheduled within, so it has done its work before the
  estimator runs.

  Also corrected: the "circuit time < 30% of \eqn{T_d}" rule of thumb was not from
  Hoenig et al. and is not the paper's condition.

* `estimate_mr_harvest()` attributed its known-constant harvest rate to Hansen &
  Van Kirk (2018), which does the opposite: both factors of that rate are
  estimated there, given log-normal sampling distributions, and resampled
  alongside \eqn{\hat{N}} in the bootstrap behind every harvest CI. The
  simplification is this package's, so the reported `se` is a lower bound on the
  true uncertainty, and `@details` now says so rather than crediting a source.

  `harvest_rate` also gains the period it was missing. In the paper's
  \eqn{H = N \cdot D \cdot V} the multiplier on the angler population is
  \eqn{D \times V} — days fished per angler times daily harvest per angler — so
  the argument must cover the same period `angler_n` counts anglers for. "Fish
  per angler" alone did not pin that down, and the daily rate is the wrong one.

* `estimate_angler_n()` documents that its Chapman and Petersen confidence
  intervals are symmetric and can fall below zero. \eqn{\hat{N}} is a ratio with
  a small integer denominator, so it is right-skewed; at `M = 200`, `n = 50`,
  `m = 3` the reported `ci_lower` is `-2124.8`, and `estimate_mr_harvest()`
  inherits the shape. Chapman is recommended precisely when recaptures are few,
  so the docs now direct small-\eqn{m} users to `ci_method = "bootstrap"`, whose
  percentile bounds respect the skew. The Schnabel branch already inverts
  Poisson quantiles and is unaffected. The interval arithmetic is unchanged in
  this release — correcting it moves every shipped Chapman and Petersen bound.

* `estimate_exploitation_rate()` described `C` as a harvest total while pointing
  at `estimate_total_catch()` to produce it. Catch includes released fish, which
  were never removed from the tagged cohort, so a catch total inflates
  \eqn{\hat{u}} by the release fraction. `@param C`, `@param strata` and
  `vignettes/mark-recapture.Rmd` now point at `estimate_total_harvest()` and say
  why. The estimator is unchanged; only the cross-reference was wrong.

  Noted in the docs because no check can catch it: both totals are counts of
  fish and both carry `unit = "fish"`, so the expression is dimensionally
  coherent. The actor matches and the quantity does not.

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

* Inert `open_hours` calendar columns are removed from the six remaining places
  they appeared — `vignettes/progressive-count-surveys.Rmd`,
  `vignettes/effort-pipeline.Rmd` and `vignettes/temporal-extrapolation.Rmd`.
  `creel_design()` reads only the date and the strata, so the column was never
  consulted anywhere it was written. The progressive article additionally listed
  the calendar's `open_hours` as the \eqn{T_d} the estimator applies; the real
  \eqn{T_d} travels with the count data and is passed as `period_length_col`
  (#113).

* `vignettes/tidycreel.Rmd`: two reported values had drifted from what the
  chunks print. The total effort estimate is 372.5 angler-hours, not the 358
  claimed, and the grouped estimates are 201.9 weekend / 170.6 weekday, not
  250 / 108. The grouped comparison now notes that the calendar holds 10
  weekdays to 4 weekend days, so a weekend total 18% higher is a per-day rate
  about three times higher. The article also called `example_counts`
  "instantaneous count observations" when the column holds angler-hours already
  accumulated over the day (#113).

* `example_counts` and `example_sections_counts` documented their
  `effort_hours` column as an instantaneous count *of angler-hours*, which is
  two different quantities at once. Both now state that the column holds
  angler-hours, and that `estimate_effort()` expands whatever column it is
  given without converting units — raw counts in, angler-days out (#113).

* `vignettes/glossary.Rmd` sanctioned the same ambiguity by defining count data
  as "the observed angler count or angler-hours". It now states that both are
  accepted, that no conversion happens, and which unit each choice returns
  (#113).

* `vignettes/ice-fishing.Rmd` described `estimate_total_catch()` as CPUE times
  effort over all interviews. On ice designs it is a Horvitz–Thompson sum with
  no CPUE term and no effort term, over complete trips only — 60 of the
  vignette's 72 interviews — and `use_trips = "all"` is refused. The standard
  error comes from Taylor linearization, not the delta method the text credited
  (#113).

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
