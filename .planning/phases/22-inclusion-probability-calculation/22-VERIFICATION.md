---
phase: 22-inclusion-probability-calculation
verified: 2026-02-16T06:00:00Z
status: passed
score: 4/4 must-haves verified
re_verification: false
---

# Phase 22: Inclusion Probability Calculation Verification Report

**Phase Goal:** System correctly calculates inclusion probabilities (πᵢ) from sampling design, not site characteristics
**Verified:** 2026-02-16T06:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | πᵢ calculated as p_site × p_period from sampling design specification | VERIFIED | `R/creel-design.R` line 265: `br_df[[".pi_i"]] <- br_df[[p_site_col]] * br_df[[p_period_col]]`; golden tests confirm exact arithmetic to 1e-10 |
| 2 | πᵢ varies by sampling design, not by site wait times or interview timing | VERIFIED | Computation reads only `p_site_col` and `p_period_col` from the sampling frame; no wait_time or interview_time referenced in bus-route path |
| 3 | Two-stage sampling (site × period) produces correct probability products | VERIFIED | Golden test 3 (multi-circuit): expected c(0.12, 0.28, 0.30, 0.20) verified to 1e-10 tolerance; range invariant property tests confirm (0,1] constraint holds |
| 4 | Implementation matches primary source definition from Jones & Pollock (2012) | VERIFIED | `@references` citing Jones & Pollock (2012) present in both `creel_design()` roxygen (line 79) and `get_inclusion_probs()` roxygen (line 1164); `man/get_inclusion_probs.Rd` contains rendered reference with Eq. 19.4 and 19.5 |

**Score:** 4/4 truths verified

---

### Required Artifacts

#### Plan 01 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/creel-design.R` | p_period uniformity check + pi_i range check + get_inclusion_probs() + @references | VERIFIED | All four elements present at lines 431-458 (validation), 1192-1208 (accessor), 79-84 and 1163-1168 (@references) |
| `NAMESPACE` | export(get_inclusion_probs) | VERIFIED | Line 27: `export(get_inclusion_probs)` |
| `man/get_inclusion_probs.Rd` | Roxygen-generated help with @references | VERIFIED | File exists, 60 lines, contains proper \references block citing Jones & Pollock (2012) and eqn{pi_i} formula |

#### Plan 02 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `tests/testthat/test-creel-design.R` | "Inclusion probability calculation" section with 15 tests | VERIFIED | Section found at line 524; 15 test_that() blocks identified: golden tests 1-4 (lines 539-597), uniformity tests 5-8 (lines 598-674), get_inclusion_probs tests 9-13 (lines 676-742), property tests 14-15 (lines 744-800) |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `validate_creel_design()` | `bus_route$data p_period values per circuit` | split by circuit_col, compute max-min range, abort if > 1e-10 | WIRED | Lines 432-446: loops over circuits, computes `max(circ_p_period) - min(circ_p_period)`, aborts with "p_period must be constant within each circuit" when range > 1e-10 |
| `get_inclusion_probs()` | `design$bus_route$data` | extract site_col, circuit_col, pi_i_col columns | WIRED | Line 1208: `br$data[, c(br$site_col, br$circuit_col, br$pi_i_col)]` — reads directly from design$bus_route data slot |
| `tests` | `creel_design() constructor and validate_creel_design()` | direct creel_design() calls with known p_site/p_period values | WIRED | All 15 tests call `creel_design()` directly; golden tests use `expect_equal(..., tolerance = 1e-10)`; validation tests use `expect_error("constant within each circuit")` |
| `pi_i computation` | `p_site_col * p_period_col` | sampling frame columns only | WIRED | Line 265 reads from `p_site_col` and `p_period_col`; no site characteristics (wait times, interview timing) involved in the computation path |

---

### Requirements Coverage

| Requirement | Description | Status | Supporting Evidence |
|-------------|-------------|--------|---------------------|
| BUSRT-01 | System calculates πᵢ from sampling design (p_site × p_period), not site characteristics | SATISFIED | `R/creel-design.R` line 265 computes from sampling frame columns only; 15 tests verify the arithmetic |
| BUSRT-05 | Nonuniform probability sampling where different sites/periods have different sampling probabilities | SATISFIED | Multi-circuit golden test (test 3) verifies varying p_site and p_period across circuits; range invariant property tests (tests 14-15) confirm (0,1] bounds |
| VALID-03 | πᵢ calculation for two-stage sampling (site × period) produces correct values | SATISFIED | Golden tests 1-4 verify exact arithmetic to 1e-10; p_period uniformity validation tests 5-8 verify the circuit-level constraint fires correctly |

---

### Anti-Patterns Found

None. No TODOs, FIXMEs, placeholder comments, stub return values, or empty handlers found in the modified files.

---

### Commit Verification

| Commit | Description | Exists |
|--------|-------------|--------|
| `f66bd1e` | feat(22-01): add p_period uniformity validation and pi_i range check | YES |
| `c74aac4` | feat(22-01): add get_inclusion_probs() exported accessor function | YES |
| `16f691c` | test(22-02): add inclusion probability calculation test section | YES |

---

### Human Verification Required

None. All phase goals are verifiable programmatically through code inspection.

The following items are observable without running the app:
- pi_i arithmetic is exactly `p_site * p_period` (confirmed by reading line 265)
- All 15 tests have substantive hand-computed expected values (confirmed by reading test bodies)
- @references entries cite Jones & Pollock (2012) (confirmed in roxygen and .Rd files)

---

### Summary

Phase 22 goal is fully achieved. The inclusion probability implementation:

1. **Computes correctly:** `pi_i = p_site * p_period` at construction time, from sampling design specification columns, not site characteristics.

2. **Validates the two-stage requirement:** p_period uniformity check enforces that p_period is a circuit-level probability (not site-level). The defensive pi_i range check ensures results stay in (0, 1].

3. **Exposes a clean accessor:** `get_inclusion_probs()` is exported, returns a 3-column data frame (site, circuit, .pi_i), and errors informatively on non-bus-route designs.

4. **Documents the primary source:** Both `creel_design()` and `get_inclusion_probs()` roxygen contain `@references` entries citing Jones & Pollock (2012) Eq. 19.4/19.5 and the πᵢ = p_site × p_period definition.

5. **Proven by 15 tests:** Golden tests verify exact arithmetic to 1e-10 tolerance for single-circuit scalar p_period, column p_period, multi-circuit, and boundary cases. Validation tests confirm both error firing and correct passing behavior. Property tests confirm the range invariant.

No gaps. No blockers. Phase 22 is complete.

---

_Verified: 2026-02-16T06:00:00Z_
_Verifier: Claude (gsd-verifier)_
