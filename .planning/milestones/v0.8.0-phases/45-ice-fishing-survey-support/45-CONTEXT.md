# Phase 45: Ice Fishing Survey Support - Context

**Gathered:** 2026-03-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Make ice fishing designs fully functional end-to-end: `creel_design(survey_type = "ice")` constructs correctly, `estimate_effort()` routes through the existing bus-route infrastructure with `p_site = 1.0` enforced, `estimate_catch_rate()` and `estimate_total_catch()` work on ice designs, and a realistic example dataset + vignette ship with the package. New capabilities (camera, aerial) belong in Phases 46-47.

</domain>

<decisions>
## Implementation Decisions

### p_site = 1.0 enforcement (ICE-01)

- `sampling_frame` is **optional** for ice designs — if omitted, the ice constructor auto-uses `p_site = 1.0` for all sites internally
- If `sampling_frame` is supplied, `p_site` column is validated: any non-1.0 value triggers `cli_abort()` immediately with a message naming the offending values
- `p_period` column follows the same pattern as bus-route: user-supplied (ice fishing still has temporal sampling probability)
- Dispatch in `estimate_effort()`: extend the existing guard from `design$design_type == "bus_route"` to `design$design_type %in% c("bus_route", "ice")` — ice routes through `estimate_effort_br()` unchanged. No new function.

### Effort type distinction (ICE-02)

- New required parameter `effort_type` on `creel_design(survey_type = "ice")` — no default
- Valid values: `"time_on_ice"` and `"active_fishing_time"`
- `cli_abort()` at construction time if `effort_type` is missing for ice designs
- Effect on output: `estimate_effort()` labels the estimate column based on `effort_type` — e.g., `total_effort_hr_on_ice` or `total_effort_hr_active`
- `effort_type` stored in `design$ice$effort_type` for downstream use

### Shelter-mode stratification (ICE-03)

- `shelter_mode` is **purely a grouping variable** — no construction-time parameter, no validation in `creel_design()`
- Lives in interview data as a column (characteristic of the angler encounter, not the site design)
- `estimate_effort(by = shelter_mode)` uses the existing `by =` mechanism unchanged
- Missing stratum behavior: NA row with `data_available = FALSE` — consistent with the missing-section guard pattern

### Interview compatibility (ICE-04)

- `add_interviews()` inherits bus-route validation (no ice-specific Tier 1 checks needed)
- `n_counted` and `n_interviewed` are REQUIRED for ice designs — same as bus-route, no roving-count fallback
- `estimate_catch_rate()` and `estimate_total_catch()` work on ice designs without modification — the dispatch guards for bus-route (extended to include ice) cover them

### Example data and documentation

- Export realistic Nebraska lake dataset: ~50-100 rows, multiple sampling days, realistic effort values
- Dataset exports: `example_ice_sampling_frame`, `example_ice_interviews` (with catch), possibly `example_ice_catch`
- Species: walleye + perch (recognizable to Nebraska biologists)
- Shelter modes in data: open + dark_house
- Vignette: full ice fishing workflow — `creel_design()` → `add_interviews()` → `estimate_effort()` → `estimate_effort(by = shelter_mode)` → `estimate_catch_rate()` → `estimate_total_catch()`

### Claude's Discretion

- Internal naming for auto-constructed sampling_frame when omitted (e.g., `.ice_sampling_frame` internal object)
- Whether `effort_type` affects the `print.creel_design()` output (likely yes — mirror how `bus_route` prints p_site/p_period info)
- Exact column name format for effort labels (`total_effort_hr_on_ice` vs `effort_on_ice_hr` — follow existing bus-route column naming convention)
- Number of sampling days and exact effort values in example data
- Whether to add `example_ice_*` to data-raw with a reproducible creation script

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- `estimate_effort_br()` (`R/creel-estimates-bus-route.R:21`): Full bus-route HT estimator — ice uses this directly by extending the dispatch guard. No modification needed to this function.
- `VALID_SURVEY_TYPES` (`R/creel-design.R:80`): Already includes `"ice"`. Enum guard is in place from Phase 44.
- `ice` stub (`R/creel-design.R:369-372`): Empty ice branch already exists — Phase 45 fills it in with `effort_type` validation and optional `sampling_frame` handling.
- Bus-route constructor pattern (`R/creel-design.R:275-366`): Template for how to handle `sampling_frame`, `p_site`, `p_period` — ice reuses this logic with `p_site = 1.0` auto-fill.
- `design$angler_effort_col` (`R/creel-design.R:1662`): Already set to `.angler_effort` by `add_interviews()` — ice designs inherit this without change.

### Established Patterns

- Bus-route dispatch guard: `if (!is.null(design$design_type) && design$design_type == "bus_route")` — extend to `%in% c("bus_route", "ice")` in `estimate_effort()`, `add_interviews()`, and the catch estimators
- Tier 1 validation with `cli_abort()`: `R/creel-design.R:521-552` shows the p_site range check pattern to mirror for the p_site = 1.0 enforcement
- `design$bus_route$p_site_col` field: ice will use `design$ice$effort_type` for analogous type-specific metadata storage
- `# nolint: object_usage_linter` required on NSE variables in cli messages

### Integration Points

- `R/creel-design.R`: ice constructor stub (L369-372) — fill in `effort_type` parameter + optional sampling_frame + p_site = 1.0 validation
- `R/creel-estimates.R`: bus_route dispatch guard (L342) — extend to include ice
- `R/creel-design.R` `add_interviews()` dispatch (~L1635): extend bus_route checks to ice
- `data/`: new `example_ice_*` dataset exports
- `vignettes/`: new `ice-fishing.Rmd` vignette

</code_context>

<specifics>
## Specific Ideas

- The architecture is: ice = degenerate bus-route (p_site = 1.0). No new estimator needed — just extend the dispatch guard and fill in the constructor. This keeps Phase 45 small and focused.
- `effort_type` is a biologically meaningful distinction: time-on-ice includes travel/setup time; active-fishing-time is the denominator for CPUE. Both are valid but they are NOT interchangeable — requiring the declaration prevents silent mislabeling.
- Example data should use a recognizable Nebraska lake context (e.g., "Lake McConaughy" or a fictional but plausible name). Walleye + perch is the standard Nebraska ice fishery species pair.

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope.

</deferred>

---

*Phase: 45-ice-fishing-survey-support*
*Context gathered: 2026-03-15*
