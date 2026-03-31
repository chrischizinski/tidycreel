# Stack Research

**Domain:** R package — creel survey utility tools (schedule generation, power/sample size, data completeness)
**Researched:** 2026-03-22
**Confidence:** HIGH (all packages verified on CRAN; versions confirmed from official sources)

## Context: Existing Imports (do NOT re-add)

Already in `DESCRIPTION` Imports — zero additions needed for these:

| Package | Role in tidycreel |
|---------|-------------------|
| checkmate | Input validation |
| cli | User-facing messages and warnings |
| dplyr | Tidy data manipulation |
| rlang | NSE / tidy eval |
| scales | Formatting helpers |
| stats | Base R stats (used for variance math) |
| survey | All design-based inference |
| tibble | Tibble construction |
| tidyselect >= 1.2.0 | Tidy column selectors |

---

## Recommended Stack: New Additions Only

### Schedule Generation and Export

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| lubridate | >= 1.9.5 | Date arithmetic for calendar generators and bus-route schedulers | `seq()` with `by = "week"` works on base R Dates, but lubridate adds `wday()`, `yday()`, period arithmetic, and DST-safe interval math needed for season-spanning schedules. Standard tidyverse date layer. Published 2026-02-04 on CRAN. |
| writexl | >= 1.5.4 | Export sampling schedules to .xlsx | Zero C/Java dependencies (pure libxlsxwriter binding). Fastest CRAN Excel writer. Single function `write_xlsx()` for named-sheet list output. No Rtools required on Windows. Published 2025-04-15. Adds 0 transitive R dependencies. |

**Why writexl over openxlsx2:** openxlsx2 v1.21 is powerful but pulls in `R6`, `stringi`, and `zip` as hard imports — three packages tidycreel doesn't otherwise need. writexl covers the schedule export use case (write tidy tibbles to xlsx) with no dependencies and 2x faster writes. Choose openxlsx2 only if rich cell-level formatting (colors, merged cells, conditional formatting) is required for the schedule output — it is not for a sampling calendar.

**Why writexl over the original openxlsx:** openxlsx is no longer actively maintained (maintainer recommends migrating to openxlsx2 or writexl).

### Power and Sample Size Analysis

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| (no new import) | — | CV-target and change-detection calculations | Implement analytically using existing `stats` import — see rationale below |

**Rationale — implement analytically, no new dependency:**

Creel survey power calculations are narrow and well-defined by two formulas from the peer-reviewed literature:

1. **CV-target sample size** (McCormick and Quist 2017): `n = (z_alpha * CV_population)^2 / CV_target^2` where `CV_population` is estimated from pilot data or historical records. All inputs are scalars; the calculation uses only `stats::qnorm()` and `stats::qt()`, already available via the `stats` import.

2. **Change detection (two-period t-test on log-transformed CPUE):** `n = 2 * ((z_alpha + z_beta) / log(1 + delta))^2 * sigma^2` — again pure `stats`.

The `pwr` package (Cohen 1988 effect sizes) does not speak creel vocabulary (effort CV, CPUE change percentage) and would require the user to translate domain inputs into Cohen's d — adding cognitive burden rather than removing it. `samplesize4surveys` v4.1.1 was last updated 2020-01-17 and targets social survey designs (proportions, means under stratified SRS); its design assumptions do not align with the HT estimators in tidycreel.

`AnglerCreelSurveySimulation` v1.0.3 (updated 2024-05-14) is the closest domain match but is simulation-based, adds `ggplot2` as a hard dependency, and is scoped to bus-route designs only. It belongs in `Suggests` if simulation-based power is exposed as an optional vignette, not in `Imports`.

**Recommendation:** Implement `creel_power()` and `creel_sample_size()` as internal analytical functions using only `stats`. This gives users creel-vocabulary inputs (CV target, % change, alpha, power) with no new dependency weight.

**If simulation-based power is later prioritized:** add `AnglerCreelSurveySimulation` to `Suggests` and call it conditionally.

### Data Completeness Diagnostics

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| (no new import) | — | Missing-data and completeness checks | Implement as tidy summaries using existing dplyr + cli imports — see rationale below |

**Rationale — implement as tidy summaries, no new dependency:**

The completeness checks needed for creel surveys are domain-specific:
- Missing count observations for a sampled period-section combination
- Interview records with no matching catch rows
- Days in the season with zero periods sampled
- Camera records with gap-spanning entries exceeding threshold

These are all expressible as `dplyr::anti_join()` + `dplyr::summarise()` + `cli::cli_warn()` — all packages already in Imports.

**`pointblank` v0.12.3 is NOT recommended for Imports.** It brings 19 hard imports including `gt`, `htmltools`, `blastula`, `dbplyr`, `fs`, and `yaml` — packages that are unrelated to tidycreel's estimation pipeline. CRAN packages with 19+ Imports receive a NOTE from `R CMD check` advising to move packages to Suggests. Adding pointblank to Imports would triple tidycreel's dependency footprint for what amounts to `is.na()` checks achievable in dplyr.

**`validate` v1.1.7** (updated 2025-12-10) is lighter (5 imports: stats, graphics, grid, settings, yaml) and produces structured rule-violation reports. It is acceptable in `Suggests` if a formal validation report workflow is added later. Do not put it in `Imports` — its rule DSL is overkill for tidycreel's targeted completeness functions.

---

## Summary of Net New Imports

| Package | Version | Add To | New Transitive Dependencies |
|---------|---------|--------|----------------------------|
| lubridate | >= 1.9.5 | Imports | generics, timechange (2 small packages) |
| writexl | >= 1.5.4 | Imports | 0 |

Total new hard imports: **2 packages**. Both are widely deployed tidyverse-ecosystem packages with stable APIs and active maintenance.

---

## Supporting Libraries (Suggests only)

| Library | Version | Purpose | Condition |
|---------|---------|---------|-----------|
| AnglerCreelSurveySimulation | >= 1.0.3 | Simulation-based power vignette | Only if simulation power path is built |
| validate | >= 1.1.7 | Structured completeness report output | Only if formal HTML validation reports are added |

---

## Installation

```r
# Add to DESCRIPTION Imports:
# lubridate (>= 1.9.5)
# writexl (>= 1.5.4)

# Install for development:
install.packages(c("lubridate", "writexl"))
```

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| writexl | openxlsx2 | Pulls in R6 + stringi + zip; rich formatting not needed for schedule export |
| writexl | openxlsx | No longer actively maintained; maintainer recommends writexl or openxlsx2 |
| analytical stats:: formulas | pwr package | Cohen's d vocabulary does not match creel domain inputs (CV, % change) |
| analytical stats:: formulas | samplesize4surveys 4.1.1 | Last updated 2020; social survey design assumptions; TeachingSampling dependency |
| dplyr + cli (existing) | pointblank | 19 hard imports; triples dependency footprint for is.na() logic |
| dplyr + cli (existing) | validate in Imports | Structured DSL unnecessary; adds yaml/settings for simple NA checks |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| openxlsx (original) | Unmaintained; maintainer deprecated in favor of openxlsx2 or writexl | writexl for export-only; openxlsx2 if formatting required |
| pointblank (in Imports) | 19 required imports including gt, htmltools, blastula — unrelated to estimation pipeline | dplyr::anti_join() + cli::cli_warn() for targeted completeness checks |
| samplesize4surveys | Last updated 2020; hard dependency on TeachingSampling; social survey focus | Custom analytical functions using stats::qnorm() / stats::qt() |
| pwr | General-purpose effect-size package; user must translate creel vocabulary to Cohen's d | Custom functions with creel-native parameters (CV_target, pct_change, alpha, power) |

---

## Stack Patterns by Feature Area

**If schedule export is CSV-only:**
- Drop writexl from Imports entirely
- `utils::write.csv()` is base R, zero dependency

**If rich Excel formatting is required (e.g., color-coded day-type columns):**
- Use openxlsx2 >= 1.21 in Imports instead of writexl
- Accept R6 + stringi + zip as transitive dependencies

**If simulation-based power analysis is a first-class feature:**
- Add AnglerCreelSurveySimulation >= 1.0.3 to Imports (not Suggests)
- Accept ggplot2 as transitive dependency

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| lubridate 1.9.5 | R >= 3.2, timechange >= 0.4.0 | timechange is a small C package; no issues with tidycreel's R >= 4.1.0 requirement |
| writexl 1.5.4 | R >= 3.0 | Pure C binding; no Java; works on all platforms including Windows without Rtools |
| lubridate 1.9.5 | dplyr (existing) | No conflicts; lubridate and dplyr are designed to interoperate |

---

## Sources

- [CRAN: writexl](https://cran.r-project.org/web/packages/writexl/index.html) — version 1.5.4, published 2025-04-15. HIGH confidence.
- [CRAN: lubridate](https://cran.r-project.org/web/packages/lubridate/index.html) — version 1.9.5, published 2026-02-04. HIGH confidence.
- [CRAN: openxlsx2](https://cran.r-project.org/web/packages/openxlsx2/index.html) — version 1.21, published Nov 2025. MEDIUM confidence (version from rdrr.io).
- [CRAN: pointblank](https://cran.r-project.org/web/packages/pointblank/index.html) — version 0.12.3, published 2025-11-28; 19 hard imports confirmed. HIGH confidence.
- [CRAN: validate](https://cran.r-project.org/web/packages/validate/index.html) — version 1.1.7, published 2025-12-10; 5 imports. HIGH confidence.
- [CRAN: samplesize4surveys](https://cran.r-project.org/web/packages/samplesize4surveys/index.html) — version 4.1.1, published 2020-01-17; stale. HIGH confidence.
- [CRAN: AnglerCreelSurveySimulation](https://cran.r-project.org/web/packages/AnglerCreelSurveySimulation/index.html) — version 1.0.3, published 2024-05-14; bus-route only, adds ggplot2. HIGH confidence.
- [McCormick and Quist 2017, NAJFM](https://afspubs.onlinelibrary.wiley.com/doi/full/10.1080/02755947.2017.1342723) — CV-target and change-detection sample size formulas for creel surveys; confirms analytical formula approach. MEDIUM confidence (abstract).
- [AnglerCreelSurveySimulation vignette](https://cran.r-project.org/web/packages/AnglerCreelSurveySimulation/vignettes/creel_survey_simulation.html) — simulation-based power approach confirmed; bus-route scope confirmed. HIGH confidence.
- [rOpenSci writexl announcement](https://ropensci.org/blog/2017/09/08/writexl-release/) — zero-dependency rationale; C implementation benchmark confirmed. HIGH confidence.

---
*Stack research for: tidycreel v0.9.0 utility tools (schedule generation, power/sample size, data completeness)*
*Researched: 2026-03-22*
