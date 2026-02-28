# Phase 3: Survey Bridge Layer - Context

**Gathered:** 2026-02-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Building the internal translation layer (orchestration layer) that converts creel survey data into survey package (svydesign) objects for statistical estimation. This phase implements:
- `add_counts()` method for attaching instantaneous count data to creel_design
- Internal svydesign construction with day-PSU stratified design
- Count data schema validation
- Escape hatch (`as_survey_design()`) for power users to access internal survey objects

This is the bridge between domain vocabulary (creel_design with counts) and statistical machinery (svydesign with weights and stratification). Estimation logic belongs in Phase 4.

</domain>

<decisions>
## Implementation Decisions

### add_counts() interface design
- **Immutability**: Returns new creel_design object (follows tidyverse patterns) — `design2 <- add_counts(design, counts)`
- **Duplicate handling**: Error if counts already attached — forces explicit workflow, prevents silent data loss
- **Argument style**: Both positional and named allowed — `add_counts(design, counts)` or `add_counts(design, counts = my_data)`
- **Error messages**: Detailed format (what's wrong + why + how to fix) — helps learning users understand validation failures

### Internal survey construction approach
- **Construction timing**: Claude's discretion — choose eager vs lazy construction based on R patterns and error handling philosophy
- **PSU identification**: PSU column specified as argument to add_counts() — flexible to support different sampling designs (defaults to date_col for day-as-PSU common case). PSU is only meaningful when count data is present, so specifying it at add_counts() time (not creel_design() time) is the correct abstraction boundary.
- **survey package dependency**: Claude's discretion — determine appropriate phase for adding survey package to DESCRIPTION
- **Stratification mapping**: Use creel strata directly — pass strata columns from creel_design to svydesign strata argument as straightforward mapping

### Escape hatch design (as_survey_design)
- **Visibility**: Exported (user-facing) — power users can access, documented, enables advanced workflows with survey package
- **User guidance**: Warning on first use — once-per-session reminder this is advanced feature, not typical workflow
- **Mutation prevention**: Return a copy — modifications to extracted svydesign don't affect creel_design internals
- **Missing counts behavior**: Error with clear message if called before add_counts() — explicit guidance rather than silent NULL

### Validation integration (Tier 1 vs Tier 2)
- **Validation boundaries**: Structural validation in add_counts() (schema, types, required columns), statistical validation in estimate_effort() (sparse strata, distributions)
- **Tier 1 failure handling**: Error by default, with allow_invalid flag to convert to warnings — safe by default, power users can opt into flexibility
- **Validation storage**: Store validation results in creel_design object for inspection — helpful for debugging even if adds to object size
- **Schema validator integration**: Separate validators called independently — validate_count_schema() parallel to validate_calendar_schema() from Phase 1

</decisions>

<specifics>
## Specific Ideas

- PSU flexibility important: "day as PSU" is common but not universal in creel surveys — some designs use "day-site combination" or "day-stratum" as PSU
- Error messages should teach: since target users are creel biologists without survey statistics background, errors are learning opportunities
- as_survey_design() warning should mention: "This is an advanced feature. Most users should use estimate_effort() instead. Modifying the survey design may produce incorrect variance estimates."

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-survey-bridge-layer*
*Context gathered: 2026-02-02*
*Decision clarified: 2026-02-08 — PSU specification scoped to add_counts() only (not creel_design constructor)*
