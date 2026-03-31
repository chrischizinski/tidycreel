# Architecture Research

**Domain:** tidycreel v0.9.0 — Quality-of-Life Utility Tools integration into existing R package
**Researched:** 2026-03-22
**Confidence:** HIGH (grounded in direct codebase inspection; existing architecture verified against all 15 R source files, NAMESPACE, and DESCRIPTION)

---

## Existing Architecture (v0.8.0 Baseline)

The three-layer architecture is established and proven through five survey types over 47 phases.

```
┌─────────────────────────────────────────────────────────────────┐
│                         API Layer                                │
│                                                                  │
│  creel_design()   add_counts()   add_interviews()               │
│  add_catch()      add_lengths()  add_sections()                 │
│  compute_effort() preprocess_camera_timestamps()                │
│                                                                  │
│  summarize_*()    validate_incomplete_trips()                   │
│  summarize_trips()                                               │
└──────────────────────────┬──────────────────────────────────────┘
                           │  creel_design S3 object
┌──────────────────────────▼──────────────────────────────────────┐
│                    Orchestration Layer                           │
│                                                                  │
│  estimate_effort()         dispatch on survey_type              │
│  estimate_catch_rate()     dispatch on species / sections       │
│  estimate_harvest_rate()   dispatch on species / sections       │
│  estimate_release_rate()   dispatch on species / sections       │
│  estimate_total_catch()    delta method product                 │
│  estimate_total_harvest()  delta method product                 │
│  estimate_total_release()  delta method product                 │
│                                                                  │
│  Internal: estimate_effort_br(), estimate_effort_aerial()       │
│  Internal: estimate_effort_sections(), aggregate_section_totals()│
└──────────────────────────┬──────────────────────────────────────┘
                           │  survey.design2 / svydesign objects
┌──────────────────────────▼──────────────────────────────────────┐
│                      Survey Layer                                │
│                                                                  │
│  survey::svydesign()   survey::svytotal()   survey::svyratio()  │
│  survey::svyby()       survey::svycontrast()                    │
│  as_survey_design() escape hatch for power users                │
└─────────────────────────────────────────────────────────────────┘
```

### Current S3 Classes and Their Slots

**`creel_design`** (the central object):
- `$calendar` — sampling frame data frame
- `$date_col`, `$strata_cols`, `$site_col` — resolved column names
- `$design_type` / `$survey_type` — dispatch key
- `$counts` — NULL until `add_counts()` called
- `$survey` — NULL until first estimation; holds `survey.design2`
- `$interviews`, `$refused_col`, `$trip_status_col` — set by `add_interviews()`
- `$catch`, `$lengths` — set by `add_catch()`, `add_lengths()`
- `$sections` — set by `add_sections()`
- `$bus_route` — list with sampling frame data (bus_route/ice only)
- `$aerial` — list with `h_open`, `visibility_correction` (aerial only)
- `$camera` — list with `camera_mode` (camera only)

**`creel_estimates`**, **`creel_estimates_mor`** — tibble wrappers returned by estimation functions

**`creel_validation`**, **`creel_tost_validation`** — returned by validation functions

**`creel_trip_summary`** — returned by `summarize_trips()`

---

## New Components for v0.9.0

The four new QoL feature families attach at different points in the workflow. None require changes to the three-layer model or to `creel_design`.

### Integration Map

```
PRE-DESIGN                                     POST-ESTIMATION
     │                                               │
Schedule Generators    Power Calculators    Completeness   Season
                       (independent)        Checkers       Summary
     │                       │                  │            │
     ▼                       ▼                  ▼            ▼
returns plain          takes numerics    takes creel_design  takes named
data.frame             returns data.frame  returns S3 check   list of estimates
     │                                         │            │
     ▼                                         │            ▼
creel_design()                                 │       export_creel()
(unchanged)                                    │       write_creel_csv()
                                               │
                               (read-only; design unchanged)
```

### Component Boundaries for New Features

| Component | Responsibility | Layer Position | Interface |
|-----------|----------------|----------------|-----------|
| `generate_schedule()` family | Build a calendar data frame (dates, strata, sites) from season parameters | Pre-design utility; API layer peer to `creel_design()` | Returns plain `data.frame` fed into `creel_design()` |
| `power_creel()` / `n_days_required()` | Compute CV, required days given variance inputs; standalone calculators | API layer; no `creel_design` dependency | Takes numerics, returns data frame or scalar |
| `check_completeness()` | Inspect attached data in `creel_design` for missing dates, strata, sites; report coverage | Post-construction diagnostic; reads `creel_design` slots | Returns new `creel_completeness_check` S3 class |
| `export_creel()` / `write_creel_csv()` | Serialize estimation outputs to CSV or xlsx | Post-estimation; takes named list of data frames | Side-effect function; thin wrapper over `write.csv()` and optionally `writexl::write_xlsx()` |
| `summarize_season()` | Collate user-supplied estimation outputs for a season into one structured list | Post-estimation; takes named list of estimates | Returns `creel_season_summary` S3 class |

---

## Recommended Package Structure for New Files

```
R/
├── creel-design.R             # UNCHANGED
├── creel-estimates.R          # UNCHANGED
├── creel-estimates-aerial.R   # UNCHANGED
├── creel-estimates-bus-route.R # UNCHANGED
├── creel-estimates-total-*.R  # UNCHANGED
├── creel-summaries.R          # UNCHANGED
├── creel-validation.R         # UNCHANGED
├── survey-bridge.R            # UNCHANGED
├── validate-incomplete-trips.R # UNCHANGED
├── validate-schemas.R         # UNCHANGED
├── print-methods.R            # EXTEND — add print/format for new S3 classes
├── data.R                     # EXTEND — document any new example datasets
│
├── creel-schedule.R           # NEW — generate_schedule(), generate_bus_schedule()
├── creel-power.R              # NEW — power_creel(), n_days_required(), cv_from_n()
├── creel-completeness.R       # NEW — check_completeness(), creel_completeness_check S3
└── creel-export.R             # NEW — export_creel(), write_creel_csv(), summarize_season()
```

**Rationale:** One new file per feature family follows the existing 15-file convention (kebab-case, `creel-` prefix). `print-methods.R` is the only existing file that changes. No changes to `creel-design.R` or any estimation file.

---

## Architectural Patterns

### Pattern 1: Pre-Design Generator (schedule tools)

**What:** A standalone function that takes scalar season parameters (start/end date, survey days per stratum, optional site list) and returns a plain `data.frame` suitable as the `calendar` argument to `creel_design()`.

**When to use:** All schedule generation functions.

**Trade-offs:** Returning a plain `data.frame` means schedule generators have no survey package dependency. They are testable with zero mock design objects. The risk is that biologists pass the result directly to downstream functions without calling `creel_design()` first — guard against this with clear `@section Workflow` documentation pointing to `creel_design()` as the mandatory next step.

**Example:**
```r
# PRE-DESIGN: schedule generator returns calendar data.frame
cal <- generate_schedule(
  start      = as.Date("2025-05-01"),
  end        = as.Date("2025-08-31"),
  n_weekday  = 2L,
  n_weekend  = 1L
)
# Normal workflow resumes unchanged
design <- creel_design(cal, date = date, strata = day_type)
```

### Pattern 2: Standalone Power Calculator (no creel_design dependency)

**What:** Pure functions that take variance parameters derived from historical data or pilot surveys and return required sample sizes or expected CVs. No `creel_design` object is read or constructed.

**When to use:** `power_creel()`, `n_days_required()`, `cv_from_n()`.

**Trade-offs:** Decoupling from `creel_design` means these functions work with pilot data summaries from any source (published tables, past surveys in Excel). An optional helper `extract_power_inputs(design)` can extract variance components from a completed design for retrospective power assessment, but the core calculators remain independent.

**Key variance inputs** (from McCormick & Quist 2017 creel-specific sample size framework):
- `cv_target` — desired relative precision (e.g., 0.20 for ±20% CI width)
- `sigma2` — variance of daily effort counts from pilot data
- `mu` — mean daily effort from pilot data
- `n_strata` — number of sampling strata (typically 2: weekday/weekend)
- `season_days` — total days in the season

**Example:**
```r
result <- n_days_required(
  cv_target   = 0.20,
  sigma2      = 120.5,
  mu          = 45.3,
  n_strata    = 2L,
  season_days = 120L
)
# Returns data.frame: stratum, n_required, achieved_cv
```

### Pattern 3: Post-Construction Diagnostic (completeness checkers)

**What:** Functions that accept a `creel_design` object (with data attached) and return a structured diagnostic S3 object. Pattern mirrors `validate_incomplete_trips()` — guard-first, structured S3 return, no mutation of the input.

**When to use:** `check_completeness()`, any data gap diagnostic.

**Trade-offs:** Taking `creel_design` as input provides access to the calendar, strata, sections, and all attached data frames for cross-referencing coverage gaps. The guard-first pattern (`if (!inherits(design, "creel_design")) cli_abort(...)`) is canonical across 10 existing functions — apply identically here.

**Example:**
```r
chk <- check_completeness(design)
# Returns creel_completeness_check S3:
#   $calendar_coverage: n sampled vs total days per stratum
#   $count_gaps: dates in calendar missing from counts data
#   $interview_gaps: count days missing interview records
#   $passed: logical
print(chk)  # dispatches to format.creel_completeness_check in print-methods.R
```

### Pattern 4: Post-Estimation Export (thin wrapper, Suggests dependency)

**What:** Functions that take a named list of data frames (estimation outputs) and write them to disk. CSV path uses `write.csv()` from base R — zero new dependencies. Excel path uses `writexl::write_xlsx()` — one `Suggests` addition.

**When to use:** `export_creel()`, `write_creel_csv()`.

**Trade-offs:** `writexl` is zero-dependency C code (rOpenSci, actively maintained 2025), twice as fast as `openxlsx`, and produces smaller files. As `Suggests`, it is optional — if absent, CSV path works and Excel path fails with an informative `rlang::check_installed("writexl")` message. This keeps `Imports` clean.

**Example:**
```r
results <- list(
  effort  = estimate_effort(design),
  catch   = estimate_total_catch(design, species = species),
  harvest = estimate_total_harvest(design, species = species)
)
# CSV: base R only, no new dependencies
write_creel_csv(results, dir = "output/", prefix = "lake_a_2025")
# Excel: requires writexl in Suggests
export_creel(results, path = "output/lake_a_2025.xlsx")
```

---

## Data Flow

### Full Season Workflow with New Tools

```
generate_schedule()          # NEW — returns plain data.frame
    │
    ▼
creel_design()               # UNCHANGED — constructs creel_design S3
    │
add_counts() → add_interviews() → add_catch() → add_sections()
    │
    ▼
check_completeness()         # NEW — diagnostic, read-only, returns creel_completeness_check
    │ (user fixes data gaps, re-attaches if needed)
    ▼
estimate_effort()            # UNCHANGED
estimate_total_catch()       # UNCHANGED
estimate_catch_rate()        # UNCHANGED
    │ named list of creel_estimates
    ▼
summarize_season()           # NEW — collates into creel_season_summary
    │
export_creel() / write_creel_csv()  # NEW — side-effect: writes files
```

### Power Calculator Flow (independent)

```
Pilot data (numeric inputs or past survey data.frame)
    │
n_days_required() / power_creel() / cv_from_n()   # NEW, standalone
    │
data.frame of sample size recommendations
    │ (user uses this to plan the season calendar — manual step)
    ▼
generate_schedule() → creel_design() → ...
```

### Key Data Flow Properties

1. **Schedule generators are fully upstream.** They produce the calendar; `creel_design()` consumes it. No circular dependencies possible.
2. **Power calculators are orthogonal.** They do not read or modify `creel_design`. They can be called before any design exists.
3. **Completeness checkers are read-only.** They inspect `creel_design` slots but never modify the object. The design passes through unchanged.
4. **Export utilities are terminal.** They consume estimates tibbles and produce files. They do not return data for further computation.
5. **`summarize_season()` is a collator, not an estimator.** It assembles pre-computed results. It does not call any estimation function internally.

---

## Integration Points

### New vs. Modified Components

| Component | Status | Files Touched | Regression Risk |
|-----------|--------|---------------|-----------------|
| `generate_schedule()`, `generate_bus_schedule()` | NEW | `R/creel-schedule.R` (new file) | None — additive |
| `power_creel()`, `n_days_required()`, `cv_from_n()` | NEW | `R/creel-power.R` (new file) | None — additive |
| `check_completeness()`, `creel_completeness_check` S3 | NEW | `R/creel-completeness.R` (new file) | None — read-only |
| `export_creel()`, `write_creel_csv()`, `summarize_season()` | NEW | `R/creel-export.R` (new file) | None — terminal |
| `print-methods.R` | MODIFIED | Add `format.creel_completeness_check`, `format.creel_season_summary` | Low — additive S3 methods |
| `DESCRIPTION` | MODIFIED | Add `writexl` to `Suggests` | None |
| `NAMESPACE` | MODIFIED | roxygen2 regenerates; ~8 new exports | None |
| `creel-design.R` | UNCHANGED | No parameter changes, no dispatch changes | None |
| All estimation files | UNCHANGED | QoL tools do not alter estimation logic | None |
| All `summarize_*()` functions | UNCHANGED | Existing summaries are not replaced | None |

### DESCRIPTION Changes Required

```
Suggests:
    writexl          # zero-dependency xlsx export (rOpenSci, actively maintained 2025)
```

No `Imports` additions are needed. The CSV export path uses `write.csv()` from base R. The schedule and power tools use only base R arithmetic and `stats`. The completeness checker uses only base R and existing `cli` (already in `Imports`).

---

## Suggested Build Order

Build order is driven by dependency direction: schedule generators and power calculators have no internal dependencies and can be built first (or in parallel). Completeness checkers depend on `creel_design` slot stability (stable since v0.4.0). Export utilities depend on estimation outputs being stable (they are).

### Phase Sequence

**Phase A — Schedule generators** (no internal dependencies)

- `R/creel-schedule.R`: `generate_schedule()` for instantaneous/access designs; `generate_bus_schedule()` that also generates a companion sampling frame data frame
- Tests: verify date range, stratum assignment, no-NA calendar, bus-route `p_site` sum-to-1
- Vignette stub: show `generate_schedule() |> creel_design()` workflow

**Phase B — Power and sample size tools** (no internal dependencies, parallel with A)

- `R/creel-power.R`: `n_days_required()`, `power_creel()`, `cv_from_n()`
- Verification target: reproduce McCormick & Quist (2017) Table 2 worked example
- Tests: unit tests with known analytic solutions; boundary checks (cv_target at 0.05, 0.40)
- Vignette: show pre-season planning workflow; connect to `generate_schedule()`

**Phase C — Completeness checkers** (depends on `creel_design` API — already stable)

- `R/creel-completeness.R`: `check_completeness()`; `creel_completeness_check` S3 constructor
- `R/print-methods.R`: add `format.creel_completeness_check`
- Tests: designs with deliberate calendar coverage gaps; verify `$count_gaps`, `$interview_gaps` slots; verify `$passed` logic; verify guard-first abort on non-`creel_design` input

**Phase D — Export utilities and season summary** (depends on estimators — already stable)

- `R/creel-export.R`: `write_creel_csv()` (base R path); `export_creel()` (writexl path); `summarize_season()`; `creel_season_summary` S3 constructor
- `R/print-methods.R`: add `format.creel_season_summary`
- `DESCRIPTION`: add `writexl` to `Suggests`
- Tests: write to `tempfile()`, verify CSV structure; verify xlsx path fails gracefully when writexl absent; verify `summarize_season()` with partial estimate list

**Why this order:**

- Phases A and B are independent and can proceed in parallel.
- Phase C must come after the `creel_design` API is confirmed stable for v0.9.0. It is confirmed — no changes to `creel-design.R` are planned.
- Phase D comes last because `summarize_season()` integration tests benefit from having the schedule (Phase A) and completeness diagnostics (Phase C) established, so end-to-end workflow tests cover the full pipeline in one vignette.
- No phase requires modifying estimation logic. Regression risk on existing 1696 tests is effectively zero for all four phases.

---

## Anti-Patterns

### Anti-Pattern 1: Schedule Generator Returns `creel_design`

**What people do:** Have `generate_schedule()` call `creel_design()` internally and return the design object.

**Why it's wrong:** Couples schedule generation to survey design construction. Users cannot inspect or modify the calendar before building the design. Conflates schedule errors with design validation errors at construction time.

**Do this instead:** Return a plain `data.frame`. Let the user call `creel_design()` explicitly. Document the two-step workflow in vignette.

### Anti-Pattern 2: Power Calculator Reads `creel_design$survey`

**What people do:** Accept a `creel_design` object and extract variance estimates from the fitted survey design.

**Why it's wrong:** Power analysis is a planning-time activity; `creel_design$survey` is NULL until `add_counts()` and a first estimation call complete. If `power_creel()` requires a fitted design, it cannot be used for prospective planning — the primary use case.

**Do this instead:** Accept raw variance inputs (`sigma2`, `mu`, `n_strata`). Optionally provide a separate `extract_power_inputs(design)` helper for retrospective assessment. Keep the core calculator independent.

### Anti-Pattern 3: Completeness Checker Modifies `creel_design`

**What people do:** Have `check_completeness()` fill gap rows, impute missing data, or append a `$completeness` slot to the design object.

**Why it's wrong:** All existing `add_*()` functions return a new design object — none modify in place. Side effects on `creel_design` are invisible to the user and untestable.

**Do this instead:** Return a new `creel_completeness_check` S3 object. Mirror the `creel_tost_validation` pattern from `validate_incomplete_trips()`.

### Anti-Pattern 4: Adding `openxlsx` or `openxlsx2` to Imports

**What people do:** Use `openxlsx` for its multi-sheet, formatted output capabilities.

**Why it's wrong:** `openxlsx` is no longer under active development as of 2025 (maintainer-confirmed). `openxlsx2` is a heavier API than needed for simple tabular export. Either adds an `Imports` dependency for a convenience feature that not all users need.

**Do this instead:** Use `writexl` in `Suggests`. It is zero-dependency C code (rOpenSci), twice as fast as `openxlsx`, and actively maintained. For CSV, use `write.csv()` from base R.

### Anti-Pattern 5: `summarize_season()` Calls Estimators Internally

**What people do:** Have `summarize_season(design)` call `estimate_effort()`, `estimate_total_catch()`, etc. internally.

**Why it's wrong:** Buries variance method choices, `by =` groupings, and species selections inside the function with no user control. Impossible to test without a fully configured design with all data attached.

**Do this instead:** `summarize_season(design, estimates)` accepts a named list of pre-computed estimates from the user. It collates, labels, and structures for output. The user controls all estimation parameters.

---

## Sources

- tidycreel NAMESPACE (verified 2026-03-22) — full public API enumeration
- tidycreel DESCRIPTION (verified 2026-03-22) — current dependency footprint
- `R/creel-design.R` — `creel_design` S3 slots, Tier 1 validation pattern, tidy selector conventions
- `R/creel-summaries.R` — three-guard pattern for functions taking `creel_design`
- `R/validate-incomplete-trips.R` — `creel_tost_validation` S3 return pattern; guard-first discipline
- `R/creel-validation.R` — `creel_validation` S3 constructor internals
- `R/survey-bridge.R` — `as_survey_design()` escape hatch, once-per-session warning pattern
- `R/creel-estimates-aerial.R` — survey_type dispatch pattern for internal functions
- McCormick, S.L. & Quist, M.C. (2017). Sample size estimation for on-site creel surveys. *North American Journal of Fisheries Management*. https://afspubs.onlinelibrary.wiley.com/doi/full/10.1080/02755947.2017.1342723
- rOpenSci writexl release post (2017, package actively maintained 2025). https://ropensci.org/blog/2017/09/08/writexl-release/
- AnglerCreelSurveySimulation CRAN vignette — simulation-based power analysis approach for creel surveys. https://cran.r-project.org/web/packages/AnglerCreelSurveySimulation/vignettes/creel_survey_simulation.html

---

*Architecture research for: tidycreel v0.9.0 QoL utility tools integration*
*Researched: 2026-03-22*
