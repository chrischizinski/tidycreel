# Milestones

## v1.6.0 — Analytical Extensions II (Shipped: 2026-05-06)

**Phases:** 83–87 | **Plans:** 9 | **Timeline:** 2026-04-28 → 2026-05-06 (8 days)
**Files changed:** 152 (+10,081 / −190 lines) | **Tests:** 2556 → 2667 (+111)

**Key accomplishments:**
1. Implemented `creel_n_camera()` — Cochran (1977) stratified sample-size with Feltz-Middaugh (2025) minimum-day warnings; output shape matches `creel_n_effort()` (Phase 83)
2. Implemented `impute_camera_counts()` — Poisson GLM default (Hartill 2016) + NB GLMM opt-in (Afrifa-Yamoah 2020) for camera outage fill-in; schema-compatible with `add_counts()`; `.imputed` flag; CAMP-01..05 satisfied (Phase 84)
3. Implemented `estimate_angler_n()` — Chapman (default), Petersen (m ≥ 7), and Schnabel closed-population estimators with input guards, Poisson/normal CI branches, and `creel_estimates` S3 output (Phase 85)
4. Implemented `estimate_mr_harvest()` — delta-method harvest propagation from N_hat uncertainty; H = N_hat × rate; SE = rate × se_N (Phase 85)
5. Implemented `audit_strata()`, `simulate_strata_collapse()`, `reallocate_strata()` — effort-precision stratification audit, before/after merge simulation, and Neyman-optimal reallocation of fixed sampling budget (Phase 86)
6. Closed all 6 v1.6.0 advisory items — corrected NB GLMM docs, fixed Petersen variance_method label, guarded Schnabel ci_hi, added harvest_rate > 1 test, fixed .imputed false-positive logic, generated Phase 86 VERIFICATION.md (Phase 87)

---

## M024 / v1.5.0 — Analytical Extensions (Shipped: 2026-04-28)

**Phases:** 80–82 | **Plans:** 8 | **Timeline:** 2026-04-26 → 2026-04-28 (3 days)
**Files changed:** 32 (+2,479 / -173 lines) | **R source LOC:** 22,442

**Key accomplishments:**
1. Fixed `estimate_total_catch()` stratified-sum inconsistency (INV-06) — aggregate now equals sum of per-species estimates across multi-strata designs; 24/24 quickcheck invariants pass
2. Implemented `estimate_exploitation_rate()` — Pollock et al. moment estimator with delta-method SE, [0,1]-clamped CI, and stratified path with T-weighted aggregate `.overall` row
3. Wired `estimate_exploitation_rate` into pkgdown Estimation section with four quickcheck property invariants
4. Resolved `lifecycle` rcmdcheck NOTE via `@importFrom lifecycle badge` in `R/tidycreel-package.R`
5. Replaced all 14 `sapply()` calls with type-safe `vapply()` across 8 R source files
6. Created `vignettes/tidycreel-connect.Rmd` stub article under new Ecosystem pkgdown nav section
7. rhub v2 GitHub Actions workflow committed; ubuntu-release and macos-release confirmed green
8. Full test suite: 2537+ tests passing, 0 failures; rcmdcheck 0 errors 0 warnings

**Known Gaps:**
- QUAL-05: rOpenSci software review submission deferred to undetermined future date

---

## M023 / v1.4.0 — Quality, Polish, and rOpenSci Readiness (Local closeout: 2026-04-23)

**Phases:** 76–79 | **Plans:** 15 | **Timeline:** 2026-04-19 → 2026-04-23 (5 days)
**Release surface:** local planning closeout only; package version remains `1.3.0` and no `v1.4` git tag was created

**Key accomplishments:**
1. Closed the priority rOpenSci blocker set — named condition classes, lifecycle badges, `inst/CITATION`, and `scales` removal
2. Demoted `lubridate`, threaded `caller_env()` through bus-route estimator internals, and relocated `get_site_contributions()` into the estimation layer
3. Added `@family` tags across the exported surface and snapshot regression coverage for the three priority text-output print methods
4. Added property-based tests for the highest-value implemented invariants with reusable design generators
5. Established a CI-backed coverage gate with a documented `86.27%` local baseline and an `85%` Codecov project target
6. Closed the milestone with a passing full test suite and `rcmdcheck` (`0 errors`, `0 warnings`)

**Known Gaps (tech debt, not blockers):**
- Nyquist validation artifacts remain incomplete across Phases 76–79
- Pre-existing `rcmdcheck` notes remain for unused `lifecycle` import and local/top-level hidden files
- Release-surface work remains before a true `v1.4.0` release: version bump, release commit, and tag

---

## M022 — Comprehensive Project Evaluation and Future Planning (Shipped: 2026-04-19)

**Phases:** 70–75 | **Plans:** 11 | **Timeline:** 2026-04-14 → 2026-04-19 (5 days)
**Commits:** 37 | **Files changed:** 54 (+7,886 / -19 lines)

**Key accomplishments:**
1. Complete bus-route/ice HT estimators — `estimate_total_harvest_br()` and `estimate_total_release_br()` with ice dispatch as degenerate bus-route; 22 new tests
2. Profiling harness built — 4 scripts in `inst/profiling/`; empirical: Taylor ~1.5 ms, jackknife ~28 ms (18×), bootstrap ~83 ms (54×); Rcpp DEFER grounded in data
3. Architectural review complete — 4 findings (A1–A4), 6 positive patterns (P1–P6), full dependency drop/demote analysis for all 11 Imports
4. Error handling strategy codified — `cli::cli_abort` named-vector convention canonical across 368 call-sites; 4 intentional deviations documented
5. Quality audit at 87% coverage — 28 tidyverse/rOpenSci verdicts; 8 named condition sites; R1–R8 v1.4.0 roadmap
6. Property-based testing invariants specified — 6 domain invariants (INV-01–06), quickcheck adoption plan, benchmark regression guards

**Known Gaps (tech debt, not blockers):**
- ROADMAP tracking gaps: 74-01 and 75-02 checkboxes were `[ ]` despite plans delivered (fixed in archive)
- Nyquist VALIDATION.md: all 6 phases in DRAFT state (Nyquist not adopted for M022)
- Phase 72 architectural findings (drop `scales`, demote `ggplot2`) not tracked into v1.4.0 backlog
- Phase 70 human verification deferred: vignette build + test suite green confirmation outstanding
- `rlang::caller_env()` missing from new bus-route estimators (medium priority for v1.4.0)

---
