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
| 14 | *not opened* | Ice designs skip the bus-route dispatch in the rate estimators (added 2026-08-09) |
| 15 | *not opened* | ~~`use_trips` unvalidated on the bus-route path; a typo silently swaps the estimator~~ **LANDED** (added and fixed 2026-08-09) |
| 16 | *not opened* | ~~Scalar `n_anglers` resolves positionally to the first column, and sets `n_anglers_supplied = TRUE`~~ **LANDED** (added and fixed 2026-08-09) |

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
| #111 | 10 | **Sonnet** | ~~Thread a `method` string through 4 call sites and fix one `autoplot` map entry. No math.~~ **LANDED.** Three call sites, not four (effort builds its own object and its `"total"` was already correct), and three label maps, not one. |
| #112 | 7, 9, 11 | **Sonnet** | ~~All three are guards. #11 is an allowlist check; #7 is a flag plus a warn; #9 is a guard **once Opus decides reject-vs-honour** — decide that first, then it is one branch.~~ **LANDED.** #9 was not one branch: the reject was, but the substantive half was giving catch and release the completed-trip filter harvest already had, which moves shipped numbers. #7's blast radius had to be measured, not reasoned about. |
| #113 | 12a | **Opus** | `flexible-count-estimation.Rmd` needs a *correct* replacement worked example. Producing the right numbers is exactly what failed the first time. |
| #113 | 12b | **Sonnet** | `glossary.Rmd:68`, `data.R:330`, `ice-fishing.Rmd:~214-218`, `tidycreel.Rmd:47/71` — prose only, exact target text already identified. |
| *not opened* | 14 | **Opus** | One-line dispatch condition, but it moves every ice harvest-rate number and the two paths are indistinguishable from their output, so the regression fixture is the whole job. |
| *not opened* | 15 | **Sonnet** | One guard in two twin functions, with the valid set already written down on the standard path. **But Opus decides first whether `"all"` is blessed or rejected on bus-route** — that is an estimator question, not a validation one. |
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

**LANDED (#108).** Reproduced before the fix: on a fixture where every angler harvests
at exactly 1 fish per angler-hour, the estimator returned 19.17, 38.33, and 76.67 for
the same population sampled with 4, 8, and 16 interviews — defect 2 confirmed exactly.
Replaced by the truncated mean of ratios of Hoenig et al. (1997), weighted by
`.expansion / .pi_i` (a Hájek mean, which is what defect 1 required and what restores
the dropped `.expansion` of defect 3) and divided by angler-effort (finding 2 residue).
Returns 1.0 at all three sample sizes. `method = "mean-of-ratios-hpue"`.

### 5. `use_trips = "diagnostic"` compares two different physical dimensions

`R/creel-estimates-bus-route.R:311-332` returns `list(complete=, incomplete=)` classed
`creel_estimates_diagnostic`, whose entire purpose is side-by-side comparison. Given
findings 3 and 4, the `complete` slot is fish (a total) and the `incomplete` slot is
`sum(fish per party-hour / probability)`. A user reads the gap as "incomplete-trip
bias is enormous". It is not bias; the slots are not the same quantity.

**Decision: REAL BUG** — consequence of 3 + 4, but separately user-facing.

**LANDED (#108).** Both slots are now fish per angler-hour, verified on a fixture whose
true rate is 2.0: both return 2.0, and tripling party size divides both by three. They
stay different estimators (ratio of HT totals vs truncated mean of ratios) because each
is the estimator its trip type supports. A one-sided design used to fail inside `survey`
with "all arguments must have the same length"; it now aborts naming the counts. The
`verbose` message named the complete-trip estimator on every path, including the one
that never ran it — it now names the estimator actually used.

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

**LANDED (#109).** Wired in, both halves. Reproduced first: on an 8-day fixture with 3
counts/day, identical data gave `se 6.928, se_within 0` through the prep seam and
`se 9.522, se_within 6.532` through `add_counts(count_time_col=)` — a **27% downward**
understatement. The user's supplied `ss_d` was **32**, exactly what
`aggregate_within_day()` computes, so the column was always the right quantity and was
simply never read. `resolve_supplied_within_day_var()` in `add_counts()` now reads it;
both seams now return `se 9.522` on the same data, and the cf ≠ 1 and boat paths were
cross-checked against equivalently-scaled raw counts (exact match).

One thing the audit did not flag: the roxygen said "a within-day variance **or** sum of
squares", but the consumer needs SS specifically — it forms
`sum(ss_d) / (n_sampled * (k_bar - 1))`, supplying the divisor itself, so a variance is
wrong by `k_d - 1`. Wiring the column in as-is would have converted a silent omission
into a silent miscalculation. The contract is now SS only, enforced by requiring
`n_counts` alongside, rejecting negatives, and rejecting non-zero SS where `n_counts`
is 1. Supplying the component through both seams at once is an error, not a double
count.

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

**LANDED (#112).** `add_interviews()` now records
`design$n_anglers_supplied <- !is.null(n_anglers_col)`, and
`warn_party_hours_product()` fires on the product path of `estimate_total_catch()`,
`estimate_total_harvest()` and `estimate_total_release()` when it is `FALSE`. The
warning is placed after the bus-route dispatch: those totals are HT sums over
interviews with no rate multiplication, so warning there would be a false positive on
every bus-route call.

Blast radius was measured rather than guessed. 309 `add_interviews()` calls in the
suite pass `n_anglers` only 5 times, so the upper bound looked alarming; the measured
cost is **58 new warnings and 0 failures** (602 -> 660), because most tests never reach
a product total.

The predicate has to be the stored flag, not a runtime comparison of `.angler_effort`
against the effort column. When `n_anglers` is absent the two columns are identical and
there is no party-size data to consult, so the runtime check cannot distinguish "every
party is one angler" (no bug) from "we were never told" (the bug). The flag records the
second.

Examples: the four roxygen blocks that reach a product total were identified by parsing
`@examples` blocks rather than by grep over the file, which had matched prose. Three now
pass `n_anglers`, as does the `write_estimates()` example named above.
`man/example_sections_interviews.Rd`'s block is left warning **on purpose** --
`example_sections_interviews` carries no `n_anglers` column, so the warning is true
there and suppressing it would hide a real signal in the docs.

**Not done:** 16 vignettes call a product total and will now emit the warning. Sweeping
them is mechanical but touches 16 files, so it is left as a follow-up rather than folded
into this commit.

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

**LANDED (#110).** Both halves dispatched. Reproduced first on a bus-route fixture whose
catch records set the released count equal to the harvest column interview by
interview, which makes the true release total *equal* the true harvest total:

| call | before | after |
| ---- | ------ | ----- |
| `estimate_total_harvest()` (dispatch already present) | 465.4 (se 115) | 465.4 |
| `estimate_total_release()` | **51.1** (se 13.7) | **465.4** (se 115) |
| `estimate_total_release_br()` direct | 465.4 | 465.4 |
| `estimate_release_rate()` vs bus-route `estimate_harvest_rate()` | **0.225** vs 0.185 | 0.1198 vs 0.1198 |

The 51.1 is not a scaled harvest total; it is a different quantity, built by dividing
interview-derived releases by a `svytotal` over count rows. Without counts attached the
same call aborted demanding `add_counts()` — on precisely the designs whose own
estimator was sitting unused.

`estimate_total_release_br()` was verified before being trusted, per the routing note:
it had never executed. On the complete-trip path it reproduces the harvest total to
machine precision, so the dead code was correct as written.

RPUE reaches full parity with HPUE rather than the complete-trip path alone (user's
call): `use_trips` now accepts `"incomplete"` (truncated Hájek mean of ratios) and
`"diagnostic"`, and `truncate_at` is a public argument with the same name, default, and
units as on `estimate_harvest_rate()`. Rather than duplicate the estimator,
`estimate_release_br()` joins the release count and delegates to
`estimate_harvest_br()` with `harvest_col` repointed — the same temp-design idiom the
standard release path already used — under a new `metric` argument that selects the
`method` string and the noun in conditions. On the truth fixture (every angler releases
at 2 fish per angler-hour) both trip paths return exactly 2, tripling party size
divides both by 3, and `truncate_at = 2.5` drops n from 4 to 2 without moving the
estimate.

Two things left deliberately untouched, both flagged rather than fixed:

* `estimate_total_release_br()` does not filter to complete trips while
  `estimate_total_harvest_br()` does. `estimate_total_catch_br()` has the same gap, and
  finding 9 (#112) already owns the reject-vs-honour decision for `use_trips` on the
  bus-route total path. Deciding it twice, in two commits, would risk two answers.
* Per-species release on a bus-route design now aborts (`by = species` resolves against
  interviews, where the column does not exist) instead of silently returning a
  count-based number. `estimate_total_harvest()` has behaved this way since its own
  dispatch landed; the bus-route HT estimators take no species argument.

### 9. `estimate_total_catch()` accepts `use_trips` and discards it on the bus-route path

`R/creel-estimates-total-catch.R:144` calls `match.arg(use_trips)`; the bus-route
dispatch never forwards it. Verified: `estimate_total_catch_br()` performs **no** trip
filtering, while `estimate_total_harvest_br()` does filter to complete trips
(`R/creel-estimates-bus-route.R:50-53`).

So total catch sums interrupted-trip catch as though complete while total harvest does
not — the two are computed over different row sets on the same design, making their
comparison unsound.

Empirical demo (2026-08-09), on the 24-interview fixture forced to 12 complete and 12
incomplete with `rep(c("complete","incomplete"), length.out = n)`:

| call | estimate | se | n |
| ---- | -------- | -- | - |
| `estimate_total_harvest()` — filters to complete | 171.06 | 68.02 | 12 |
| `estimate_total_catch()` — no filter | 1089.81 | 242.60 | 24 |
| `estimate_total_catch()` as it would be if it filtered | 512.31 | 206.22 | 12 |

Unfiltered catch is **2.13×** the filtered figure. `use_trips` is provably inert on this
path: `"all"` and `"complete"` both return 1089.8125 at n = 24, so even the *default*
does not filter.

**Decision: GUARD — reject, do not honour.** Bus-route and ice totals are
complete-trip-only by construction; `use_trips = "all"` aborts on those designs.

The bus route is an **access-point** method, not a roving one — Malvestuto (1996) files
it under §20.3.1.2 Access Point Surveys, and the estimator implemented here is the
access-point estimator that section describes: "Completed trip lengths are simply added
over all interviews to obtain an estimate of fishing effort" (§20.5.1). Feeding it
uncompleted trips breaks it in two independent places:

- **Quantity.** The HT sum treats \eqn{c_i} as the trip's catch. An uncompleted trip
  reports catch *so far* — biased **down**.
- **Design.** \eqn{\pi_i} is the inclusion probability of a completed trip at a site
  during the circuit. Uncompleted trips are intercepted with probability proportional to
  trip length ("the probability of contacting an angler is proportional to trip length",
  Malvestuto 1996 §20.3.1.1, length-of-stay bias) — biased **up**.

The two run in opposite directions, so they do not cancel predictably and the net error
cannot even be signed. Honouring `"all"` would mean shipping an estimator whose bias
direction is unknown. This also matches what finding 4/5 (#108) already established:
incomplete trips support a **rate** (truncated Hájek mean of ratios, Hoenig et al. 1997),
never a total. No incomplete-trip total exists in the package or in the literature.

Implementation, all in one commit:

1. `estimate_total_catch_br()` and `estimate_total_release_br()` gain the complete-trip
   filter `estimate_total_harvest_br()` already has. This is the substantive half — the
   three are currently computed over different row sets on the same design, which is why
   171.06 and 1089.81 above are not comparable. Breaking: moves catch and release totals
   on any bus-route or ice design carrying incomplete trips.
2. `estimate_total_catch(use_trips = "all")` aborts on bus-route and ice, pointing at
   `estimate_catch_rate(use_trips = "incomplete")`. `"complete"` is accepted as a no-op —
   it is already the default, so callers passing nothing are unaffected.
3. **Do not** add `use_trips` to `estimate_total_harvest()` or `estimate_total_release()`.
   Neither carries it today, and an argument whose only legal value is its default is
   noise.

Edge case, unchanged: when `trip_status_col` is `NULL` nothing can be filtered, so all
rows are treated as complete — the existing `estimate_total_harvest_br()` behaviour, now
applied consistently across the three.

**LANDED (#112).** All three totals now route through one `br_complete_trips_only()`
helper rather than each carrying (or omitting) its own filter — the drift between them
*was* the defect, so consolidating is the fix that stops it recurring.
`estimate_total_catch()` aborts on `use_trips = "all"` for bus-route and ice, naming
`estimate_catch_rate(use_trips = "incomplete")` as the incomplete-trip route.

Measured on the mixed fixture: total catch drops from 1089.81 over 24 rows to 512.31
over 12, and catch and harvest now report the same `n` on the same design — the
invariant that matters, since the two estimate different quantities and should not
report the same estimate.

Mutation testing, 4/4: make the helper a no-op -> 3 failures; drop the filter from catch
only -> 3; from release only -> 2; remove the `use_trips = "all"` rejection -> 2.

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

**LANDED (#111).** Reproduced first on an 8-day bus-route fixture. All three totals came
back under the effort label, beside a genuine effort total for contrast:

| call | method before | method after | estimate | autoplot y-axis before | after |
| ---- | ------------- | ------------ | -------- | ---------------------- | ----- |
| `estimate_effort()` | `total` | `total` | 2513.38 angler-hours | Total Effort | Total Effort |
| `estimate_total_catch()` | `total` | `ht-total-catch` | 1089.81 fish | **Total Effort** | Total Catch |
| `estimate_total_harvest()` | `total` | `ht-total-harvest` | 464.77 fish | **Total Effort** | Total Harvest |
| `estimate_total_release()` | `total` | `ht-total-release` | — | **Total Effort** | Total Release |

The estimates are untouched; only the method string and everything derived from it move.
`print()` went from `Method: Total` to `Method: Total Catch (Horvitz-Thompson)`, and the
CSV provenance header from `Method: total` to `Method: ht-total-catch`.

The `ht-` prefix was the user's call over reusing the standard path's
`product-total-*` strings. Reuse was cheaper — two of the three names are already in all
three label maps — but it would have asserted an effort × rate product estimator where
the bus-route path is a Horvitz–Thompson sum over site contributions, making the two
estimators indistinguishable in the returned object. That is precisely the complaint
finding 14 raises about the rate path, so reuse would have written a second instance of
the defect while closing the first. `ht-` also matches the existing convention of naming
the estimator and the quantity.

Three label maps carry the new strings: `R/autoplot-methods.R`, `R/print-methods.R`, and
the `format()` method in `R/creel-estimates.R`. Unmapped strings fall through to the raw
method string rather than erroring, so a missed map degrades quietly — the tests assert
the rendered label, not just `$method`.

`br_build_estimates()`'s unused `key_col` parameter was dropped in the same commit
(user's call): it was documented and passed positionally by all three callers but never
read in the body, and the commit was already editing all four locations.

A `match.arg()` guard on the new `method` parameter was written and then removed: all
three call sites pass literals in the same file, so no test can reach it. Mutation-tested
to confirm — deleting the guard failed nothing.

Mutation testing, 5/5 caught: hardcode the ungrouped branch back to `"total"` → 8
failures; the grouped branch → 2 (only the `by =` path exercises it); mislabel the catch
call site as harvest → 5; mislabel the release call site → 2; drop the three `autoplot`
map entries → 4. Baseline unmutated: 0. Suite 3417 pass, 0 fail, 0 error.

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

**LANDED (#112).** `require_effort_estimates()` replaces the bare `inherits()` check in
both functions and tests `effort$method` against `effort_family_methods()`, which is
`c("total", "total-sections")` — determined by running `estimate_effort()` across design
types rather than by grepping for `method =` strings, which turns up the *argument*
named `method` on `estimate_effort()` itself and two unrelated defaults.

The guard also catches the other direction of the same mistake: since #111 the
bus-route HT totals carry `ht-total-*` strings, so a fish-valued total is rejected here
too. Before #111 they carried `"total"` and would have passed this allowlist — the two
findings had to land in this order.

Mutation testing, 1/1: make the allowlist admit everything -> 3 failures.

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

### 14. Ice designs skip the bus-route dispatch in the *rate* estimators

Added 2026-08-09, found while wiring #110. The total estimators dispatch on
`design_type %in% c("bus_route", "ice")`; the rate estimators dispatch on
`design_type == "bus_route"` alone (`R/creel-estimates.R:1676`, and the new release
dispatch mirrors it). One design object therefore takes the Horvitz-Thompson route for
its totals and the standard interview-survey route for its rates.

Reproduced on an 8-day, 24-interview ice fixture:

```
estimate_harvest_rate(ice_design)                    0.435   method ratio-of-means-hpue
estimate_harvest_br(ice_design, use_trips="complete") 0.420   method ratio-of-means-hpue
```

The two paths report the **same `method` string**, so nothing in the returned object
distinguishes them — the same property that made findings 3 and 8 survive. The gap here
is `.expansion`, not `p_site`: ice is degenerate in `p_site` (1.0) but not in the
within-site enumeration expansion, so the standard path is not a special case of the
HT one.

Ice is documented and implemented as a degenerate bus route, and `estimate_effort()`
and `estimate_total_harvest()` both treat it as one. The rate estimators are the
outlier.

**Decision: REAL BUG**, kept out of #110 on purpose — the fix moves every ice
harvest-rate number in the package and belongs in a commit whose title says so, with
its own regression fixture. **Not yet opened as a GitHub issue.**

### 15. `use_trips` is never validated on the bus-route path, so a typo silently changes the estimator

Added 2026-08-09, found while wiring #110. `estimate_harvest_rate()` and
`estimate_release_rate()` validate `use_trips` against `valid_use_trips_std` only on
the **standard** path. The bus-route dispatch runs before that check and hands the
string straight to `estimate_harvest_br()`, which branches on `== "diagnostic"`,
`== "complete"`, `else if (== "incomplete")` — with no final `else`. Anything
unrecognised therefore falls through to the complete-trip code **without the
trip-status filter**.

Reproduced on a 24-interview bus-route fixture, 12 complete and 12 incomplete:

| `use_trips` | bus-route result | same value, standard design |
| ----------- | ---------------- | --------------------------- |
| `"complete"` | 0.119752, n = 12 | — |
| `"all"` | 0.184918, n = 24 | — |
| `"bogus"` | **0.184918, n = 24**, silent | `Invalid use_trips value: "bogus"` |
| `"Complete"` | **0.184918, n = 24**, silent | aborts |

The dangerous cell is the last one: a capitalisation typo in a *valid* value returns
the all-trips answer, **54% away** from the complete-trip answer the caller asked for,
with no condition raised — and only on bus-route designs. The standard path rejects the
same input. This is the audit's own failure mode one level up: not a wrong dimension,
but a silently substituted estimator.

Both twins behave identically. The release dispatch added in `dc017aa` mirrored the
harvest behaviour deliberately rather than fixing one twin and creating an asymmetry.

Two questions to settle before coding:

- ~~Is `"all"` a legitimate bus-route value?~~ **Settled 2026-08-09 with finding 9:
  reject it.** The reasoning is recorded in full under finding 9 and applies unchanged
  to the rate path — an unfiltered pool of complete and uncompleted trips mixes a
  truncated numerator with a length-biased inclusion probability, in opposite
  directions. The valid sets are **not** the same on the two paths and should not be
  unified: `"incomplete"` is legitimate for rates (Hoenig et al. 1997) and illegitimate
  for totals. So `complete|incomplete|diagnostic` for the rate twins,
  `complete` only for the totals.
- Reject unknown values with a `cli_abort()` listing the valid set, matching the
  standard path's message, or `match.arg()` inside `estimate_harvest_br()`? **Prefer the
  explicit `cli_abort()`** — it is what the standard path already emits for the same
  mistake, and `match.arg()` would partial-match `"comp"` to `"complete"`, quietly
  accepting input the standard twin rejects.

**Decision: REAL BUG — guard.** Fix both functions in one commit so the twins stay
symmetric. **Not yet opened as a GitHub issue.**

**LANDED.** Both twins now call one `validate_use_trips_br()` before dispatching, so
their valid sets cannot drift apart the way the estimators themselves did under
findings 9 and 16. Reproduced first on a fixture of four complete and four incomplete
trips with rates that differ, so the substituted estimator shows in the number and not
only in `n`:

| `use_trips` | HPUE before | RPUE before | after |
| ----------- | ----------- | ----------- | ----- |
| `"complete"` | 2.642202, n = 4 | 2.990826, n = 4 | unchanged |
| `"incomplete"` | 2.000000, n = 4 | 2.000000, n = 4 | unchanged |
| `"diagnostic"` | both slots | both slots | unchanged |
| `"all"` | 2.816514, n = 8 | 2.816514, n = 8 | **abort** |
| `"bogus"` | 2.816514, n = 8 | 2.816514, n = 8 | **abort** |
| `"Complete"` | 2.816514, n = 8 | 2.816514, n = 8 | **abort** |
| `"comp"` | 2.816514, n = 8 | 2.816514, n = 8 | **abort** |

Note what the "before" column shows: every rejected value returned the *same* number,
because all four fell through to the complete-trip branch with the filter switched off.
The estimator was not selected by the argument at all once the argument stopped being
recognised.

Two things the audit did not predict. First, the **documentation was already correct** —
both `@param use_trips` blocks named `complete|incomplete|diagnostic` for bus-route
designs. The fix makes the code match its own docs rather than changing the contract;
what changed is that `"all"`, previously undocumented on this path and silently
accepted, now aborts. Second, `""` (empty string) takes the same fall-through, so it is
pinned in the tests alongside the typos.

Mutation 6/6, including one mutant that swaps the guard for `pmatch()` semantics — that
is the test that fails if the guard is ever rewritten as `match.arg()`.

### 16. Scalar `n_anglers` resolves positionally to the first column

Added 2026-08-09, found while sweeping the vignettes for #112. There is no way to tell
`add_interviews()` "every party is one angler". The obvious spelling, `n_anglers = 1`,
does not mean the scalar 1 -- it is resolved as a **column selector**, and tidyselect
reads a bare integer as a position. `n_anglers = 1` therefore means *column 1*.

Reproduced on `example_interviews` reordered so that a numeric column comes first:

```
ei <- example_interviews[, c("catch_kept", setdiff(names(example_interviews), "catch_kept"))]
d  <- add_interviews(design, ei, catch = catch_total, effort = hours_fished, n_anglers = 1, ...)

d$n_anglers_supplied                                      # TRUE
all.equal(d$interviews$.angler_effort,
          d$interviews$hours_fished * d$interviews$catch_kept)   # TRUE
```

`.angler_effort` became hours x **catch_kept** -- effort multiplied by a *fish count*.
With the shipped column order the first column is `date`, so the same call fails with
`* not defined for "Date" objects`: an error whose text names neither `n_anglers` nor
the column it picked. Whether the user gets a confusing error or silent corruption
depends on their column order.

This is finding 1's failure mode (`add_counts()` selecting the count column
positionally) in a second location, and it defeats the guard added for finding 7 in the
same breath: `n_anglers_supplied` is set to `TRUE`, so the warning that exists to catch
exactly this mismatch is switched **off** by the input that causes it.

**Decision: REAL BUG -- guard.**

**LANDED.** A bare number is now a constant party size rather than a column position:
`n_anglers = 1` states one angler per interview, `n_anglers = 3` states three. Bare
column names are untouched. The user chose this over rejecting numeric literals
outright, because it is the only option that lets a solo-angler survey be *stated* --
and therefore the only one that lets such a survey silence the finding-7 warning without
inventing a constant column, which is what the vignette sweep had to do.

Those fabricated columns were removed in `797e7bc`, which states `n_anglers = 1`
directly in `progressive-count-surveys.Rmd`, `temporal-extrapolation.Rmd` (2 call sites)
and `catch-pipeline.Rmd`. Every number was unchanged: the column held `1L`, the constant
is `1`, and a constant column consumes no RNG draws. The sequence closed on itself --
the vignette sweep needed a workaround, the workaround exposed this finding, and fixing
it made the workaround unnecessary.

Tracing the cascade reframed the fix. `.angler_effort` is derived once at
`add_interviews()` and stored, after which it is an anonymous numeric column read as
angler-hours by **37 references across 6 files** (`creel-estimates.R`,
`creel-estimates-bus-route.R`, `creel-summaries.R`, `creel-estimates-total-release.R`,
`creel-estimates-regression-cpue.R`, `survey-bridge.R`). Nothing downstream can tell
hours x party-size from hours x anything-else, so construction is the only place a wrong
multiplier can be caught -- and a guard on the argument's *shape* is the smaller half.
The reproduction resolved to `catch_kept`, a **real column name** that any shape guard
would accept, holding a zero: a party of no anglers. `validate_party_size()` therefore
checks values wherever they come from -- constant or column. Zero, negative and
non-finite abort; missing aborts as a constant but warns as a column, since a column may
legitimately have gaps and a stated constant may not; non-integer warns.

Two details worth keeping:

- `-2` parses as a *call* to `-`, not a numeric literal, so it initially slipped past the
  literal branch into tidyselect and reported "must select exactly one column, not 11".
  `party_size_literal()` handles unary minus explicitly so the message names the real
  problem.
- Only bare literals were ever silent. An **external variable** (`v <- 2;
  n_anglers = v`) already draws a tidyselect deprecation warning pointing at `all_of()`,
  so it is out of scope by design rather than by oversight.

`compute_angler_effort()` was fixed in the same commit -- it is the other exported entry
point that writes `.angler_effort`, and fixing one twin and not the other is the drift
pattern findings 9 and 15 are both about.

Mutation testing, 6/6: disable literal detection -> 5 failures; drop the non-positive
check -> 5; remove the unary-minus branch -> 1; stop counting a constant as supplied ->
2; ignore `allow_missing` -> 1; remove the literal branch from `compute_angler_effort()`
-> 3. **Never opened as a GitHub issue.**

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
