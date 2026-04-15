# Analytical Extensions Research: tidycreel v1.4+ Planning Artifact

**Produced:** 2026-04-15
**Phase:** 71 — Future Analytical Needs
**Status:** Planning artifact — for roadmap review only

---

## Preamble

This document is a planning artifact for a future roadmap review session. It is **not** a design decision record and does not commit the tidycreel project to any particular implementation path. All build-vs-wrap assessments and interface sketches are recommendations for future discussion.

**Audience:** Package author and fisheries biologists who may not be experts in survey sampling theory. Statistical formulas appear where they add clarity and are always explained in plain language alongside the notation.

**Scope:** Four analytical extension areas — multi-species joint estimation, spatial stratification, temporal modelling, and mark-recapture — plus a Current State baseline to anchor the gap analysis. Mark-recapture is a v1.5+ milestone but receives the same research depth as nearer-term extensions, because it is the most completely absent capability and because biologist readers benefit from a clear explanation of the full landscape.

**What this document does not do:**
- Create new roadmap phases or implementation timelines (those come from a separate review session)
- Prescribe exact function signatures, argument names, or internal architecture
- Commit to any specific build-vs-wrap choice before prototyping is done

---

## Section 1: Current State of Analytical Capabilities

### 1.1 The HT Estimator Framework

Before cataloguing gaps, it helps to understand the statistical foundation. tidycreel uses the **Horvitz-Thompson (HT) estimator**, the standard workhorse of survey statistics.

**The core idea:** When you sample a population, not every unit has the same chance of being selected. If a unit has inclusion probability pi_i (Greek letter pi, subscript i, read "the probability that unit i was sampled"), then the HT estimator weights each sampled unit by 1/pi_i to produce an unbiased estimate of the population total.

For a quantity of interest y (say, fish harvested):

```
T_HT = sum_i ( y_i / pi_i )
```

In tidycreel, the `pi_i` for each interview period is computed from the scheduled survey design (day types, time blocks, section probabilities). The R `survey` package handles the mechanics: the caller provides a survey design object (`svydesign()`) and calls `svytotal()` or `svyby()` to get estimates and their variances.

**Variance of an HT total** is computed from the pairwise joint inclusion probabilities pi_ij (probability that both unit i and unit j were sampled). In practice, the `survey` package derives variances from **influence functions** — a computationally stable approach that does not require explicitly enumerating all pi_ij values. This is important context for the multi-species section below.

**Key `survey` package functions in tidycreel:**
- `survey::svydesign()` — creates the survey design object from data + weights
- `survey::svytotal()` — estimates population totals (one or more variables simultaneously)
- `survey::svyby()` — estimates totals/means by subgroup (e.g., by species, day type)

### 1.2 What Single-Species Support Exists Today

**Interview-based CPUE and harvest estimation:**

`estimate_cpue_species()` (in `R/creel-estimates.R`) loops over unique species values and calls `svyby()` independently for each. It returns a tidy tibble of per-species catch-per-unit-effort estimates. Each species is processed in isolation — there is no joint estimation step.

`estimate_total_harvest_species()` follows the same loop pattern for total harvest (count, not rate). Each species loop produces separate point estimates and standard errors. No cross-species relationship is captured.

**The gap this creates:** When an angler targets walleye *and* perch simultaneously, the per-species estimates are individually correct, but any combined total (e.g., "total salmonids" or "walleye + perch combined harvest") will have an incorrect variance if calculated by summing the marginal variances. The cross-species covariance term is never estimated. See Section 2 for the statistical explanation.

**Section-level spatial estimation:**

`estimate_catch_rate_sections()` (in `R/creel-design.R`) calls `estimate_cpue_species()` once per registered section. It produces per-section catch rate estimates. **There is no area-weighted lake-wide total.** If sections cover different proportions of the lake, summing section estimates without area weights produces a biased lake-wide total. See Section 3 for details.

**Temporal modelling:**

`creel-estimates-aerial-glmm.R` implements a quadratic GLMM for aerial survey counts using `lme4::glmer.nb()` — the Askey 2018 model. This is the **only** temporal modelling in the package. Bus-route and instantaneous survey types have no analogous model: their daily effort and catch observations are treated as independent across survey days, which is approximately correct within a season but may be inadequate for trend analysis across seasons. See Section 4a for gaps.

**Mark-recapture:**

There is no mark-recapture code anywhere in the tidycreel package. See Section 4b for a full survey of what exists and what creel integration would look like.

### 1.3 The `creel_design` Object and What Extensions Would Leverage

The `creel_design` object stores structured metadata that future extensions would use without requiring new user-facing data structures:

| Field | Content | Relevant to |
|-------|---------|-------------|
| `$species_sought_col` | Column name for target species | Multi-species joint estimation |
| `$catch_species_col` | Column name for catch species | Multi-species joint estimation |
| `$sections` | Registry of lake sections | Spatial stratification |
| `$area_col` | Column name for section area weights | Spatial stratification |
| `$shoreline_col` | Column name for shoreline length | Spatial stratification |

Extensions for multi-species covariance and area-weighted lake totals would likely be triggered by new function arguments rather than new `creel_design` fields — the data hooks already exist.

---

## Section 2: Multi-species Joint Estimation

### 2.1 The Statistical Problem

Consider two species — walleye and perch — caught in the same creel survey. Let T_walleye and T_perch be the HT total harvest estimates for each species. A manager might want to report combined salmonid harvest, T_combined = T_walleye + T_perch, with a confidence interval.

The variance of the sum is:

```
Var(T_walleye + T_perch) = Var(T_walleye) + Var(T_perch) + 2 * Cov(T_walleye, T_perch)
```

**Why the covariance term matters:** When anglers target both species simultaneously, harvest of walleye and perch in the same interview are positively correlated. High-catch interviews contribute large values for both species; low-catch interviews contribute small values for both. Ignoring the covariance term — which is positive in this case — produces a variance estimate that is too small. This leads to confidence intervals that are too narrow: the "combined salmonid" estimate looks more precise than it really is.

The direction of the covariance depends on the fishery:
- Anglers targeting multiple species simultaneously → positive covariance → ignoring it understates combined variance
- Anglers targeting one species exclusively → near-zero covariance → small effect
- Anglers in competing sectors (some walleye-only, some perch-only) → may be negative

**In plain language:** The current tidycreel code answers "how many walleye were harvested?" and "how many perch were harvested?" correctly for each species individually. It cannot correctly answer "how many fish total were harvested?" because it never measures whether the walleye answer and the perch answer tend to move together.

### 2.2 How the `survey` Package Solves This

The `survey` package can compute cross-species covariance without any new dependencies. The key is to pass a **multivariate formula** to `svytotal()` rather than calling it once per species:

```r
# Current pattern (per-species loop — no cross-species covariance):
result_walleye <- survey::svytotal(~walleye_count, svy_design)
result_perch   <- survey::svytotal(~perch_count,   svy_design)

# Joint pattern (single call — full vcov matrix returned):
result_joint <- survey::svytotal(~walleye_count + perch_count, svy_design)
vcov(result_joint)
# Returns 2x2 matrix:
#              walleye_count  perch_count
# walleye_count  Var(T_w)      Cov(T_w, T_p)
# perch_count    Cov(T_w, T_p) Var(T_p)
```

The package derives the covariance from **influence functions** — essentially, how sensitive each total estimate is to the inclusion or exclusion of each sampled interview. This is numerically stable and already implemented. No new packages or custom formulas are needed.

An analogous path exists via `svyby(..., covmat = TRUE)`:

```r
result_by_species <- survey::svyby(~catch_count, ~species, svy_design,
                                   svytotal, covmat = TRUE)
vcov(result_by_species)  # Full covariance matrix including cross-species terms
```

**The work is interface design, not statistics.** The statistical machinery exists in `survey`. The gap is that tidycreel's current code never calls these with the multivariate path.

### 2.3 Non-binding Interface Sketches

The following sketches illustrate how joint estimation might integrate into tidycreel's existing API. These are **non-binding** — they are provided to make the gap concrete, not to prescribe implementation.

**Option A — `joint_variance` argument on existing functions:**

```r
# Estimate total harvest for multiple species with joint variance
estimate_total_harvest(
  design,
  species = c("walleye", "perch"),
  joint_variance = TRUE
)
# Returns: estimates tibble (as now) + vcov matrix as an attribute
# attr(result, "vcov") → 2x2 covariance matrix
```

**Option B — Extend the `by = species` idiom in `estimate_catch_rate()`:**

```r
estimate_catch_rate(design, by = species, joint_variance = TRUE)
# Returns: per-species rows + vcov attribute
# The by = species idiom is already established in the API
```

Both options follow the existing style: cli_abort() / cli_warn() for input validation, tidy tibble output as the primary return, metadata attached as attributes.

**creel_design changes:** The sketches above suggest argument-driven multi-species mode. A `$joint_species` field on `creel_design` is another option — but this is a design question deferred to the roadmap review. Either approach would leverage `$species_sought_col` and `$catch_species_col` already stored.

### 2.4 Open Questions

**Cross-species covariance under bus-route HT specifically:** The bus-route HT path constructs `.contribution` columns (catch_i / pi_i) per interview. When each species has a different zero-inflation pattern (many zero-catch interviews for one species, few for another), it is unclear whether `svytotal()` influence function derivation handles this correctly without a prototype. **Recommendation:** Prototype in a notebook before committing to a joint-variance interface.

**When joint variance is not meaningful:** If two species are never co-targeted (e.g., spring walleye season vs. fall trout season), joint variance adds complexity for near-zero benefit. An interface should allow the user to request it, not impose it.

### 2.5 Build-vs-Wrap Recommendation

**Wrap `survey`.** The multivariate `svytotal()` call is the correct tool. The implementation work is:
1. Change the per-species loop to a single multivariate formula call
2. Expose the `vcov()` matrix output in a user-accessible way
3. Update output formatting to handle multi-species returns

No new statistical theory or new R packages are required.

---

## Section 3: Spatial Stratification Extensions

### 3.1 What Exists

`add_sections()` (in `R/creel-design.R`) registers lake sections in the `creel_design` object. Each section can store:
- `area_ha` — water surface area in hectares (optional)
- `shoreline_km` — shoreline length in kilometres (optional)

`estimate_catch_rate_sections()` calls `estimate_cpue_species()` once per registered section and returns per-section catch rate estimates. This is correct for within-section inference. The function does **not** combine section estimates into a lake-wide total.

### 3.2 The Gap: No Area-Weighted Lake-Wide Estimator

Summing per-section HT totals without area weights produces an implicit assumption that all sections have equal area. When sections differ substantially in size, this assumption biases the lake-wide total toward the catch rate of the sections with the most sampling effort (which may be the most accessible sections, not the most representative).

**Example:** A lake has three sections: North (60 ha), Central (30 ha), South (10 ha). The survey sampled Central intensively (because the boat launch is there). A simple sum of section totals overweights the Central section. The correct lake-wide total weights each section by its proportion of the total lake area.

### 3.3 The Post-Stratification Estimator

The standard fisheries approach for a section-area-weighted lake estimate is a post-stratification estimator:

```
T_lake = sum_s( w_s * T_s )
```

where:
- T_s is the HT total estimate for section s
- w_s = area_s / area_lake is the area weight for section s (area_s divided by total lake area)
- The sum runs over all sections

**In plain language:** Each section's estimated total is scaled by that section's share of the total lake area. A section covering 60% of the lake contributes 60% of its estimated total to the lake-wide figure.

This is a standard **post-stratification** estimator — well-established in survey statistics for the case where stratum sizes (here: section areas) are known from an external source. The `survey` package implements this as `survey::postStratify()`.

### 3.4 Two Weighting Approaches

The choice of weight w_s is fishery-specific. The research document presents both without recommending one; the decision belongs to the fieldwork design.

**Area weighting (area_ha):**
- w_s = area_s / sum(area)
- Appropriate when catch rate is relatively uniform within a section and sections are reasonably homogeneous
- Data already stored in `$area_col` (if populated by the user)
- Limitation: ignores heterogeneity in angler use — anglers cluster around structure (points, weedbeds, tributaries)

**Effort-proportional weighting:**
- w_s = angler_hours_s / sum(angler_hours)
- Appropriate when sections differ systematically in angler density — a section that receives 70% of all fishing effort should contribute proportionally to the lake total
- Requires sufficient interviews per section to estimate effort reliably
- Limitation: if the survey itself is biased toward accessible sections, the weights will reflect that bias

**Data requirements note:** Area weighting requires only the `area_ha` field, which `add_sections()` already accepts. Effort-proportional weighting requires that angler effort is estimated per section from the creel data — this is feasible but requires that section-level effort variation is captured in the survey design.

### 3.5 `survey::postStratify()` as the Primary Tool

`survey::postStratify()` takes an existing survey design object and a population totals data frame (here: section areas) and re-calibrates the design weights to match the known section sizes. It is already part of the `survey` package (imported by tidycreel), handles edge cases cleanly, and integrates with all downstream `svytotal()` / `svyby()` calls.

**Pitfall: Do not sum per-section HT totals directly.** The existing `estimate_catch_rate_sections()` output is a list of per-section estimates. Summing these without post-stratification ignores between-section covariance and the section area information. The correct path routes through `postStratify()` before calling `svytotal()`.

### 3.6 Build-vs-Wrap Recommendation

**Wrap `survey`.** The `postStratify()` function is the correct tool. The implementation work is:
1. Add a helper to compute section area weights from `creel_design$sections`
2. Apply `postStratify()` to the survey design with section area totals
3. Call `svytotal()` on the post-stratified design for a lake-wide estimate

The hook (`area_col` in `add_sections()`) already exists. The primary decision (area vs. effort weights) is fishery-specific and deferred.

---

## Section 4: Temporal Modelling and Mark-Recapture

## Section 4a: Temporal Modelling Extensions

### 4a.1 What Exists

The aerial GLMM path (`creel-estimates-aerial-glmm.R`) implements a quadratic negative binomial GLMM using `lme4::glmer.nb()`. This is the Askey 2018 model: angler count ~ quadratic(hours_since_sunrise) + random(day). It applies to aerial instantaneous counts and produces a temporal expansion factor for effort estimation.

**This is the only temporal modelling in the package.** Bus-route and instantaneous interview-based surveys treat each sampled day as independent. This is approximately correct when a season's days are considered a random sample, but it creates three gaps described below.

### 4a.2 Gap 1: Autocorrelation in Daily Effort and Catch

Bus-route and instantaneous creel surveys sample on specific scheduled days within a season. High-effort days tend to follow high-effort days (good weather persists, fish reports spread, weekend effect runs Friday–Sunday). Low-effort days cluster around poor weather, weekdays, or shoulder seasons.

**The statistical problem:** Treating adjacent survey days as independent overstates the effective sample size of the daily observations. If Monday's high effort predicts Tuesday's high effort, then sampling both days adds less information than two truly independent days would.

**Quantifying the effect:** The autocorrelation can be detected via lag-1 residual correlation in effort or catch regression models. Residual plots from stratum-level effort models with clear lag-1 pattern are the diagnostic warning sign.

**Two statistical paths:**

**Path 1 — Day-level random effects (`lme4`):** Add a random intercept for survey day in the effort or catch model. This absorbs most day-to-day autocorrelation without explicitly modelling the correlation structure. Less flexible than AR(1) but simpler and typically sufficient when the main source of autocorrelation is day-specific covariates (weather, day-of-week) rather than true temporal persistence.

**Path 2 — Explicit AR(1) modelling:** Model residual correlation as a first-order autoregressive process. More statistically rigorous for persistent temporal patterns but requires sufficient data to identify the autocorrelation parameter. In a typical creel design with 10–30 sampled days per season, the AR(1) coefficient may not be identifiable — the data volume question is a design-level concern, not just a modelling one.

**Data volume note:** The choice between random effects and AR(1) depends on how many sampled days per season the survey produces. Research recommends flagging this as a design-data-volume question: the document presents both paths, but the practical recommendation for sparse surveys (fewer than ~20 days) is random effects.

### 4a.3 Gap 2: Panel Modelling for Trend Estimation Across Years

Many creel programs run for multiple seasons to track trends. The challenge is that creel surveys are temporally irregular — sampling intensity, day selection, and conditions vary year to year. A simple year-to-year comparison of raw estimates is confounded by these design differences.

**van Poorten and Lemp (2025)** ("Robust Trend Estimation From Temporally Irregular Recreational Fisheries Surveys") provide a panel modelling framework designed specifically for this context. Their cross-sectional GLM approach adjusts for temporal covariates (calendar year, day type, weather) and estimates underlying trends while accounting for the irregular sampling design.

**Relevance to tidycreel:** The package currently provides no multi-year trend estimation. A `compare_designs()` function exists for comparing variance across design options, but not for estimating temporal harvest trends from repeated surveys. The van Poorten & Lemp 2025 framework is directly applicable to bus-route and instantaneous survey types.

### 4a.4 Gap 3: Mixed-Effects Extensions for Non-Aerial Survey Types

The aerial GLMM (Askey 2018) models the within-day temporal pattern of angler density — how many anglers are on the water at each observation time, modelled as a function of time-since-sunrise with a random day effect. This is specific to aerial instantaneous counts.

For bus-route and instantaneous interview-based surveys, a mixed-effects model for **day-type × time-of-day interaction** with random lake/year effects would:
- Improve effort expansion accuracy by borrowing strength across day types and time blocks
- Allow uncertainty propagation from the temporal model into harvest estimates
- Generalise the Askey GLMM concept beyond aerial surveys

`lme4` is already a suggested dependency (used by the aerial path). The generalisation would adapt the existing GLMM architecture to other survey types.

### 4a.5 Build-vs-Wrap Recommendation

**Extend existing.** The aerial GLMM architecture already uses `lme4` in the package. Generalising to non-aerial survey types would adapt existing code rather than introduce new statistical infrastructure. The van Poorten & Lemp 2025 panel framework may require a separate implementation pathway. No new package dependencies are expected.

---

## Section 4b: Mark-Recapture

### 4b.1 Why Mark-Recapture in a Creel Context?

Mark-recapture methods enter creel surveys in two distinct ways. Understanding the difference is essential for deciding which methods to study and ultimately implement.

**Mode 1 — Effort Estimation Replacement (Hansen et al. 2018, NAJFM):**
In traditional instantaneous creel surveys, a sampler drives a route and counts anglers at fixed sites. This is expensive (vehicle mileage) and logistically demanding. Hansen et al. (2018) demonstrated that marking anglers at lake access points (boat launches, parking areas) at the start of a sampling period and re-sighting (recapturing) them at access points at the end produces effort estimates statistically comparable to traditional counts, at roughly 50% of the vehicle mileage.

This mode does **not** require tagging fish. It requires marking anglers and counting recaptures during the same creel visit. The estimator is a closed-population Petersen/Chapman applied to anglers rather than fish.

**Mode 2 — Exploitation Rate from Combined Creel + Tag Data (Saha thesis, ODU; Pollock et al.):**
A separate fish tagging study is conducted alongside the creel survey. Tagged fish are released; creel agents record whether each harvested fish was tagged or untagged. This allows estimation of the **exploitation rate** — the fraction of the total population that was harvested.

This is statistically distinct from **harvest rate** (CPUE × effort), which estimates harvest per unit effort without reference to population size. Exploitation rate requires knowing (or estimating) the initial tagged population and observing recaptures in the creel catch.

**Conflating exploitation rate and harvest rate is a common pitfall.** They require different data, different estimators, and answer different management questions. The creel part of a Mode 2 study provides recapture data; the estimator combines it with the tagging study to yield an exploitation rate.

### 4b.2 Estimator Families

The following five estimator families are relevant to fisheries mark-recapture. Each is explained below for a biologist audience, followed by its R package implementation.

**Family 1: Petersen / Chapman (Closed Population, Two-Sample)**

The simplest and most widely applied mark-recapture estimator. The study has two sampling occasions:
1. Capture, mark, and release M fish (or anglers)
2. Later, capture a new sample of n individuals; count m recaptures (previously marked)

The Petersen estimator is:

```
N_hat = (M * n) / m
```

In plain language: "If 20% of the second sample was marked, and we released 100 marked fish, then the population is about 100 / 0.20 = 500."

The **Chapman correction** adjusts for small-sample bias (important when m is small relative to M and n):

```
N_hat_Chapman = ((M + 1) * (n + 1)) / (m + 1) - 1
```

R implementation: `FSA::mrClosed()` — handles both Petersen and Chapman corrections, produces confidence intervals, requires no external binary.

**Family 2: Schnabel / Schumacher-Eschmeyer (Closed Population, Multi-Sample)**

Extension of Petersen to multiple sampling occasions. Fish are marked cumulatively across K occasions; at each occasion the number of new captures, recaptures, and total cumulative marks is recorded. This produces a more precise N estimate when the study spans multiple days.

R implementation: `FSA::mrClosed()` with multi-sample input.

**Family 3: Jolly-Seber / POPAN (Open Population)**

For populations where births (recruitment), deaths, and emigration occur between sampling occasions — the realistic case for most fish populations over weeks to months. The Jolly-Seber estimator produces:
- Population abundance estimate per sampling interval
- Apparent survival probability between intervals
- Apparent recruitment into the population per interval

The POPAN parameterization (Schwarz & Arnason 1996) is a reformulation of Jolly-Seber that has become standard in modern software — it works from individual capture histories rather than summary statistics.

R implementations: `FSA::mrOpen()` for basic open-population estimation; `RMark` (POPAN model) for the full POPAN implementation with covariate support.

**Family 4: CJS — Cormack-Jolly-Seber (Open Population, Survival Focus)**

CJS models focus on survival and recapture probability rather than absolute abundance. They require individual capture histories (a binary string recording whether each marked individual was seen at each sampling occasion). CJS models are the standard tool when the primary question is "what fraction of marked individuals survived from period t to period t+1?"

CJS does **not** directly estimate abundance; it estimates apparent survival (the product of true survival and fidelity — not distinguishing emigration from death). Pairing CJS with a Petersen abundance estimate from the first occasion yields a time series of abundance.

R implementations: `RMark` (wraps Program MARK, full CJS model suite); `marked` package (pure-R CJS, no external binary).

**Family 5: Robust Design (Mixed Open/Closed)**

The robust design (Pollock 1982) structures sampling into:
- **Primary periods:** Long intervals during which the population can change (open population assumptions apply — Jolly-Seber or CJS)
- **Secondary periods:** Short intervals within each primary period during which the population is approximately closed (closed-population assumptions apply — Petersen/Chapman/Schnabel)

This structure allows simultaneous estimation of survival between primary periods AND abundance within each primary period — the most powerful mark-recapture design for short-term study of exploited populations.

R implementation: `RMark` — full robust design model support.

### 4b.3 Package Coverage

| Package | Deployment | Estimator Coverage | Wrap Potential |
|---------|-----------|-------------------|----------------|
| FSA | Pure R, no external deps | Petersen, Chapman, Schnabel, Schumacher-Eschmeyer, Jolly-Seber (mrClosed, mrOpen) | HIGH — thin wrapper, matches tidycreel output style |
| marked | Pure R, no external deps | CJS models (survival + recapture) with covariate support | MEDIUM — portable CJS, but POPAN coverage uncertain (see Open Questions) |
| RMark | R interface to Program MARK (external FORTRAN binary) | Full model suite: CJS, POPAN, robust design, multi-state, individual covariates | HIGH — most powerful, but deployment requires MARK.EXE (Windows-centric) |

**Deployment note for RMark:** On macOS and Linux, Program MARK must be installed separately or accessed via wine or Docker. This is a non-trivial requirement for a package intended for broad fisheries biologist use. `marked` (pure R, no external binary) is the portable alternative for CJS models. For a tidycreel wrapper, `FSA` is the first choice for closed-population estimators; `marked` for portable CJS; `RMark` where full POPAN or robust design power is required and the user can manage the MARK binary dependency.

### 4b.4 Applicability to Bus-Route and Instantaneous Survey Types

**Mode 1 (Angler effort replacement):** Applicable to instantaneous surveys — the field deployment (mark anglers at access points, re-sight during creel visit) maps directly onto instantaneous count methodology. Bus-route surveys sample from a moving vehicle; the logistical challenge is greater but the statistical estimator is the same Chapman closed-population approach.

**Mode 2 (Exploitation rate from creel + tags):** Applicable to any survey type where creel agents can reliably record tag status at harvest. The tagging study (catching and tagging fish) runs independently of the creel survey design. The creel component provides recapture data (tagged fish in the creel). This is compatible with bus-route, instantaneous, and potentially ice surveys.

### 4b.5 Build-vs-Wrap Recommendation

| Estimator | Recommendation | Notes |
|-----------|---------------|-------|
| Petersen / Chapman / Schnabel (closed pop) | Wrap FSA | `FSA::mrClosed()` covers all variants; thin wrapper matching tidycreel output style |
| Jolly-Seber open-pop (basic) | Wrap FSA | `FSA::mrOpen()` handles standard JS; simpler than RMark for basic use |
| CJS / POPAN survival model | Wrap `marked` (portable) or `RMark` (full power) | `marked` preferred if POPAN coverage verified; `RMark` if MARK.EXE deployment is acceptable |
| Exploitation rate from creel + tags | Build or future standalone package | No existing R package wraps the Saha/Pollock creel-integrated exploitation estimator cleanly; genuine build candidate |

**Overall assessment:** Wrapping existing packages is clearly preferable for all standard mark-recapture estimator families. The only genuine build candidate is the creel-integrated exploitation rate estimator, which occupies a niche not well covered by FSA or RMark. That estimator may be better placed in a future standalone package than in tidycreel itself.

---

## Section 5: Build-vs-Wrap Summary Table

| Extension | Build or Wrap | Package / Tool | Recommendation | Notes |
|-----------|--------------|---------------|---------------|-------|
| Multi-species joint variance | Wrap | `survey::svytotal()` / `svyby(..., covmat=TRUE)` | Change per-species loop to multivariate formula call; expose vcov attribute | No new dependencies; work is interface design |
| Section-area-weighted lake total | Wrap | `survey::postStratify()` | Add area weight helper; apply postStratify before svytotal | Area weighting hook already in `add_sections()` |
| Temporal autocorrelation (daily) | Extend existing | `lme4` (already suggested) | Add day-level random effects to effort/catch models | Generalise aerial GLMM pattern to bus-route/instantaneous |
| Multi-year panel trend estimation | Build or extend | `lme4` + van Poorten & Lemp 2025 framework | Implement cross-sectional GLM following vP&L 2025 | No existing R wrapper for the exact panel approach |
| Mixed-effects extension for non-aerial | Extend existing | `lme4` (already suggested) | Generalise aerial GLMM to day-type × time-of-day for bus-route/instantaneous | Adapts existing code, no new dependencies |
| Closed-pop mark-recapture (Petersen, Schnabel) | Wrap | `FSA::mrClosed()` | Thin wrapper matching tidycreel output style | Pure R, no external binary |
| Jolly-Seber open-pop mark-recapture | Wrap | `FSA::mrOpen()` | Thin wrapper for standard JS; RMark for advanced POPAN | Pure R for basic JS |
| CJS / POPAN survival models | Wrap | `marked` (portable) or `RMark` (full power) | Verify `marked` POPAN coverage first; use `RMark` for full suite | RMark requires MARK.EXE on macOS/Linux |
| Exploitation rate from creel + tags | Build | (no clean existing wrapper) | Genuine build candidate or future standalone package | Niche estimator not covered by FSA or RMark |

---

## Section 6: Open Questions

The following unresolved questions are collected here for a future roadmap review session.

**Multi-species (Section 2):**

1. **Cross-species covariance under bus-route HT specifically:** The bus-route HT path constructs `.contribution = catch_i / pi_i` per interview. When each species has a different zero-inflation pattern per interview, it is unclear whether `survey::svytotal()` influence-function covariance handles this without a prototype. *Recommendation: Prototype in a notebook before committing to a joint-variance interface.*

2. **When is joint variance not meaningful?** If two species are never co-targeted (e.g., separate seasons), joint variance adds complexity for near-zero benefit. The interface should allow users to request it, not impose it automatically.

**Spatial (Section 3):**

3. **Area weighting vs. effort-proportional weighting:** The choice of section weights is fishery-specific. Both approaches are valid; the decision requires understanding whether angler use intensity is proportional to section area or concentrated in specific areas. *Recommendation: Research document presents both; the user provides the weight column.*

4. **What happens when section areas are missing?** `add_sections()` allows `area_ha` to be omitted. A section-weighted estimator must handle missing area information gracefully — either error with a clear message (cli_abort) or fall back to equal weighting with a warning.

**Temporal (Section 4a):**

5. **AR(1) vs. random day effects — data volume threshold:** For sparse survey designs (10–30 sampled days per season), is there enough data to identify AR(1) structure, or should the guidance default to random day effects? *Recommendation: Flag as design-data-volume question; document both approaches with their minimum data requirements.*

6. **Van Poorten & Lemp 2025 panel framework — implementation pathway:** The framework uses cross-sectional GLMs for trend estimation; the exact model specification requires access to the full paper. *Recommendation: Confirm exact model structure from the paper before design.*

**Mark-recapture (Section 4b):**

7. **`marked` package POPAN coverage:** The `marked` package is known for CJS models; whether it supports POPAN open-population estimation needs verification before recommending it as the primary CJS wrap target. *Recommendation: Check `marked` package documentation for POPAN model type.*

8. **Exploitation rate estimator formulation:** The Saha/Pollock creel-integrated exploitation rate estimator is the only mark-recapture target without a clean existing R implementation. A full formulation (likelihood, stratification by area/season, Bayesian extension) would be needed before implementation. *Recommendation: Obtain Saha thesis for statistical detail.*

---

## References

Askey, P. J., Benson, A., Post, J. R., Ward, H. G. M., & Sullivan, M. G. (2018). Angler effort estimates from instantaneous aerial counts: Use of high-frequency time-lapse camera data to inform model-based estimators. *North American Journal of Fisheries Management*, 38(3), 632–644. https://doi.org/10.1002/nafm.10010

Hansen, J. M., Schueller, A. M., Guy, C. S., & Ogle, D. H. (2018). A mark-recapture-based approach for estimating angler harvest. *North American Journal of Fisheries Management*, 38(4), 898–908. https://doi.org/10.1002/nafm.10038

Ogle, D. H. (2016). *Introductory Fisheries Analyses with R*. CRC Press. [FSA package: `mrClosed()`, `mrOpen()`, `capHistSum()`] https://cran.r-project.org/package=FSA

Laake, J. L. (2013). *RMark: An R Interface for Analysis of Capture-Recapture Data with MARK*. AFSC Processed Rep. 2013-01. https://cran.r-project.org/web/packages/RMark/RMark.pdf

Lumley, T. (2010). *Complex Surveys: A Guide to Analysis Using R*. Wiley. [survey package: `svytotal()`, `svyby()`, `postStratify()`] https://cran.r-project.org/web/packages/survey/survey.pdf

Malvestuto, S. P. (1996). Sampling the recreational fishery. In B. R. Murphy & D. W. Willis (Eds.), *Fisheries Techniques* (2nd ed., pp. 591–623). American Fisheries Society.

Pollock, K. H., Jones, C. M., & Brown, T. L. (1994). *Angler Survey Methods and Their Applications in Fisheries Management*. American Fisheries Society Special Publication 25.

Saha, S. *Mark-recapture creel survey and survival models* [Master's thesis, Old Dominion University]. ODU Digital Commons. https://digitalcommons.odu.edu/mathstat_etds/52/

van Poorten, B., & Lemp, P. (2025). Robust trend estimation from temporally irregular recreational fisheries surveys: A panel modeling framework for sparse time series. *Fisheries Management and Ecology*. https://doi.org/10.1111/fme.12816

Practical Significance blog (Lumley, T.). (n.d.). *Survey covariances using influence functions*. https://www.practicalsignificance.com/posts/survey-covariances-using-influence-functions/

---

*End of research document. All assessments and interface sketches are non-binding planning inputs for a future roadmap review session.*
