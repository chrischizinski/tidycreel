# Roadmap — M022: Comprehensive Project Evaluation and Future Planning

**Milestone version:** M022
**Goal:** Conduct a comprehensive evaluation of tidycreel to identify completeness gaps and produce planning artifacts for high-priority future work.

---

## Phase 70: Core Estimator Completeness — Bus-route, Aerial, Ice

**Goal:** Fix bus-route/ice harvest-rate dispatch, implement total-harvest/total-release HT estimators for bus-route and ice designs, and expand test/vignette coverage for all core estimators.

**Depends on:** —
**Delivers:** All core estimators (effort, catch-rate, harvest-rate, total-harvest, total-release) dispatch and estimate correctly for bus-route and ice designs, with 100+ targeted tests and updated vignettes.

---

## Phase 71: Future Analytical Needs — Multi-species & Beyond

**Goal:** Produce a design proposal for multi-species estimation and a research summary for spatial, temporal, and mark-recapture extensions.

**Depends on:** —
**Delivers:** Design proposal document for multi-species support; research summary for spatial/temporal/mark-recapture.

**Plans:** 1/1 plans complete

Plans:
- [x] 71-01-PLAN.md — Write combined analytical extensions research document (multi-species, spatial, temporal, mark-recapture)

---

## Phase 72: Architectural Principles & Dependency Review

**Goal:** Review current package architecture for layering violations, coupling issues, and dependency risk; document findings and recommendations.

**Depends on:** —
**Delivers:** Architectural review report; dependency review report.

**Plans:** 2/2 plans complete

Plans:
- [x] 72-01-PLAN.md — Write architectural review report (layer violations, S3 class audit, positive findings, recommendations)
- [x] 72-02-PLAN.md — Write dependency review report (Imports risk ratings, drop/demote analysis, recommendations)

---

## Phase 73: Error Handling Strategy & creel.connect Investigation

**Goal:** Define a consistent error-handling strategy (rlang/cli patterns) and investigate the creel.connect integration surface.

**Depends on:** —
**Delivers:** Error handling strategy document; creel.connect investigation report.

**Plans:** 2/2 plans complete

Plans:
- [x] 73-01-PLAN.md — Write error handling strategy document (canonical cli::cli_abort pattern, deviation inventory, contributor reference)
- [x] 73-02-PLAN.md — Write creel.connect integration surface investigation report (schema contract, companion package gaps, readiness verdict)

---

## Phase 74: Quality Bar Assessment — Tidyverse Quality & Testing Strategy

**Goal:** Audit package against tidyverse quality checklist; define external testing strategy.

**Depends on:** —
**Delivers:** Quality checklist/audit report; external testing strategy document.

**Plans:** 1/2 plans complete

Plans:
- [ ] 74-01-PLAN.md — Write quality checklist audit (tidyverse baseline, rOpenSci delta, coverage measurement, named condition class recommendation)
- [x] 74-02-PLAN.md — Write external testing strategy (decision guide: unit, snapshot, integration, property-based)

---

## Phase 75: Performance Optimization — Rcpp Opportunity Identification

**Goal:** Profile computational hot spots and identify where Rcpp could provide material gains.

**Depends on:** —
**Delivers:** Performance analysis report with Rcpp recommendations.

---
