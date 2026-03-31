---
phase: 47-aerial-survey-support
verified: 2026-03-22T20:15:00Z
status: gaps_found
score: 8/10 must-haves verified
re_verification: false
gaps:
  - truth: "AIR-04: Aerial estimator is verified against Malvestuto (1996) worked example before shipping"
    status: failed
    reason: "REQUIREMENTS.md still marks AIR-04 as [ ] (incomplete). The Malvestuto (1996) Box 20.6 has no aerial worked example. The team substituted a constructed numeric validation (svytotal x h_open = 111 x 14 = 1554 angler-hours) and the test passes — but REQUIREMENTS.md was never updated to reflect the alternate validation strategy. The requirement checkbox remains unchecked."
    artifacts:
      - path: ".planning/REQUIREMENTS.md"
        issue: "AIR-04 marked [ ] (incomplete); checkbox should be updated to [x] and wording adjusted to reflect the alternate constructed-numeric validation strategy that was actually used"
      - path: "tests/testthat/test-primary-source-validation.R"
        issue: "Test exists and passes (make_aerial_box20_6() fixture, E_hat = 1554, tolerance = 1e-4) — test is correct, only the requirements tracking is outdated"
    missing:
      - "Update REQUIREMENTS.md AIR-04 checkbox from [ ] to [x] and revise wording to reflect that the Malvestuto (1996) Box 20.6 has no aerial example and the alternate constructed numeric validation (Pollock et al. 1994 formula) was used instead"

  - truth: "REQUIREMENTS.md AIR-01 and AIR-02 formula descriptions match the implemented estimator"
    status: partial
    reason: "REQUIREMENTS.md AIR-01 states the formula as 'N_counted × H_open × mean_trip_duration' — but the implemented formula (per Pollock et al. 1994 §15.6.1 and the aerial correction memo) is 'svytotal(counts) × (h_open / v)' with no mean_trip_duration. REQUIREMENTS.md AIR-02 says 'delta method variance...propagating count and mean trip duration uncertainty' — but the implementation uses linear scaling (SE = SE(svytotal) × h_over_v), no delta method, no mean_trip_duration variance. The implementation is correct; the requirement text is the outdated pre-correction wording."
    artifacts:
      - path: ".planning/REQUIREMENTS.md"
        issue: "AIR-01 description says 'N_counted × H_open × mean_trip_duration' — should say 'N_counted × (h_open / v)' (no mean_trip_duration; L_bar not in effort formula). AIR-02 description says 'delta method variance...mean trip duration uncertainty' — should say 'linear scaling SE = SE(svytotal) × (h_open/v); no delta method needed'"
    missing:
      - "Update AIR-01 formula in REQUIREMENTS.md from 'N_counted × H_open × mean_trip_duration' to 'N_counted × (h_open / v)'"
      - "Update AIR-02 description from 'delta method variance...mean trip duration' to 'linear scaling variance: SE = SE(svytotal) × (h_open/v); no delta method required because h_open and v are fixed calibration constants'"
human_verification: []
---

# Phase 47: Aerial Survey Support Verification Report

**Phase Goal:** Complete aerial survey support for tidycreel — creel_design() aerial constructor, estimate_effort_aerial() using svytotal x (h_open/v), interview-based catch estimation, example datasets, and vignette.
**Verified:** 2026-03-22T20:15:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | creel_design(survey_type='aerial', h_open=14) constructs; design$aerial$h_open == 14 | VERIFIED | L1260-1268, test-creel-design.R; 7 constructor tests pass |
| 2 | creel_design without h_open aborts with cli_abort() naming h_open as required | VERIFIED | L1271-1279, test-creel-design.R; validates against is.null(h_open) |
| 3 | visibility_correction = 0.85 constructs; 1.5 aborts | VERIFIED | L1292-1323, test-creel-design.R; vc_bad validation in creel-design.R L569-579 |
| 4 | estimate_effort_aerial() uses svytotal x (h_open/v); no L_bar in effort formula | VERIFIED | R/creel-estimates-aerial.R L26-53; 6 effort tests pass; test-estimate-effort.R L1613-1679 |
| 5 | SE equals SE(svytotal) x (h_open/v) — linear scaling, no delta method | VERIFIED | R/creel-estimates-aerial.R L53; numeric SE test at L1645-1655, test-estimate-effort.R |
| 6 | add_interviews() / estimate_catch_rate() / estimate_total_catch() work on aerial designs | VERIFIED | 7 AIR-05 tests across 3 files; 1696 tests passing total |
| 7 | example_aerial_counts loads; 16 rows; all n_anglers > 0; variability (SD > 0) | VERIFIED | data-raw script uses set.seed(47); nrow=16 confirmed via Rscript |
| 8 | example_aerial_interviews loads; 48 rows; hours_fished, walleye_catch, walleye_kept; walleye_kept <= walleye_catch | VERIFIED | data-raw script uses set.seed(147); nrow=48 confirmed via Rscript |
| 9 | aerial-surveys vignette renders; demonstrates uncorrected/corrected effort and catch estimation | VERIFIED | vignettes/aerial-surveys.Rmd exists; 4 mentions of visibility_correction; 4 mentions of estimate_catch_rate/estimate_total_catch |
| 10 | AIR-04: requirement status and formula descriptions in REQUIREMENTS.md are accurate | FAILED | REQUIREMENTS.md marks AIR-04 as [ ] (incomplete); AIR-01/AIR-02 still carry pre-correction formula text (mean_trip_duration, delta method) |

**Score:** 8/10 truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/creel-estimates-aerial.R` | estimate_effort_aerial() using svytotal x h_over_v | VERIFIED | 89 lines; full implementation with within-day Rasmussen component; committed 995c0da |
| `R/creel-design.R` | h_open/visibility_correction params; aerial slot construction; aerial print section | VERIFIED | L258-259 (params), L555-586 (validation+slot), L2132-2135 (print) |
| `R/creel-estimates.R` | 'aerial' in NULL-survey guard exclusion; aerial dispatch block after bus_route/ice | VERIFIED | L333 exclusion list; L389-398 dispatch block |
| `tests/testthat/test-creel-design.R` | AIR-01/02/03 constructor tests appended | VERIFIED | L1246-1332; 7 tests in "Phase 47: Aerial constructor" describe block |
| `tests/testthat/test-estimate-effort.R` | AIR-01/02/03 effort tests appended | VERIFIED | L1581-1679; 6 tests in "Phase 47: Aerial effort" describe block |
| `tests/testthat/test-primary-source-validation.R` | AIR-04 make_aerial_box20_6() fixture; test passes | VERIFIED | L480-557; constructed numeric test passes (E_hat=1554, tolerance=1e-4); no skip |
| `tests/testthat/test-add-interviews.R` | AIR-05 add_interviews() tests appended | VERIFIED | L1674-1740; 2 tests; committed 589a178 |
| `tests/testthat/test-estimate-catch-rate.R` | AIR-05 estimate_catch_rate() tests appended | VERIFIED | L2438-2496; 2 tests |
| `tests/testthat/test-estimate-total-catch.R` | AIR-05 estimate_total_catch() tests appended | VERIFIED | L928-996; 3 tests |
| `data-raw/create_example_aerial_counts.R` | Reproducible script; set.seed(47); 16 rows | VERIFIED | 59 lines; stopifnot assertions present |
| `data-raw/create_example_aerial_interviews.R` | Reproducible script; set.seed(147); 48 rows | VERIFIED | 74 lines; stopifnot assertions present |
| `data/example_aerial_counts.rda` | Compiled dataset | VERIFIED | File exists; loads via Rscript |
| `data/example_aerial_interviews.rda` | Compiled dataset | VERIFIED | File exists; loads via Rscript |
| `R/data.R` | Roxygen entries for both datasets | VERIFIED | L568-645; both datasets documented with @format, @source |
| `man/example_aerial_counts.Rd` | Generated man page | VERIFIED | File exists |
| `man/example_aerial_interviews.Rd` | Generated man page | VERIFIED | File exists |
| `man/creel_design.Rd` | Regenerated with @param h_open and @param visibility_correction | VERIFIED | Committed 76b94e5 (deviation auto-fixed in Plan 03) |
| `vignettes/aerial-surveys.Rmd` | 6-section vignette; visibility correction demonstrated | VERIFIED | 199 lines; 4 uses of visibility_correction; estimate_catch_rate/estimate_total_catch present |
| `.planning/REQUIREMENTS.md` | AIR-04 [x]; AIR-01/AIR-02 formula text matches implementation | FAILED | AIR-04 is [ ]; AIR-01 cites mean_trip_duration; AIR-02 cites delta method |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| creel_design() aerial branch | design$aerial$h_open and design$aerial$visibility_correction | is.null(h_open) check + vc_bad variable | WIRED | R/creel-design.R L556-586 |
| R/creel-estimates.R L333 guard | aerial dispatch block | 'aerial' in c('bus_route','ice','aerial') exclusion | WIRED | L333: `!design$design_type %in% c("bus_route", "ice", "aerial")` |
| estimate_effort_aerial() | design$counts via svytotal | count var auto-detection + survey::svytotal() x h_over_v | WIRED | R/creel-estimates-aerial.R L26-53 |
| SE linear scaling | se in estimates tibble | SE(svytotal) x h_over_v; sqrt(se_between^2 + var_within) | WIRED | R/creel-estimates-aerial.R L53-60 |
| example_aerial_counts | vignette effort estimation | add_counts(design, example_aerial_counts) auto-detects n_anglers | WIRED | vignettes/aerial-surveys.Rmd L95 |
| example_aerial_interviews | vignette catch estimation | add_interviews() → estimate_catch_rate() → estimate_total_catch() | WIRED | vignettes/aerial-surveys.Rmd L103-179 |
| visibility_correction = 0.85 | corrected effort output | creel_design(..., visibility_correction = 0.85) → estimate_effort() | WIRED | vignettes/aerial-surveys.Rmd L131-150 |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| AIR-01 | 47-01-PLAN | Effort from aerial counts using expansion formula | SATISFIED (implementation) / STALE (requirement text) | estimate_effort_aerial() in R/creel-estimates-aerial.R; formula text in REQUIREMENTS.md still says N_counted x H_open x mean_trip_duration |
| AIR-02 | 47-01-PLAN | Variance on aerial effort estimate | SATISFIED (implementation) / STALE (requirement text) | SE = SE(svytotal) x h_over_v implemented; REQUIREMENTS.md still says "delta method...mean trip duration uncertainty" |
| AIR-03 | 47-01-PLAN | Visibility correction factor | SATISFIED | visibility_correction in (0,1] validated; test-creel-design.R L1292-1323 |
| AIR-04 | 47-01-PLAN | Verified against Malvestuto (1996) worked example | BLOCKED — REQUIREMENTS.md unchecked | Test exists and passes (constructed numeric, E_hat=1554); Malvestuto has no aerial example; REQUIREMENTS.md never updated |
| AIR-05 | 47-02-PLAN | Interview-based catch estimation on aerial designs | SATISFIED | 7 tests across add-interviews, estimate-catch-rate, estimate-total-catch; 1696 tests passing |
| AIR-06 | 47-03-PLAN | Example dataset and vignette | SATISFIED | example_aerial_counts (16 rows), example_aerial_interviews (48 rows), vignettes/aerial-surveys.Rmd |

---

## Anti-Patterns Found

No stub, placeholder, or TODO anti-patterns found in any production source files modified in Phase 47. The AIR-04 test contains no skip() call — the constructed numeric test runs and passes.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `.planning/REQUIREMENTS.md` | 33-34 | Stale formula descriptions for AIR-01/AIR-02 | Warning | Does not affect functionality; misleads future readers about the aerial effort formula |
| `.planning/REQUIREMENTS.md` | 36 | `[ ]` AIR-04 unchecked | Warning | Signals the requirement was not completed; creates incorrect v0.8.0 release gate status |

---

## Human Verification Required

None — all verification could be performed programmatically. The vignette builds cleanly (confirmed by 03-SUMMARY.md: R CMD check 0 errors, 0 warnings; devtools::build_vignettes() succeeds).

---

## Gaps Summary

Phase 47 fully achieves its functional goal. All production code is implemented and wired:

- The aerial constructor validates h_open (required) and visibility_correction (optional, (0,1])
- estimate_effort_aerial() correctly uses svytotal x (h_open/v) with no delta method
- The aerial dispatch block is in place in estimate_effort()
- The interview pipeline (add_interviews, estimate_catch_rate, estimate_total_catch) works on aerial designs without production code changes
- Both example datasets are present, validated, and documented
- The vignette demonstrates uncorrected effort, corrected effort (visibility_correction = 0.85), and interview-based catch estimation
- 1696 tests pass

The two gaps are **requirements tracking artifacts only** — they do not affect package behavior:

**Gap 1 (AIR-04):** REQUIREMENTS.md still has `[ ]` for AIR-04. The Malvestuto (1996) Box 20.6 was confirmed to contain no aerial worked example. The team substituted a hand-verifiable constructed numeric validation (E_hat = 111 x 14 = 1554 angler-hours from Pollock et al. 1994 §15.6.1). The test exists, runs, and passes. REQUIREMENTS.md was not updated to reflect this alternate strategy or to check the box.

**Gap 2 (AIR-01/AIR-02 formula text):** The aerial correction memo (`project_phase47_aerial_correction.md`) changed the effort formula from `N_counted × H_open × mean_trip_duration` (with delta method) to `svytotal(counts) × (h_open/v)` (linear scaling, no delta method). This correction was applied correctly to the implementation and plan documents, but the corresponding AIR-01 and AIR-02 requirement description text in REQUIREMENTS.md still carries the outdated pre-correction wording.

Both gaps can be resolved by updating `.planning/REQUIREMENTS.md` — no code changes required.

---

_Verified: 2026-03-22T20:15:00Z_
_Verifier: Claude (gsd-verifier)_
