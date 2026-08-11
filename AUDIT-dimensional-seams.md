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
implemented as a degenerate bus route). Aerial and camera were *not* in the original
scope but were pulled in on 2026-08-10 by findings 21 and 22, which surfaced while
extending unit propagation — the effort family cannot be labelled without deciding
where each design's period length comes from. Mark-recapture and exploitation rate
were audited on 2026-08-11 while labelling the last unlabelled estimators, producing
findings 23–25. Still not audited: the `tidycreel.connect` boat→angler
reconstruction.

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
| 12 | #113 | ~~Documentation asserts units the code does not produce~~ **LANDED** (12a 2026-08-08, 12b and 12c 2026-08-10) |
| 13 | *not opened* | ~~Instantaneous path never carries T, so it returns angler-days~~ **LANDED 2026-08-10** (added 2026-08-08), with the first pass of unit propagation |
| 20 | *not opened* | `circuit_time` cancels out of the progressive estimate and cannot change any output (added 2026-08-10) |
| 14 | *not opened* | ~~Ice designs skip the bus-route dispatch in the rate estimators~~ **LANDED** (added and fixed 2026-08-09) |
| 17 | *not opened* | ~~`estimate_catch_rate()` has no bus-route or ice dispatch at all, and no CPUE estimator existed to dispatch to~~ **LANDED** (added and fixed 2026-08-09, with finding 14) |
| 15 | *not opened* | ~~`use_trips` unvalidated on the bus-route path; a typo silently swaps the estimator~~ **LANDED** (added and fixed 2026-08-09) |
| 16 | *not opened* | ~~Scalar `n_anglers` resolves positionally to the first column, and sets `n_anglers_supplied = TRUE`~~ **LANDED** (added and fixed 2026-08-09) |
| 18 | *not opened* | ~~Species rates on bus-route and ice designs ignore the HT weights~~ **LANDED** (added and fixed 2026-08-09) |
| 19 | *not opened* | ~~Species totals abort on bus-route and ice designs~~ **LANDED** (added and fixed 2026-08-09) |
| 21 | *not opened* | ~~Finding 13 made aerial and camera designs apply time twice~~ **LANDED** (added and fixed 2026-08-10) |
| 22 | *not opened* | The camera ratio path cannot know whether it returned angler-hours or party-hours; unit recorded `NA`, ambiguity **not fixed** (added 2026-08-10) |
| 23 | *not opened* | ~~`estimate_mr_harvest()` multiplied by a proportion of anglers and called the product total harvest~~ **LANDED** (added and fixed 2026-08-11) |
| 24 | *not opened* | ~~`estimate_exploitation_rate()` documented `C` as coming from `estimate_total_catch()`, but the estimator needs harvest~~ **LANDED** (added and fixed 2026-08-11) |
| 25 | *not opened* | `estimate_angler_n()` cannot know whether it counted anglers, boats, or parties; unit recorded `NA`, ambiguity **not fixed** (added 2026-08-11) |
| 26 | *not opened* | ~~Binned release counts claimed integer enforcement that was never there~~ **LANDED** (added and fixed 2026-08-11, from the `cli_abort()` sweep finding 12c called for) |

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
| #113 | 12a | **Opus** | ~~`flexible-count-estimation.Rmd` needs a *correct* replacement worked example.~~ **LANDED** (`3af819f`, 2026-08-08). |
| #113 | 12b | **Sonnet** | ~~`glossary.Rmd:68`, `data.R:330`, `ice-fishing.Rmd:~214-218`, `tidycreel.Rmd:47/71` — prose only, exact target text already identified.~~ **LANDED** (2026-08-10). Not prose only: two of the four targets carried stale *numbers*, and the ice one had gone stale a second time when #112 landed the completed-trip filter. |
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

**LANDED (#113).** 12a in `3af819f` (2026-08-08); 12b on 2026-08-10. Four things
worth recording, because "prose only" was wrong three times over.

*The decoy was not confined to one vignette.* `open_hours` survived in six more
places after 12a — `progressive-count-surveys.Rmd:63,91,249`,
`effort-pipeline.Rmd:113,241,324`, `temporal-extrapolation.Rmd:73` — all inert
calendar columns, since `creel_design()` reads only the date and the strata. The
progressive one was the worst of them: its data-requirements list called the
calendar's `open_hours` the \eqn{T_d} the estimator uses, when the real \eqn{T_d}
travels with the counts as `shift_hours` via `period_length_col`. All six removed.

*Two targets carried stale numbers, not just stale units.* `tidycreel.Rmd:71`
claimed "approximately 358 angler-hours" against an actual **372.5**, and `:83`
claimed weekend 250 / weekday 108 against an actual **201.9 / 170.6**. The second
was also framed misleadingly: the calendar holds 10 weekdays to 4 weekend days, so
a weekend total only 18% higher corresponds to a per-day rate roughly **3x** higher
(50.5 against 17.1). Every number in the fix was read off a rendered chunk rather
than off the prose it replaced.

*`example_counts` is angler-hours, so the units half of the `tidycreel.Rmd`
finding pointed at the wrong line.* The values are fractional (45.2, 52.8) in a
column named `effort_hours`. L71's "angler-hours" was therefore correct and L47's
"instantaneous count observations" was the wrong half — the reverse of what this
finding assumed. `R/data.R:39` had the same ambiguity as `:330` two entries up and
was fixed with it.

*The ice text had gone stale a second time, after this finding was written.* It
described `estimate_total_catch()` as CPUE x effort over all interviews. By the
time 12b landed, #112 had added `br_complete_trips_only()`, so the live behaviour
is an HT sum (`ht-total-catch`) over **complete trips only** — verified 60 of 72
interviews, `use_trips = "all"` refused, and no effort term at all. The vignette
also credited the delta method for the SE, where the HT path uses Taylor
linearization; there is no product whose uncertainty needs propagating. A doc
finding aimed at a moving estimator has to be re-verified against the branch, not
against the audit entry.

**12c (2026-08-10): an error message claiming an enforcement that was never there.**
Found while labelling trip density. `require_effort_estimates()` aborted with *"must
hold angler-hours, but carries {method}"*, and the roxygen on both consumers said the
same — `estimate_angler_trips()` "dividing extrapolated angler-hours effort",
`estimate_effort_per_acre()` "producing angler-hours per acre". The guard only ever
compared `effort$method` against `c("total", "total-sections")`. A party-hours effort
passed it silently, which is how a bus-route design with no `n_anglers` reaches these
estimators today.

This is the reverse of the usual shape in this finding. Elsewhere the prose describes
arithmetic the code does not do; here the *code* describes a check it does not
perform, in the string the user actually sees when it fires.

**Fixed by correcting the claim, not by adding the check.** Enforcing angler-hours
would reject party-hours effort, which is a legitimate input — the consumers now carry
the actor through to their own unit (`party-trips`, `party-hours/acre`), so there is
nothing left to protect against. The guard polices the *quantity*, not the actor: a
rate or a fish-valued total still cannot be divided by acres and relabelled. Message
is now "must hold effort"; a test pins both halves, that party-hours is accepted and
that a rate is still refused.

**Lesson.** The audit's rule is "derive, never declare". A guard's error message is a
declaration too, and this one had been asserting a dimension for as long as the
function existed without a line of code behind it. Worth checking the other abort
messages for the same shape.

Gate: all 8 affected and dependent vignettes knit, and the three numbers above were
confirmed against the rendered HTML.

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

**LANDED (estimator half, 2026-08-10).** The unit-propagation half is still ahead;
see "Prevention: carry the unit on the object". Four things the writeup did not
anticipate.

*The gap was worse than "no way to supply T".* Supplying `period_length_col` on an
instantaneous design was **accepted and discarded**: no error, no warning,
`design$period_length_col` set as though it were in use, and the T_d column left
sitting unread in `design$counts`. On an 8-day fixture with T_d of 8–14 hours the
estimate came back 140 against a true 1780. So the finding was not only a missing
capability, it was a silent one.

*The machinery already existed and was already general.* `period_length_col` is
resolved unconditionally in `add_counts()` for any `count_type`, stored on the
design, and excluded from count-column resolution. Two `count_type ==
"progressive"` guards were the whole gate. Applying T_d at attach time means the
ungrouped, grouped, sectioned and within-day-variance paths inherit it with no
dispatch of their own — the fix is `apply_period_length()` plus widening two `if`s.

*The positivity guard was inside the progressive block*, so a zero or negative
period passed unchecked on an instantaneous design. Moved out.

*Answering the open questions.* `period_length_col` was generalised rather than a
new argument added, as the writeup preferred. Absent T_d **warns once per session**
and returns the counts as before. The warning deliberately does **not** label the
result angler-days, which departs from `unit_out = unit_in × days` in the
prevention section: `example_counts$effort_hours` already holds angler-hours, so
the package cannot tell a head count from a pre-expanded effort column — both are
a numeric column. Asserting "angler-days" there would produce exactly the
confident, well-labelled, wrong number that section warns about. The honest
derived state is unknown; the warning carries the reading instead.

Mutation testing, control 0: disabling the instantaneous application 5 kills (Ê_d
came back 10, 20 against a true 80, 160); replacing per-row T_d with `mean(T_d)`
5 kills (330 against 360 — the collapsed, biased-low form); dropping the ss_d
T_d² scaling 2 kills; removing the warning 1 kill, with the two does-not-warn
tests correctly unmoved.

### 20. `circuit_time` cannot change any progressive effort estimate

Found 2026-08-10 while reading the progressive path for finding 13. Not yet fixed.

`compute_progressive_effort()` computes
\eqn{\hat{E}_d = C \times \tau \times \kappa} with \eqn{\kappa = T_d / \tau}, so
\eqn{\tau} cancels and the result is \eqn{C \times T_d}. Verified: the same design
with `circuit_time = 2` and `circuit_time = 5` returns **1490** both times.

`circuit_time` is nonetheless required, type-checked, and stored on the design. Its
only live effect is the \eqn{\kappa < 1} advisory warning. So a user who supplies
the wrong \eqn{\tau} gets the right number, and a user who reasons about \eqn{\tau}
as an input to the estimate is reasoning about something inert. The vignette states
the cancellation algebraically, which makes this a naming and API question rather
than a wrong number: it is the one parameter in the count path whose value cannot
move any output.

Worth deciding whether it stays required. Not a dimensional defect — flagged here
because the audit's method is to surface seams where a plausible input has no
effect on the answer.

### 21. Finding 13 made aerial and camera designs apply time twice

Found 2026-08-10 while extending unit propagation to the effort family. **LANDED**
the same day. This is a regression introduced by the audit's own fix, which is why
it is written up rather than quietly patched.

`estimate_effort_aerial()` computes \eqn{\hat{E} = \mathrm{svytotal}(C) \times
h_{open}/v} (Pollock Eq. 15.4), and its comment asserted "svytotal on the raw
instantaneous count". `estimate_effort_camera()`'s raw-count fallback does the same
with a caller-supplied `h_open`. Both treat \eqn{h_{open}} as *the* period length.

Finding 13 (`ee3e74f`) made `apply_period_length()` multiply the count column by
\eqn{T_d} at attach time for **any** `count_type`, with no `design_type` guard. So a
design carrying both got \eqn{C \times T_d \times h_{open}} — angler-hour-*hours*.
Measured on a 4-day design, \eqn{h_{open} = 14}, \eqn{T_d = 2}:

| | counts column | estimate | `effort_unit` |
| --- | --- | --- | --- |
| no `period_length_col` | 10 20 30 40 | **1400** | `NA` |
| with `period_length_col` | 20 40 60 80 | **2800** | `angler-hours` |

Camera reproduces the same 2x through `est_effort_camera(h_open = )`, which is a
separate exported entry point and is *not* reached by `estimate_effort()`.

Two things make this worse than an ordinary arithmetic bug. The aerial result is
labelled `angler-hours` by the unit spine — the confident, well-labelled, wrong
number the prevention section exists to prevent, produced by the machinery built to
prevent it. And before finding 13 the same call was *harmless*: `period_length_col`
on a non-progressive design was accepted and discarded, so aerial returned 1400 by
accident. Finding 13 converted a silent no-op into a wrong number.

**Fix.** Refuse rather than silently pick a side. \eqn{h_{open}} is a required slot
on the aerial design and already is the period length; two sources for one quantity
is the defect, and a caller who supplied both has a wrong model of which term the
estimator applies that a silent choice would preserve. `add_counts()` aborts with
class `creel_error_aerial_period_length` when `period_length_col` meets
`design_type == "aerial"` — eagerly, matching the documented "catch design errors at
`add_counts()`" pattern, since both facts are known at attach time.

Camera's guard sits in `estimate_effort_camera()` instead, because `h_open` is an
argument there and is unknown at attach time. It is scoped to the raw-count branch
only: the ratio-calibration path divides by `mean(count)` before multiplying by
`count`, so a constant \eqn{T_d} cancels and does no harm. That cancellation is
asserted by a test rather than assumed — the ratio path returns **36** with and
without \eqn{T_d}.

Mutation, control 0: disabling the aerial guard **1** (mutant returns 2800 against a
true 1400); disabling the camera guard **1** (same 2800 against 1400); re-scoping the
aerial guard to `design_type == "instantaneous"` **24** across the suite, which is
what pins it to aerial rather than to any design carrying \eqn{T_d}.

**Lesson for the prevention section.** Finding 13 generalised \eqn{T_d} from the
progressive path to "any `count_type`" on the reasoning that the machinery was
already general. It was — but two estimators had their *own* period-length term,
supplied through a different door. Generalising a multiplication requires checking
every consumer for a term that already plays that role, not only that the plumbing
accepts it.

### 22. The camera ratio path cannot know whether it returned angler-hours or party-hours

Found 2026-08-10 while labelling the effort family, by asking where the ratio path's
unit comes from and finding that nothing in the package can answer. The unit is
recorded as `NA` (`b3611d6`), which is honest but is a **marker, not a fix** — the
underlying ambiguity is untouched.

Everywhere else in tidycreel, angler-hours vs party-hours is decided in one place:
`add_interviews(n_anglers = )` performs the multiplication, records
`design$n_anglers_supplied`, and `interview_effort_unit()` reports the result. That
is the mechanism finding 7 exists to police.

`est_effort_camera()` bypasses all of it. Its `interviews` is a **plain data frame
passed as an argument**, not an `add_interviews()` attachment, and `effort_col` is a
**bare string defaulting to `"hours_fished"`**. Grepping the camera path for
`n_anglers` or party size returns nothing. The calibration is

\deqn{\rho_h = \frac{\sum_d E_d}{\sum_d C_d}, \qquad \hat{E} = \sum_h \hat{T}_h \rho_h}

so the counts cancel and the result carries whatever unit `effort_col` was in. The
design cannot stand in for that column: on the documented example
`design$angler_effort_col` is `NULL` and `example_camera_interviews` has
`hours_fished` but **no `n_anglers` column at all**.

Measured on that example, varying only whether the input column is party- or
angler-hours (synthetic party sizes, mean 1.875):

| `hours_fished` holds | estimate | reported unit |
| --- | --- | --- |
| party-hours (the shipped example) | **110.902** | `NA` |
| angler-hours | **205.098** | `NA` |

Two different physical quantities, a factor of 1.849 apart, reported identically.
The ratio is the count-weighted mean party size rather than the simple mean, because
\eqn{\rho} is a ratio of sums.

This is finding 7 again, in the one path where the unit spine cannot diagnose it.
`add_interviews()` at least *warns* when `n_anglers` is omitted; here nothing warns,
because nothing on this path ever looks. And because `est_effort_camera()` is a
separate exported entry point, a caller reaches it without passing through any of
the machinery that would have asked.

The consequence is not confined to the effort number. A camera effort total that is
silently party-hours, multiplied by a CPUE that is per angler-hour, is the mixed
denominator of finding 2 — and `check_product_units()` cannot catch it, since it
compares design-level units and this quantity has none.

**Not fixed.** Two candidate directions, both unexplored:

1. Give `est_effort_camera()` an `n_anglers` argument mirroring `add_interviews()`,
   so the same normalisation and the same recorded provenance apply. Makes the unit
   derivable rather than unknown, at the cost of a second place implementing the
   party-size rule.
2. Warn when the ratio path runs, naming the ambiguity, as `add_interviews()` does
   for the same omission. Cheaper, and consistent with how the package already
   treats this exact gap, but leaves the number ambiguous.

Direction 1 is the better match for the audit's "derive, never declare" line;
direction 2 is what the codebase already does at the analogous seam. Not decided.

### 23. `estimate_mr_harvest()` multiplied by a proportion and called the product harvest

Found 2026-08-11 while labelling the mark-recapture family, by asking what unit
\eqn{\hat{H} = \hat{N} \times r} carries and discovering that the answer depended on
a question the documentation answered one way and the function name answered another.

`harvest_rate` was documented as "Proportion of anglers that harvested fish" and
guarded to \eqn{(0, 1]}. Under that reading the arithmetic is

\deqn{\hat{H} = \underbrace{\hat{N}}_{\text{anglers}} \times \underbrace{r}_{\text{dimensionless}} = \text{anglers who kept a fish}}

but the result is returned as `parameter = "total_harvest"`, from a function called
`estimate_mr_harvest()`, with `method = "mark-recapture-harvest"`, under a vignette
section headed "Total Harvest from Mark-Recapture". Four places said the output was
fish; one param description and one guard said the multiplier was a proportion, which
makes the output anglers. Both cannot hold.

Measured on the documented example before the fix:

| call | returned | labelled | reading under the old param doc |
| --- | --- | --- | --- |
| `estimate_mr_harvest(N̂ = 930.909, harvest_rate = 0.35)` | **325.818** | `total_harvest` | 325.8 *anglers* who kept ≥1 fish |
| `estimate_mr_harvest(N̂ = 930.909, harvest_rate = 1.4)` | **error** | — | rejected by the `(0, 1]` guard |

The second row is the sharper half. A fishery averaging 1.4 kept fish per angler is
ordinary, and the guard made total harvest unreachable for it — the guard was not
merely documenting the wrong reading, it was enforcing it. The guard arrived as a
"WARNING-03 fix" and was pinned by Test L in `test-estimate-mr-harvest.R`, so the
wrong reading had a test defending it.

The failure is the audit's own class with the roles reversed. Elsewhere a number
crosses a boundary with its dimension unasserted; here the dimension was asserted in
two incompatible ways at the same boundary, and the arithmetic silently picked one.
A manager reading `total_harvest = 325.8` takes it for fish. Under the documented
multiplier it was a count of people.

**Fixed** (2026-08-11). `harvest_rate` is now documented as harvest per angler, in
fish per angler, and the upper bound is dropped — the guard is `> 0`. Every
previously legal call returns the identical number, because the arithmetic never
changed; what changed is which quantity the caller is told to supply, and that calls
above 1 are now reachable. Test L is inverted to pin that a rate above 1 is accepted,
with the reasoning recorded in the test.

**Caveat on the fix direction.** The `creel-knowledge` KB is broken (searches for
Hansen & Van Kirk 2018 returned Cochran sampling theory and Wolter variance
estimation at relevance 0.0), so the primary reference could not be consulted. The
direction rests on internal evidence — the function name, the parameter label, the
method string, the docstring title, and the vignette heading all say the output is
harvest in fish — plus the standard expansion of an angler count to a harvest total
being a per-angler rate. Worth a literature confirmation before release.

### 24. `estimate_exploitation_rate()` is documented against the wrong input

Found 2026-08-11 alongside finding 23. `C` was described as "Total creel harvest
estimate (from `estimate_total_catch()`)", and the vignette said the same. The two
halves of that sentence name different quantities.

Exploitation rate is the fraction of a tagged cohort removed by the fishery:

\deqn{\hat{u} = \frac{C \cdot m}{T \cdot n}}

Catch includes fish that were caught and released. Those fish were not removed from
the cohort and are still available to be caught again, so feeding a catch total where
harvest is required inflates \eqn{\hat{u}} by the release fraction — which in a
catch-and-release-dominated fishery is most of the catch. `estimate_total_catch()`
and `estimate_total_harvest()` are separate exported functions, so the wrong one was
named by a live cross-reference a user would follow.

The unit spine cannot help here, and that is the point worth recording. Both totals
are counts of fish and both carry `unit = "fish"`, so `check_product_units()` sees a
dimensionally coherent expression. The actor matches; the *quantity* does not. This
is the limit of a single-token unit: `"fish"` distinguishes fish from angler-hours,
not harvested fish from caught fish.

**Fixed** (2026-08-11). `@param C` and `@param strata` now point at
`estimate_total_harvest()`, state that harvest and not catch is required, give the
reason, and note that no unit check can detect the substitution. The vignette carries
the same correction. No code change — the estimator was always right about what it
needed, and only the documentation sent callers elsewhere.

### 25. `estimate_angler_n()` cannot know whether it counted anglers, boats, or parties

Found 2026-08-11 while labelling the mark-recapture family. The handoff for this work
specified `"anglers"`; re-deriving it before implementing showed that nothing in the
function can support the claim.

`M`, `n`, and `m` arrive as bare numerics. There is no design, no attached
interviews, and no argument naming what the marking protocol marked. The arithmetic

\deqn{\hat{N} = \frac{(M+1)(n+1)}{(m+1)} - 1}

is actor-preserving: it divides counts by counts, so \eqn{\hat{N}} carries whatever
actor the inputs carried and the code never observes which that was. The parameter
documentation itself says "marked **animals**", generic mark-recapture boilerplate,
while the function name says anglers. Creel mark-recapture is routinely run on boats
or trailers at access points rather than on individual anglers, so this is not a
hypothetical caller.

This is finding 22's shape at a different seam, with one difference that matters: the
camera ratio path has an input column whose unit *could* in principle be derived, so
its ambiguity is fixable. Here there is no channel at all — no measurement can
discriminate, because no input varies the answer. A label here could only ever be a
restatement of the function name, which is precisely what the "derive, never declare"
line in `R/survey-bridge.R` exists to forbid. Compare the aerial effort estimator,
which does assert `"angler-hours"` unconditionally: there the function's own
arithmetic multiplies angler counts by `h_open`, so the code earned the label.

The consequence propagates. `estimate_mr_harvest()` multiplies \eqn{\hat{N}} by a
per-angler rate, so its product is fish only if \eqn{\hat{N}} counted anglers. That
is why both estimators now report `NA` rather than `"anglers"` and `"fish"`.

**Not fixed.** The unit is recorded as `NA`, which is honest but is a marker, not a
fix. The candidate direction, parallel to finding 22's direction 1, is an explicit
argument naming the marked unit — but unlike the camera case that argument would
carry no data the code could verify, so it is a declaration wearing a derivation's
clothes. A warning at the seam, finding 22's direction 2, is the cheaper option and
is what the codebase already does at analogous gaps. Not decided.

### 26. Binned release counts claimed integer enforcement that was never there

Found 2026-08-11 by the sweep finding 12c called for: checking the other `cli_abort()`
messages for a guard declaring something no code behind it enforces. 514 call sites
across 44 files; this is the only new instance.

`add_lengths()` with `release_format = "binned"` validated the count column in two
steps — abort on `NA`, abort on `<= 0` — and the first of those messages read "Every
release row must have a positive **integer** count". Nothing tested integrality.
Verified by running it: a release table with `count = c(3.5, 2.7)` returned a
`creel_design` with `3.5` and `2.7` stored on `design$lengths`, no warning.

The value is not inert. `design$lengths_count_col` reaches
`estimate_length_distribution()` (`R/creel-estimates-length.R:155`), which aggregates
it as `.fish_count` per length bin, so a fraction of a fish enters the distribution
and every proportion computed from it.

**The precedent is in the same file.** `validate_party_size()`
(`R/creel-design.R:171`) checks `x != round(x)` and warns "Party sizes are counts of
anglers; a fractional value suggests a wrong column". Same category error — a
fractional count of discrete things — policed 3,700 lines earlier and unpoliced here.

**Fixed by adding the check, which is the opposite of 12c's fix.** That is
deliberate. 12c corrected the message rather than adding the check because enforcing
angler-hours would have rejected party-hours effort, a legitimate input. No fractional
count of fish is legitimate, so the discriminator does not transfer and the
party-size precedent governs instead. The check warns rather than aborts, matching
that precedent: a fractional count signals a wrong column, and aborting would break
data that has always been accepted. The `NA` message now says "a positive count;
non-integer values warn", so the claim and the code match exactly.

**Boundary of the sweep, stated because it decides what counts as this shape.**
Parenthetical unit hints — `"must be a single positive number (hours)"`, `"All
harvest lengths must be > 0 mm"` — are *not* instances. They instruct the caller
which unit to supply, which is the only thing a guard on a bare numeric can do. 12c's
message claimed verification by naming the value it had observed ("must hold
angler-hours, but carries `{method}`"). That is the distinction: a message that
reports an observation implies a check; a message that states an expectation does not.

**Everything else came back clean**, each verified rather than skimmed: `conf_level`
(8 sites, all enforcing the open interval they name), `na_threshold`,
`visibility_correction`, `circuit_time` (2 sites), `open_start`, `period_length`, the
hybrid-design fractions, `check_product_units()`, `require_effort_estimates()`, the
MOR guard (which counts incomplete trips rather than proxying via column presence),
and the camera double-time guard — that last one sound because `design$effort_unit`
has exactly one writer, `R/creel-design.R:1669`, which sets `"angler-hours"` if and
only if `period_length_col_name` is non-`NULL`, so the message names the true cause.

**Adjacent, not fixed.** `est-effort-camera.R:96` and `creel-estimates-bus-route.R:709`
omit the `length(x) != 1L` term their sibling guards carry, so a length-2 input dies
on R's `||` error instead of the guard's message. Not a dimensional defect.

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

**Sharpened by finding 15 (2026-08-09), not caused by it.** The guard added for finding
15 fires on `design_type == "bus_route"` only, so ice rate estimators still fall to the
standard path and its `all|complete` set. Measured on an 8-day, 24-interview ice fixture
*after* the finding-15 commit:

```
estimate_harvest_rate(ice, use_trips = "complete")     0.514328  n = 24
estimate_harvest_rate(ice, use_trips = "all")          0.514328  n = 24
estimate_harvest_rate(ice, use_trips = "incomplete")   abort: Invalid use_trips value
estimate_harvest_rate(ice, use_trips = "diagnostic")   abort: Invalid use_trips value
```

The rejections are **not new** — the standard path's check predates finding 15. What
changed is that the contradiction is now *written down twice*: one guard says the
bus-route rate family takes `complete|incomplete|diagnostic`, the other says a design the
package documents as a degenerate bus route takes `all|complete`. An ice design is
therefore refused the two values its own design type is supposed to support, and offered
`"all"`, which finding 15 rejects for the estimator it is meant to be running.

This is a second symptom of the same dispatch gap, so it lands with the fix above rather
than separately; the regression fixture that pins the moved ice rate numbers should pin
the accepted `use_trips` set alongside them.

**LANDED (with finding 17).** All three rate estimators now dispatch on
`design_type %in% c("bus_route", "ice")`.

The reproduction that settled which answer was wrong is **internal consistency**, not a
reference value: a ratio of HT totals must equal `total / effort` *exactly*, because it
is that ratio. Measured before the fix:

| design | rate | before | its own totals imply | gap |
| ------ | ---- | ------ | -------------------- | --- |
| ice | HPUE | 0.514328 | 0.478561 | +7.47% |
| bus-route | CPUE | 0.466438 | 0.433603 | +7.57% |

After the fix all four rate/total pairs (ice HPUE, ice RPUE, ice CPUE, bus-route CPUE)
reconcile to 0.00%. Ice consequently takes the bus-route `use_trips` set, closing the
contradiction recorded above: it now accepts `"incomplete"` and `"diagnostic"` and
rejects `"all"`.

**The suite did not notice.** Widening the dispatch — which moves every ice rate number
and every bus-route CPUE number in the package — produced **0 failures** against 3477
passing tests. That is not a safety signal; it is the audit's own thesis in the tests
rather than the code. No fixture pinned an ice rate or a bus-route CPUE, so the fixtures
were degenerate in exactly the dimension that mattered. Worse, once the new tests were
written, the mutant that drops ice from the **release** dispatch still failed nothing
until an ice RPUE fixture was added specifically for it: the harvest and catch twins were
pinned and the release twin was not, which is findings 9, 15 and 16's drift pattern
reappearing one level up, in the test suite.

Mutation 6/6 after that gap was closed.

### 17. `estimate_catch_rate()` has no bus-route or ice dispatch, and no CPUE estimator existed

Added 2026-08-09, found while reproducing finding 14. Finding 14 assumed the rate
estimators were correct on bus-route designs and wrong only on ice. They are not:
`estimate_catch_rate()` never had a bus-route dispatch either, so CPUE came off the
standard interview survey on **both** design types while `estimate_total_catch()` and
`estimate_effort()` on the same object took the Horvitz-Thompson route.

```
estimate_catch_rate(bus_route)        0.466438   method = "ratio-of-means-cpue"
HT total catch / HT effort            0.433603
```

There was also nothing to dispatch *to*: `estimate_harvest_br()`'s `metric` argument was
`c("hpue", "rpue")`, so no bus-route CPUE estimator existed anywhere in the package.

**Decision: REAL BUG — fix with finding 14** (user's call, 2026-08-09; the alternative
considered was recording it and fixing separately). Fixing two of three sibling
estimators would have written the next instance of the drift the audit keeps finding.

**LANDED.** `metric` gains `"cpue"` and a new `estimate_catch_br()` repoints
`harvest_col` at `catch_col` and delegates to `estimate_harvest_br()` — the same
delegation `estimate_release_br()` already used, so the three siblings now share one
estimator body rather than three copies that can drift.

**Coverage follow-up (2026-08-09).** The fix shipped with the reconciliation test and
nothing else, so bus-route CPUE and ice CPUE were each pinned by exactly **one**
assertion — up from zero, but reconciliation only sees the pooled point estimate. Both
now carry what the HPUE and RPUE twins already had: a per-angler-hour dimensional check
on both trip paths, SE/CI/`n`, grouped (`by = day_type`) reconciliation within each
stratum, the `method` string on both trip paths, and a numerator check that moves catch
without moving harvest. Perturbing every numeric column of the CPUE result kills **6**
tests on each design type (was 1); control run kills 0. Three targeted mutants on
`estimate_catch_br()` — `metric = "hpue"`, dropping the `harvest_col` repoint, and
dropping `by_vars` — kill 2, 5 and 1. The last was **0** before this work: grouped output
was unmeasured for every quantity, because the coverage sweep's probe perturbed column 1,
which is the group label.

**Deliberately out of scope at the time:** species CPUE (`by = species`) kept the standard
path, on the reasoning that it routes to `estimate_cpue_species()`, a different estimator
reporting a `-cpue-species` method, and that the bus-route path could not compute it. A
test pinned the carve-out so it read as a decision rather than an oversight. **That
reasoning was wrong on the second half and the decision is reversed by finding 18** — the
bus-route path computes it fine once the numerator is repointed one species at a time,
which is the delegation `estimate_release_br()` was already using.

### 18. Species rates on bus-route and ice designs ignore the HT weights

Added 2026-08-09, the carve-out finding 17 recorded and declined to fix. The species-level
rate estimators — `estimate_cpue_species()`, `estimate_hpue_species()`,
`estimate_release_rate_species()` — build a per-species interview table and hand it to the
**standard** interview-survey estimators, so on a bus-route or ice design they ignore
`.pi_i` and `.expansion` entirely. Findings 14 and 17 fixed the all-species side and left
this one, which is what made the contradiction visible: one design object then returned
both answers, each under a method string naming the same quantity.

The falsifier is a **partition identity**, not a reference value. Species partition the
catch and every species shares the same effort denominator, so `sum_s rate_s` must equal
the all-species rate exactly. Before the fix the species sum matched the *standard-path*
rate to the last digit on every combination, which is what identified the species path
rather than the all-species one as the wrong side:

```
design      quantity  all-species (HT)  species sum (standard)   gap
bus_route   CPUE      0.748339          0.937805               +25.32%
bus_route   RPUE      0.421378          0.494953               +17.46%
ice         HPUE      0.919685          0.862944                -6.17%
ice         RPUE      0.909720          0.964467                +6.02%
ice         CPUE      1.829405          1.827411                -0.11%
```

Ice CPUE's −0.11% is this fixture, not a milder defect: the same code path produced
+25.32% one design type over. A tolerance-based check would have passed it.

**Second defect, a regression this audit introduced.** The dispatch finding 14 widened
resolves `by` with `tidyselect::eval_select()` against `design$interviews`, where there is
no species column. `estimate_catch_rate()` was given a `resolve_species_by()` guard;
`estimate_harvest_rate()` and `estimate_release_rate()` were not. So `by = species`
**aborted** on ice designs where it had worked before commit `61b439a`, and on bus-route
designs where it had never worked. Verified against `origin/main`: ice HPUE by species
returned `ratio-of-means-hpue-species`, sum 0.862944; on the branch it raised
``Column `species` doesn't exist``. An estimator that aborts is the loudest failure mode in
this audit and it still shipped unnoticed, because no fixture in the suite combined a
species column with an HT design type.

**Decision: fix all three species rates, not only CPUE** (user's call, 2026-08-09). Fixing
CPUE alone would have left HPUE-species and RPUE-species on the standard path — the exact
drift that made finding 17 necessary after finding 14 fixed two of three siblings.

**LANDED.** One `estimate_rate_species_br()` in `R/creel-estimates-bus-route.R` loops
species, repoints `harvest_col` at that species' count column and delegates to
`estimate_harvest_br()` — the delegation `estimate_release_br()` and `estimate_catch_br()`
already use, so the species rates come off the same estimator body as the all-species ones
and cannot drift from them. The reported method is the delegate's with `-species` appended,
which reproduces the standard path's labels on both trip paths. All five combinations
above now reconcile to 0.00%, grouped (`by = c(day_type, species)`) reconciles within each
stratum, and both trip paths hold the identity.

`use_trips = "diagnostic"` is **refused** with species grouping: the pair returns two
estimates per species, which does not fit one row per species, and returning either half
under a single label is finding 5's failure mode.

**Coverage.** Widening the dispatch moved bus-route species CPUE by 25% and failed **0 of
3534** tests — the same signal findings 9, 15, 16 and 17 each produced. Mutants against
the new path, control 0: ignoring `.pi_i`/`.expansion` kills 4; hardcoding `metric` kills
2; dropping the `-species` suffix kills 2; dropping `by_vars` kills 1; removing the
diagnostic guard kills 1.

**Surfaced, not fixed:**

- `estimate_release_rate(by = species)` reports `ratio-of-means-rpue` with **no `-species`
  suffix** on the standard path — finding 10's shape, pre-existing, and now inconsistent
  with the HT path, which does append it.
- The `metric` argument on `estimate_harvest_br()`'s **diagnostic** branch is pinned by a
  single test: hardcoding it to `"hpue"` for the complete half kills only `bus-route RPUE
  supports use_trips = 'diagnostic' (GH #110)`.

### 19. Species totals abort on bus-route and ice designs

Added 2026-08-09, surfaced by finding 18 and opened as its own finding. All three totals
resolve `by` with `tidyselect::eval_select()` against `design$interviews`, which carry no
species column, so `by = species` **aborted** — six combinations (three quantities x two
design types), none of them reachable, on `origin/main` as well as on this branch:

```
estimate_total_catch(bus_route, by = species)     Error: Column `species` doesn't exist.
estimate_total_harvest(ice, by = species)         Error: Column `species` doesn't exist.
...
```

Same root cause as finding 18's regression, in the totals rather than the rates, but
pre-existing rather than introduced: the totals never had the guard, so this one predates
the audit.

**The fix is not "add the guard".** The species-level total estimators the guard would
reach — `estimate_total_catch_species()` and its siblings — are stratum product sums built
on the *standard* interview survey, and `estimate_total_catch_species()` calls
`estimate_cpue_species()`, which is precisely the estimator finding 18 had to repoint.
Routing `by = species` there would have made the call return a number and reintroduced
finding 18 one estimator over, in the totals: a species total contradicting the
all-species total on the same design object. Making an aborting call return a wrong number
is not a fix.

**LANDED.** One `estimate_total_species_br()` in `R/creel-estimates-bus-route.R` loops
species, repoints the numerator at that species' counts and delegates to the all-species HT
total estimator — the same delegation `estimate_rate_species_br()` uses. Release is
repointed by subsetting `design$catch` rather than the interviews, because
`estimate_total_release_br()` derives its own per-interview release counts from the catch
table; catch and harvest are repointed on the interviews.

Two identities, both exact:

```
partition        sum_s total_s == total_all        all 6 combinations, 0.0000%
cross-estimator  total_s / E_hat == rate_s         max gap 2.22e-16
```

The second is what ties findings 18 and 19 together: satisfying the partition sum alone
would still allow a totals path that weighted its interviews differently from the rate
path. Grouped (`by = c(day_type, species)`) reconciles within each stratum for all three
quantities. The reported method names both the estimator and the quantity
(`ht-total-release-species`); `use_trips = "all"` stays rejected, since the completed-trip
guard runs ahead of the species branch.

**Coverage.** Mutants against the new path, control 0: ignoring `.pi_i`/`.expansion` kills
4 (the four value-based tests; the label and finiteness tests correctly do not respond to a
weighting change), hardcoding the quantity in the method string kills 1, reading `"caught"`
where harvest wants `"harvested"` kills 1, dropping `by_vars` on the release branch kills 1
— that last one killed **0** until the grouped test was widened past catch, because release
reaches the estimator down a different branch.

**Instrument note.** The first `ignore_ht_weights` measurement reported 6 kills from a
mutant that was not computing at all: the `perl` replacement text left `$` unescaped, so
`design_sp$catch_col` interpolated an empty Perl variable and the mutant aborted with `$
operator is invalid for atomic vectors`. Erroring mutants read as kills. The corrected
mutant returns 144 against a true 1684.25 and kills 4. Same class of instrument failure as
the session-7 sweep: always confirm the mutant produces a *wrong number*, not an error.

**Surfaced, not fixed:** the standard path's species totals report `product-total-catch`
with **no `-species` suffix**, so the HT and standard paths now label species totals
differently. Same gap already recorded for `estimate_release_rate()` under finding 18.

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
with CRAN in view. Revisited after the first pass landed — see *Design note: why not
`units`* below, which confirms the rejection on a sharper reason and records the part
worth stealing.

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

**LANDED (first pass, 2026-08-10)**, with finding 13. Four departures from the plan
above, each forced by something the plan did not know.

*"Unknown" is a required third state, and it is not "angler-days".* The plan has
`estimate_effort()` propagate `unit_out = unit_in x days`, which implies labelling
an unexpanded instantaneous total "angler-days". That is unsafe:
`example_counts$effort_hours` **already holds angler-hours**, so a bare numeric
count column may be either a head count or pre-expanded effort and nothing can
tell them apart. Asserting a unit there would produce precisely the confident,
well-labelled, wrong number this section exists to prevent. The unit is asserted
only where the package did the arithmetic — T_d multiplication on the count side,
party-size multiplication on the interview side — and is `NA` otherwise. An absent
`Unit:` line is a claim of ignorance, which is a different statement from a
default.

*The abort could not take the seam it was written for.* The plan's example —
"aborts when the CPUE denominator unit != the effort unit" — describes the
party-hours case, which finding 7 had already shipped as a **warning** with a
better message at the same three call sites. Escalating it would break every
caller who omits `n_anglers`, which is what the bundled examples do. Decision:
the abort fires on known mismatches finding 7 does not cover, and the
party-hours seam keeps its warning.

*One defect, one diagnosis.* An unknown effort unit at the multiplication point
is the same fact the finding-13 warning reports. A second, differently-worded
warning there read as two problems. The totals now call
`warn_missing_period_length()` directly instead — needed anyway, since they reach
`estimate_effort_total()` without passing through `estimate_effort()`, so that
path had been silent.

*The preferred workflow had to be exempted.* `prep_counts_*()` resolves counts
into sampled-day effort before `add_counts()`, so the finding-13 warning fired on
the documented recommended pipeline. Marked with an attribute, which degrades to
"unknown" if dropped by intervening verbs — the safe direction.

Mutation testing, control 0: labelling the unknown unit "angler-days" 5 kills;
dropping the mismatch abort 1 kill; dropping the party-hours carve-out **0 kills
at first**, because every fixture in the file had an *unknown* effort unit, so the
check returned early and the carve-out was never reached. The case that exercises
it — T_d applied (effort known to be angler-hours) against interviews with no
`n_anglers` — needed its own fixture; with it the mutant kills 1. A carve-out
guarding a decision the user made explicitly was, until then, entirely unmeasured.

Still outstanding: rate estimators outside the standard CPUE spine (species,
bus-route, aerial, regression) return `NA` units rather than derived ones, and
`estimate_angler_trips()` / `estimate_effort_per_acre()` do not yet carry
`angler-trips` and `angler-hours/acre`. Those are what would make the abort
reachable from ordinary use rather than only from a hand-set unit.

### Design note: why not `units` (2026-08-10, revisit)

The `units` package (r-quantities/units, a udunits2 wrapper) is the obvious
off-the-shelf answer and was rejected above on invasiveness. That reason holds, but
it is not the strongest one, and the first pass surfaced a better one. Recording both
so this does not get re-proposed on the weaker argument.

**The numbers never touch plain arithmetic.** Every quantity that would carry a unit
is produced inside `survey::svytotal()`, `svyratio()`, Taylor linearization,
`lme4::glmer.nb()` or a bootstrap resample. None of those accept a units vector — they
do internal matrix algebra and will error or silently strip the class. Adopting
`units` therefore means `drop_units()` on entry and reattach on exit, which is the
label-passing spine that already exists, plus a udunits system dependency and a
label-to-udunits translation layer. Non-trivial install friction for the agency
Windows users this package targets, bought with no change in what the machinery can
express.

**"Unknown" has no representation, and it is the state that matters most.** This is
the decisive objection and it only became visible once the first pass established
unknown as a required third state. `units` has two states: carries units, or plain
numeric. Map unknown onto plain numeric and udunits treats it as **dimensionless**, so
`unknown + angler-hours` errors (correct) but `unknown x angler-hours` silently
succeeds (wrong — and that product is exactly the confident, well-labelled, wrong
number this whole section exists to prevent). The one distinction the landed design
depends on is the one udunits cannot hold.

**What is worth stealing anyway.** Two things udunits gets right that the current
string-label spine does not:

- *Derived units are computed, not looked up.* effort x rate -> catch falls out of the
  algebra; no rule table, and combinations nobody anticipated are still checked. The
  current spine only catches mismatches someone wrote a rule for.
- *Variance squares for free.* `Var(effort)` in angler-hours² rather than the
  hand-tracked `T_d^2` scaling in `add_counts()`.

Also worth noting as a modelling confirmation: udunits would represent angler-hours
and party-hours as distinct base dimensions with **no installed conversion**, because
a party holds an unknown number of anglers. Refusing to convert between them is the
correct behaviour, not a limitation — the same conclusion findings 2 and 7 reached
independently.

**Cheaper path to the same benefit, if it is ever needed.** Represent a unit as
numerator/denominator token vectors instead of a string:

```
angler-hours     -> list(num = c("angler", "hour"), den = character())
fish/angler-hour -> list(num = "fish", den = c("angler", "hour"))
```

Multiply = concatenate then cancel; square = duplicate the numerator; compare = sorted
token equality; `NULL` remains the unknown state with its own short-circuit. Roughly
50 lines, no dependency, character labels preserved at the API surface via a
formatter. Gets computed derived units and free variance-squaring; skips conversion
factors, which nothing in the package currently needs.

**Trigger condition — do not build this yet.** The package currently has **six**
distinct unit labels (`fish`, `angler-hours`, `party-hours`, `angler-trips`,
`angler-days`, `fish/angler-hour`) across six `unit =` assignment sites. String
equality over six labels is the right tool and the token form would be speculative
generality. Revisit only if extending propagation to the species, bus-route, aerial
and regression estimators plus `estimate_angler_trips()` /
`estimate_effort_per_acre()` (see "Still outstanding" above) pushes the label set past
roughly ten — that is the point at which hand-written pairwise rules start missing
legal combinations, which is the failure mode the token form removes. Sequence it
*after* that extension, never before: the extension is what reveals whether the
problem is real.

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
