# Phase 19: Diagnostic Validation Framework - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Statistical validation framework comparing complete vs incomplete trip CPUE estimates to determine if incomplete trips are a valid substitute in a given dataset. Users call validate_incomplete_trips() to perform equivalence testing, view diagnostic plots, and receive guidance on whether their incomplete trip data meets quality standards for use in estimation.

</domain>

<decisions>
## Implementation Decisions

### Statistical approach
- **Test type**: Equivalence test (TOST - Two One-Sided Tests) to prove similarity rather than just "not different"
- **Equivalence threshold**: ±20% relative difference (moderate threshold appropriate for ecological field data variability)
- **Grouped estimates**: Test both overall equivalence AND per-group equivalence when CPUE was estimated with by= parameter
- **Threshold configuration**: Package option (e.g., tidycreel.equivalence_threshold) with ±20% default - consistent with tidycreel.min_complete_pct pattern from Phase 18

### Visualization content
- **Error bars**: Yes, display confidence intervals on scatter plot to show precision
- **Annotations**: Label points/groups that fail equivalence test - immediate attention to problems
- **Color scheme**: Claude's discretion based on grouped vs ungrouped context
- **Reference elements**: Claude's discretion on equivalence bands, regression line, or other visual aids beyond y=x line

### Interpretation guidance
- **Validation criteria**: "Safe to use incomplete trips" requires TOST passes overall AND all groups pass (most conservative - prevents overlooking group-specific bias)
- **Actionable next steps**: Provide guidance only on validation failure (e.g., suggest use_trips="complete" or investigate specific groups) - silent on success
- **Limitation emphasis**: Document assumptions (length-of-stay bias, nonstationary catch rates) in vignette only, don't repeat in every validation output
- **Guidance format**: Claude's discretion on decision tree, traffic light, or narrative style

### Report format
- **Return type**: S3 class object (creel_validation) - consistent with package patterns (creel_design, creel_estimates_mor)
- **Statistical detail**: Full detail in results table - estimates, SEs, CIs, test statistics, p-values, pass/fail conclusions
- **Plot display**: Display plot in print method - consistent with how print.creel_estimates_mor formats output
- **Object components**: Claude's discretion on structure (results table, plot object, recommendation, metadata, etc.)

### Claude's Discretion
- Color scheme for grouped vs ungrouped plots
- Reference elements beyond y=x line (equivalence bands, regression line, confidence region)
- Guidance format (decision tree, traffic light system, or narrative)
- S3 object internal structure and component organization

</decisions>

<specifics>
## Specific Ideas

- TOST is the right statistical approach here - we want to prove estimates are "close enough", not just fail to reject that they're different
- Requiring all groups to pass is important - overall equivalence could mask problematic groups
- ±20% threshold balances rigor with realistic field data variability (stricter than the 30% considered in Phase 17's diagnostic mode, but appropriate for formal validation)
- Full statistical detail supports transparency - users can see the evidence behind recommendations

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope

</deferred>

---

*Phase: 19-diagnostic-validation-framework*
*Context gathered: 2026-02-15*
