# Project Research Summary

**Project:** tidycreel v0.2.0 - Interview-Based Catch and Harvest Estimation
**Domain:** R package - Creel survey statistical analysis
**Researched:** 2026-02-09
**Confidence:** HIGH

## Executive Summary

Interview-based catch and harvest estimation for tidycreel v0.2.0 is a **new application of existing infrastructure**, not a new stack requirement. The survey package already provides all necessary ratio estimation capabilities via `svyratio()` and `svymean()`. The architectural challenge is integrating two parallel data streams (counts for effort, interviews for CPUE) and combining them correctly with delta method variance propagation for total catch estimates.

The recommended approach extends the proven v0.1.0 three-layer architecture (User API → Orchestration → Survey Package) with a parallel workflow: count data flows through `add_counts()` to estimate effort, interview data flows through `add_interviews()` to estimate CPUE, and both merge at total catch estimation where `effort × CPUE` requires careful variance handling. The core architectural insight is that count and interview data are **statistically independent but functionally complementary** - they require separate survey design objects but coordinated variance estimation when combined.

The primary risk is incorrect estimator selection: ratio-of-means for access point interviews (complete trips) vs mean-of-ratios for roving interviews (incomplete trips). Using the wrong estimator produces 12-15% bias. Additional critical risks include: (1) missing truncation for roving interviews causing infinite variance, (2) naive product variance underestimating SE by 30-50%, (3) data structure mismatches between count and interview designs preventing combination, and (4) sparse interview data creating unstable estimates. Mitigation requires explicit interview type detection, built-in truncation logic, survey package-based delta method variance, shared calendar as design bridge, and progressive sample size validation.

## Key Findings

### Recommended Stack

**NO new dependencies required.** The existing survey package (v4.4.2) provides all necessary capabilities for interview-based estimation. Interview features represent a new application pattern using existing infrastructure, not new stack requirements.

**Core technologies (already in DESCRIPTION):**
- **survey (4.4.2):** Provides `svyratio()` for ratio-of-means CPUE estimation and `svymean()` for mean-of-ratios - exactly what's needed for catch rate calculation with proper design-based variance
- **tidyselect (1.2.1):** Column selection API already used in v0.1.0, extends naturally to interview columns (catch, effort, trip_complete)
- **dplyr (1.1.4):** May be needed for interview/count data joins, already available in imports
- **checkmate (2.3.2):** Progressive validation framework extends to interview data (Tier 1: structure, Tier 2: data quality warnings)
- **cli (3.6.5):** User messaging extends to interview-specific error guidance

**What NOT to add:**
- **srvyr:** Would be redundant with tidycreel's domain-specific API; users never touch survey objects directly
- **FSA (Fisheries Stock Assessment):** Out of scope - tidycreel is survey statistics, not biological stock assessment
- **Custom ratio estimators:** survey package implementation is peer-reviewed and correct; reimplementing would introduce bugs

### Expected Features

**Must have (table stakes for v0.2.0):**
- `add_interviews()` — Add interview data to creel_design object (parallel to `add_counts()`)
- `estimate_cpue()` — Catch per unit effort with ratio-of-means estimator for complete trips
- `estimate_catch()` — Total catch via Effort × CPUE with automatic variance propagation
- Grouped CPUE and catch — `by =` parameter for stratified/species-level estimates
- Harvest vs release distinction — Separate estimates for catch_kept and catch_released
- Complete trip interviews only — Access point design pattern (simplifies v0.2.0 scope)

**Should have (competitive advantage):**
- Automatic variance propagation for total catch — Users don't hand-calculate delta method; tidycreel handles Effort × CPUE variance
- Unified design object workflow — Single creel_design holds counts + interviews; coherent analysis pipeline
- Progressive validation for interviews — Warn about incomplete trips, missing effort, extreme CPUE values
- Print methods showing estimator context — Output shows "Ratio-of-Means CPUE" vs "Mean-of-Ratios CPUE" for transparency
- Variance method control — Existing Taylor/bootstrap/jackknife from v0.1.0 extends to CPUE and total catch

**Defer (v0.3.0+):**
- Incomplete trip handling (mean-of-ratios with truncation) — Roving design support requires trip length handling and length-bias correction
- Multi-species estimation — Requires survey-based covariance handling for species aggregation
- Caught-while-seeking adjustments — Complex domain logic requiring target species tracking
- Species aggregation helpers — Must handle covariance correctly, not simple post-hoc sums

### Architecture Approach

Interview-based estimation integrates with v0.1.0 architecture through a **parallel data stream** pattern. Count data (effort) and interview data (CPUE) flow through separate validation and survey construction pipelines, then merge at final estimation where `total catch = effort × CPUE` using delta method variance. Both streams share a common calendar/stratification foundation but maintain separate PSU structures (day-PSU for counts, interview-PSU for interviews).

**Major components:**
1. **add_interviews()** — Attaches interview data to design, validates schema, constructs interview survey design object parallel to count survey
2. **estimate_cpue()** — Mode-based dispatch to ratio-of-means (`svyratio()`) for access interviews or mean-of-ratios (`svymean(~I(catch/effort))`) for roving interviews
3. **estimate_catch()** — Species-specific CPUE wrapper, filters to single species (v0.2.0 scope constraint)
4. **estimate_total_catch()** — Combines effort × CPUE estimates using delta method variance via `survey::svycontrast()`, validates design compatibility
5. **construct_interview_survey()** — Builds `svydesign` from interview data with shared calendar strata but independent PSU structure
6. **delta_method_product()** — Variance utility for product of two estimates: `Var(E×C) = C²·Var(E) + E²·Var(C) + 2·E·C·Cov(E,C)`

**Architectural patterns preserved from v0.1.0:**
- Three-layer architecture (User API → Orchestration → Survey Package)
- Progressive validation (Tier 1: fail fast → Tier 2: warn → Tier 3: deep diagnostics)
- Design-centric workflow with immutable operations
- Variance method abstraction (Taylor/bootstrap/jackknife)

### Critical Pitfalls

1. **Wrong estimator for interview type (ratio-of-means vs mean-of-ratios)** — Using ratio-of-means for roving interviews produces 12-15% bias. **Prevention:** Encode interview_type in design object, dispatch estimator based on type, error if roving data with ratio-of-means requested. **Phase:** 08-02 (CPUE Estimation)

2. **Missing truncation for roving interviews** — Mean-of-ratios without trip truncation produces infinite variance from extreme ratios (short trips). **Prevention:** Built-in truncation at 0.5 hours (30 minutes) in `estimate_cpue()` for mean-of-ratios mode, warn if >10% of trips truncated, error if user tries to disable truncation. **Phase:** 08-03 (Roving CPUE)

3. **Incorrect variance propagation for total catch** — Naive formula `Var(E) + Var(C)` underestimates SE by 30-50%. **Prevention:** Use `survey::svycontrast()` with delta method, never allow manual multiplication, reference tests against hand-calculated delta method. **Phase:** 08-05 (Total Catch Estimation)

4. **Data structure mismatch between count and interview designs** — Count data uses day-PSU, interviews use individual-PSU; incompatible for merging. **Prevention:** Shared calendar provides bridge, `merge_count_interview_designs()` validates compatibility, aggregates interviews to day-level for covariance computation. **Phase:** 08-01 (Interview Integration)

5. **Sparse interview data creating unstable estimates** — CPUE with <30 interviews per stratum produces unreliable estimates with poor CI coverage. **Prevention:** Validate sample sizes before estimation, warn if n<30, error if n<10, suggest stratum pooling or bootstrap variance for small samples. **Phase:** 08-02 (CPUE Estimation)

6. **Bag limit bias in roving interviews** — Successful anglers leave fishery, roving only encounters unsuccessful anglers; 15-36% negative bias with effective bag limits. **Prevention:** Detect bag limit scenarios, check for truncated catch distributions, strong warning for roving + low limits (≤5 fish), recommend access design instead. **Phase:** 08-03 (Roving CPUE)

7. **Mismatched species between effort and catch data** — Total harvest requires consistent targeting (e.g., all anglers vs species-specific anglers). **Prevention:** Metadata tracking of species/targeting in estimate results, validation in `estimate_total_catch()` that effort and CPUE match. **Phase:** 08-05 (Total Catch Estimation)

## Implications for Roadmap

Based on research, suggested phase structure follows dependency order: data integration → basic estimation → advanced patterns → combined estimation.

### Phase 08-01: Interview Data Integration
**Rationale:** Must establish data structure and validation before any estimation can occur. Interviews and counts are parallel streams requiring separate but coordinated survey designs.
**Delivers:** `add_interviews()` function, interview schema validation (Tier 1/2), interview survey design construction
**Addresses:** Data structure mismatch pitfall (#4); establishes foundation for all interview-based features
**Avoids:** Incompatible design structures that prevent total catch estimation later
**Architecture:** Extends `creel_design` S3 class with `$interviews` and `$interview_survey` slots, parallels `add_counts()` pattern

### Phase 08-02: CPUE Estimation (Access Point)
**Rationale:** Access point interviews with complete trips are simpler (ratio-of-means only), well-documented, and the foundation for total catch. Implementing complete trip CPUE first validates the estimation pipeline before adding roving complexity.
**Delivers:** `estimate_cpue()` with mode="ratio_of_means", grouped CPUE estimation via `by=` parameter, sample size validation
**Addresses:** Wrong estimator pitfall (#1) for access case, sparse data pitfall (#5)
**Uses:** survey::svyratio() for ratio estimation, existing variance method infrastructure from v0.1.0
**Implements:** Mode-based dispatch architecture, estimator routing based on interview_type
**Avoids:** Starting with roving (more complex) before validating basic CPUE workflow

### Phase 08-03: CPUE Estimation (Roving Design)
**Rationale:** Roving interviews require mean-of-ratios with mandatory truncation and bag limit diagnostics. This is higher complexity and should only be added after access point CPUE is proven.
**Delivers:** `estimate_cpue()` with mode="mean_of_ratios", trip truncation logic (default 0.5 hours), bag limit diagnostics
**Addresses:** Missing truncation pitfall (#2), bag limit bias pitfall (#6)
**Uses:** survey::svymean(~I(catch/effort)) for mean-of-ratios, truncation filtering before estimation
**Implements:** Truncation validation, bag limit detection, roving-specific warnings
**Avoids:** Launching roving support without critical safeguards (truncation, bag limits)
**Research flag:** Roving design patterns well-documented in fisheries literature (Pollock et al. 1997); skip research-phase.

### Phase 08-04: Catch and Harvest Wrappers
**Rationale:** `estimate_catch()` and `estimate_harvest()` are lightweight wrappers around `estimate_cpue()` for species-specific or harvest-specific filtering. They provide user convenience without adding statistical complexity.
**Delivers:** `estimate_catch()` (species-specific CPUE), `estimate_harvest()` (harvest-only CPUE), consistent output formatting
**Addresses:** User convenience for common workflows, species filtering for v0.2.0 single-species scope
**Uses:** Existing `estimate_cpue()` implementation, filtering logic, metadata preservation
**Implements:** Wrapper pattern, species consistency tracking for later validation in Phase 08-05
**Avoids:** Scope creep into multi-species (deferred to v0.3.0)

### Phase 08-05: Total Catch Estimation (Combined)
**Rationale:** This is the ultimate deliverable of v0.2.0 - combining effort and CPUE to estimate total catch with correct variance. Requires all previous phases working correctly. Most complex due to design merging and delta method variance.
**Delivers:** `estimate_total_catch()` function, delta method variance propagation, design compatibility validation, species/targeting consistency checks
**Addresses:** Incorrect product variance pitfall (#3), species mismatch pitfall (#7), data structure mismatch validation
**Uses:** survey::svycontrast() for delta method, design merging utility, existing effort and CPUE estimation
**Implements:** Product variance factory, covariance handling (assume independence in v0.2.0), combined design construction
**Avoids:** Naive multiplication of estimates without proper variance, launching total catch without safeguards
**Research flag:** Delta method well-documented in survey statistics literature; skip research-phase.

### Phase 08-06: Documentation and Examples
**Rationale:** Interview-based estimation introduces new concepts (estimator choice, truncation, product variance) that require clear documentation. Examples demonstrate correct usage patterns.
**Delivers:** Vignette "Interview-Based Estimation", example datasets (access and roving interviews), ratio estimator guide integration, workflow examples
**Addresses:** Usability, education on estimator selection, preventing common misuse patterns
**Uses:** Existing vignette infrastructure from v0.1.0, pkgdown documentation
**Implements:** Example workflows end-to-end (design → counts → interviews → total catch)

### Phase Ordering Rationale

- **Sequential dependencies:** Can't estimate CPUE without interview integration (Phase 08-01), can't combine estimates without both effort and CPUE working (Phases 08-02/03 before 08-05)
- **Complexity progression:** Access CPUE (simpler) before roving CPUE (more complex), wrappers after core estimation, combined estimation last
- **Risk management:** Validate basic workflow (access point, ratio-of-means) before adding advanced patterns (roving, mean-of-ratios, truncation)
- **Pitfall prevention:** Each phase addresses specific pitfalls in order of discovery: data integration issues first, then estimation issues, then combination issues
- **Architectural coherence:** Parallel data stream pattern established in Phase 08-01 enables independent development of count-based (v0.1.0) and interview-based (v0.2.0) features

### Research Flags

**Phases with standard patterns (skip research-phase):**
- **Phase 08-02:** Access point CPUE using ratio-of-means is well-documented in fisheries literature and survey statistics; direct application of `svyratio()`
- **Phase 08-03:** Roving design patterns thoroughly studied (Pollock et al. 1997, Rasmussen et al. 1998); truncation thresholds established
- **Phase 08-05:** Delta method for product variance is standard survey statistics; survey package provides `svycontrast()` implementation

**Phases needing minimal validation (not full research):**
- **Phase 08-01:** Design integration pattern is tidycreel-specific architecture; validate shared calendar approach with quick test
- **Phase 08-04:** Wrappers are convenience functions; no statistical complexity requiring research

**Overall:** v0.2.0 does NOT need `/gsd:research-phase` during planning - the domain is well-understood, methods are established, and integration points are clear from v0.1.0 architecture analysis.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | survey package capabilities verified via official documentation and CRAN reference; v0.1.0 already uses all required dependencies |
| Features | HIGH | Table stakes features based on creel survey textbook (Pollock et al. 1994) and peer-reviewed literature; estimator requirements well-established |
| Architecture | HIGH | v0.1.0 architecture proven in production use; parallel data stream pattern is natural extension; integration points clearly defined |
| Pitfalls | HIGH | Critical pitfalls documented in peer-reviewed fisheries literature with quantified bias magnitudes; prevention strategies tested in existing packages |

**Overall confidence:** HIGH

The combination of (1) established statistical methods, (2) proven v0.1.0 architecture, (3) comprehensive domain literature, and (4) no new dependencies provides strong foundation for v0.2.0 development. Primary uncertainties are implementation details (e.g., exact API for design merging), not fundamental approach.

### Gaps to Address

- **Covariance between effort and CPUE estimates:** Research assumes independence (Cov(E,C) = 0) for v0.2.0 simplicity; if count and interview data are collected on same days by same clerks, may be correlated. **Resolution:** Document independence assumption, add covariance term in v0.3.0 if users report issues; bootstrap variance as fallback.

- **Multi-species aggregation patterns:** v0.2.0 scope constraint (single species only) defers this complexity. **Resolution:** Phase 08-04 tracks species metadata in results; v0.3.0 implements survey-based covariance for species aggregation.

- **Bootstrap variance for combined estimates:** Delta method assumes large samples; small creel surveys may need bootstrap. **Resolution:** Phase 08-05 implements delta method first (simpler, faster); add bootstrap path in v0.2.1 if users request.

- **Interview weight handling:** If interview surveys use probability sampling (not all anglers interviewed), need sampling weights. **Resolution:** v0.2.0 assumes equal probability sampling (access point design); add weight parameter in v0.3.0 for complex sampling designs.

## Sources

### Primary (HIGH confidence)
- [survey package documentation: svyratio, svycontrast](https://r-survey.r-forge.r-project.org/survey/) — Ratio estimation and delta method implementation
- [Pollock, K.H., Jones, C.M., & Brown, T.M. (1994). Angler Survey Methods and their Applications in Fisheries Management. American Fisheries Society Special Publication 25](https://www.researchgate.net/publication/313949781_Creel_Surveys) — Gold standard reference for creel survey methods
- [Pollock, K.H., et al. (1997). Catch Rate Estimation for Roving and Access Point Surveys. North American Journal of Fisheries Management 17(1):11-19](https://www.academia.edu/80439796/Catch_Rate_Estimation_for_Roving_and_Access_Point_Surveys) — Ratio-of-means vs mean-of-ratios with bias quantification
- [Rasmussen, P.W., et al. (1998). Bias and confidence interval coverage of creel survey estimators evaluated by simulation. Transactions of the American Fisheries Society 127:469-480](https://fisheries.org/doi/9781934874295-ch19/) — Simulation evidence for truncation benefits, CI coverage analysis
- tidycreel v0.1.0 codebase — `.planning/codebase/ARCHITECTURE.md`, `R/creel-estimates.R`, `R/survey-bridge.R` (proven architecture foundation)

### Secondary (MEDIUM confidence)
- [NOAA Fisheries: CPUE Modeling Best Practices](https://www.fisheries.noaa.gov/resource/peer-reviewed-research/catch-unit-effort-modelling-stock-assessment-summary-good-practices) — General CPUE guidance (stock assessment focus, not survey focus)
- [AnglerCreelSurveySimulation CRAN package](https://cran.r-project.org/web/packages/AnglerCreelSurveySimulation/vignettes/creel_survey_simulation.html) — Simulation tools demonstrating estimator behavior (complementary, not competing)
- tidycreel domain documents — `creel_chapter.md`, `creel_foundations.md`, `creel_effort_estimation_methods.md` (internal literature review)

### Tertiary (LOW confidence)
- [Bayesian integration of multiple creel survey data sources (ScienceDirect 2023)](https://www.sciencedirect.com/science/article/pii/S0165783623003259) — Advanced methods for future consideration (v1.0.0+)

---
*Research completed: 2026-02-09*
*Ready for roadmap: yes*
