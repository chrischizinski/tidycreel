# Feature Research

**Domain:** Creel survey quality-of-life utility tools — schedule generation, power/sample-size analysis, and data quality diagnostics for an existing R estimation package
**Researched:** 2026-03-22
**Confidence:** HIGH (methodologies are well-established in fisheries literature and agency practice; formula sources are primary literature; tidycreel integration points confirmed from codebase inspection)

---

## Background: What This Milestone Is

tidycreel v0.8.0 shipped a complete estimation pipeline for five survey types. v0.9.0 adds the tools that wrap around the estimation pipeline: plan the survey before the season, check adequacy before the field crew leaves, and diagnose completeness and power after the season. These are quality-of-life tools, not new estimators.

The three workflow phases addressed:

| Phase | Question | Tools |
|-------|----------|-------|
| Pre-season planning | How many days do I need? Which days? Who goes where? | Calendar generator, CV calculators, bus-route scheduler, large-lake scheduler, design validator |
| Post-season QA | Did we collect enough? What is missing? | Data completeness checker, refusal rate threshold check |
| Reporting | What happened this season? | Season summary table |

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features that any agency creel biologist expects from a planning/QA toolkit. Missing these makes the milestone feel incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Sampling calendar generator — basic | Pre-season scheduling is the first task every biologist does; a tidy tibble of sampled days with weekday/weekend day-type codes and period IDs is the expected output | MEDIUM | Inputs: `start_date`, `end_date`, `n_weekdays` (or `pct_weekdays`), `n_weekends` (or `pct_weekends`), `n_periods`, optional `holidays` vector; output: tibble with `date`, `day_type`, `period_id`; ready to feed `creel_design()` |
| CSV / Excel export of schedule | Crew coordinators want a spreadsheet to email; biologists want a file to archive | LOW | Thin `write_schedule()` wrapper around `readr::write_csv()` and `writexl::write_xlsx()`; output format controlled by file extension |
| CV-target sample size calculator — effort | McCormick (2017) showed effort CV = 0.2 requires ~16 days (range 7–40); biologists quote CV targets in grant proposals and agency protocols | MEDIUM | Formula: `n = (s / (CV_target * mean))^2`; inputs: `pilot_mean`, `pilot_sd`, `cv_target` (default 0.20); output: named list with `n_required`, `achieved_cv_at_n`, `method = "effort_SRS"` |
| CV-target sample size calculator — CPUE | Same literature — CPUE requires ~43 days with the daily estimator (range 8–95); NOAA marine creel standard is CV = 0.10 | MEDIUM | Ratio estimator variance (Cochran 1977 eq. 6.13); inputs: `pilot_mean_effort`, `pilot_sd_effort`, `pilot_mean_catch`, `pilot_sd_catch`, `pilot_cor` (default 0), `cv_target`; returns `n_required` per season |
| Data completeness checker — missing sampling days | Post-season: which planned days have no interview or count records? Biologists discover missing data entries before reporting | LOW | Anti-join between schedule tibble and actual data (date × day_type × period); returns missing combinations; `cli_warn()` for each gap; consistent with existing `missing_sections` guard pattern (v0.7.0) |
| Refusal rate threshold check | `summarize_refusals()` exists (v0.5.0); a pass/fail wrapper that flags strata exceeding acceptable refusal rate is standard QA | LOW | Thin wrapper over existing `summarize_refusals()`; inputs: creel object, `threshold` (default 0.10); returns tibble with `stratum`, `refusal_rate`, `threshold`, `status` ("pass"/"warn"/"fail") |
| Season summary table | Wisconsin DNR, Minnesota DNR, and most agency reports produce a standard synopsis table: effort, catch/harvest/release by species, CPUE — pre-formatted for reports | MEDIUM | Assembles output of existing `estimate_effort()`, `estimate_catch_rate()`, `estimate_total_catch()`, `estimate_total_harvest()`, `estimate_total_release()` into a single wide tibble; does not re-estimate; columns: `species`, `stratum`, `effort_est`, `effort_se`, `n_interviews`, `catch_rate`, `catch_rate_se`, `total_catch`, `total_catch_se`, `total_harvest`, `total_harvest_se`, `total_release`, `total_release_se` |

### Differentiators (Competitive Advantage)

Features that go beyond what agencies currently script by hand, providing genuine time savings or analytical capability absent from competing tools (AnglerCreelSurveySimulation, creelr, legacy NGPC scripts).

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Bus-route scheduler | `AnglerCreelSurveySimulation` simulates but never generates a concrete routing plan; a function that produces an executable day-by-day circuit assignment that feeds directly into `creel_design(survey_type="bus_route")` is absent from CRAN | HIGH | Inputs: `access_points` (character vector), `sites_per_circuit`, `n_circuits`, `crew_size`, date scaffold from `creel_schedule()`, `seed`; output: tibble with `date`, `period`, `circuit_id`, `site_id`, `crew_id`, `inclusion_prob`; `inclusion_prob` feeds `creel_design()` directly |
| Large-lake multi-section scheduler | Large lakes (> 10,000 ha) require paired-crew allocation across sections with guaranteed minimum coverage per section; no CRAN package automates this with section-aware output | HIGH | Inputs: section registry from `add_sections()`, `access_points_per_section`, `crew_size`, date scaffold, `seed`; output: schedule tibble with `section_id`, `date`, `period`, `crew_id`; validates that each section achieves minimum sampled days |
| Design validator — pre-season | Cross-checks a proposed schedule against stated CV targets before any field work begins; produces a structured go/no-go report | MEDIUM | Calls `creel_n_effort()` and `creel_n_cpue()` internally; inputs: schedule tibble, `pilot_mean`, `pilot_sd`, `cv_target`; output: tibble per stratum with `n_proposed`, `n_required_effort`, `n_required_cpue`, `status` ("pass"/"warn"/"fail"); mirrors existing `validate_incomplete_trips()` design |
| Change detection / power calculator | Whether current survey intensity has power to detect a management-relevant % change in CPUE or effort between two seasons; analytically absent from all existing creel tools | MEDIUM | Two-sample t-test approach (Schmitt 2001, Lester et al. 1991, Georgia DNR 2025): Cohen's d = delta / sigma_pooled; wraps `stats::power.t.test()`; inputs: `baseline_mean`, `baseline_sd`, `pct_change` (e.g., 0.25), `alpha` (default 0.05), `desired_power` (default 0.80); outputs: `n_required`, `power_at_current_n`, `n_current` |
| Low-sample strata flag in completeness checker | Post-season: strata with fewer than a minimum interview count inflate variance and may need collapsing; not detectable from raw data without the planned schedule | LOW | Extension of missing-days check; joins interview counts per stratum cell against `min_interviews` threshold (default = 3); returns `n_interviews`, `n_threshold`, `pass` columns per stratum |
| Neyman-optimal stratum allocation helper | Given pilot variance estimates per day-type stratum, recommends optimal weekday/weekend day allocation — commonly needed but rarely automated in creel workflows | MEDIUM | Formula: `n_h = n × (N_h × s_h) / sum(N_j × s_j)` (Neyman 1934); inputs: strata size vector `N_h` (computed from date range), pilot SD vector `s_h`, total budget `n`; output: named vector of recommended days per stratum |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Full report rendering (PDF/Word/Rmd) | Biologists want one-button NGPC-style report | Requires `rmarkdown`/`officer` dependency; template is opinionated and varies by agency; breaks when users rename columns; maintenance burden is high | Produce the `season_summary()` tibble; let users render with their own template; pair with `write_schedule()` for CSV output |
| Automatic pilot data extraction from current season | Compute pilot mean/SD from the loaded creel object to avoid requiring the user to supply them | Circular: using the same season's data to size the same season's sample produces invalid CV estimates; hides the epistemological problem from the user | Require explicit `pilot_mean` and `pilot_sd` arguments; return a clear error if omitted; document that previous-season estimates are the correct input |
| Full Monte Carlo simulation of survey performance | `AnglerCreelSurveySimulation` does this already; users sometimes ask tidycreel for the same | Requires deep fishery parameters (trip length distribution, angler arrival rate) not stored in the creel object; duplicates an existing CRAN tool; slow | Analytical power formula via `power.t.test()` is sufficient and fast for the common management question; document that `AnglerCreelSurveySimulation` handles the Monte Carlo case |
| Interactive Shiny scheduler | Point-and-click calendar UI | Out of scope for an estimation package; substantial maintenance burden; breaks R CMD check conventions for CRAN submission | Tidy tibble output is pipe-friendly; pairs naturally with any Shiny app the user builds independently |
| Automatic holiday detection by jurisdiction | Detect state-specific holidays for weekday/weekend re-classification | Holiday rules vary by state and change annually; no authoritative R package covers all US state holidays reliably | Accept `holidays` as a user-supplied `Date` vector; document `timeDate` or `bizdays` as optional helpers for generating it |
| Optimization solver for survey allocation | Use LP/IP solver to minimize cost subject to CV constraint | Overkill for typical creel survey scales (weeks, not thousands of strata); adds `ROI` or `lpSolve` dependency; Neyman allocation is sufficient for two-stratum weekday/weekend designs | Implement Neyman allocation helper; document its assumptions; flag LP solvers in vignette for multi-stratum power users |

---

## Feature Dependencies

```
[creel_schedule()]  ── date scaffold ──> [schedule_bus_route()]
                    ── date scaffold ──> [schedule_large_lake()]
                    ── date scaffold ──> [validate_design()]
                    ── reference set ──> [check_completeness()]

[creel_n_effort()]  ──────────────────> [validate_design()]  (called internally)
[creel_n_cpue()]    ──────────────────> [validate_design()]  (called internally)

[existing add_sections()]  ───────────> [schedule_large_lake()]  (section registry is the input)
[existing creel_design()]  ───────────> [schedule_bus_route() output]  (schedule feeds creel_design)
[existing summarize_refusals()]  ─────> [check_refusal_threshold()]  (thin wrapper; no re-computation)
[existing estimate_*() functions]  ───> [season_summary()]  (assembles outputs; no re-estimation)

[check_completeness()]
    └──enhances──> [low-sample strata flag]  (same function, two diagnostics)

[creel_n_effort() / creel_n_cpue()]
    └──feeds into──> [creel_power()]  (power calc uses same variance inputs; different question)
    └──independent of──> [creel_power()]  (n sizing vs. trend detection are separate concerns)
```

### Dependency Notes

- **`creel_schedule()` is the foundation:** All pre-season tools (bus-route scheduler, large-lake scheduler, design validator) and all post-season diagnostics (completeness checker) need the planned schedule as a reference tibble. This is phase 1 of any v0.9.0 implementation.
- **CV calculators are prerequisites for the design validator:** The validator is "run the CV calculator per stratum and compare proposed n against required n." It must call `creel_n_effort()` / `creel_n_cpue()` internally rather than re-implementing the formula.
- **`add_sections()` (v0.7.0) feeds the large-lake scheduler:** The scheduler respects registered section boundaries and generates per-section crew assignments. The section registry from the creel object is the canonical input.
- **Season summary is an assembly layer, not a new estimator:** It consumes the output of all existing `estimate_*()` functions. It must not re-estimate. This keeps the season summary consistent with whatever variance formula the user selected.
- **Refusal rate threshold check wraps `summarize_refusals()` (v0.5.0):** Do not recompute refusal rates; call the existing function and add a threshold comparison. Keeps logic in one place and eliminates drift between implementations.
- **Low-sample strata flag and missing-days check are bundled:** Both are post-season diagnostics that examine the same reference schedule against the same data. A single `check_completeness()` function should return both diagnostics rather than requiring two separate calls.

---

## MVP Definition

### Launch With (v0.9.0)

Minimum set that delivers end-to-end value: plan a survey, check it pre-season, diagnose it post-season, produce the report table.

- [ ] `creel_schedule()` — sampling calendar generator; without this, downstream tools have no date scaffold
- [ ] `creel_n_effort()` — CV-target sample size for effort; most-requested planning calculation; McCormick (2017) provides the formula directly
- [ ] `creel_n_cpue()` — CV-target sample size for CPUE; paired with effort calculator; distinct formula
- [ ] `validate_design()` — pre-season go/no-go check; depends only on the two calculators above
- [ ] `check_completeness()` — post-season QA; covers missing days + low-sample strata in one call
- [ ] `season_summary()` — assembles existing estimate outputs into a report-ready wide tibble; delivers the table biologists produce every season

### Add After Validation (v0.9.x)

- [ ] `schedule_bus_route()` — higher complexity; validate that calendar and design validator are useful before investing in routing detail
- [ ] `creel_power()` — analytically distinct from CV sizing; add once sample-size tools are confirmed in use
- [ ] `write_schedule()` — trivial to add; defer until schedule tibble format is stable from user feedback
- [ ] `check_refusal_threshold()` — one-liner wrapper; add alongside `check_completeness()` in practice

### Future Consideration (v1.0+)

- [ ] `schedule_large_lake()` — highest complexity; needs section workflows and design validator in active use first
- [ ] Neyman stratum allocation helper — technically straightforward but requires pilot variance estimates that many users will not have from a new fishery; defer until base planning tools prove adoptable

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| `creel_schedule()` — calendar generator | HIGH | MEDIUM | P1 |
| `creel_n_effort()` — CV sample size, effort | HIGH | MEDIUM | P1 |
| `creel_n_cpue()` — CV sample size, CPUE | HIGH | MEDIUM | P1 |
| `validate_design()` — pre-season check | HIGH | MEDIUM | P1 |
| `check_completeness()` — missing days + thin strata | HIGH | LOW | P1 |
| `season_summary()` — report table | HIGH | MEDIUM | P1 |
| `schedule_bus_route()` — circuit scheduler | HIGH | HIGH | P2 |
| `creel_power()` — change detection power | MEDIUM | MEDIUM | P2 |
| `write_schedule()` — CSV/Excel export | MEDIUM | LOW | P2 |
| `check_refusal_threshold()` — refusal QA | MEDIUM | LOW | P2 |
| Neyman stratum allocation helper | MEDIUM | MEDIUM | P3 |
| `schedule_large_lake()` — multi-section scheduler | HIGH | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

| Feature | AnglerCreelSurveySimulation (CRAN, updated May 2024) | creelr (Poisson Consulting) | Legacy NGPC Scripts | Our Approach |
|---------|-----------------------------------------------------|------------------------------|---------------------|--------------|
| Schedule generation | None — simulation only; no concrete date plan | None | Manual Excel calendars | Tidy tibble; pipe into `creel_design()` |
| CV / sample size calculator | RSE from repeated Monte Carlo simulations — indirect | None | Rule of thumb (16 days) | Explicit analytical formula; returns tibble with target vs. achieved |
| Bus-route scheduling | Simulates roving surveys; no executable routing plan | None | Manual day-of assignments | Circuit + site + crew assignment tibble with `inclusion_prob` columns |
| Pre-season design validation | Evaluate RSE by running hundreds of simulations | None | None | Single-call `validate_design()` against CV target |
| Change detection / power | None | None | None | `creel_power()` wrapping `power.t.test()`; uses creel vocabulary (% change in CPUE) |
| Post-season completeness check | None | None | Ad hoc SQL queries against DB | `check_completeness()` anti-joins schedule vs. data; structured pass/fail output |
| Season summary table | None | Partial (Bayesian estimates only) | Rmd template tightly coupled to DB | `season_summary()` assembles existing `estimate_*()` outputs; DB-agnostic |
| Tidy API | No | Partial | No | Yes — core value proposition |

---

## Methodological Notes

### CV and Sample Size Formulas

**For effort** (simple random sampling within stratum — the common case before stratification):

```r
# Cochran (1977) §2.2; McCormick (2017) NAJFM 37:970-980
n_required <- ceiling((pilot_sd / (cv_target * pilot_mean))^2)
```

For stratified weekday/weekend designs, compute per-stratum and combine using Neyman or proportional allocation. McCormick (2017) benchmarks: CV = 0.20 (95% CI = ±40%) requires mean of 16 days for effort, 43 days for CPUE with the daily estimator. NOAA marine creel programs target CV = 0.10.

**For CPUE** (ratio estimator variance, Cochran 1977 eq. 6.13):

```r
# R_hat = C_bar / E_bar  (ratio of means — ROM estimator)
# Var(R_hat) ≈ (1/E_bar^2) * [Var(C) + R^2 * Var(E) - 2*R*Cov(C,E)]
# Simplification with correlation rho:
# Var(R_hat) ≈ (R^2 / n) * [CV_C^2 + CV_E^2 - 2*rho*CV_C*CV_E]
# Solve for n given CV_R target:
n_required <- ceiling(
  (pilot_cpue^2 * (cv_effort^2 + cv_catch^2 - 2*pilot_cor*cv_effort*cv_catch)) /
  cv_target^2
)
```

Inputs: `pilot_mean_effort`, `pilot_sd_effort`, `pilot_mean_catch`, `pilot_sd_catch`, `pilot_cor` (correlation between daily catch and effort; default 0 is conservative).

### Power / Change Detection Formula

Two-sample t-test is the standard approach in fisheries monitoring programs (Schmitt 2001; Lester et al. 1991; Georgia DNR 2025 NAJFM):

```r
# Cohen's d for a pct_change change from baseline
delta      <- baseline_mean * pct_change
cohen_d    <- delta / baseline_sd          # pooled SD assumed equal
result     <- stats::power.t.test(
  n          = NULL,          # solve for n
  delta      = delta,
  sd         = baseline_sd,
  sig.level  = alpha,         # default 0.05
  power      = desired_power, # default 0.80
  type       = "two.sample"
)
n_required <- ceiling(result$n)
```

The `pwr` package (`pwr::pwr.t.test()`) provides the same calculation with Cohen's d as direct input and is the preferred implementation to avoid replicating the non-central t distribution internally. Important calibration from literature: most reservoirs reach power = 0.80 at a 50% decline in CPUE over 10 years; detecting a 25% change typically requires > 10 seasons of data given the high natural variability inherent in recreational fishery CPUE.

### Design Validation Logic

Pre-season check algorithm:

1. Parse proposed schedule tibble into per-stratum counts (`n_weekday`, `n_weekend` per period).
2. Call `creel_n_effort()` and `creel_n_cpue()` with user-supplied pilot parameters.
3. Compare `n_proposed` vs. `n_required` per stratum.
4. Return tibble: `stratum | n_proposed | n_required_effort | n_required_cpue | cv_target | status`.
5. Status codes: `"pass"` (n_proposed >= max(n_required_effort, n_required_cpue)), `"warn"` (n_proposed >= 0.75 × required), `"fail"` (n_proposed < 0.75 × required).
6. Issue `cli_warn()` for each "fail" stratum; consistent with existing guard patterns.

### Post-Season Completeness Check

Two diagnostics in one `check_completeness()` call:

1. **Missing days:**
   ```r
   missing <- dplyr::anti_join(schedule, data, by = c("date", "day_type", "period_id"))
   ```
   Returns rows in the planned schedule with no corresponding records in the actual data. Issues `cli_warn()` per missing combination.

2. **Low-sample strata:**
   ```r
   counts <- dplyr::count(data, date, day_type, period_id, name = "n_interviews")
   thin   <- dplyr::left_join(schedule, counts) |>
             dplyr::filter(is.na(n_interviews) | n_interviews < min_interviews)
   ```
   Default `min_interviews = 3` per stratum cell (below which variance estimates are unreliable).

Both diagnostics mirror the `missing_sections` guard pattern established in v0.7.0: return a diagnostic tibble, issue `cli_warn()`, never silently drop data.

### Season Summary Table Structure

Standard structure matching Wisconsin DNR, Minnesota DNR, and NGPC report conventions (confirmed from agency reports 2024–2025):

```
species | stratum | effort_est | effort_se | n_interviews |
catch_rate | catch_rate_se | total_catch | total_catch_se |
total_harvest | total_harvest_se | total_release | total_release_se
```

`season_summary()` joins the outputs of:
- `estimate_effort()` → effort columns
- `estimate_catch_rate()` → catch_rate columns
- `estimate_total_catch()` → total_catch columns
- `estimate_total_harvest()` → total_harvest columns
- `estimate_total_release()` → total_release columns

Join keys: `species × stratum`. Does not re-estimate. Returns `NA` gracefully where a species has no catch/harvest/release data (e.g., a count-only period). This is an assembly function, not an estimator.

### Bus-Route Scheduler Design

The scheduler must produce `inclusion_prob` values compatible with `creel_design(survey_type = "bus_route")`, which uses `pi_i = p_site × p_period` (Jones & Pollock 2012; confirmed correct in v0.4.0):

```r
# p_site    = n_circuits_sampled / n_circuits_total per period
# p_period  = n_periods_sampled / n_periods_total per day
# inclusion_prob = p_site * p_period per site × period combination
```

The scheduler allocates circuits to sampled days using a randomized complete block design (RCB): within each day, circuits are randomly assigned to available time periods. The randomization seed ensures reproducibility for both scheduling and any simulation-based review. Output includes `p_site` and `p_period` so the user can verify the inclusion probabilities before passing to `creel_design()`.

---

## Sources

- [McCormick, J. L. & Quist, M. C. (2017). Sample Size Estimation for On-Site Creel Surveys. *North American Journal of Fisheries Management* 37(5):970–980](https://afspubs.onlinelibrary.wiley.com/doi/full/10.1080/02755947.2017.1342723)
- [AnglerCreelSurveySimulation CRAN vignette — Simulating Creel Surveys](https://cran.r-project.org/web/packages/AnglerCreelSurveySimulation/vignettes/creel_survey_simulation.html)
- [Evaluation of bus-route creel survey method in a large Australian marine recreational fishery I: Survey design](https://www.sciencedirect.com/science/article/abs/pii/S0165783697000684)
- [Evaluation of bus-route creel survey method II: Pilot surveys and optimal sampling allocation](https://www.sciencedirect.com/science/article/abs/pii/S0165783697000672)
- [Estimating power of standardized monitoring program for sport fish in Georgia, USA — *NAJFM* 2025](https://doi.org/10.1093/najfmt/vqaf117)
- [Power and Sample Size Estimation Techniques for Fisheries Management — ResearchGate](https://www.researchgate.net/publication/233445683_Power_and_Sample_Size_Estimation_Techniques_for_Fisheries_Management_Assessment_and_a_New_Computational_Tool)
- [Optimizing Creel Surveys — Springer Nature Link 2025](https://link.springer.com/chapter/10.1007/978-3-031-99739-6_13)
- [Alaska DFG Special Publication 98-1: The Mechanics of Onsite Creel Surveys](https://www.adfg.alaska.gov/fedaidpdfs/sp98-01.pdf)
- [Using balanced sampling in creel surveys — Statistics Canada, *Survey Methodology* 2018](https://www150.statcan.gc.ca/n1/pub/12-001-x/2018002/article/54954/01-eng.htm)
- Cochran, W. G. (1977). *Sampling Techniques* (3rd ed.). Wiley. — ratio estimator variance formula (eq. 6.13); Neyman allocation (§5.5)
- Pollock, K. H., Jones, C. M., Brown, T. L. (1994). *Angler Survey Methods and their Applications in Fisheries Management*. AFS Special Publication 25. — foundational reference for bus-route inclusion probabilities already implemented in tidycreel v0.4.0
- Jones, C. M. & Pollock, K. H. (2012). Recreational survey methods. In Zale et al. (eds.), *Fisheries Techniques* 3rd ed., AFS, pp. 883–919. — pi_i = p_site × p_period confirmed correct
- [pwr package CRAN documentation](https://cran.r-project.org/web/packages/pwr/pwr.pdf) — `pwr.t.test()` for two-sample power calculations
- Wisconsin DNR open-water creel survey reports 2024–2025 — season summary table structure confirmed from multiple reports

---

*Feature research for: tidycreel v0.9.0 — survey planning, power analysis, and data quality tools*
*Researched: 2026-03-22*
