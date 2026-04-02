# Requirements: tidycreel v1.1.0

**Defined:** 2026-04-01
**Core Value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals.

## v1.1.0 Requirements

### Planning Suite

- [ ] **PLAN-01**: User can generate within-day count time windows via `generate_count_times()` using random, systematic, or fixed strategies, returning a data frame compatible with `creel_schedule`
- [x] **PLAN-02**: User can read a complete survey scheduling workflow in `survey-scheduling.Rmd` — covering `generate_count_times()`, `validate_design()`, `check_completeness()`, and `season_summary()` in a coherent pre/post-season narrative

### Community Health

- [x] **COMM-01**: User filing a bug report sees a structured form with survey_type dropdown (instantaneous/bus_route/ice/camera/aerial), tidycreel version, and expected vs actual behavior fields
- [x] **COMM-02**: User filing a feature request sees a structured form with problem statement, proposed solution, use case, and survey types affected fields
- [x] **COMM-03**: User visiting the Issues tab is guided to the right channel — Discussions for questions, bug form for bugs, feature form for requests — via `config.yml`
- [x] **COMM-04**: User wanting to contribute finds a `CONTRIBUTING.md` explaining how to file issues, write reprexes, submit PRs, and follow coding standards
- [x] **COMM-05**: GitHub Discussions is enabled and linked from `config.yml` and `CONTRIBUTING.md` as the canonical place for how-to questions

## Future Requirements

### Planning Suite

- **PLAN-F01**: Simulation study for complete vs. incomplete trip pooling bias (deferred since v0.3.0)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Real-time API pull | Data-model agnostic by design |
| Report rendering (Rmd/PDF) | Tidy tibbles are the deliverable; rendering is a separate concern |
| CRAN submission | Not targeted for this milestone |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PLAN-01 | Phase 57 | Pending |
| PLAN-02 | Phase 58 | Complete |
| COMM-01 | Phase 59 | Complete |
| COMM-02 | Phase 59 | Complete |
| COMM-03 | Phase 59 | Complete |
| COMM-04 | Phase 59 | Complete |
| COMM-05 | Phase 59 | Complete |

**Coverage:**
- v1.1.0 requirements: 7 total
- Mapped to phases: 7/7
- Unmapped: 0

---
*Requirements defined: 2026-04-01*
*Last updated: 2026-04-01 after roadmap created (Phases 57-59)*
