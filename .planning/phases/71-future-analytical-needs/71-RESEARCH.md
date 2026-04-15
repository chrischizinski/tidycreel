# Phase 71: Future Analytical Needs — Multi-species & Beyond - Research

**Researched:** 2026-04-15
**Domain:** Creel survey analytical extensions — multi-species estimation, spatial stratification, temporal modelling, mark-recapture
**Confidence:** MEDIUM-HIGH (creel literature well-covered; some gaps in exact covariance formulas require paper-level access)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Research summary must map current single-species state and gaps for joint/multi-species estimation; cover joint estimation with cross-species covariance
- Include non-binding interface sketches anchored to the existing `by = species` idiom
- Document is research-only — no prescriptive design decisions; those come from a later discussion
- Spatial and temporal extensions get substantive depth (v1.4 candidates)
- Mark-recapture gets deep coverage despite being v1.5+ — biologist audience expects the full landscape
- For spatial: researcher identifies gaps, does not pre-specify them
- For temporal: researcher identifies gaps (autocorrelation, mixed-effects beyond aerial GLMM, etc.)
- Mark-recapture: full literature survey of creel-integrated methods, estimator families (Petersen, Schnabel, Jolly-Seber), applicability to bus-route/instantaneous
- Primary audience: package author + fisheries biologists — technically rigorous but explained
- Final home: `.planning/` this phase; future phase promotes to vignettes
- Outputs do NOT produce phase stubs or new roadmap entries — those come from a separate session
- Prioritize all four source categories: creel literature, general survey statistics, ecology/fisheries journals, and statistical software

### Claude's Discretion
- Exact document structure and section headings within each research summary
- How to organise the build-vs-wrap assessment (table vs. narrative vs. per-extension sidebar)
- Whether to produce one combined document or separate per-topic files
- Citation format

### Deferred Ideas (OUT OF SCOPE)
- Promote research summaries to package vignettes (future phase)
- Add new roadmap phases based on research findings (separate roadmap review session)
- Mark-recapture implementation (v1.5+ milestone)

</user_constraints>

---

## Summary

Phase 71 is a pure research/documentation phase. Its outputs are prose planning artifacts, not code. Three research summaries are needed: (1) multi-species joint estimation centred on cross-species covariance within the HT framework, (2) spatial stratification and section-level estimation gaps, and (3) temporal modelling extensions plus mark-recapture as the completely absent capability. Each summary should be accessible to biologists while maintaining statistical rigour.

The existing tidycreel codebase provides a strong foundation: the `survey` R package (already imported) can produce cross-domain covariance matrices via `svyby(..., covmat = TRUE)`, which is the key technical ingredient for joint multi-species variance. Spatial hooks (`add_sections()`, `$sections`, `area_col`, `shoreline_col`) exist but no section-weighted estimator is formalised. Temporal modelling beyond the aerial GLMM (Askey 2018) does not exist. Mark-recapture is entirely absent, though two external packages — FSA (closed-population, simple) and RMark (open-population, feature-complete) — cover most estimator families.

**Primary recommendation:** Produce one combined research document structured in four clearly labelled sections (Current State, Multi-species, Spatial, Temporal + Mark-recapture), with a build-vs-wrap table for each extension. A combined document keeps cross-cutting concerns (HT framework, `survey` package, `creel_design` object) visible across all sections.

---

## Standard Stack

This phase produces documents, not code. The "stack" relevant here is the set of R packages and literature the documents must cover.

### Core — already in tidycreel
| Package | Version | Role in research |
|---------|---------|-----------------|
| survey | >=4.1 (imported) | HT estimation, svyby covariance, domain estimation; central to all extensions |
| lme4 | >=1.1 (suggested) | Temporal GLMM (Askey 2018 aerial path); relevant to temporal extension survey |

### External — build-vs-wrap candidates
| Package | CRAN Status | Estimator Coverage | Wrap Potential |
|---------|-------------|-------------------|----------------|
| FSA | Active (0.9.6+) | Petersen, Chapman, Schnabel, Schumacher-Eschmeyer, Jolly-Seber (`mrClosed`, `mrOpen`) | HIGH for closed-pop |
| RMark | Active (3.0.0) | Full Program MARK interface — CJS, POPAN, robust design, open-pop | HIGH for open-pop |
| AnglerCreelSurveySimulation | Active | Bus-route simulation (Steven Ranney) — not estimation | LOW (simulation only) |

**Key insight — survey package covariance capability (HIGH confidence):**
`survey::svyby(..., covmat = TRUE)` returns the full covariance matrix including between-domain (between-species) covariance. This means multi-species joint variance is already computable from within the existing framework. The gap is not a missing dependency — it is an interface and workflow gap: tidycreel currently calls `svyby` without `covmat = TRUE`, and does not expose cross-species covariance to the caller. See: https://www.practicalsignificance.com/posts/survey-covariances-using-influence-functions/ and the survey package manual at https://cran.r-project.org/web/packages/survey/survey.pdf.

---

## Architecture Patterns

### Existing HT Framework (HIGH confidence)
The dominant pattern is HT estimation via `survey::svydesign` + `svytotal`/`svyby`. All extensions must work within this framework. Key internal functions:

- `build_interview_survey()` / `construct_interview_survey()` — wraps `survey::svydesign()`
- `get_variance_design()` — converts to replicate design for bootstrap/jackknife
- `estimate_cpue_species()` — loops over species, one `svyby` call per species (no joint covariance)
- `estimate_total_harvest_species()` — same loop pattern, same gap

### Multi-species Covariance Pattern (MEDIUM confidence)
The standard survey-statistics approach for joint estimation of two totals T_1, T_2 (one per species) under stratified sampling:

```
Var(T_1 + T_2) = Var(T_1) + Var(T_2) + 2 * Cov(T_1, T_2)
```

Under HT, the joint inclusion probability `pi_{ij}` is required for exact Cov. In practice, `survey::svytotal(~sp1 + sp2, design)` computes both totals simultaneously and the package derives the covariance from influence functions. This is the recommended path — do not hand-roll cross-species covariance formulas.

**Interface sketch (non-binding, for research document):**
```r
# Proposed: multivariate formula interface
estimate_total_harvest(design, species = c("walleye", "perch"), joint_variance = TRUE)
# Returns estimates tibble + vcov matrix attribute

# Or: extend by = species to accept vector and add covmat = TRUE internally
estimate_catch_rate(design, by = species, joint_variance = TRUE)
```

The `creel_design` object would need a new field (e.g., `$joint_species`) or the multi-species mode could be triggered purely by argument.

### Spatial Extension Pattern (MEDIUM confidence)
Existing: `add_sections()` registers sections with optional `area_ha` and `shoreline_km`. `estimate_catch_rate_sections()` calls `estimate_cpue_species()` per section. **Gap identified:** No section-area-weighted lake-wide estimate exists. Standard fisheries approach is post-stratification by section area weight:

```
T_lake = sum_s( w_s * T_s )   where w_s = area_s / area_lake
```

This is a standard post-stratification estimator and is fully supported by `survey::postStratify()`. The research summary should document: (a) what `add_sections()` currently stores, (b) what a section-weighted estimator would require, and (c) whether `survey::postStratify()` or manual weighting is cleaner in this context.

### Temporal Extension Pattern (MEDIUM confidence)
Existing: Askey 2018 quadratic GLMM in `creel-estimates-aerial-glmm.R` using `lme4::glmer.nb()` — temporal modelling only for aerial counts. Identified gaps:

1. **Autocorrelation in daily effort/catch** — instantaneous and bus-route surveys sample on specific days; residual autocorrelation across survey days is unmodelled
2. **Panel/trend modelling across survey years** — a 2025 paper (van Poorten & Lemp, Fisheries Management and Ecology; see sources) provides a panel modelling framework for sparse, temporally irregular creel series using cross-sectional GLMs; directly applicable
3. **Mixed-effects extensions for non-aerial survey types** — the aerial GLMM path does not generalise to bus-route or instantaneous; a mixed-effects model for day-type × time-of-day interaction with random lake/year effects could generalise

### Mark-Recapture Architecture (MEDIUM confidence — synthesised from literature)
Mark-recapture can interact with creel surveys in two distinct ways:

**Mode 1 — Effort estimation replacement (Hansen 2018):** Replace instantaneous angler counts with mark-recapture of anglers (mark anglers at launch, recapture at takeout). Reduces vehicle mileage up to 50% vs. traditional counts with no significant difference in harvest estimates (Hansen et al. 2018, NAJFM).

**Mode 2 — Exploitation rate combined estimator (Saha thesis, ODU; Pollock et al.):** Tag M fish, deploy creel agents to record tagged + untagged catch. Model: number captured per unit ~ Poisson; recaptures | captures ~ Binomial. Yields MLE of exploitation rate. Extension: stratify by area/season (Bayesian Gibbs sampler version also available).

**Estimator families relevant to fisheries creel integration:**

| Family | Assumption | R package | Key function |
|--------|-----------|-----------|-------------|
| Petersen / Chapman | Closed pop, two-sample | FSA | `mrClosed()` |
| Schnabel / Schumacher-Eschmeyer | Closed pop, multi-sample | FSA | `mrClosed()` |
| Jolly-Seber / POPAN | Open pop, births + deaths | FSA + RMark | `mrOpen()` / RMark POPAN model |
| CJS (Cormack-Jolly-Seber) | Open pop, survival focus | RMark | `mark()` |
| Robust design | Mixed open/closed primary/secondary | RMark | `mark()` with robust model |

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| Cross-species covariance under stratified HT | Custom covariance formula with manual `pi_ij` | `survey::svytotal(~sp1 + sp2, design)` or `svyby(..., covmat=TRUE)` | `survey` derives covariance from influence functions; joint inclusion probability calculation is complex and error-prone |
| Section-area-weighted lake estimate | Manual weighting loop | `survey::postStratify()` or calibration | Already in survey package; handles edge cases |
| Petersen / Schnabel closed-population N | Custom maximum likelihood | `FSA::mrClosed()` | Handles Chapman correction, confidence intervals, all standard modifications |
| Jolly-Seber open-population N | Custom open-population recursion | `FSA::mrOpen()` | Schnabel + Schumacher-Eschmeyer and JS recurrence both implemented |
| Complex open-population CJS / POPAN | Custom survival model | `RMark` (wraps Program MARK) | Full model suite, AIC model selection, covariate support; re-implementing would take years |
| Temporal autocorrelation in effort series | ARIMA by hand | `lme4` random effects for day/week, or panel GLM per van Poorten & Lemp 2025 | Established methods; auto-correlation in sparse series requires careful design |

**Key insight:** For the multi-species case, the `survey` package already solves the hardest statistical problem (cross-domain covariance). The implementation gap is in the tidycreel interface, not in the underlying statistics.

---

## Common Pitfalls

### Pitfall 1: Treating multi-species as just a loop over species
**What goes wrong:** Current `estimate_cpue_species()` calls `svyby` independently per species. Variances are correct individually but Cov(T_walleye, T_perch) is never estimated. A combined total like "total salmonids" requires the covariance term. Ignoring it produces optimistic (too narrow) confidence intervals for combined totals.
**How to avoid:** Use multivariate `svytotal(~sp1 + sp2, design)` or `svyby(..., covmat=TRUE)` in one call — do not sum marginal variances.
**Warning signs:** CI for a summed species group is narrower than any individual species CI.

### Pitfall 2: Conflating section-level estimates with lake-wide post-stratification
**What goes wrong:** Summing per-section HT totals without area weighting overstates sections with disproportionate sampling effort. The existing `estimate_catch_rate_sections()` does not apply area weights.
**How to avoid:** Section-weighted estimation requires that area weights (already storable via `area_col` in `add_sections()`) are incorporated into a post-stratification step.
**Warning signs:** Lake-wide total implicitly assumes equal section areas when sections have very different water surface areas.

### Pitfall 3: Assuming RMark can run without Program MARK installed
**What goes wrong:** RMark is an R interface to the external FORTRAN binary Program MARK (Windows-centric). On macOS/Linux, MARK must be installed separately or accessed via wine/Docker. The `marked` package (also by jlaake) runs pure-R CJS models without external dependencies.
**How to avoid:** For a potential tidycreel wrapper, `FSA::mrClosed()` / `FSA::mrOpen()` or the `marked` package are more portable. RMark is most powerful but has a non-trivial deployment requirement.
**Warning signs:** `RMark::mark()` fails with "MARK.EXE not found" on non-Windows systems.

### Pitfall 4: Ignoring temporal autocorrelation in apparent "independent" daily samples
**What goes wrong:** Bus-route and instantaneous creel surveys sample on scheduled days. High effort on day t often precedes high effort on day t+1 (weather, weekend runs, fish reports). Treating days as independent overstates effective sample size.
**How to avoid:** Day-level random effects in an lme4 model absorb most temporal autocorrelation. Panel modelling framework (van Poorten & Lemp 2025) provides a covariate-based path.
**Warning signs:** Residual plots from stratum-level effort models show clear lag-1 autocorrelation.

### Pitfall 5: Conflating exploitation rate with harvest rate
**What goes wrong:** Mark-recapture integrated with creel can estimate exploitation rate (fraction of population harvested) — not the same as harvest rate (CPUE × effort). These require different data inputs and different estimators.
**How to avoid:** Mark-recapture exploitation models (Saha / Pollock) require a tagging study; pure creel harvest rate does not. Research summary should clearly separate these two use cases.

---

## Code Examples

### Existing multi-species loop (basis for gap analysis)
```r
# Source: /R/creel-estimates.R line 2990
estimate_cpue_species <- function(design, species_col, ...) {
  all_species <- sort(unique(design[["catch"]][[species_col]]))
  results_list <- vector("list", length(all_species))
  for (i in seq_along(all_species)) {
    # One svyby call per species — no cross-species covariance
    result <- estimate_cpue_total(design_sp, variance_method, conf_level, estimator)
    results_list[[i]] <- sp_df
  }
  do.call(rbind, results_list)
}
```

### Joint covariance via survey package (illustrative — not yet in tidycreel)
```r
# Source: survey package manual + practicalsignificance.com blog post
# svytotal on multivariate formula returns full vcov
svy <- survey::svydesign(ids = ~1, strata = ~day_type, data = interviews, weights = ~wt)
# Single call — covariance between species totals is computed from influence functions
result <- survey::svytotal(~walleye_count + perch_count, svy)
vcov(result)  # 2x2 matrix with Cov(walleye, perch) off-diagonal
```

### FSA closed-population mark-recapture (illustrative)
```r
# Source: FSA package — mrClosed documentation
# Petersen / Chapman: M tagged, n captured in second sample, m recaptured
library(FSA)
mr <- mrClosed(M = 200, n = 150, m = 35, method = "Chapman")
summary(mr)  # N-hat, SE, 95% CI
```

### FSA Jolly-Seber open-population (illustrative)
```r
# Source: FSA::mrOpen documentation
# Requires capture history summary from capHistSum()
ch_sum <- capHistSum(walleye_capture_history)
js <- mrOpen(ch_sum)
summary(js)  # abundance, survival, apparent recruitment per interval
```

---

## State of the Art

| Old approach | Current approach | Status | Impact for tidycreel |
|--------------|-----------------|--------|---------------------|
| Independent per-species CPUE loops | Multivariate `svytotal` with joint vcov | Survey package feature; not yet used in tidycreel | Joint variance for species combinations now computable without new dependencies |
| Manual section totals without area weighting | `survey::postStratify()` with section area calibration | Established method; hook exists in `add_sections()` | Section-weighted estimator is a well-defined 1-function gap |
| Temporal effort expansion by simple mean count | GLMM quadratic (Askey 2018) → panel modelling framework (van Poorten & Lemp 2025) | Current literature direction | Aerial GLMM is one instance; generalisation needed for other survey types |
| Program MARK (Windows FORTRAN) for mark-recapture | RMark (R interface) + FSA (pure R, closed-pop) + marked (pure R, CJS) | Active 2024 | Three-tier choice: FSA for simple, marked for portable CJS, RMark for full power |

**Deprecated / outdated:**
- Direct calls to Program MARK binary without RMark wrapper: superseded by RMark
- Simple ratio estimators for section-level totals ignoring area: superseded by post-stratification calibration

---

## Open Questions

1. **Cross-species covariance formula under bus-route HT specifically**
   - What we know: `survey::svytotal()` computes covariance from influence functions; this should work for bus-route HT when `.contribution` columns are constructed per-species
   - What is unclear: Whether the `.contribution = (catch_i / pi_i)` construction generalises cleanly when each species has a different zero-inflation pattern per interview
   - Recommendation: Prototype in a notebook before committing to an interface design

2. **Section-weighted estimator — should weighting use area or effort?**
   - What we know: `add_sections()` stores `area_ha` and `shoreline_km`; both are optional
   - What is unclear: Whether effort-proportional weighting (based on observed angler counts per section) is more appropriate than area weighting for section-level totals
   - Recommendation: Research document should cover both approaches and note that the choice is fishery-specific

3. **marked vs. RMark portability tradeoff**
   - What we know: `marked` package runs pure-R CJS without external MARK binary; RMark has the full model suite but requires MARK.EXE
   - What is unclear: Whether `marked` supports the POPAN open-population estimators needed for exploitation rate estimation
   - Recommendation: Verify `marked` model coverage before recommending it as the primary wrap target

4. **Temporal autocorrelation — is day-of-week effect sufficient or is explicit AR(1) needed?**
   - What we know: The van Poorten & Lemp 2025 framework uses covariates (weather, weekend) to explain temporal variance; `lme4` can add day-level random effects
   - What is unclear: Whether tidycreel's typical survey designs (10–30 sampled days per season) have enough data to identify AR(1) structure vs. just absorb it in day-level random effects
   - Recommendation: Flag this as a design-data-volume question; the research document should present both AR(1) and random-effects paths with their data requirements

---

## Build-vs-Wrap Assessment

| Extension | Problem scope | Build from scratch | Wrap existing | Recommendation |
|-----------|--------------|-------------------|---------------|----------------|
| Multi-species joint variance | Extend `svyby` call to multivariate + expose vcov | Unnecessary — `survey` already does it | `survey::svytotal(~sp1+sp2, design)` | **Wrap survey** — change to multivariate formula call |
| Section-weighted lake total | Area-weighted post-stratification | Unnecessary — `postStratify` exists | `survey::postStratify()` or calibration | **Wrap survey** — add weight computation helper |
| Temporal GLMM extension | Non-aerial survey types (bus-route, instantaneous) | Moderate — adapt Askey pattern | `lme4::lmer()` already used | **Extend existing** — generalise aerial GLMM code |
| Closed-pop mark-recapture | Petersen, Schnabel | 1–2 functions, not complex | `FSA::mrClosed()` | **Wrap FSA** — thin wrapper, match tidycreel output style |
| Jolly-Seber open-pop | Multi-sample open population | Moderate complexity | `FSA::mrOpen()` | **Wrap FSA** — same as above |
| CJS / POPAN full model | Survival + abundance, open pop | Very high complexity | `RMark` or `marked` | **Wrap RMark/marked** — do not re-implement |
| Exploitation rate from creel+tags | Combined Saha-type model | Moderate — Bayesian extension is complex | No clean existing wrapper | **Build or wrap** — FSA does not cover this specific estimator |

**Overall verdict:** For all mark-recapture estimator families, wrapping existing packages is clearly preferable. For multi-species covariance and section weighting, the `survey` package (already imported) already provides the machinery — the work is interface design, not statistics. The only genuine build candidate is the exploitation-rate-from-creel+tags combined estimator, which occupies a niche not well covered by FSA or RMark.

---

## Validation Architecture

> This phase produces no testable code. All outputs are planning documents in `.planning/`. No test infrastructure changes are needed or warranted.

**Note for planner:** Because Phase 71 delivers only `.planning/` markdown documents, the Nyquist validation section is intentionally minimal. There are no automatable tests for research quality. Human review of document completeness is the sole quality gate.

| Req ID | Behavior | Test Type | Command | Notes |
|--------|----------|-----------|---------|-------|
| (none) | Document completeness | Manual review | n/a | Reviewer confirms all four areas covered |

---

## Sources

### Primary (HIGH confidence)
- `survey` R package manual — https://cran.r-project.org/web/packages/survey/survey.pdf — svytotal, svyby, postStratify, covariance matrix
- Practical Significance blog — https://www.practicalsignificance.com/posts/survey-covariances-using-influence-functions/ — between-domain covariance in survey package
- FSA package documentation — https://cran.r-project.org/package=FSA — mrClosed(), mrOpen(), capHistSum()
- tidycreel codebase: `/R/creel-estimates.R`, `/R/creel-estimates-bus-route.R`, `/R/creel-design.R`, `/R/survey-bridge.R`, `/R/creel-estimates-aerial-glmm.R` — current state documentation

### Secondary (MEDIUM confidence)
- Askey, P.J. et al. 2018. "Angler Effort Estimates from Instantaneous Aerial Counts: Use of High-Frequency Time-Lapse Camera Data to Inform Model-Based Estimators." North American Journal of Fisheries Management. https://onlinelibrary.wiley.com/doi/abs/10.1002/nafm.10010 — Askey 2018 GLMM quadratic temporal model (implemented in tidycreel aerial path)
- Hansen, J.M. et al. 2018. "A Mark-Recapture-Based Approach for Estimating Angler Harvest." North American Journal of Fisheries Management. https://onlinelibrary.wiley.com/doi/10.1002/nafm.10038 — mark-recapture replacing instantaneous counts for effort, 50% mileage saving
- Van Poorten, B. & Lemp, P. 2025. "Robust Trend Estimation From Temporally Irregular Recreational Fisheries Surveys: A Panel Modeling Framework for Sparse Time Series." Fisheries Management and Ecology. https://onlinelibrary.wiley.com/doi/10.1111/fme.12816 — temporal panel framework for sparse creel series
- Saha, S. "Mark-Recapture Creel Survey and Survival Models." ODU thesis. https://digitalcommons.odu.edu/mathstat_etds/52/ — exploitation rate from combined mark-recapture + creel estimator
- RMark package: https://cran.r-project.org/web/packages/RMark/RMark.pdf and https://github.com/jlaake/RMark — full MARK interface in R
- Bayesian creel + Bayesian multi-source integration: https://www.sciencedirect.com/science/article/pii/S0165783623003259 — Bayesian integration of multiple creel data sources (2023, Fisheries Research)

### Tertiary (LOW confidence — flag for validation)
- Multivariate HT estimator for two sensitive means: https://www.mdpi.com/2075-1680/15/2/108 — theoretical extension; not directly fisheries-facing
- CreelCat database (14,729 surveys): https://www.nature.com/articles/s41597-023-02523-2 — context for creel survey prevalence, not estimator methodology
- Optimizing Creel Surveys (2025 Springer): https://link.springer.com/chapter/10.1007/978-3-031-99739-6_13 — chapter content not verified; potentially relevant for spatial stratification

---

## Metadata

**Confidence breakdown:**
- Multi-species covariance via survey package: HIGH — verified from survey package documentation and blog post showing `svyby(..., covmat=TRUE)` returns full covariance matrix including between-domain terms
- Mark-recapture estimator families (FSA, RMark): HIGH — direct CRAN package documentation reviewed
- Temporal extension (Askey 2018, van Poorten 2025): MEDIUM — papers identified and abstracts verified; full text not accessed
- Hansen 2018 mark-recapture angler effort: MEDIUM — abstract and summary verified via search
- Exploitation-rate combined estimator (Saha): MEDIUM — thesis identified, methodology summary verified; full statistical details require thesis access
- Spatial section-weighted gap identification: MEDIUM — derived from codebase analysis + standard post-stratification theory; no tidycreel-specific documentation confirms the exact gap

**Research date:** 2026-04-15
**Valid until:** 2026-10-15 (stable domain; mark-recapture and survey package APIs change slowly)
