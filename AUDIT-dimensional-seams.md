# Dimensional seam audit — instantaneous and bus-route paths (2026-08-07)

## Scope and method

Audit of the **seams** (handoffs between pipeline stages) rather than of individual
functions, targeting one bug class:

> A numeric quantity crossing a function boundary whose physical dimension is not
> asserted, where both sides are individually correct.

This class has produced three shipped defects in this package so far, all found by
accident:

1. `simulate_creel_data()$counts$total_anglers` (anglers present) reaching
   `estimate_effort()` and being labelled angler-hours. Effort understated ~14.4x on
   the AFS 2026 poster. See `.ai/handoffs/effort-units-daylight.md`.
2. NEWS.md 2.5.0 — progressive `ss_d` in count² units where
   `compute_within_day_var_contribution()` required effort².
3. Everything below.

Paths audited: **instantaneous** and **bus-route** (including ice, which is
implemented as a degenerate bus route). Not audited: aerial, camera,
mark-recapture, and the `tidycreel.connect` boat→angler reconstruction.

Findings 1–4 and 5, 9, 10 were reproduced by running the package. 6, 7, 8 were
confirmed by code trace. Every finding below is verified; none are speculative.

---

## Issue map

Findings are tracked on GitHub (opened 2026-08-07). Grouped where findings share a
fix or travel together.

| Finding(s) | Issue | Title |
| ---------- | ----- | ----- |
| 1 | #105 | `add_counts()` selects the count column positionally |
| 2 | #106 | Bus-route/ice `estimate_effort()` returns party-hours |
| 3 | #107 | `estimate_harvest_rate()` returns a total, not a rate |
| 4, 5 | #108 | Incomplete-trip ratio/pi sum; diagnostic slots not comparable |
| 6 | #109 | `prep_counts_*()` `within_day_var`/`n_counts` are dead arguments |
| 8 | #110 | No bus-route dispatch for release; `estimate_total_release_br()` dead |
| 10 | #111 | `br_build_estimates()` hardcodes `method = "total"` |
| 7, 9, 11 | #112 | Missing unit guards |
| 12 | #113 | Documentation asserts units the code does not produce |
| 13 | *not opened* | Instantaneous path never carries T, so it returns angler-days (added 2026-08-08) |

Downstream book work is tracked in
`~/Dev/modern-creel-surveys/.planning/TIDYCREEL-WISHLIST.md`, not as GitHub issues —
that repo has never used issues and the wishlist is its working tracker.

---

## Model routing

**Routing principle:** route by whether a wrong answer is *detectable*. Dimensional
and estimator-design work produces confidently-wrong answers that still pass the
suite — that is the entire lesson of this audit, and of shipped bug 2. Mechanical
changes with a fixed contract and a test that can actually fail are safe to delegate.

**Verification is always Opus** (user instruction), including the confirm-the-fix
pass on anything Sonnet implements.

| Issue | Finding(s) | Implement | Why |
| ----- | ---------- | --------- | --- |
| #105 | 1 | **Opus** | Breaking API contract + back-compat call (abort vs warn vs default), and **three** positional call sites, not two — `creel-design.R:1237`, `creel-design.R:1263` (progressive `count_var_prog`), `creel-estimates.R:2803`. |
| #106 | 2 | **Opus** | Moves every bus-route and ice number. Requires confirming `angler_effort_col` is the right operand against Malvestuto / Jones & Pollock, plus designing the party-size != 1 regression test. |
| #107 | 3 | **Opus** | Divide-by-HT-effort vs error-out is an estimator design call, and the ratio needs correct variance (delta / `svyratio`), not just a division. |
| #108 | 4, 5 | **Opus** | Hardest. Re-deriving the incomplete-trip estimator from Jones & Pollock Eq. 19.4/19.5. Pure estimator design. |
| #109 | 6 | **Opus** | `cf²` and `mean_party_size²` scaling in variance units — precisely the class Sonnet gets confidently wrong, and precisely how shipped bug 2 happened. |
| #110 | 8 | **Sonnet** implement / **Opus** verify | The dispatch mirrors the existing harvest bus-route dispatch — mechanical. **But `estimate_total_release_br()` has never been called, so it has never been exercised. Opus must verify it is correct before the wiring is trusted.** |
| #111 | 10 | **Sonnet** | Thread a `method` string through 4 call sites and fix one `autoplot` map entry. No math. |
| #112 | 7, 9, 11 | **Sonnet** | All three are guards. #11 is an allowlist check; #7 is a flag plus a warn; #9 is a guard **once Opus decides reject-vs-honour** — decide that first, then it is one branch. |
| #113 | 12a | **Opus** | `flexible-count-estimation.Rmd` needs a *correct* replacement worked example. Producing the right numbers is exactly what failed the first time. |
| #113 | 12b | **Sonnet** | `glossary.Rmd:68`, `data.R:330`, `ice-fishing.Rmd:~214-218`, `tidycreel.Rmd:47/71` — prose only, exact target text already identified. |
| *not opened* | 13 | **Opus** | Adds \eqn{T_d} to the instantaneous estimator. Estimator design, moves every instantaneous number in the package, and the absent-\eqn{T_d} behaviour has to be decided jointly with unit propagation. Exactly the class where a plausible wrong answer passes the suite. |

Non-finding work:

| Task | Model | Why |
| ---- | ----- | --- |
| ~~Finish daylight change — tests for `kearney_daylight()`~~ | ~~**Opus**~~ | **DONE 2026-08-08** (`974e976`). `kearney_daylight` no longer exists: it was a hardcoded 12-value Kearney vector, and the CBM model reproduces all twelve from latitude alone to within 0.03 min, so it was replaced by `day_length(lat, date, horizon)`. Tested against published solstice values, the twelve retired monthly means, and two physical identities. |
| ~~Finish daylight change — roxygen, `document()`~~ | ~~**Sonnet**~~ | **DONE 2026-08-08** (`974e976`). Version bump still outstanding — deferred to ship time for all findings at once. |
| NEWS entry, version bump | **Sonnet** | Drafted from the commit log. |
| Interpreting `just check` / `just test` failures | **Opus** | Verification. |
| Verify/close stale issues #93–#101 | **Opus** | Verification, and the claim "all nine resolved" is unconfirmed. |

**Sequencing constraints that override convenience:**

- #106 before #107 — #107's denominator is wrong until #106 lands.
- #105 before #110 — `estimate_total_release()` currently reaches the positional
  selector via `estimate_effort_total()`.
- #108 depends on #106 for the same denominator reason.
- Unit propagation last, after all 12. See the sequencing note at the end of this
  document: labelling an estimator that computes the wrong quantity yields
  confident, well-labelled, wrong numbers.

---

## Findings

Severity order. All are silent — none currently produce an error or warning.

### 1. `add_counts()` selects the count column positionally

`R/creel-design.R:1237` and `R/creel-estimates.R:2790-2803` take
`setdiff(numeric_cols, excluded)[1]` — the first numeric column by position.

Adding `daylight_hours` and `angler_hours` to `simulate_creel_data()` gave the counts
table three numeric candidates. Column order is
`date, day_type, count_time, total_anglers, daylight_hours, angler_hours`, so the
first candidate is `count_time` — a row index.

Reproduced (60-day season, 12 sampled days, 3 counts/day, seed 7):

```
add_counts(d, sim$counts)                          -> 72      # sums the index 1,2,3
add_counts(d, sim$counts, count_time_col=count_time) -> 60.33  # total_anglers, angler-days
sum of daily-mean angler_hours (truth)             -> 796.69
ratio                                              -> 13.2x
```

A row index is expanded and returned as "Total Effort" with no warning.

**Decision: REAL BUG — guard.** A doc note cannot fix a positional heuristic.
`add_counts()` needs an explicit `count_col` argument, or must abort listing the
candidates when more than one is present. Note this means the daylight change as it
currently stands is documentation-only; the trap it was meant to close is still armed.

### 2. Bus-route and ice `estimate_effort()` returns party-hours labelled angler-hours

`R/creel-estimates-bus-route.R:83` reads `design$effort_col` (raw per-party trip
duration). Every other rate estimator reads `design$angler_effort_col`
(= duration × `n_anglers`, built at `R/creel-design.R:2076`) — see
`R/creel-estimates.R:3038, 3177, 3728, 3832`.

Reproduced — the estimate is invariant to party size:

```
n_anglers = 1  ->  estimate_effort = 438.275
n_anglers = 3  ->  estimate_effort = 438.275
```

Truth at mean party size 3 is 3x the reported value. Understated by exactly the mean
party size in any boat fishery.

Asserted as angler-hours by `vignettes/bus-route-surveys.Rmd:258,268,276`,
`vignettes/bus-route-equations.Rmd:148`, `vignettes/ice-fishing.Rmd:136`, and the ice
column name `total_effort_hr_on_ice` (`R/creel-estimates.R:516`).

Compounding: on the same design CPUE is fish per **angler**-hour while effort is
**party**-hours, so any E x CPUE product mixes denominators.

**Decision: REAL BUG.**

**Process note:** the Malvestuto Box 20.6 validation fixture has exactly one angler
per party, so party-hours and angler-hours coincide and the test passes either way.
That test cannot fail when this logic changes. Any fix must add a party-size != 1 case
to `test-primary-source-validation.R`.

### 3. `estimate_harvest_rate()` on a bus-route design returns a total, not a rate

`R/creel-estimates.R:1656-1685` dispatches to `estimate_harvest_br()`, which computes
a Horvitz-Thompson total in fish (`R/creel-estimates-bus-route.R:386,398`).

Reproduced:

```
estimate_harvest_rate  -> 216.875  method = "total"
estimate_total_harvest -> 216.875  method = "total"   IDENTICAL
estimate_catch_rate    -> 0.582    method = "ratio-of-means-cpue"   <- sibling IS a rate
```

The roxygen is unambiguous that a rate is intended: `R/creel-estimates.R:1520-1521`
"Harvest rates (fish per angler-hour)"; L1541 "ratio of total harvest to total
effort"; L1533 declares `method = "ratio-of-means-hpue"`. The returned object carries
`method = "total"`.

**Decision: REAL BUG.** Either divide by the HT effort total to give a real HPUE, or
make `estimate_harvest_rate()` error on bus-route designs. Do not leave both.

### 4. Bus-route incomplete-trip branch divides a ratio by pi and sums it

`R/creel-estimates-bus-route.R:363-364` computes `r_i = harvest_i / effort_i` then
`r_i / pi_i`, and sums via `svytotal` with unit weights.

Three defects at one seam:

1. Inverse-probability weights apply to **totals**, not ratios. `sum(r_i / pi_i)` is
   neither the population rate nor a total. Jones & Pollock Eq. 19.4/19.5 — the
   declared contract in `vignettes/bus-route-equations.Rmd:100,158` — weights totals.
2. **The result grows with sample size.** Doubling the number of incomplete interviews
   at a constant true rate doubles the "rate". A rate estimator must be invariant in
   n. This alone falsifies it.
3. `.expansion` is silently dropped; the complete branch applies it (L386). The two
   branches are not comparable even after fixing 1 and 2.

The denominator is `effort_col`, so the underlying ratio is also fish per
**party**-hour (finding 2).

**Decision: REAL BUG.**

### 5. `use_trips = "diagnostic"` compares two different physical dimensions

`R/creel-estimates-bus-route.R:311-332` returns `list(complete=, incomplete=)` classed
`creel_estimates_diagnostic`, whose entire purpose is side-by-side comparison. Given
findings 3 and 4, the `complete` slot is fish (a total) and the `incomplete` slot is
`sum(fish per party-hour / probability)`. A user reads the gap as "incomplete-trip
bias is enormous". It is not bias; the slots are not the same quantity.

**Decision: REAL BUG** — consequence of 3 + 4, but separately user-facing.

### 6. `prep_counts_*(within_day_var=, n_counts=)` are dead arguments

`R/prep-counts.R:205-208` and `:463-466` write `n_counts` and `within_day_var` into the
output tibble. `add_counts()` populates `design$within_day_var` **only** from
`aggregate_within_day()` on the `count_time_col` path (`R/creel-design.R:1232-1248`);
it never reads columns by those names.
`compute_within_day_var_contribution()` returns 0 when the slot is NULL.

Reproduced:

```
prep output cols: date, day_type, effort_type, daily_effort, psu,
                  correction_factor, n_counts, within_day_var
design$within_day_var is NULL: TRUE
estimate 95   se 20.9   se_between 20.9   se_within 0
```

The user supplied per-PSU within-day sums of squares through the documented preferred
seam and the reported SE omits the entire within-day component. **Downward-biased SE**
— the dangerous direction, same class as shipped bug 2.

Latent compounding: `daily_effort` is scaled by `correction_factor`
(`R/prep-counts.R:189`) but `within_day_var` is passed through unscaled (`:208`). If
the slot is ever wired up it will be in (base effort)² while the estimate is in
(base x cf)² — a `cf²` mismatch. Same at `:458/:466` for the boat path, where the
required factor is `(mean_party_size x cf)²`.

**Decision: REAL BUG.** Wire the columns in (scaling `within_day_var` by
`correction_factor²`, and by `mean_party_size²` in the boat path), or abort when they
are present but unusable. Silently dropping a variance component the user explicitly
supplied is not acceptable.

### 7. `.angler_effort` is party-hours when `n_anglers` is omitted, and the flagship examples omit it

`R/creel-design.R:2073-2076` sets `.angler_effort <- effort_col` unchanged when
`n_anglers` is absent, emits `cli_inform` (not a warning), and stores no flag.
`design$angler_effort_col` is `".angler_effort"` either way, so no downstream function
can tell.

`example_interviews` **has** an `n_anglers` column (mean 2.05), yet `add_interviews()`
is called without it in `estimate_total_catch()`'s own example
(`R/creel-estimates-total-catch.R:100-105`), `write_estimates()`'s example
(`R/write-estimates.R:51-55`), and `vignettes/tidycreel.Rmd`.

Reproduced: `identical(.angler_effort, hours_fished) == TRUE`. CPUE is then fish per
**party**-hour while `estimate_total_catch()` multiplies it by count-derived
angler-hours. Both operands individually correct; the product is not.

**Decision: GUARD.** Record `n_anglers_supplied` on the design and warn at the point of
multiplication, not only at `add_interviews()`. Fix the examples to pass `n_anglers`.

### 8. `estimate_total_release()` has no bus-route dispatch; `estimate_total_release_br()` is dead code

`R/creel-estimates-total-release.R` contains zero `design_type` references; at L243 it
calls `estimate_effort_total()`, the count-based estimator that selects the first
non-excluded numeric column — the exact mechanism of finding 1. Meanwhile
`estimate_total_release_br()` exists at `R/creel-estimates-bus-route.R:689` and is
**never called** (verified: no callers in `R/`).

On one bus-route design, `estimate_effort()` returns party-hours over interviews while
the effort used inside `estimate_total_release()` is a `svytotal` over count rows.
Two different efforts, two dimensions, one design object, no warning.

`estimate_release_rate()` likewise has no bus-route dispatch
(`R/creel-estimates.R:2079`), so RPUE on a bus-route design ignores `pi_i` entirely.

**Decision: REAL BUG.**

### 9. `estimate_total_catch()` accepts `use_trips` and discards it on the bus-route path

`R/creel-estimates-total-catch.R:144` calls `match.arg(use_trips)`; the bus-route
dispatch never forwards it. Verified: `estimate_total_catch_br()` performs **no** trip
filtering, while `estimate_total_harvest_br()` does filter to complete trips
(`R/creel-estimates-bus-route.R:50-53`).

So total catch sums interrupted-trip catch as though complete while total harvest does
not — the two are computed over different row sets on the same design, making their
comparison unsound.

(Empirical demo pending: the available bus-route fixture has 12/12 complete trips, so
results coincide. The code path is decisive on its own.)

**Decision: GUARD** — honour `use_trips` or reject it for bus-route designs.

### 10. `br_build_estimates()` hardcodes `method = "total"`, so every bus-route plot reads "Total Effort"

`br_build_estimates()` (`R/creel-estimates-bus-route.R:790`) is called by effort
(L408), catch (L544), harvest (L655) and release (L758), and hardcodes
`method = "total"` in both its `new_creel_estimates()` calls (L146, L209).
`R/autoplot-methods.R:50` maps `total -> "Total Effort"` and uses it as the y-axis
title (L115, L143) and plot title (L67-75).

Result: a fish-valued bus-route catch total plots with a y-axis reading "Total
Effort". `write_estimates()` (`R/write-estimates.R:121,142`) writes the same bare
`"total"` into the CSV provenance header, so the exported file records no indication
of which quantity it holds.

**Decision: REAL BUG** — thread the correct method string through
`br_build_estimates()`.

### 11. `estimate_angler_trips()` / `estimate_effort_per_acre()` accept any `creel_estimates`

Both guard only on `inherits(effort, "creel_estimates")`
(`R/creel-estimates-trip-density.R:43-48, 272-277`); neither checks `effort$method`.
Both document their input as angler-hours.

Reproduced:

```
estimate_angler_trips(cpue_object, d)     -> 0.419    method "angler-trips"
estimate_effort_per_acre(cpue_object, 100)-> 0.00967  method "effort-per-acre"
```

Fish per hour divided by hours per trip, relabelled "angler-trips", no warning.

**Decision: GUARD** — reject any `effort$method` outside the effort family.

### 12. Documentation asserting units the code does not produce

- `vignettes/flexible-count-estimation.Rmd:24-25` states "Effort is estimated as count
  x total open hours", then the baseline example (L55-66) builds
  `open_hours = rep(10, 4)`, passes raw counts to `add_counts()`, and calls the output
  effort. Verified: `open_hours` appears **nowhere** in `R/` — it is an inert decoy
  that makes the example look like it accounts for T. Estimate 135; the vignette's own
  formula gives 1350. **10x understatement in teaching material.** The progressive
  section of the same vignette (L159) applies the expansion correctly.
- `vignettes/ice-fishing.Rmd:~214-218` describes `estimate_total_catch()` as CPUE x
  effort with a complete-trip filter. For ice/bus-route the code takes the bus-route
  dispatch to a direct HT sum with no CPUE, no effort term, and no trip filter. The
  result is still fish, so nothing is numerically wrong — but a reader auditing units
  against this text validates the wrong seam.
- `vignettes/glossary.Rmd:68` — "this is often the observed angler count **or**
  angler-hours" — the glossary sanctions the ambiguity that permits this whole class.
- `R/data.R:330` — `example_sections_counts$effort_hours` documented as "instantaneous
  count of angler-hours", which is dimensionally self-contradictory.
- `vignettes/tidycreel.Rmd:47` calls `example_counts` "instantaneous count
  observations", then L71 reports "358 angler-hours".

**Decision: DOC FIX** for all, but note the first is a 10x error in the primary
teaching vignette for this exact topic.

### 13. The instantaneous path never carries T, so it returns angler-days

Added 2026-08-08, after findings 1 and 12a landed. This is the seam those two fixes
kept running into without closing.

`estimate_effort()` on an instantaneous design expands whatever numeric column it was
given to the season and returns it. There is no \eqn{T_d} anywhere on that path — no
argument, no design slot, no column. Verified: the estimate is exactly
`sum(counts$n_anglers)` when every calendar day is sampled.

But an instantaneous count estimates the *number of anglers present at an instant*,
not effort. Effort is that count multiplied by the length of the period the count was
randomised within (Hoenig et al. 1993):
\eqn{\hat{E}_d = \bar{C}_d \times T_d}. So the returned quantity is **angler-days**,
reported under the label "Total Effort" and read as angler-hours.

The progressive path gets this right — `period_length_col` carries \eqn{T_d} per row
and `compute_progressive_effort()` applies it before aggregation. The instantaneous
path has no equivalent.

**Why this is its own finding and not part of 12.** Finding 12 is documentation
asserting units the code does not produce, and the fix there was to make the docs
honest — `flexible-count-estimation.Rmd` now says the estimate is angler-days and that
the caller must scale it. That is correct but it is a workaround: it documents a gap
rather than closing it. Closing it changes the estimator.

**Two consequences worth stating separately.**

*Order of operations.* Anyone converting after the fact computes
\eqn{\bar{C} \times \bar{T}} over a stratum, when the target is
\eqn{\overline{C \times T}}. The gap is \eqn{\mathrm{Cov}(C, T)}, and it is not zero:
anglers fish more on long days, so the covariance is positive and the collapsed form
biases **low**. Roughly \eqn{\rho \cdot CV_C \cdot CV_T} — under 1% within a calendar
month, one to two percent across an April–September block. Small, systematic, and
entirely avoidable by multiplying per date before aggregating, which is what the
progressive path already does.

*Temporal strata.* Measured at Kearney (40.699°N) with `day_length()`:

| Stratum | Within-stratum spread in \eqn{T} |
| ------- | -------------------------------- |
| Week | median 13 min, max 16 min |
| Month | up to 1.35 h (March); 7–12% of the mean in 8 of 12 months |
| Apr–Sep as one stratum | 3.23 h, 23% of the mean |

Weeks are effectively \eqn{T}-homogeneous; months are not. This matters for stratum
design **only if** the collapsed form is used. Carrying \eqn{T_d} per date makes the
covariance term exactly zero at any stratum width and removes the constraint on
stratum design altogether. Prefer that over telling users to stratify by week.

**Decision: REAL GAP — estimator change.** `add_counts()` should accept a per-date
\eqn{T_d} for instantaneous designs the way it already does for progressive, and
`estimate_effort()` should apply it before expansion. Open questions for whoever takes
this:

- Is \eqn{T_d} a new argument, or is `period_length_col` generalised off the
  progressive path? The latter is less surface area and the semantics already match.
- What happens when it is absent — abort, warn, or return angler-days with the unit
  carried on the object? This should be answered together with the unit-propagation
  work below, not before it, since the whole point of carrying the unit is to make
  "angler-days" a legitimate answer rather than a silent one.
- `day_length()` (added `974e976`) supplies \eqn{T_d} from latitude for simulation and
  planning. It must **not** become the default for real surveys: the estimator's
  \eqn{T_d} is the period the protocol randomised within — set by regulation, access
  hours, or field practice — and astronomical daylight is a proxy for it, not the
  thing itself.

**Not yet opened as a GitHub issue.**

---

## Seams checked and found sound

Recorded so coverage is auditable, not just hits.

- **pi construction.** `pi_i = p_site x p_period`, probability x probability, applied
  exactly once as `1/pi` at `bus-route.R:101,398,534,646,749`. No double application.
- **`.expansion` dimension.** `n_counted/n_interviewed` is parties/parties =
  dimensionless, so the operand's dimension is preserved. Correct in all four
  complete-trip branches.
- **Variance/SE dimensions in the bus-route path.** Every `se` comes from `svytotal`
  on the same `.contribution` column as the point estimate, so `se` is dim¹ and `var`
  is dim² throughout. Shipped bug 2's class does not recur here.
- **Progressive `ss_d x T_d²` rescale** (`creel-design.R:1254-1257`). The 2.5.0 fix is
  correct: `E_d,k = C_k x T_d` implies SS scales by `T_d²`.
- **`product_total_variance()` / `compute_stratum_product_sum()`**
  (`creel-estimates.R:3408-3524`). `E²Var(R) + R²Var(E) - Var(E)Var(R)`; every term is
  `[E]²[R]²`. Stratum sums add variances, not SEs.
- **`estimate_angler_trips()` delta variance** (`trip-density.R:113,186`).
  `se_E²/L² + E²se_L²/L⁴`, both terms `[E]²/[L]²`. It also correctly divides by raw
  `trip_duration` rather than `.angler_effort`.
- **`get_effort_target_design()`** — `.expansion_weight = N_avail/n_sampled`,
  dimensionless; added columns live only on the temporary svydesign frame and cannot
  contaminate count-var selection.
- **`estimate_effort()` dispatch guards** (`creel-estimates.R:458,528,553`). Expanded
  targets hard-abort for bus-route, ice, aerial and sectioned designs, which makes the
  sectioned mislabel path unreachable. Sound, but fragile if the guard is relaxed.
- **`creel_schema()`** — pure name-to-name mapping, zero arithmetic.
- **Ice degenerate case, `p_site = 1.0`** (`creel-design.R:447-474`). No latent
  site-weighting error is being masked. Ice does inherit findings 2 and 10 in full.
- **Boats vs anglers.** Largely N/A in this package: the only boat->angler conversion
  is `prep_counts_boat_party()`, applied exactly once, never doubly. The
  bank+boats reconstruction happens in `tidycreel.connect` — **audit separately.**
- **Time quantities in the bus-route path.** There is no circuit/residence/waiting
  time and no hours-vs-minutes conversion anywhere in
  `R/creel-estimates-bus-route.R`; effort arrives pre-formed. Nothing to find, and
  `bus-route-equations.Rmd:216-218` explicitly rejects wait-time pi estimation, which
  the code correctly does not implement.
- **`vignettes/effort-pipeline.Rmd:117`** — the one place in the docs that gets this
  seam right, with an explicit comment that `n_anglers` holds angler-hours.

---

## Prevention: carry the unit on the object

Detection fixes today's bugs. The durable fix is to make the dimension non-silent.

**Shape.** A field on `creel_design` / `creel_estimates` — *not* a column in the data
frame. A column duplicates a constant per row, is dropped or mangled by dplyr verbs
and `rbind`, does not survive `svytotal()`, and is user-editable. The design object
already carries `effort_col`, `angler_effort_col`, `count_col`; `effort_unit` and
`estimates$unit` fit that existing metadata pattern and survive everything.

**Derived, never declared.** A unit the user types is exactly as trustworthy as the
axis label on the poster — a second place to write the wrong thing. The package must
compute and propagate it:

- `add_counts()` records the selected column and the unit it implies
- `estimate_effort()` propagates `unit_out = unit_in x days`
- `estimate_cpue()` yields `fish / unit_in`
- `estimate_total_catch()` **aborts** when the CPUE denominator unit != the effort unit
- `autoplot()` / `write_estimates()` print the carried unit instead of a hardcoded
  string (this alone fixes finding 10 and gives finding 6 somewhere to report to)

The abort at the multiplication point would have caught the original daylight bug and
findings 1, 2 and 7.

**Rejected: the `units` package.** Real dimensional arithmetic, but `svytotal()` will
not accept a units vector and it would touch every estimator. Too invasive at 2.5.0
with CRAN in view.

**Back-compat.** Default `unit = NA` ("unknown") must warn rather than abort, or every
existing caller breaks. Scope the first pass to the effort/catch spine.

**Sequencing — important.** Do this *after* findings 1-12. A unit field cannot fix
findings 3 and 4: those return a total where a rate is documented, and labelling that
output does not correct it, it only makes the wrong claim machine-readable.
Propagating units through an estimator that computes the wrong quantity yields
confident, well-labelled, wrong numbers.

**Complementary: scale-invariance property tests.** Multiply an input effort column by
k; total effort must scale by k, CPUE by 1/k, total catch by k, variance by k². A
dimension error breaks these; a fixed-number example test cannot. These verify that the
propagation logic itself is right.

---

## Suggested order of work

1. **Finding 1** — closes the trap the in-flight daylight change was meant to close,
   and is a prerequisite for that change being more than documentation.
2. **Findings 2 and 3** — independent shipped defects in the primary documented
   workflow, widest blast radius, both corrupt ice as well. Finding 2 needs the
   party-size != 1 regression test noted above.
3. **Findings 4 and 5** — travel together.
4. **Findings 6, 8** — missing wiring and a missing dispatch with a dead function
   already written for it.
5. **Findings 7, 9, 11** — guards.
6. **Finding 10** — one-line map fix once `br_build_estimates()` carries a real method
   string.
7. **Finding 12** — doc fixes; do the `flexible-count-estimation.Rmd` one alongside
   finding 1, since they are the same error.
8. **Finding 13 and unit propagation together, last.** Finding 13 asks what
   `estimate_effort()` should do when no \eqn{T_d} is supplied, and unit propagation is
   what makes "angler-days" a legitimate labelled answer instead of a silent one.
   Deciding either alone forces the other's hand. Finding 13 also supersedes the doc
   workaround shipped for 12a — once the estimator carries \eqn{T_d},
   `flexible-count-estimation.Rmd` should teach the real path rather than the manual
   conversion.

## Downstream

`~/Dev/modern-creel-surveys` has bus-route and ice chapters whose numbers move under
finding 2, and `add_counts()` appears in ~15 chapters (finding 1 changes its
signature). Open a wishlist entry there before either lands.

`tidycreel.connect` performs the bank+boats -> anglers reconstruction that this audit
did not cover. Audit it on the same method.
