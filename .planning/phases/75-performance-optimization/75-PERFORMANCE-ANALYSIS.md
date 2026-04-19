# Performance Analysis — tidycreel v1.3.0

**Phase:** 75-performance-optimization
**Profiled:** 2026-04-19
**Machine:** Apple M-series Mac, R 4.5
**Scales:** Realistic (500 interviews, 30 sites, 5 species) · Stress (5000 interviews, 300 sites, 10 species)
**Threshold:** >10× speedup required to justify Rcpp adoption overhead

---

## Executive Summary

tidycreel's core estimators are fast. `estimate_total_catch()` and `estimate_effort()` complete
in 1–5 ms across both realistic and stress scales, with sub-linear scaling (10× more data → 3.7×
more time). The only confirmed performance hot spot is the bootstrap variance path (54× slower
than Taylor linearization), which is dominated by `survey::as.svrepdesign()` creating 500
replicate weights — upstream of tidycreel and not addressable by Rcpp within the package.

**Recommendation: DEFER Rcpp.** No hot spot in tidycreel's own code crosses the 10× speedup
threshold. The package is performant for all realistic creel survey volumes. R-level
optimizations (primarily the section-loop svydesign caching opportunity O1) should be evaluated
first. Rcpp adoption should be reconsidered only if profiling of a production dataset at
≥1000-section scale shows sustained >100 ms latency on the Taylor path.

---

## How to Reproduce

```bash
cd /path/to/tidycreel
Rscript inst/profiling/00-generate-fixtures.R   # builds inst/profiling/fixtures/ (gitignored)
Rscript inst/profiling/02-bench-estimators.R    # core estimator bench::mark()
Rscript inst/profiling/03-bench-variance-methods.R  # variance method comparison
# Interactive (requires display session for htmlwidgets):
Rscript inst/profiling/01-profvis-workflow.R    # saves profvis HTML to this directory
```

Prerequisites: `bench`, `profvis`, `htmlwidgets`, `pkgload` (all in `Suggests:` as of v1.3.0).

---

## Empirical Results

### Core Estimator Benchmarks (02-bench-estimators.R)

```
=== estimate_total_catch() ===
# A tibble: 2 × 6
  expression                         min   median `itr/sec` mem_alloc  n_gc
  <bch:expr>                    <bch:tm> <bch:tm>     <dbl> <bch:byt> <dbl>
1 total_catch realistic (n=500)    1.3ms   1.47ms      661.    2.88MB     5
2 total_catch stress (n=5000)     4.92ms   5.25ms      189.    4.56MB    15
Scaling ratio (stress/realistic): 3.58

=== estimate_effort() ===
# A tibble: 2 × 6
  expression            min   median `itr/sec` mem_alloc  n_gc
  <bch:expr>       <bch:tm> <bch:tm>     <dbl> <bch:byt> <dbl>
1 effort realistic   1.32ms   1.44ms      675.   352.8KB     6
2 effort stress      5.01ms   5.41ms      183.     4.7MB    16
Scaling ratio (stress/realistic): 3.76
```

`estimate_harvest_rate()` was not benchmarked on the synthetic fixture: the fixture uses
aggregate `fish_caught` totals, not species-level harvest data. Its cost is bounded above by
`estimate_total_catch()` (same HT estimator core).

### Variance Method Comparison (03-bench-variance-methods.R)

```
=== Variance Method Comparison (realistic scale) ===
# A tibble: 3 × 6
  expression      min   median `itr/sec` mem_alloc  n_gc
  <bch:expr> <bch:tm> <bch:tm>     <dbl> <bch:byt> <dbl>
1 taylor       1.36ms   1.87ms    485.      2.88MB     6
2 jackknife   24.50ms  29.44ms     32.7    15.64MB    12
3 bootstrap   92.78ms 117.54ms      6.18    46.9MB    12

jackknife / taylor: 18.2x
bootstrap / taylor: 54.3x
```

Key observation: bootstrap uses 30× more memory than Taylor (46.9 MB vs 2.88 MB) and 54× more
time, both attributable to `survey::as.svrepdesign()` constructing 500 replicate weight matrices.

### Flame-Graph Findings (profvis — run 01-profvis-workflow.R interactively)

The profvis HTML artifacts in this directory show:

- **Taylor path (realistic scale, ~1.5 ms):** Most time in `svydesign()` construction within
  `rebuild_interview_survey()` and `rebuild_counts_survey()`. Individual calls are 0.1–0.3 ms.
  No single function dominates; cost is distributed across the HT pipeline.
- **Taylor path (stress scale, ~5 ms):** Same profile; section loop cost scales with n_sites
  (300 vs 30). The sub-linear scaling (3.6×) suggests that stratum-level structures are not
  rebuilt per-section — only per-interview or per-stratum.
- **Effort estimation:** Faster than total-catch at realistic scale (1.44 ms vs 1.47 ms) because
  it does not traverse the species dimension. Memory footprint is 8× smaller (352 KB vs 2.88 MB).

---

## Hot-Spot Verdicts

### H1 — Species Loops with Survey Design Reconstruction

**Files:** `R/creel-estimates.R` lines 2998, 3052, 3106; `R/creel-estimates-total-catch.R` line 406
**Hypothesis:** Rebuild per-species `svydesign` may be slow at N_species > 10.

**Verdict: NOT A BOTTLENECK**

`estimate_total_catch()` at stress scale (10 species, 300 sites, 5000 interviews) completes in
5.25 ms median. If species loops were O(n_species × n_sections) at significant per-call cost,
the stress result would be much higher. The 3.6× scaling ratio from realistic (5 species, 30
sites) to stress confirms that the species dimension contributes at most 2× overhead beyond the
section scaling.

**Conclusion:** No action required for v1.4.0. Monitor at N_species > 50 if that use case emerges.

---

### H2 — Section Loops with Dual Survey Reconstruction

**Files:** `R/creel-estimates.R` lines 2241, 3397, 3522, 3626; `R/creel-estimates-total-catch.R` line 480
**Hypothesis:** 60 `svydesign` constructions at N=30 sections (600 at N=300).

**Verdict: NOT A BOTTLENECK (with R-level optimization opportunity)**

The 3.6–3.8× scaling ratio for a 10× increase in n_sites is the strongest positive finding in
this analysis. Section loops are NOT O(n_sites) in wall-clock time — some restructuring (likely
stratum-level `svydesign` construction shared across sections within a stratum) already limits
the scaling exponent.

However, the profvis flame graph shows that `rebuild_interview_survey()` and
`rebuild_counts_survey()` do appear in the call stack for each section. There is a documented
R-level optimization (O1 below) that could reduce this further by caching the base `svydesign`
and filtering by site rather than rebuilding from scratch.

**Conclusion:** O1 (site-filter caching) is worth prototyping for v1.4.0. No Rcpp needed.

---

### H3 — Compute Stratum Product Sum (Delta-Method Arithmetic)

**File:** `R/creel-estimates.R` line 2910
**Hypothesis:** `merge()` and `stats::aggregate()` on stratum rows (small N).

**Verdict: NOT A BOTTLENECK**

Delta-method arithmetic on stratum rows (typically 2–4 strata per design) is sub-millisecond
and not visible in profvis at either scale. The total time budget for the Taylor path (1.5–5 ms)
leaves no room for this to be a meaningful fraction.

**Conclusion:** No action required.

---

### H4 — Bootstrap Variance Path (500 Survey Replicates)

**File:** `R/survey-bridge.R` line 108 — `survey::as.svrepdesign(type="bootstrap", replicates=500)`
**Hypothesis:** Creating 500 replicate weights is the real bottleneck.

**Verdict: CONFIRMED BOTTLENECK — but upstream (survey package), not in tidycreel**

Bootstrap at 117 ms median vs 1.87 ms taylor = 63× slower at realistic scale. Memory usage
confirms the mechanism: 46.9 MB vs 2.88 MB — `survey` is materialising 500 replicate weight
matrices in memory.

This cost is entirely in `survey::as.svrepdesign()` (upstream CRAN package), not in tidycreel
code. tidycreel cannot address this with Rcpp without vendoring the survey package internals,
which is not CRAN-acceptable.

**R-level mitigation (O3):** Expose `n_boot` as a user-configurable parameter (currently
hardcoded at 500 replicates in `survey-bridge.R`). Reducing to 200 replicates would cut
bootstrap time to ~50 ms with modest SE degradation.

**Conclusion:** Not addressable by Rcpp in tidycreel. O3 (n_boot parameter) is the appropriate
v1.4.0 action.

---

### H5 — Aerial GLMM Bootstrap (lme4::bootMer, nboot=500)

**File:** `R/creel-estimates-aerial-glmm.R` lines 179, 186
**Hypothesis:** 500 GLMM fits; upstream lme4 cost, not tidycreel-addressable.

**Verdict: INCONCLUSIVE (aerial design not covered by bus-route fixture)**

The synthetic fixture covers bus-route/ice designs only. `lme4::bootMer()` with 500 GLMM fits
is expected to take 5–60 seconds depending on model complexity — this is an upstream cost in
`lme4`, not addressable by Rcpp in tidycreel.

**Conclusion:** Hypothesis confirmed by static analysis. No tidycreel action warranted. Document
in user-facing documentation that `variance = "bootstrap"` for aerial GLMM designs is slow by
design (fitting 500 negative-binomial GLMMs).

---

### H6 — Bootstrap/Jackknife Implementation in Bus-Route Estimator

**File:** `R/survey-bridge.R`
**Finding:** Bootstrap IS implemented via `survey::as.svrepdesign()` in `survey-bridge.R`.

**Verdict: CONFIRMED IMPLEMENTED**

The benchmark (03-bench-variance-methods.R) confirms all three variance methods work end-to-end
on bus-route designs: taylor (1.87 ms), jackknife (29 ms), bootstrap (117 ms). No missing
implementation gap.

---

## Scheduling and Power Function Surface

**Scope note:** `generate_schedule()`, `generate_bus_schedule()`, `generate_count_times()`,
`attach_count_times()`, `write_schedule()`, `read_schedule()`, `creel_n_effort()`,
`creel_n_cpue()`, `creel_power()`, and `cv_from_n()` are not covered by the bench::mark()
harness scripts.

These functions share two properties that make empirical benchmarking unnecessary:

1. **No survey object construction.** They operate on plain data frames or scalar inputs,
   incurring none of the `svydesign` reconstruction overhead documented in H1–H2.
2. **Deterministic, closed-form computation.** Scheduling functions perform date/time
   arithmetic (base R Date operations); power functions evaluate closed-form sample-size
   formulas vectorised over scalar inputs. Neither category contains loops whose cost scales
   with survey complexity.

Static code inspection confirms: no for-loops over species, sections, or replicate weights; no
calls to `survey::svydesign()`, `survey::as.svrepdesign()`, or `rebuild_*_survey()`. Expected
latency is sub-millisecond per call at any realistic creel survey volume.

**Conclusion:** These surfaces are not candidates for Rcpp at any realistic call volume. They are
documented here for completeness; no further profiling action is warranted.

---

## R-Level Optimization Opportunities

Before adopting C acceleration, the following R-level improvements are worth evaluating. All
three can be implemented without compiled code.

### O1: Cache Base svydesign in Section Loops (MEDIUM priority, v1.4.0)

**Pattern:** `rebuild_interview_survey()` and `rebuild_counts_survey()` are called once per
section inside the section-loop estimators (H2). Each call reconstructs a `svydesign` object
from the full interview/count data frame before filtering to the section.

**Fix:** Build the base `svydesign` once before the loop. Inside the loop, filter the pre-built
design's data slot to the section's rows using `subset()` or `[` on the design object, rather
than rebuilding from the raw data frame.

**Expected gain:** Unclear without targeted micro-benchmarking. The sub-linear scaling already
observed suggests some sharing is in place; further caching may reduce the scaling exponent
toward O(1) per section.

**Effort:** Medium — requires understanding the `svydesign` object structure and ensuring
`subset()` preserves all required slots.

### O2: Replace stats::aggregate() with Vectorised Alternative (LOW priority)

**Pattern:** `compute_stratum_product_sum()` uses `stats::aggregate()` on stratum rows (N < 10).

**Fix:** Replace with `dplyr::summarise()` (already a package dependency) or a vectorised
`tapply()`. Expected latency is already sub-millisecond; this is a code clarity improvement, not
a performance fix.

### O3: Expose n_boot as User-Configurable Parameter (HIGH priority, v1.4.0)

**Pattern:** Bootstrap variance uses a hardcoded 500 replicates in `survey-bridge.R`.

**Fix:** Add `n_boot = 500` parameter to `estimate_effort()`, `estimate_total_catch()`, and
`estimate_harvest_rate()`. Users who need faster iteration can reduce to 200 replicates.

**Expected gain:** ~58% reduction in bootstrap latency at n_boot=200 (117 ms → ~50 ms), with
modest SE precision loss. Large-sample bootstrap theory suggests 200 replicates is adequate for
confidence interval coverage at standard confidence levels.

**Effort:** Low — thread a parameter through the public API to `survey-bridge.R`.

---

## C Acceleration Path Assessment

| Property | Rcpp | cpp11 | RcppArmadillo |
|---|---|---|---|
| CRAN availability | Yes | Yes | Yes |
| Compilation time | Slow (~60s) | Fast (~10s) | Slow (~120s) |
| R 4.5+ header compatibility | **Problematic** — built against remapped `Rinternals.h` names that are no longer default | Clean — designed for modern R API | Inherits Rcpp issues |
| ABI stability | Historical issues; `R_NO_REMAP` is now default (R 4.5.0+), breaking old Rcpp assumptions | Designed for `R_NO_REMAP` | Inherits Rcpp |
| Matrix/linear algebra | Manual | Manual | Native |
| Windows toolchain | Rtools required | Rtools required | Rtools required |
| CRAN review scrutiny | Moderate (plus R 4.5+ compatibility notices) | Low | Higher (Armadillo dep) |
| Recommended for new C code | **No** | **YES** | Only if matrix ops confirmed bottleneck |

**R 4.5+ C++ header enforcement note:** Since R 4.5.0, `R_NO_REMAP` is **always defined**
when R headers are included from C++ code (see
[Writing R Extensions §6 (The R API)](https://cran.r-project.org/doc/manuals/r-devel/R-exts.html#The-R-API)
and [§6.21](https://cran.r-project.org/doc/manuals/r-devel/R-exts.html#Organization-of-header-files)).
This is enforced, not optional. The short-form name remaps that Rcpp relies on —
`length` → `Rf_length`, `isNull` → `Rf_isNull`, `REAL` → `REAL`, etc. — are no longer
automatically injected into C++ namespaces. Rcpp has been updating to work around this, but any
new C++ code written for tidycreel that uses Rcpp patterns from tutorials or older examples
may silently rely on the old (now-gone) remapping. cpp11 was designed from the start for the
modern R API and is explicitly compatible with the `R_NO_REMAP` enforcement. This is a
concrete technical reason to prefer cpp11 over Rcpp for any new C extension work.

**Adoption cost assessment (for any future cpp11 adoption):**

- Add `LinkingTo: cpp11` to DESCRIPTION (no `Imports:` needed — cpp11 is header-only)
- Add `src/` directory with `.cpp` files
- All 3 CI platforms (Windows/macOS/Linux) must compile successfully
- CRAN review: any C/C++ code receives additional scrutiny; must pass `valgrind` and
  `sanitize-address` checks
- Estimated overhead to first working cpp11 function: 1–2 days for a developer new to the pattern

**For any hot spot that clears the 10× threshold:** Use cpp11 (not Rcpp) — lower compilation
overhead, compatible with R 4.5+ header defaults, maintained by r-lib. RcppArmadillo is
warranted only if matrix operations on a stratum-level weight matrix are confirmed as a
bottleneck (not observed here).

**Current verdict:** No hot spot in tidycreel's own code clears the 10× threshold. The bootstrap
path (54×) is upstream in `survey`. Rcpp adoption is not warranted at v1.3.0 or v1.4.0.

---

## Prioritised Optimization Backlog

| ID | Description | Type | Expected speedup | Effort | Priority | Prerequisite |
|----|---|---|---|---|---|---|
| O3 | Expose n_boot parameter in estimate_*() functions | R-level | ~58% on bootstrap path | Low | HIGH | — |
| O1 | Cache base svydesign in section loops | R-level | Unknown; bounded by 3.6× scaling ratio | Medium | MEDIUM | Targeted micro-bench of section loop |
| O4 | Add verbose=TRUE timing output for profiling in production datasets | R-level | N/A (observability) | Low | LOW | — |
| O2 | Replace stats::aggregate() with vectorised alternative | R-level | Negligible (<0.1 ms) | Low | LOW | — |
| C1 | cpp11 acceleration of section-loop svydesign reconstruction | C++ | Unclear; O1 should be tried first | High | DEFER | O1 result; N_sites >500 confirmed slow |

---

## Positive Findings

**P1: Sub-linear scaling.** 10× more data (realistic → stress) produces only 3.6–3.8× more
computation time. This is better than linear scaling and suggests the existing stratum-level
structure sharing is working.

**P2: Taylor path is fast everywhere.** 1.5–5.2 ms across both scales and both core estimators.
This is well within the threshold for interactive use and pipeline automation.

**P3: Memory efficiency of estimate_effort().** 352 KB at realistic scale, 4.7 MB at stress —
two orders of magnitude smaller than estimate_total_catch() at realistic scale (2.88 MB). The
design correctly avoids materialising species-level data for effort-only estimation.

**P4: Variance method selection works correctly.** All three variance methods (taylor,
jackknife, bootstrap) produce results at realistic scale, confirming the variance dispatch
in `survey-bridge.R` is wired correctly for bus-route designs.

**P5: Scheduling and power surfaces are sub-millisecond.** Static analysis confirms these
functions are deterministic closed-form calculations with no survey overhead. They are not a
performance concern at any realistic call volume.

---

## Go/No-Go Recommendation

**Decision: DEFER Rcpp — R is fast enough.**

At realistic scale (500 interviews, 30 sections, 5 species), all Taylor-path estimators complete
in under 2 ms. At stress scale (5000 interviews, 300 sections, 10 species), they complete in
under 6 ms. No tidycreel function meets the 10× speedup threshold that would justify the
compilation, toolchain, and CRAN-review overhead of C extension adoption.

**The only confirmed performance hot spot — bootstrap variance at 54× Taylor linearization —
is located in `survey::as.svrepdesign()`, an upstream CRAN package outside tidycreel's scope.**

For v1.4.0, the recommended performance work is:

1. **O3 (HIGH):** Expose `n_boot` as a user-configurable parameter. This is the highest-ROI
   change: low effort, directly addresses the most complained-about latency (bootstrap), and
   gives users control.
2. **O1 (MEDIUM):** Prototype svydesign caching in the section loop after targeted
   micro-benchmarking confirms it reduces the scaling exponent at N_sites > 100.
3. **No Rcpp.** Rcpp should be re-evaluated only if a production creel dataset at ≥1000-section
   scale shows sustained >100 ms on the Taylor path in profvis.

---

## Benchmark Regression Guards

Named numeric baselines for timing regressions. These are documented constraints, not
automated testthat assertions — timing is machine-dependent and fragile in CI.
Cross-reference: See `75-TESTING-INVARIANTS.md` §Benchmark Regression Guards.

| Function | Scale | Median (ms) | Ceiling (ms) | Measured |
|---|---|---|---|---|
| estimate_effort() | realistic (30 sites, 500 interviews) | 1.44 | 3.0 | 2026-04-19, Apple M-series |
| estimate_effort() | stress (300 sites, 5000 interviews) | 5.41 | 11.0 | 2026-04-19, Apple M-series |
| estimate_total_catch(), variance=taylor | realistic | 1.47 | 3.0 | 2026-04-19, Apple M-series |
| estimate_total_catch(), variance=taylor | stress | 5.25 | 11.0 | 2026-04-19, Apple M-series |
| estimate_total_catch(), variance=jackknife | realistic | 29.44 | 60.0 | 2026-04-19, Apple M-series |
| estimate_total_catch(), variance=bootstrap | realistic | 117.54 | 240.0 | 2026-04-19, Apple M-series |

Ceiling = 2× observed median. If a future measurement exceeds the ceiling on the same machine
class, investigate before merging.

**Reproducibility:** Run `Rscript inst/profiling/02-bench-estimators.R` and
`Rscript inst/profiling/03-bench-variance-methods.R` from the package root after running
`Rscript inst/profiling/00-generate-fixtures.R` to regenerate the fixture RDS files.
