# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

---

## Milestone: v0.4.0 — Bus-Route Survey Support

**Shipped:** 2026-02-28
**Phases:** 7 (21-27) | **Plans:** 14 | **Commits:** ~54 | **Timeline:** 12 days

### What Was Built

- `creel_design(survey_type = "bus_route")` — bus-route design constructor with sampling frame, nonuniform probabilities (πᵢ = p_site × p_period), and Tier 1 validation
- `add_interviews()` extension — enumeration counts (n_counted/n_interviewed), πᵢ join, .expansion factor, Tier 3 bus-route validation
- Effort estimator implementing Jones & Pollock (2012) Eq. 19.4: sum(e_i / πᵢ) with survey package variance (svydesign + svytotal)
- Harvest/catch estimators implementing Jones & Pollock (2012) Eq. 19.5 with incomplete trip handling
- Accessor quartet: `get_sampling_frame()`, `get_inclusion_probs()`, `get_enumeration_counts()`, `get_site_contributions()`
- Primary source validation: Malvestuto (1996) Box 20.6 reproduced exactly (E_hat = 847.5, tolerance 1e-6)
- Two vignettes: workflow tutorial (bus-route-surveys.Rmd) + equation traceability reference (bus-route-equations.Rmd)
- 21 requirements fully satisfied; tidycreel is now the ONLY R package with correct bus-route estimation

### What Worked

- **Primary source analysis before implementation:** Reading Malvestuto (1996) and Jones & Pollock (2012) before writing code prevented the conceptual errors that plague all existing R implementations (confusing πᵢ with "interview probability")
- **Validation against published examples:** Using Malvestuto (1996) Box 20.6 as a golden test caught a critical cross-validation bug in Phase 26 (ids=~site approach gave 18.625 instead of 847.5)
- **Phase 24 VERIFICATION.md retroactive creation:** The audit identified Phase 24 was never formally verified (only SUMMARY.md existed). Creating the VERIFICATION.md during Phase 26 closed this process gap without rework
- **Two-vignette separation:** Workflow tutorial + equation traceability as separate documents serves both practitioner (how) and statistician (why) audiences without confusing either
- **Pre-commit hooks with lintr:** Zero linting debt across 14 plans — continuous enforcement prevents cleanup phases

### What Was Inefficient

- **Phase 26 cross-validation discovery:** The initial plan's `ids=~site, weights=~1/.pi_i` survey design approach was wrong and had to be corrected during execution. Deeper pre-planning of the variance cross-validation approach would have avoided the deviation
- **Phase 27 data ordering issue:** Vignette interview data row ordering didn't match the validated test helper, requiring auto-fix during execution. A test-first approach to vignette data would catch this earlier
- **Audit staleness:** The milestone audit (Feb 25) was stale by the time milestone completion ran (Feb 28) because Phases 26-27 had closed all gaps. An audit immediately before completion would eliminate the "gaps_found" confusion

### Patterns Established

- **Dispatch order matters for multi-strategy estimators:** Bus-route dispatch must be placed BEFORE any guard that checks design slots that bus-route doesn't use (design$survey = NULL for bus-route). This pattern extends to any future non-standard design type
- **Two-stage test helper naming:** Section-scope helpers (make_br_sf/make_br_cal) defined immediately before the tests that use them — avoids global test helper pollution while keeping tests readable
- **Golden tests from published examples:** Box 20.6 helpers are the authoritative correctness reference for all bus-route tests. Any future estimator changes must pass these first
- **Enumeration expansion NA handling:** n_interviewed = 0 rows produce NA expansion (warn, don't error) — statistically appropriate, user gets feedback without crashing

### Key Lessons

1. **Read primary sources before implementation:** All existing R bus-route implementations are wrong because they never read Jones & Pollock (2012) carefully. Primary source investment paid off in one session and prevented months of debugging
2. **Validate against published examples early:** Box 20.6 as a Phase 26 golden test caught a fundamental variance calculation error. Moving this validation to Phase 24 (when effort estimation was first built) would have been more efficient
3. **Audit immediately before milestone completion, not days before:** Stale audits create confusion about gap status and may lead to unnecessary gap-planning work for gaps already closed
4. **Bus-route designs are architecturally similar to the existing instantaneous design:** The three-layer architecture absorbed the new design type cleanly. The dispatch pattern (check survey_type in estimators before any survey package call) is the only structural addition needed

### Cost Observations

- Model mix: ~100% sonnet (balanced profile)
- Sessions: ~8-10 sessions across 12 days
- Notable: Primary source analysis phase (reading Malvestuto 1996 + Jones & Pollock 2012) was the highest-value session — prevented fundamental conceptual errors that would have required complete rewrite

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v0.1.0 | 7 | 12 | Established three-layer architecture and GSD workflow |
| v0.2.0 | 5 | 10 | Added interview-based estimation; ratio estimator pattern |
| v0.3.0 | 8 | 16 | Largest milestone; incomplete trip complexity required more phases |
| v0.4.0 | 7 | 14 | Primary source research prevented fundamental errors; nonuniform design type pattern |

### Cumulative Quality

| Milestone | Tests | Coverage | Vignettes |
|-----------|-------|----------|-----------|
| v0.1.0 | 253 | 88.75% | 1 (getting-started) |
| v0.2.0 | 610 | 89.24% | 2 (+interview-estimation) |
| v0.3.0 | 718 | ~90% | 3 (+incomplete-trips) |
| v0.4.0 | 1,098 | ~90% | 5 (+bus-route-surveys, +bus-route-equations) |

### Top Lessons (Verified Across Milestones)

1. **Primary sources beat existing implementations:** All existing R bus-route packages had wrong πᵢ. Reading the primary source (Jones & Pollock 2012) before implementation prevented propagating those errors
2. **lintr at every commit prevents cleanup phases:** Zero linting debt across all 4 milestones — pre-commit enforcement works
3. **Golden tests from known answers:** Box 20.6 (v0.4.0), TOST reference values (v0.3.0), manual survey calculations (v0.1.0) — reference tests are the strongest quality signal
4. **Dispatch order is architectural:** Multi-strategy estimators (bus-route, ROM, standard) require careful ordering of dispatch checks relative to design slot availability

---
*Last updated: 2026-02-28 after v0.4.0 milestone*
