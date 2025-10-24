# tidycreel Development Roadmap
## Comprehensive Feature Planning & Gap Analysis

**Last Updated:** October 24, 2025
**Package Version:** 0.0.0.9000
**Status:** Package is ~75% complete for basic creel analysis
**Next Major Milestone:** Implement roving estimators and QA/QC framework

---

## Recent Accomplishments ✅

### October 2025 - Critical Functions Implemented

1. **`aggregate_cpue()`** - Survey-based species aggregation ✅
   - Properly aggregates CPUE across species groups
   - Accounts for covariance between species
   - Essential for species group harvest estimation
   - **383 lines of code, 10 passing tests**

2. **`est_total_harvest()`** - Total harvest/catch estimation ✅
   - Product estimator with delta method variance propagation
   - Independent and correlated variance estimation
   - Flexible stratification support
   - **418 lines of code, 66 passing tests**

3. **Survey-First Vignette Refactoring** ✅
   - Migrated from design containers to direct survey package usage
   - Cleaned vignette caches
   - Updated documentation

**Impact:** Users can now complete full creel analyses from effort → CPUE → species aggregation → total harvest with proper variance estimation.

---

## Comprehensive Gap Analysis Summary

A detailed comparison with the comprehensive textbook chapter (*Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition*, Chapter 17: Creel Surveys) revealed **18 major gaps** organized by priority.

**Full Report:** See `CHAPTER_GAP_ANALYSIS.md` (1,581 lines)

### Current State Assessment

**Strengths (What We Have):**
- ✅ 48+ exported functions with robust survey-first architecture
- ✅ Core effort estimation methods (instantaneous, progressive, aerial, bus route)
- ✅ CPUE estimation with multiple approaches (ratio-of-means, mean-of-ratios, auto mode)
- ✅ **NEW:** Species aggregation with survey-based variance
- ✅ **NEW:** Total harvest estimation with delta method
- ✅ Survey design integration (`as_day_svydesign`, replicate designs)
- ✅ Comprehensive validation framework
- ✅ Basic visualization (`plot_design`, `plot_effort`)
- ✅ Excellent documentation structure and vignettes

**Updated Completeness Assessment:**
- **Survey Design & Sampling:** 90% complete
- **Effort Estimation:** 85% complete (missing roving/incomplete trip methods)
- **Catch/Harvest Estimation:** ✅ **85% complete** (was 60%, now has total harvest + aggregation)
- **Quality Assurance/Control:** 30% complete (basic validation only)
- **Variance Analysis Tools:** 40% complete (missing decomposition)
- **Sample Size Planning:** 10% complete (no formal tools)
- **Biological Data Analysis:** 20% complete (length frequencies not implemented)
- **Visualization & Reporting:** 40% complete (basic plots only)
- **Advanced Methods:** 20% complete (aerial, cameras, hybrid designs)
- **Angler Segmentation:** 30% complete (ad-hoc via `by` argument)

---

## Top 15 Priority Features
### Reorganized Based on Chapter Analysis & User Needs

---

## PHASE 1 - Critical Operational Gaps (Next 8-10 weeks)

### 1. 🔴 **Roving/Incomplete Trip Estimators** - HIGHEST PRIORITY

**Status:** Not implemented
**Priority:** P0 - One of the most common survey types
**Effort:** 2-3 weeks
**Chapter Reference:** Section 17.3.2, Box 18.5 (Pollock et al. 1997)

**Why Critical:**
- Roving surveys are extremely common (anglers interviewed while actively fishing)
- Current `est_cpue()` has basic incomplete trip handling but missing proper Pollock et al. methods
- Length-biased sampling correction needed
- Different variance formulas than access-point surveys

**Missing Components:**
- **Pollock et al. (1997) mean-of-ratios estimator** for incomplete trips
- **Trip length truncation** - systematic handling of very short trips (< 0.5 hrs)
- **Length-biased sampling correction** - longer trips more likely intercepted
- **Incomplete trip expansion** - proper handling when anglers still fishing
- **Separate variance formulas** for roving vs access-point

**Key Formulas:**
```r
# Roving (incomplete) - Mean of Ratios
rate_i = catch_i / effort_i  (for each party)
mean_rate = Σ(rate_i) / k
var_rate = [Σ(rate_i²) - (Σ rate_i)²/k] / [k(k-1)]

# MUST truncate trips < 0.5 hours (Hoenig et al. 1997)
```

**Implementation Plan:**
```r
est_cpue_roving(
  interviews,
  response = "catch_total",
  effort_col = "hours_fished",
  min_trip_hours = 0.5,              # Truncation threshold
  correction = c("none", "length_biased"),  # Length-biased sampling
  by = NULL,
  svy = NULL,
  conf_level = 0.95
)

# Or enhance existing est_cpue()
est_cpue(
  ...,
  interview_type = c("complete", "incomplete", "mixed"),
  apply_truncation = TRUE,
  length_bias_correction = FALSE
)
```

**Testing:**
- Compare to Pollock et al. examples
- Validate truncation effects
- Test variance formulas against access-point method
- Integration with `est_total_harvest()`

**Documentation:**
- Vignette: "Roving vs Access-Point Surveys"
- When to use each method
- Variance implications
- Best practices for field implementation

**Success Metrics:**
- Matches Pollock et al. (1997) examples
- Users can analyze roving survey data correctly
- Proper variance estimation for incomplete trips

---

### 2. 🔴 **Quality Assurance/Quality Control Framework**

**Status:** Basic schemas only
**Priority:** P0 - Data quality issues extremely common
**Effort:** 2-3 weeks
**Chapter Reference:** Section 17.2.2, Table 17.3

**Why Critical:**
- Table 17.3 lists 10 common mistakes in creel surveys
- Current package only validates basic data schemas
- No systematic checks for common errors
- Users need guidance to avoid biased estimates

**Common Mistakes to Detect (Table 17.3):**
1. **Skipping zeros** - Creel clerks only recording when anglers present
2. **Targeting successful parties** - Interviewing at cleaning stations
3. **Measuring biggest fish only** - Size structure bias
4. **Counts don't cover entire area** - Spatial coverage gaps
5. **Interviews exclude groups** - Non-response bias
6. **Mixing measurement units** - Inches vs mm, hours vs minutes
7. **Species misidentification** - Data quality issues
8. **Party-level effort errors** - Accounting for multiple anglers
9. **Lack of standardized training** - Data inconsistency
10. **No QA-QC procedures** - Compounding errors

**Implementation:**
```r
qa_checks(
  counts = NULL,
  interviews = NULL,
  schedule = NULL,
  checks = c(
    "zero_counts",         # Flag if no zero counts recorded
    "successful_bias",     # Detect interviewing only at cleaning stations
    "measurement_units",   # Check unit consistency
    "party_effort",        # Validate multi-angler party effort
    "coverage",           # Verify counts covered entire waterbody
    "outliers",           # Statistical outlier detection
    "species_id",         # Flag uncommon species combinations
    "missing_data",       # Completeness checks
    "temporal_coverage",  # All strata sampled
    "interview_location"  # Location bias assessment
  ),
  severity = c("error", "warning", "info")
)

# Generate comprehensive report
qc_report(
  data,
  qa_results,
  output_format = c("html", "pdf", "console"),
  include_recommendations = TRUE
)

# Validation functions
validate_counts(counts, design_type, check_design_requirements = TRUE)
validate_interviews(interviews, survey_type, check_consistency = TRUE)
validate_schedule(schedule, calendar, check_allocation = TRUE)
```

**Testing:**
- Synthetic data with known issues
- Real data examples (anonymized)
- Edge cases for each check
- Performance with large datasets

**Documentation:**
- Vignette: "Data Quality Best Practices"
- Table of common mistakes and checks
- How to interpret QA/QC report
- Fixing common issues

**Success Metrics:**
- Detects all 10 common mistakes
- Clear, actionable error messages
- Users improve data quality before analysis

---

### 3. 🟡 **Variance Component Decomposition**

**Status:** Uses survey package variance but no decomposition
**Priority:** P1 - Needed for optimal survey design
**Effort:** 2 weeks
**Chapter Reference:** Box 18.4, Rasmussen et al. (1998)

**Why Important:**
- Understanding variance components guides sampling decisions
- Optimal allocation between weekdays/weekends
- Optimal number of counts per shift
- Design effect calculations

**Missing Components:**
- Within-day variance (variance among counts within a shift)
- Among-day variance (variance among days within a stratum)
- Within-shift variance (multiple counts per shift)
- Variance ratio analysis for optimal allocation

**Key Formula:**
```r
# Strata estimator with variance decomposition
var(Y_stratum) = ((1 - n/N)/n) * s_b² + (1/(2N)) * s_w²

where:
  s_b² = among-day variance
  s_w² = within-day variance (from multiple counts)
  n = days sampled
  N = total days in stratum
```

**Implementation:**
```r
decompose_variance(
  effort_est,  # Output from est_effort()
  level = c("shift", "day", "stratum", "month"),
  components = c("within_day", "among_day", "within_shift")
)

# Output includes:
# - Variance components table
# - Intraclass correlation
# - Design effects
# - Optimal allocation recommendations
# - Variance ratio (for sample size planning)

# Visualize variance components
plot_variance_components(
  variance_decomp,
  type = c("table", "barplot", "nested")
)
```

**Testing:**
- Known variance decomposition examples
- Compare to manual calculations
- Nested ANOVA validation
- Different survey designs

**Documentation:**
- Vignette: "Understanding Variance in Creel Surveys"
- Optimal allocation examples
- Sample size determination using variance ratios

**Success Metrics:**
- Correct variance decomposition
- Users can optimize sampling design
- Clear recommendations for allocation

---

### 4. 🟡 **Sample Size Determination Tools**

**Status:** Not implemented
**Priority:** P1 - Frequently needed for planning and grants
**Effort:** 2-3 weeks
**Chapter Reference:** Newman et al. (1997), McCormick & Meyer (2017)

**Why Important:**
- Grant proposals require sample size justification
- Pilot studies need proper analysis
- Budget constraints require optimization
- Users ask "how many days should I sample?"

**Missing Components:**
- Power analysis for detecting trends
- Precision-based sample size for target CV
- Optimal allocation between weekdays/weekends
- Optimal counts per shift
- Pilot study analysis tools
- Variance ratio methods

**Implementation:**
```r
calc_sample_size(
  target_cv = 0.15,              # Desired coefficient of variation
  variance_ratio = NULL,          # s_within² / s_among² from pilot
  pilot_data = NULL,              # Or provide pilot data directly
  allocation = c("proportional", "optimal", "equal"),
  strata = c("weekday", "weekend", "highuse"),
  budget_constraint = NULL,
  cost_per_day = NULL
)

# Power analysis for trend detection
calc_power_creel(
  effect_size,                    # Minimum detectable change
  years = 5,
  alpha = 0.05,
  days_per_stratum,
  variance_components
)

# Analyze pilot study
analyze_pilot(
  pilot_data,
  recommend_sample_size = TRUE,
  target_precision = 0.15,
  stratification = c("weekday", "weekend")
)

# Optimal counts per shift
calc_optimal_counts(
  variance_components,
  shift_duration = 8,
  cost_per_count = NULL
)
```

**Testing:**
- Known examples from literature
- Sensitivity to variance ratios
- Budget constraint scenarios
- Integration with variance decomposition

**Documentation:**
- Vignette: "Planning Your Creel Survey"
- Sample size workflow
- Pilot study analysis
- Budget optimization

**Success Metrics:**
- Accurate sample size recommendations
- Power analysis matches published examples
- Users can justify sampling effort

---

### 5. 🟡 **Angler Segmentation Framework**

**Status:** Ad-hoc via `by` argument
**Priority:** P1 - Addresses heterogeneity and bias
**Effort:** 3-4 weeks
**Chapter Reference:** Section 17.4.2

**Why Important:**
- Anglers are heterogeneous (bank vs boat, target species, etc.)
- Different segments have different detection probabilities
- Non-response bias assessment
- Proper variance estimation requires accounting for segments

**Segmentation Types:**
- **Geographic** - Resident vs non-resident, location
- **Demographic** - Age, gender, income, education
- **Psychographic** - Motivations, values, attitudes
- **Behavioral** - Bank vs boat, target species, gear type

**Missing Components:**
- Formal segmentation framework
- Detection probability adjustment
- Non-response bias assessment by segment
- Harvest propensity modeling

**Implementation:**
```r
define_segments(
  interviews,
  segment_type = c("method", "target_species", "demographic", "behavioral"),
  segment_vars = NULL,             # Variables defining segments
  estimate_detection = TRUE        # Adjust for differential detection
)

# Enhanced estimation with segmentation
est_effort_segmented(
  counts,
  interviews,
  segments,
  adjust_detection = TRUE,
  test_differences = TRUE,         # Test if segments differ significantly
  by = NULL,
  svy = NULL
)

# Assess non-response bias by segment
assess_nonresponse_bias(
  interviews,
  counts,
  segments,
  methods = c("comparison", "sensitivity", "bounds")
)

# Automatic bank vs boat separation
separate_bank_boat(
  counts,
  interviews,
  method_col = "fishing_method",
  estimate_separately = TRUE
)
```

**Testing:**
- Known segmentation examples
- Detection probability scenarios
- Non-response bias assessment
- Integration with existing estimators

**Documentation:**
- Vignette: "Angler Segmentation and Heterogeneity"
- When segmentation is needed
- Detection probability concepts
- Non-response bias implications

**Success Metrics:**
- Proper segment-specific estimates
- Detection probability adjustment working
- Non-response bias quantified

---

## PHASE 2 - Enhanced Functionality (6-8 weeks)

### 6. 🟢 **Enhanced Bus Route Estimator**

**Status:** Basic implementation exists
**Priority:** P2 - Enhancement to existing feature
**Effort:** 1-2 weeks
**Current:** `/Users/cchizinski2/Dev/tidycreel/R/est-effort-busroute.R`

**Enhancements Needed:**

**6.1 Interview-based Expansion**
- Current: Only time-interval method
- Missing: Completed trip interview expansion (second method from chapter)

**6.2 Sampling Probability Adjustment**
- Current: Uses `inclusion_prob` column
- Missing: Automatic calculation from wait times and travel times
- Formula: `π_j = w_i / T` where w_i is wait time at site i, T is total circuit time

**6.3 Non-uniform Probability Documentation**
- Reference: Malvestuto et al. (1978)
- Missing: Explicit handling when sites have different sampling probabilities

**Implementation:**
```r
est_effort.busroute_design(
  x,
  method = c("time_interval", "completed_trips"),  # ADD choice

  # For completed_trips method (NEW)
  interview_based = FALSE,
  trip_duration_col = "trip_duration",

  # Probability calculation (NEW)
  auto_calc_pi = TRUE,
  wait_time_col = "wait_time",
  total_circuit_time_col = "circuit_time"
)
```

---

### 7. 🟢 **Aerial Survey Methods**

**Status:** Stub implementation only
**Priority:** P2 - Specialized but important
**Effort:** 3-4 weeks
**Chapter Reference:** Sections 17.3.1.2, 17.5.3

**Missing Components:**
- Instantaneous aerial counts with expansion factors
- Treatment of boats in transit vs active fishing
- Inflation factors for time-of-day expansion
- Integration with ground counts for calibration
- Weather/visibility adjustments
- Flight path design and coverage probability

**Key Formula:**
```r
# Instantaneous aerial to daily effort
Daily_Effort = Aerial_Count × Inflation_Factor
Inflation_Factor = (Total_Day_Hours / Peak_Period_Hours) × Activity_Ratio
```

**Implementation:**
```r
est_effort_aerial(
  counts,                    # Aerial count data
  inflation_factors,         # Time-of-day expansion
  boats_in_transit = c("include", "exclude", "adjust"),
  calibration_data = NULL,   # Ground truth for validation
  flight_coverage = NULL,    # Coverage probability by area
  by = NULL,
  svy = NULL
)

# Companion function
calc_inflation_factors(
  aerial_counts,
  reference_counts,          # High-res camera or complete counts
  time_periods = c("dawn", "morning", "afternoon", "dusk"),
  method = c("ratio", "regression")
)
```

---

### 8. 🟢 **Remote Camera Integration**

**Status:** Not implemented
**Priority:** P2 - Emerging technology
**Effort:** 3-4 weeks
**Chapter Reference:** Section 17.3.1.2 (van Poorten et al. 2015)

**Missing Components:**
- Image analysis workflow
- Field-of-view correction
- Missing data imputation (camera malfunction, vandalism)
- Zero-inflation handling
- Hierarchical Bayesian models
- Integration with aerial counts

**Implementation:**
```r
process_camera_counts(
  images,                    # Image metadata with timestamps
  field_of_view = c("partial", "complete"),
  missing_data = c("interpolate", "model", "omit"),
  validation_counts = NULL   # Whole-system counts for calibration
)

est_effort_camera(
  camera_counts,
  field_of_view_fraction,    # Proportion of total area visible
  calibration_method = c("ratio", "hierarchical_bayes"),
  whole_system_counts = NULL,
  by = NULL,
  svy = NULL
)
```

---

### 9. 🟢 **Hybrid Survey Design Support**

**Status:** Mentioned but not fully implemented
**Priority:** P2 - Advanced integration
**Effort:** 2-3 weeks
**Chapter Reference:** Table 17.4, Section 17.3.2

**Missing Components:**
- Bus route with interviews (McGlennon & Kinloch 1997)
- Access + Roving combined
- Aerial + On-site integration
- Camera + Creel + Aerial
- Postcard surveys
- Variance combination across multiple data sources

**Implementation:**
```r
design_hybrid(
  methods = c("access", "roving", "aerial", "camera", "postcard"),
  counts_list,               # Named list of count data by method
  interviews_list,           # Named list of interview data by method
  calendar,
  combination_method = c("hierarchical_bayes", "glm", "glmm"),
  weights = "auto"
)

est_effort_hybrid(
  design,
  method_weights = "auto",   # Effort-based or precision-based
  correlation_structure = NULL,
  by = NULL,
  svy = NULL
)
```

---

## PHASE 3 - Visualization & Reporting (4-6 weeks)

### 10. 🟡 **`plot_estimates_timeseries()`**

**Status:** Not implemented
**Priority:** P1 - Essential for reporting
**Effort:** 1-2 weeks

**Description:**
Professional time series visualization with confidence bands, faceting, and reference lines.

```r
plot_estimates_timeseries(
  estimates,
  x = "date",
  y = "estimate",
  ci = TRUE,
  facet_by = NULL,
  color_by = NULL,
  reference_line = NULL,
  theme = theme_tidycreel()
)
```

---

### 11. 🟡 **`plot_catch_composition()`**

**Status:** Not implemented
**Priority:** P1 - Common for multi-species fisheries
**Effort:** 1 week

**Description:**
Species composition visualization with confidence intervals.

```r
plot_catch_composition(
  catch_data,
  by = "species",
  type = "bar",              # "bar", "stacked", "pie", "treemap"
  proportional = FALSE,
  ci = TRUE,
  order_by = "estimate"
)
```

---

### 12. 🟢 **Diagnostic Plots**

**Status:** Not implemented
**Priority:** P2 - Enhance analysis quality
**Effort:** 2-3 weeks

**Needed Plots:**
- Residual plots for CPUE models
- Variance component visualization
- QA/QC diagnostic dashboards
- Outlier detection plots
- Coverage assessment maps
- Sample size simulation plots

```r
plot_diagnostics(
  effort_est,
  type = c("residuals", "qq", "influence", "coverage")
)

plot_variance_components(
  variance_decomp,
  type = c("nested_barplot", "table", "pie")
)

plot_qa_dashboard(
  qa_results,
  highlight = c("errors", "warnings")
)
```

---

## PHASE 4 - Documentation & Refinement (Ongoing)

### 13. 🔴 **Comprehensive Vignette Suite**

**Status:** Basic vignettes exist
**Priority:** P0 - Critical for adoption
**Effort:** Ongoing

**Missing Vignettes:**

1. **"Choosing the Right Design"** - Decision tree for method selection
2. **"Roving vs Access-Point Surveys"** - When to use each, variance implications
3. **"Sample Size Planning"** - Power analysis workflow
4. **"Data Quality Best Practices"** - Avoiding common mistakes (Table 17.3)
5. **"Angler Segmentation"** - How and when to stratify
6. **"Hybrid Designs"** - Combining multiple data sources
7. **"Understanding Variance"** - Variance decomposition and optimization
8. **"Species Aggregation"** - Using aggregate_cpue() correctly
9. **"Complete Workflow"** - End-to-end example with real data

---

### 14. 🟡 **Enhanced Data Validation**

**Status:** Basic validation exists
**Priority:** P1 - Part of QA/QC framework
**Effort:** Integrated with Item 2

Expand current validation in `R/data-schemas.R` and `R/validation.R`

---

### 15. 🟢 **Additional Helper Functions**

**Status:** Various
**Priority:** P2 - Nice to have
**Effort:** 1-2 weeks total

**Functions Needed:**
- `expand_party_to_angler()` - Convert party counts to angler counts
- `calc_angler_hours()` - Standardized effort calculation
- `standardize_species_codes()` - Species name harmonization
- `convert_units()` - Length/weight unit conversions
- `impute_missing_effort()` - Handle incomplete trip data
- `flag_outliers()` - Statistical outlier detection
- `merge_interview_biological()` - Link interview and bio data

---

## Implementation Timeline

### Sprint 1-2 (Weeks 1-4): Critical Foundations
- ✅ **Complete:** `aggregate_cpue()` and `est_total_harvest()`
- 🔲 Roving/incomplete trip estimators
- 🔲 QA/QC framework (Part 1: Core checks)

### Sprint 3-4 (Weeks 5-8): Variance & Planning
- 🔲 Variance component decomposition
- 🔲 Sample size determination tools
- 🔲 QA/QC framework (Part 2: Reporting)

### Sprint 5-6 (Weeks 9-12): Segmentation & Enhancement
- 🔲 Angler segmentation framework
- 🔲 Enhanced bus route estimator
- 🔲 Vignette suite (Part 1)

### Sprint 7-8 (Weeks 13-16): Advanced Methods
- 🔲 Aerial survey methods
- 🔲 Remote camera integration
- 🔲 Hybrid design support

### Sprint 9-10 (Weeks 17-20): Visualization
- 🔲 Time series plots
- 🔲 Composition plots
- 🔲 Diagnostic plots
- 🔲 Vignette suite (Part 2)

### Sprint 11-12 (Weeks 21-24): Polish & Testing
- 🔲 Helper functions
- 🔲 Enhanced validation
- 🔲 Comprehensive testing
- 🔲 Documentation completion
- 🔲 CRAN preparation

---

## Success Metrics

### Package Completeness Targets

**By End of Q1 2026:**
- Survey Design & Sampling: 95%
- Effort Estimation: 95%
- Catch/Harvest Estimation: 95%
- Quality Assurance/Control: 85%
- Variance Analysis: 90%
- Sample Size Planning: 85%
- Visualization: 80%
- Advanced Methods: 60%
- Documentation: 95%

**Overall Target:** 90% feature complete for standard creel survey workflows

### User Experience Metrics
- Users can complete full analysis from design → estimates → reporting
- Clear guidance for method selection
- Excellent error messages and warnings
- Comprehensive validation and QA/QC
- Professional visualizations
- Reproducible workflows

### Code Quality Metrics
- >90% test coverage
- All estimators validated against literature
- Comprehensive documentation
- Consistent API design
- Performance benchmarks

---

## Risk Assessment & Mitigation

### High Risk Items

**1. Roving Estimator Complexity**
- **Risk:** Statistical complexity, limited examples in literature
- **Mitigation:** Start with Pollock et al. (1997) canonical methods, extensive testing

**2. QA/QC False Positives**
- **Risk:** Overly strict checks frustrate users
- **Mitigation:** Severity levels (error/warning/info), comprehensive documentation

**3. Sample Size Tool Accuracy**
- **Risk:** Variance estimates from pilots may be unreliable
- **Mitigation:** Clear documentation of assumptions, sensitivity analysis

**4. Hybrid Design Integration**
- **Risk:** Multiple data sources create complex variance structure
- **Mitigation:** Start with simple combinations, leverage Bayesian approaches

**5. Documentation Completeness**
- **Risk:** Technical methods hard to explain
- **Mitigation:** Multiple vignettes, worked examples, decision trees

### Medium Risk Items

- Aerial survey inflation factors (method-specific, data-intensive)
- Camera integration (emerging tech, limited R packages)
- Angler segmentation (detection probability modeling complex)

### Mitigation Strategy
- Iterative development with user feedback
- Extensive testing against published examples
- Clear documentation of assumptions and limitations
- Vignettes with worked examples
- Regular consultation with creel survey practitioners

---

## Key References for Implementation

### Critical Papers

1. **Pollock et al. (1994)** - *Angler Survey Methods and Their Applications* - Foundation
2. **Pollock et al. (1997)** - Incomplete trip/roving methods
3. **Robson (1961)** - Progressive count theory
4. **Malvestuto (1996)** - Review of creel survey methods
5. **Rasmussen et al. (1998)** - Three-stage sampling variance
6. **Newman et al. (1997)** - Precision and sample size
7. **Hoenig et al. (1993, 1997)** - Instantaneous counts, trip truncation
8. **McGlennon & Kinloch (1997)** - Bus route with interviews
9. **van Poorten et al. (2015)** - Camera-based estimation with missing data
10. **Malvestuto et al. (1978)** - Bus route with unequal probabilities
11. **Vølstad et al. (2006)** - Aerial survey methods
12. **McCormick & Meyer (2017)** - Sample size determination
13. **Askey et al. (2018)** - Modern aerial survey applications

### Textbook
- **Pope et al. (2025)** - Chapter 17: Creel Surveys in *Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition*

---

## Notes

### Design Philosophy
- **Survey-first:** Leverage R's survey package for design-based inference
- **Tidy workflows:** Pipe-friendly, consistent return schemas
- **Validation by default:** Comprehensive checks, informative errors
- **Reproducibility:** Document workflows, enable reproducible analyses
- **Modern R:** Use current best practices, maintain code quality

### Community Engagement
- Seek feedback from practicing creel biologists
- Present at fisheries conferences
- Publish methods paper
- Engage with state/federal agencies
- Build example datasets

### Long-Term Vision
Position tidycreel as:
- **The** R solution for creel surveys
- Comprehensive alternative to specialized software
- Integration point for emerging technologies
- Teaching tool for survey methods
- Platform for methodological innovation

---

**Last Updated:** October 24, 2025
**Next Review:** Monthly or after major milestones
**Maintained by:** tidycreel development team
