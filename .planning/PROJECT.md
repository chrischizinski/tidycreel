# tidycreel

## What This Is

tidycreel is an R package providing a tidy, pipe-friendly interface for creel survey design, data management, estimation, and reporting. Built on the `survey` package for robust design-based inference, it lets fisheries biologists work in domain vocabulary — dates, strata, counts, effort, catch, species — without managing survey design internals directly. The package targets creel biologists using Nebraska Game and Parks' SQL Server creel database (accessible via REST API or direct connection) and anyone with similarly structured interview/catch/length data.

## Core Value

Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- ✓ `creel_design()` — single entry point for survey design with tidy selectors — v0.1.0
- ✓ `add_counts()` — attach instantaneous count observations with validation — v0.1.0
- ✓ `estimate_effort()` — total and grouped effort with Taylor/bootstrap/jackknife variance; section dispatch with correlated-domain aggregation — v0.1.0–v0.7.0
- ✓ `add_interviews()` — attach party-level interview data (catch, effort, harvest, trip metadata) — v0.2.0
- ✓ `estimate_catch_rate()` — catch rate via ratio-of-means or mean-of-ratios; section-aware (no lake total, rates not additive) — v0.2.0 *(renamed from `estimate_cpue()` in v0.7.0)*
- ✓ `estimate_harvest_rate()` — harvest rate from interview data; section-aware — v0.2.0 *(renamed from `estimate_harvest()` in v0.7.0)*
- ✓ `estimate_release_rate()` — release rate; section-aware — v0.5.0
- ✓ `estimate_total_catch()` / `estimate_total_harvest()` / `estimate_total_release()` — totals with delta method variance; section dispatch with sum(TC_i) lake total — v0.2.0–v0.7.0
- ✓ `validate_incomplete_trips()` — TOST equivalence testing for incomplete vs complete trips — v0.3.0
- ✓ `summarize_trips()` — trip status, duration, completeness — v0.3.0
- ✓ Bus-route survey support — correct πᵢ = p_site × p_period, enumeration expansion, HT estimators — v0.4.0
- ✓ Bus-route accessors: `get_sampling_frame()`, `get_inclusion_probs()`, `get_enumeration_counts()`, `get_site_contributions()` — v0.4.0
- ✓ `add_catch()` — long-format species-level catch data with tidy selectors and validation — v0.5.0
- ✓ `add_lengths()` — individual and binned fish length data with auto-format detection — v0.5.0
- ✓ Seven interview-level unextrapolated summary functions (`summarize_refusals()`, `summarize_by_day_type()`, etc.) — v0.5.0
- ✓ `summarize_cws_rates()` / `summarize_hws_rates()` — caught/harvested-while-sought rates — v0.5.0
- ✓ `summarize_length_freq()` — length frequency distributions — v0.5.0
- ✓ Species-level grouping in all estimation functions — v0.5.0
- ✓ Multiple counts per PSU — count_time_col, within-day aggregation, Rasmussen two-stage variance (se_between/se_within) — v0.6.0
- ✓ Progressive count estimator — circuit_time, Ê_d computation — v0.6.0
- ✓ `add_sections()` — spatial section registration with validation — v0.7.0
- ✓ Section dispatch for all estimators — SECT-01..05, RATE-01..03, PROD-01..02 — v0.7.0
- ✓ `missing_sections` guard — NA row + cli_warn() for registered sections absent from data — v0.7.0
- ✓ `example_sections_*` datasets and section-estimation vignette — v0.7.0

### Active (v0.8.0 — Non-Traditional Creel Designs)

<!-- Aerial, remote camera, and ice fishing survey support — to be defined during milestone planning. -->

- [ ] Aerial survey support — effort/angler estimation from air (plane/drone)
- [ ] Remote camera survey support — access-point counts and/or continuous effort at a site
- [ ] Ice fishing survey support — fixed-location angler design, statistically characterized
- [ ] All three extend `creel_design()` as the single entry point

### Out of Scope

- Real-time/online data pull from creel API — package is data-model agnostic; users pull data themselves
- Aerial survey support (area_ha / shoreline_km used in estimation) — deferred, not yet scoped
- Geographic summaries (zip/county tabulation via external lookup) — deferred
- Full report rendering (Rmd/PDF template reproducing NGPC report structure) — deferred
- Supplemental question tabulation — deferred

## Current Milestone: v0.8.0 Non-Traditional Creel Designs

**Goal:** Extend tidycreel to support aerial, remote camera, and ice fishing survey designs within the existing `creel_design()` entry point and three-layer architecture.

**Target features:**
- Aerial surveys — effort estimation from plane/drone angler counts
- Remote camera surveys — access-point ingress/egress counts and continuous site-level effort
- Ice fishing surveys — fixed-location angler design with statistically appropriate estimators

## Current State (v0.7.0 — shipped 2026-03-15)

**Package status:** 7 milestones shipped, 43 phases, 84 plans, 1588 tests passing
**Stack:** R package, survey package for all design-based inference, tidy API with tidyselect
**Architecture:** Three-layer (API → Orchestration → Survey) proven through spatially stratified designs
**Next milestone:** v0.8.0 — TBD (run `/gsd:new-milestone` to define)

## Context

### Data Model (from Nebraska creel database)

The creel database has three analysis tables used by tidycreel:

**interviews** (`vwCombinedR_InterviewData_wSupplemental`) — one row per angling party:
- `cd_Date`, `cd_Period`, `cd_Section` — when/where
- `ii_Refused` — refused interview flag
- `ii_NumberAnglers` — party size
- `ii_AnglerType` — bank (1) or boat (2) — code table
- `ii_AnglerMethod` — fishing method — code table
- `ii_TimeFishedHours` / `ii_TimeFishedMinutes` — effort
- `ii_TripType` — complete/incomplete — code table
- `ii_SpeciesSought` — target species — code table
- `ii_ZipCode` — angler origin
- `ii_UID` — interview unique key
- Supplemental question columns

**catch** (`vwCombinedR_CatchData`) — one row per species per interview:
- `ii_UID` — links to interview
- `ir_Species` — species code
- `Num` — count
- `CatchType` — caught / harvested / released

**harvest_lengths** (`vwCombinedR_HarvestLengthData`) — one row per fish:
- `ii_UID`, `ih_Species`, `ihl_Length`

**release_lengths** (`vwCombinedR_ReleasedLengthData`) — by length group:
- `ii_UID`, `ir_Species`, `ir_LengthGroup`, `ir_Count`
- Note: may also have individual lengths depending on creel; handle both formats

### Existing Reference Code

- `/Users/cchizinski2/Documents/git2/creel/` — legacy R scripts using SQL Server and REST API
- `CreelApiHelper.R` — REST API endpoints
- `CreelDataAccess.R` / `CreelDataAccess_CJCedits.R` — data access layer
- `CreelAnalysisFunctionsCJCEDits.R` — full legacy analysis pipeline
- `spawn report.Rmd` / `StandardReportTemplate mattWorkspace.Rmd` — existing report templates

### Report Structure (from examples/ PDFs)

Reports have 3 sections: (1) Design Parameters, (2) Unextrapolated Summaries, (3) Extrapolated Estimates. The package currently produces (3). v0.5.0 adds the data model to support (2).

### Architecture

Three-layer: API → Orchestration → Survey package. The dispatch pattern (check survey_type and data availability before survey package calls) is established and working across instantaneous and bus-route designs.

## Constraints

- **R package**: Must pass R CMD check with 0 errors, 0 warnings, clean lintr
- **survey package**: All design-based inference goes through `survey::` — no custom variance formulas
- **tidy API**: Tidy selectors (tidyselect) for all column references, never character strings
- **Test coverage**: Maintain ~90%+ test coverage (currently 1,098 tests)
- **Backward compatibility**: Existing `add_interviews()` API must not break — new parameters are additional/optional

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Three-layer architecture (API → Orchestration → Survey) | Isolates domain vocabulary from survey package internals | ✓ Good — absorbed bus-route without structural change |
| `creel_design()` as single entry point | Prevents design inconsistency; validates at construction time | ✓ Good — progressive validation works |
| `trip_status` required parameter for add_interviews() | Breaking change accepted — scientifically necessary for MOR vs ROM selection | ✓ Good — forces explicit decision |
| πᵢ = p_site × p_period (not interview probability) | Corrects all existing R implementations; primary source (Jones & Pollock 2012) | ✓ Good — Malvestuto Box 20.6 reproduced exactly |
| Catch data in long format (one row per species per interview) | Matches database schema; enables species-level grouping | ✓ Validated — v0.5.0 |
| Release lengths: handle both individual and binned formats | Database stores both; midpoint normalization for binned | ✓ Validated — v0.5.0 |
| `normalize_by_anglers` removed from all rate functions | `add_interviews(n_anglers=1)` default + unconditional `angler_effort_col` is simpler | ✓ Validated — v0.5.0 |
| Geographic summaries deferred | Requires external zip-county lookup; out of v0.5.0–v0.7.0 scope | — Pending |
| Report rendering deferred | Tidy tibbles are the deliverable; rendering is separate concern | — Pending |
| `svyby(covmat=TRUE)` + `svycontrast()` for section aggregation | Sections share day-level PSUs so naive Cochran 5.2 additivity would underestimate SE | ✓ Good — correlated-domain path is default, independent available for genuinely separate designs |
| Rate estimators produce no `.lake_total` row | Rates are not additive — lake-wide rate requires separate unpooled call | ✓ Good — enforced by design, documented in vignette |
| `sum(TC_i)` not `E_total × CPUE_pooled` for product lake total | Section-specific effort and CPUE interact; pooled estimator conflates spatial variation | ✓ Good — matches standard spatially stratified survey literature |
| Breaking rename: `estimate_cpue()` → `estimate_catch_rate()`, `estimate_harvest()` → `estimate_harvest_rate()` | v0.7.0 API consistency; no deprecated wrappers | ✓ Good — clean break, documented in NEWS.md |

---
*Last updated: 2026-03-15 — v0.8.0 milestone started*
