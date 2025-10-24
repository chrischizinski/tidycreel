# tidycreel Development Roadmap
## Comprehensive Feature Planning & Gap Analysis

**Last Updated:** October 24, 2025
**Status:** Package is ~70% complete for basic creel analysis
**Next Major Milestone:** Complete core estimation workflow with total harvest

---

## Executive Summary

### Current State Assessment

**Strengths (What We Have):**
- ✅ 48 exported functions with robust survey-first architecture
- ✅ Core effort estimation methods (instantaneous, progressive, aerial, bus route)
- ✅ CPUE estimation with multiple approaches (ratio-of-means, mean-of-ratios, auto mode)
- ✅ Basic catch estimation from interview data
- ✅ Survey design integration (`as_day_svydesign`, replicate designs)
- ✅ Comprehensive validation framework
- ✅ Basic visualization (`plot_design`, `plot_effort`)
- ✅ Excellent documentation structure and vignettes

**Critical Gap Identified:**
The package lacks **total harvest estimation** (effort × CPUE), which is the PRIMARY outcome of most creel surveys. Users can estimate effort and CPUE separately, but there's no function to properly combine them with variance propagation using the delta method.

**Completeness Assessment:**
- **Survey Design & Sampling:** 90% complete
- **Effort Estimation:** 85% complete (missing tie-in estimators, party expansion)
- **Catch/Harvest Estimation:** 60% complete (missing total harvest calculation)
- **Biological Data Analysis:** 20% complete (length frequencies not implemented)
- **Visualization & Reporting:** 40% complete (basic plots only)
- **Data Quality Tools:** 70% complete (validation exists, diagnostics limited)
- **Survey Planning Tools:** 10% complete (no sample size calculators)

---

## Top 10 Priority Functions

### PHASE 1 - Critical Missing Pieces (Immediate Priority - Next 4-6 weeks)

#### 1. 🔴 **`est_total_harvest()`** - HIGHEST PRIORITY

**Status:** Not implemented
**Priority:** P0 - Blocking users from completing analyses
**Effort:** 2-3 weeks (including tests, vignette, validation)

**Description:**
Combines effort and CPUE estimates to calculate total harvest with proper variance propagation using the delta method.

**Function Signature:**
```r
est_total_harvest(
  effort_est,           # Tibble from est_effort()
  cpue_est,             # Tibble from est_cpue()
  by = NULL,            # Grouping variables (must match between inputs)
  method = "product",   # "product", "ratio_est", "separate_ratio"
  correlation = NULL,   # Optional correlation between effort and CPUE
  conf_level = 0.95
)
```

**Returns:**
Tibble with schema: `[grouping_vars], estimate, se, ci_low, ci_high, n, method, diagnostics`

**Statistical Methods:**
- **Product estimator:** `H = E × C` where E = effort, C = CPUE
- **Delta method variance:** `Var(H) ≈ E² × Var(C) + C² × Var(E) + 2 × E × C × Cov(E,C)`
- **Correlation handling:** When effort and CPUE from same survey, estimate correlation; otherwise assume independent

**Implementation Notes:**
- Must handle grouped estimates (join on grouping variables)
- Validate that grouping variables match between inputs
- Propagate diagnostics from both input estimates
- Handle NA values gracefully
- Provide informative error messages for common mistakes

**Testing Strategy:**
- Unit tests with known variance propagation
- Compare to manual calculations
- Test with correlated and uncorrelated inputs
- Test grouped and ungrouped estimates
- Edge cases: zero effort, zero CPUE, single group

**Documentation:**
- Comprehensive vignette showing complete workflow: design → effort → CPUE → total harvest
- Mathematical notation for variance formulas
- When to use each method
- Interpretation guidance

**Success Metrics:**
- Function implemented and passing all tests
- Vignette demonstrating end-to-end workflow
- Matches hand calculations for test cases
- User can complete full creel analysis from start to finish

---

#### 2. 🟡 **`expand_party_to_angler()`**

**Status:** Not implemented
**Priority:** P1 - Commonly needed, workarounds exist
**Effort:** 1 week

**Description:**
Converts party-based counts to angler counts for accurate effort estimation. Many surveys record counts by party/boat rather than individual anglers.

**Function Signature:**
```r
expand_party_to_angler(
  data,
  party_col = "parties_count",
  angler_col = "anglers_count",
  by = NULL,                    # Stratification variables
  method = "mean_ratio",        # "mean_ratio", "weighted", "stratified"
  expansion_source = NULL       # Optional interview data for ratios
)
```

**Methods:**
- **Mean ratio:** Mean anglers per party from interviews, apply to counts
- **Weighted:** Survey-weighted mean expansion factor
- **Stratified:** Separate ratios by strata (e.g., weekday/weekend, mode)

**Use Cases:**
- Boat counts → angler counts
- Party counts → angler counts
- Vehicle counts → angler counts (with occupancy data)

---

#### 3. 🟡 **`plot_estimates_timeseries()`**

**Status:** Not implemented
**Priority:** P1 - Essential for reporting
**Effort:** 1-2 weeks

**Description:**
Professional time series visualization with confidence bands, faceting, and reference lines.

**Function Signature:**
```r
plot_estimates_timeseries(
  estimates,            # Tibble from estimation functions
  x = "date",
  y = "estimate",
  ci = TRUE,
  ci_alpha = 0.2,
  facet_by = NULL,      # e.g., "species", "location"
  color_by = NULL,
  reference_line = NULL,
  title = NULL,
  theme = theme_tidycreel()
)
```

**Features:**
- Confidence bands with customizable transparency
- Automatic date formatting for x-axis
- Faceting by categorical variables
- Reference lines (e.g., historical average, management target)
- Consistent tidycreel theme
- Export-ready quality (print, reports, presentations)

**Example Output:**
```r
# Time series of effort by location
effort_est %>%
  plot_estimates_timeseries(
    x = "date",
    facet_by = "location",
    title = "Fishing Effort by Access Point"
  )
```

---

#### 4. 🟡 **`plot_catch_composition()`**

**Status:** Not implemented
**Priority:** P1 - Common output for multi-species fisheries
**Effort:** 1 week

**Description:**
Species composition visualization with confidence intervals, supporting multiple display formats.

**Function Signature:**
```r
plot_catch_composition(
  catch_data,
  by = "species",
  type = "bar",           # "bar", "stacked", "pie", "treemap"
  proportional = FALSE,   # Show as proportions vs absolute
  ci = TRUE,
  order_by = "estimate",  # "estimate", "alphabetical", "manual"
  palette = NULL
)
```

**Features:**
- Multiple visualization types
- Error bars on bar charts
- Proportional and absolute scales
- Custom ordering and colors
- Legend management

---

#### 5. 🟢 **`compare_estimates()`**

**Status:** Not implemented
**Priority:** P2 - Useful for sensitivity analysis
**Effort:** 1 week

**Description:**
Side-by-side comparison of different estimation methods, models, or time periods.

**Function Signature:**
```r
compare_estimates(
  estimate_list,        # Named list of estimate tibbles
  metric = "estimate",
  show_ci = TRUE,
  format = "table",     # "table", "plot", "both"
  test_differences = FALSE
)
```

**Outputs:**
- Comparison table with all estimates
- Optional forest plot showing estimates with CIs
- Difference calculations with significance tests
- Relative differences (% change)

**Use Cases:**
- Compare ratio-of-means vs mean-of-ratios
- Compare years (2024 vs 2023)
- Sensitivity to design assumptions
- Method validation

---

### PHASE 2 - Survey Planning & Advanced Methods (Months 2-3)

#### 6. 🟢 **`est_effort_tiein()`**

**Status:** Not implemented
**Priority:** P2 - Classic methodology, some agencies require
**Effort:** 2-3 weeks

**Description:**
Classic Robson & Jones (1989) tie-in estimator combining interview and count data.

**Function Signature:**
```r
est_effort_tiein(
  interviews,
  counts,
  svy_day,
  by = c("date", "location"),
  party_hours_col = "hours_fished",
  count_col = "parties_count",
  method = "traditional"  # "traditional", "stratified"
)
```

**Statistical Method:**
1. From interviews: estimate mean party hours per unit time
2. From counts: total parties observed
3. Product: total effort = mean party hours × total parties
4. Variance via delta method

**References:**
- Robson & Jones (1989) - "The Theoretical Basis of an Access Site Angler Survey Design"
- Pollock et al. (1994) - "Angler Survey Methods and Their Applications in Fisheries Management"

---

#### 7. 🟢 **`calc_sample_size()`**

**Status:** Not implemented
**Priority:** P2 - Essential for survey planning
**Effort:** 2 weeks

**Description:**
Power analysis and sample size determination for creel surveys.

**Function Signature:**
```r
calc_sample_size(
  target_cv = 0.2,        # Target coefficient of variation
  expected_mean = NULL,   # Expected estimate value
  expected_sd = NULL,     # Expected standard deviation
  power = 0.8,
  alpha = 0.05,
  design_effect = 1.5,    # Clustering effect
  finite_pop = FALSE,     # Apply FPC?
  method = "cv"           # "cv", "power", "precision"
)
```

**Methods:**
- **CV-based:** Determine n for target CV
- **Power-based:** Detect minimum effect size
- **Precision-based:** Achieve target CI width

**Outputs:**
- Required sample size
- Expected precision
- Design effect adjustment
- Budget implications (if costs provided)

---

#### 8. 🟢 **`sample_allocation()`**

**Status:** Not implemented
**Priority:** P2 - Optimize survey design
**Effort:** 1-2 weeks

**Description:**
Optimal allocation of sampling effort across strata.

**Function Signature:**
```r
sample_allocation(
  total_n,
  strata_sizes,         # Population sizes by stratum
  strata_variance,      # Expected variance by stratum
  method = "neyman",    # "neyman", "proportional", "equal", "cost_optimal"
  costs = NULL,         # Relative costs by stratum
  min_per_stratum = 2   # Minimum sample per stratum
)
```

**Methods:**
- **Neyman allocation:** Minimize variance for fixed n
- **Proportional:** Allocate proportional to stratum size
- **Equal:** Equal samples per stratum
- **Cost-optimal:** Minimize cost for target precision

**Use Cases:**
- Allocate interview days across weekday/weekend
- Distribute effort across access points
- Balance temporal coverage (months, seasons)

---

#### 9. 🟢 **`est_length_dist()`**

**Status:** Not implemented
**Priority:** P2 - Common biological data analysis
**Effort:** 2 weeks

**Description:**
Survey-weighted length frequency distribution with proper variance estimation.

**Function Signature:**
```r
est_length_dist(
  length_data,
  svy_design,
  by = NULL,
  bins = NULL,            # Or specify breaks
  min_length = NULL,
  max_length = NULL,
  bin_width = 10,         # mm or cm
  proportional = FALSE
)
```

**Features:**
- Survey-weighted frequencies
- Variance estimation for each bin
- Flexible binning strategies
- Handles multiple species
- Integration with length-weight relationships

**Outputs:**
- Length frequency table with CIs
- Mean length by group
- Size structure metrics (PSD, RSD)

---

#### 10. 🟢 **`creel_report()`**

**Status:** Not implemented
**Priority:** P2 - Automate routine reporting
**Effort:** 3-4 weeks

**Description:**
Automated comprehensive report generation for creel surveys.

**Function Signature:**
```r
creel_report(
  design,
  interviews,
  counts,
  calendar,
  output_file = "creel_report.html",
  template = "standard",  # "standard", "detailed", "summary", "custom"
  include_sections = c("effort", "cpue", "catch", "length", "diagnostics"),
  custom_sections = NULL,
  parameters = list()     # Report parameters (title, dates, waterbody, etc.)
)
```

**Report Sections:**
- Executive summary with key findings
- Survey design description
- Data quality metrics
- Effort estimates with temporal patterns
- CPUE by species/group
- Total harvest estimates
- Length distributions
- Diagnostic plots
- Methods and references

**Output Formats:**
- HTML (interactive, embedded plots)
- PDF (print-ready)
- Word (editable)

**Template System:**
- Built-in templates for common report types
- Customizable via Quarto/RMarkdown
- Agency-specific branding options

---

## Additional Functions by Category

### Data Quality & QA/QC

#### `detect_outliers()`
**Priority:** P3
**Effort:** 1 week

Identify and flag outliers in creel data using multiple methods.

```r
detect_outliers(
  data,
  vars = c("catch_total", "hours_fished", "cpue"),
  method = "iqr",         # "iqr", "mad", "dixon", "grubbs", "mahalanobis"
  action = "flag",        # "flag", "remove", "winsorize"
  multiplier = 3,
  by = NULL               # Group-specific outlier detection
)
```

**Methods:**
- IQR rule (Q1 - k×IQR, Q3 + k×IQR)
- MAD (median absolute deviation)
- Dixon's Q test
- Grubbs' test
- Multivariate (Mahalanobis distance)

---

#### `survey_coverage_report()`
**Priority:** P3
**Effort:** 1 week

Assess temporal and spatial coverage of survey effort.

```r
survey_coverage_report(
  calendar,
  actual_days,
  target_coverage = 0.8,
  by = c("month", "day_type", "location"),
  visualize = TRUE
)
```

**Metrics:**
- Percent of strata sampled
- Days sampled per stratum
- Gap analysis (unsampled periods)
- Coverage uniformity index
- Recommendations for additional sampling

---

#### `qa_report()`
**Priority:** P3
**Effort:** 2 weeks

Comprehensive data quality report.

```r
qa_report(
  interviews,
  counts,
  calendar,
  checks = "all",         # Specify which checks to run
  output_format = "html"
)
```

**Checks:**
- Missing data patterns
- Duplicate detection
- Date/time consistency
- Outlier flagging
- Cross-table validation (interviews match calendar dates)
- Species code validation
- Effort unit consistency
- Interview quality metrics (response rate, refusals)

---

### Biological Extensions

#### `est_mean_length()`
**Priority:** P3
**Effort:** 1 week

Survey-weighted mean length by group.

```r
est_mean_length(
  length_data,
  svy_design,
  by = c("species"),
  length_col = "length_mm",
  conf_level = 0.95
)
```

---

#### `create_age_length_key()`
**Priority:** P4 (specialized)
**Effort:** 2 weeks

Create and apply age-length keys for age composition estimation.

```r
create_age_length_key(
  aged_sample,
  length_bins,
  method = "traditional"  # "traditional", "smooth"
)
```

---

#### `est_mortality_proxy()`
**Priority:** P4 (specialized)
**Effort:** 2 weeks

Estimate fishing mortality indices from catch rates.

```r
est_mortality_proxy(
  catch_data,
  effort_data,
  by = "year",
  method = "catch_rate"   # "catch_rate", "exploitation_rate"
)
```

---

### Advanced Diagnostics

#### `model_diagnostics()`
**Priority:** P3
**Effort:** 2 weeks

Residual analysis and goodness-of-fit tests.

```r
model_diagnostics(
  estimates,
  data,
  tests = c("shapiro", "ks", "levene"),
  plot = TRUE
)
```

**Diagnostics:**
- Residual plots
- Q-Q plots
- Leverage and influence
- Goodness-of-fit tests
- Variance homogeneity

---

#### `bootstrap_estimates()`
**Priority:** P3
**Effort:** 2 weeks

Bootstrap resampling for robust confidence intervals.

```r
bootstrap_estimates(
  estimator_function,
  data,
  svy_design,
  n_boot = 1000,
  method = "stratified",  # "stratified", "cluster", "simple"
  parallel = TRUE
)
```

---

#### `sensitivity_analysis()`
**Priority:** P3
**Effort:** 2 weeks

Systematically vary assumptions and assess impact.

```r
sensitivity_analysis(
  estimator_function,
  data,
  parameters,
  ranges,               # Parameter ranges to test
  metrics = c("estimate", "cv", "ci_width")
)
```

---

### Multi-year Analysis

#### `combine_years()`
**Priority:** P3
**Effort:** 2 weeks

Meta-analysis combining multiple years of data.

```r
combine_years(
  year_list,            # List of annual estimates
  method = "meta",      # "meta", "pooled", "average"
  weights = NULL,       # Optional weights (e.g., by precision)
  test_homogeneity = TRUE
)
```

---

#### `trend_analysis()`
**Priority:** P3
**Effort:** 2-3 weeks

Temporal trend estimation with survey design.

```r
trend_analysis(
  multi_year_data,
  response,
  time_var = "year",
  by = NULL,
  method = "regression", # "regression", "mann_kendall", "loess"
  svy_design = NULL
)
```

**Methods:**
- Survey-weighted regression
- Mann-Kendall trend test
- Locally weighted smoothing (LOESS)
- Change point detection

---

#### `detect_changepoints()`
**Priority:** P4 (specialized)
**Effort:** 2 weeks

Identify regime shifts in time series data.

```r
detect_changepoints(
  time_series_data,
  response,
  method = "pettitt",    # "pettitt", "bcp", "segmented"
  confidence = 0.95
)
```

---

## Enhanced Visualization Suite

### Priority Plots (Beyond Top 10)

#### `plot_effort_distribution()`
**Priority:** P2
**Effort:** 1 week

Visualize effort distribution by time/space.

```r
plot_effort_distribution(
  effort_data,
  type = "histogram",    # "histogram", "density", "violin"
  by = NULL,
  overlay_normal = FALSE
)
```

---

#### `plot_model_comparison()`
**Priority:** P2
**Effort:** 1 week

Visual comparison of different models/methods.

```r
plot_model_comparison(
  model_results,
  type = "forest",       # "forest", "bar", "table"
  metric = "estimate",
  show_aic = TRUE
)
```

**Outputs:**
- Forest plot with estimates and CIs
- AIC comparison table
- Relative effect sizes

---

#### `plot_length_frequency()`
**Priority:** P2
**Effort:** 1 week

Length frequency histograms with confidence intervals.

```r
plot_length_frequency(
  length_data,
  by = NULL,
  bins = 20,
  ci = TRUE,
  reference_lengths = NULL  # e.g., size limits
)
```

---

#### `plot_catch_map()` (Spatial)
**Priority:** P4 (if spatial scope expands)
**Effort:** 2 weeks

Spatial distribution of catch/effort.

```r
plot_catch_map(
  catch_data,
  locations,            # Spatial coordinates
  metric = "cpue",
  map_type = "point"    # "point", "heatmap", "polygon"
)
```

---

## Implementation Strategy

### Development Phases

#### **SPRINT 1: Critical Gap Closure (Weeks 1-4)**

**Goal:** Enable users to complete full creel analysis workflow

**Deliverables:**
1. `est_total_harvest()` implemented with tests
2. `expand_party_to_angler()` implemented with tests
3. Comprehensive vignette: "Complete Creel Analysis Workflow"
4. Update getting-started vignette with harvest example

**Success Criteria:**
- [ ] User can estimate total harvest from effort and CPUE
- [ ] Variance properly propagated using delta method
- [ ] All tests passing with >90% coverage
- [ ] Vignette demonstrates end-to-end analysis
- [ ] Documentation reviewed by fisheries expert

---

#### **SPRINT 2: Visualization & Communication (Weeks 5-7)**

**Goal:** Professional-quality plots for reports and presentations

**Deliverables:**
1. `plot_estimates_timeseries()` - time series with CIs
2. `plot_catch_composition()` - species composition
3. `compare_estimates()` - model comparison
4. Visualization vignette with examples
5. Consistent tidycreel theme

**Success Criteria:**
- [ ] Plots ready for publication/reports
- [ ] Consistent styling across all plots
- [ ] Export to common formats (PNG, PDF, SVG)
- [ ] Examples in vignettes
- [ ] User feedback incorporated

---

#### **SPRINT 3: Survey Planning Tools (Weeks 8-11)**

**Goal:** Support survey design and optimization

**Deliverables:**
1. `calc_sample_size()` - power analysis
2. `sample_allocation()` - optimal allocation
3. `survey_coverage_report()` - QA/QC
4. Survey planning vignette

**Success Criteria:**
- [ ] Sample size calculations match published methods
- [ ] Allocation algorithms validated
- [ ] Coverage reports actionable
- [ ] Integrated into design workflow

---

#### **SPRINT 4: Advanced Methods (Weeks 12-16)**

**Goal:** Classic methods and biological extensions

**Deliverables:**
1. `est_effort_tiein()` - Robson & Jones methodology
2. `est_length_dist()` - length frequencies
3. `est_mean_length()` - mean length estimation
4. Biological data vignette

**Success Criteria:**
- [ ] Tie-in estimates match published examples
- [ ] Length distributions properly weighted
- [ ] Integration with size limit regulations
- [ ] Validated against known datasets

---

#### **SPRINT 5: Reporting & Automation (Weeks 17-21)**

**Goal:** Automated report generation

**Deliverables:**
1. `creel_report()` - comprehensive reports
2. Report templates (standard, detailed, summary)
3. Customization guide
4. Example reports

**Success Criteria:**
- [ ] HTML/PDF reports generated automatically
- [ ] Templates cover common use cases
- [ ] Customization straightforward
- [ ] Agency adoption

---

#### **SPRINT 6: Data Quality & Diagnostics (Weeks 22-26)**

**Goal:** Robust QA/QC and diagnostic tools

**Deliverables:**
1. `detect_outliers()` - outlier detection
2. `qa_report()` - comprehensive QA
3. `model_diagnostics()` - goodness-of-fit
4. Quality assurance vignette

**Success Criteria:**
- [ ] Outlier detection algorithms validated
- [ ] QA reports catch common errors
- [ ] Diagnostics guide interpretation
- [ ] Integration into workflow

---

### Design Principles

#### 1. **Survey-First Consistency**
All functions must integrate seamlessly with the `survey` package:
- Accept `svydesign`/`svrepdesign` objects
- Return consistent tibble schema
- Preserve survey design properties
- Support replicate weights

**Standard Return Schema:**
```r
tibble(
  [grouping_vars],
  estimate,
  se,
  ci_low,
  ci_high,
  n,
  method,
  diagnostics  # list-column with additional info
)
```

---

#### 2. **Composability & Pipe-Friendliness**
Functions should work together seamlessly:
```r
# Example: Complete workflow
svy_day %>%
  est_effort(counts, method = "instantaneous") %>%
  combine_with_cpue(cpue_est) %>%
  est_total_harvest() %>%
  plot_estimates_timeseries(facet_by = "location")
```

---

#### 3. **Defensive Programming**
- Validate inputs rigorously
- Informative error messages (use `cli` package)
- Warn about potential issues (lonely PSUs, small samples)
- Handle edge cases gracefully (zero values, missing data)
- Document assumptions clearly

**Example Error Message:**
```r
if (!all(by %in% names(effort_est))) {
  cli::cli_abort(c(
    "x" = "Grouping variables not found in effort estimates.",
    "i" = "Available variables: {.field {names(effort_est)}}",
    "!" = "Missing: {.field {setdiff(by, names(effort_est))}}"
  ))
}
```

---

#### 4. **Performance Considerations**
- Vectorize operations (avoid loops)
- Use grouped operations (`dplyr::group_by()` + `summarise()`)
- Lazy evaluation where possible
- Profile bottlenecks for large datasets
- Consider parallel processing for bootstrap/permutation tests

---

#### 5. **Testing Strategy**

**Test Coverage Targets:**
- Unit tests: >90% coverage for all functions
- Integration tests: Complete workflows
- Validation tests: Compare to published results
- Edge case tests: Extreme values, missing data, single groups

**Test Data:**
- Synthetic data with known properties
- Published datasets with expected results
- Edge cases and boundary conditions

**Example Test Structure:**
```r
test_that("est_total_harvest multiplies effort and CPUE", {
  # Known inputs
  effort <- tibble(estimate = 1000, se = 100, species = "bass")
  cpue <- tibble(estimate = 2, se = 0.2, species = "bass")

  # Expected output
  expected_harvest <- 2000
  expected_se <- sqrt(1000^2 * 0.2^2 + 2^2 * 100^2)  # Delta method

  # Actual
  result <- est_total_harvest(effort, cpue, by = "species")

  # Assertions
  expect_equal(result$estimate, expected_harvest)
  expect_equal(result$se, expected_se, tolerance = 0.01)
})
```

---

#### 6. **Documentation Standards**

**Required for Each Function:**
- Clear purpose statement
- Parameter descriptions with types and defaults
- Return value schema
- Statistical methods with references
- Examples using toy data
- Common use cases
- Edge cases and limitations

**Vignette Structure:**
- Introduction with learning objectives
- Conceptual overview
- Step-by-step examples
- Real-world applications
- Troubleshooting common issues
- References to literature

---

## Priority Matrix

### P0 - Blocking (Must have immediately)
- `est_total_harvest()` - Can't complete analyses without this

### P1 - High Priority (Next 2 months)
- `expand_party_to_angler()` - Common preprocessing need
- `plot_estimates_timeseries()` - Essential for communication
- `plot_catch_composition()` - Multi-species fisheries
- `compare_estimates()` - Method validation

### P2 - Medium Priority (Months 3-5)
- `est_effort_tiein()` - Classic methodology
- `calc_sample_size()` - Survey planning
- `sample_allocation()` - Design optimization
- `est_length_dist()` - Biological data
- `creel_report()` - Automated reporting

### P3 - Nice to Have (Months 6-12)
- QA/QC tools (`detect_outliers()`, `qa_report()`)
- Advanced diagnostics (`model_diagnostics()`, `bootstrap_estimates()`)
- Multi-year analysis (`combine_years()`, `trend_analysis()`)
- Enhanced visualizations

### P4 - Specialized (Future consideration)
- Age composition estimators
- Economic valuation
- Spatial analysis tools
- Mortality proxies

---

## Success Metrics

### Package Completeness
- [ ] 100% of core creel workflow implemented
- [ ] 85%+ of common use cases supported
- [ ] <5 critical missing features

### Code Quality
- [ ] >90% test coverage
- [ ] All functions documented with examples
- [ ] Zero ERROR/WARNING/NOTE in R CMD check
- [ ] Passes lintr style checks

### User Adoption
- [ ] >10 successful analyses by external users
- [ ] Positive feedback from fisheries professionals
- [ ] Agency adoption (at least 1 state/federal agency)
- [ ] Published analyses using the package

### Performance
- [ ] Handles datasets up to 100K interviews efficiently (<10s)
- [ ] Parallel processing for computationally intensive operations
- [ ] Memory-efficient for large simulations

---

## Risk Assessment

### Technical Risks

**Risk:** Variance propagation errors in total harvest estimation
- **Likelihood:** Medium
- **Impact:** High (incorrect inference)
- **Mitigation:** Extensive testing against known results, peer review by statistician

**Risk:** Survey design edge cases (lonely PSUs, single-stratum)
- **Likelihood:** High
- **Impact:** Medium (estimation fails)
- **Mitigation:** Robust error handling, clear warnings, documented solutions

**Risk:** Performance degradation with large datasets
- **Likelihood:** Medium
- **Impact:** Medium (user frustration)
- **Mitigation:** Profiling, optimization, parallel processing

### Adoption Risks

**Risk:** Learning curve too steep for target users
- **Likelihood:** Medium
- **Impact:** High (low adoption)
- **Mitigation:** Comprehensive vignettes, workshops, support

**Risk:** Competition from established tools (FSA, RMark, custom scripts)
- **Likelihood:** High
- **Impact:** Medium (slow adoption)
- **Mitigation:** Clear advantages (survey-first, modern, documented), migration guides

---

## Dependencies

### Current Dependencies (Keep Lean)
- **survey** - Core survey design and estimation
- **dplyr** - Data manipulation
- **tidyr** - Data tidying
- **ggplot2** - Visualization
- **cli** - User communication
- **tibble** - Modern data frames
- **purrr** - Functional programming

### Potential New Dependencies (Evaluate Carefully)
- **scales** - Axis formatting (ggplot2 extension)
- **patchwork** - Combine plots
- **gt** or **flextable** - Publication-quality tables
- **quarto** or **rmarkdown** - Report generation
- **future** - Parallel processing backend

### Avoid Unless Essential
- Heavy spatial packages (sf, terra) - only if spatial scope expands
- Database backends - only if needed for large data
- Shiny - keep separate from core package

---

## References & Resources

### Statistical Methods
- Pollock, K. H., C. M. Jones, and T. L. Brown. 1994. "Angler Survey Methods and Their Applications in Fisheries Management." American Fisheries Society Special Publication 25.
- Robson, D. S., and C. M. Jones. 1989. "The Theoretical Basis of an Access Site Angler Survey Design." Biometrics 45:83-98.
- Lumley, T. 2010. "Complex Surveys: A Guide to Analysis Using R." Wiley.

### R Package Development
- Wickham, H., and J. Bryan. "R Packages" (2nd ed.). https://r-pkgs.org
- Tidyverse Style Guide: https://style.tidyverse.org

### Survey Package Resources
- survey package documentation: https://r-survey.r-forge.r-project.org/survey/
- Survey analysis in R tutorial: https://stats.idre.ucla.edu/r/seminars/survey-data-analysis-with-r/

---

## Changelog

### October 24, 2025 - Initial Roadmap
- Completed comprehensive gap analysis
- Identified top 10 priority functions
- Defined 6-sprint development plan (26 weeks)
- Established design principles and testing strategy

### Next Review: November 2025
- Assess Sprint 1 progress
- Adjust priorities based on user feedback
- Update timelines if needed

---

## Contributing

This roadmap is a living document. Contributions and feedback are welcome:

1. **Function Priorities:** Disagree with priorities? Open an issue to discuss.
2. **New Features:** Suggest additional functions with use case justification.
3. **Implementation:** Pick a function and submit a PR following design principles.
4. **Testing:** Help validate implementations against published results.

**Contact:** See CONTRIBUTING.md for guidelines.

---

## Appendix: Function Quick Reference

### Effort Estimation
- ✅ `est_effort()` - Wrapper for effort estimation
- ✅ `est_effort.instantaneous()` - Snapshot counts
- ✅ `est_effort.progressive()` - Roving surveys
- ✅ `est_effort.aerial()` - Aerial counts
- ✅ `est_effort.busroute()` - Bus route method
- 🔴 `est_effort_tiein()` - Tie-in estimator (NOT IMPLEMENTED)

### Catch & Harvest
- ✅ `est_cpue()` - Catch per unit effort
- ✅ `est_catch()` - Total catch from interviews
- 🔴 `est_total_harvest()` - Effort × CPUE (NOT IMPLEMENTED)

### Data Preprocessing
- 🔴 `expand_party_to_angler()` - Party to angler conversion (NOT IMPLEMENTED)
- ✅ `parse_time_column()` - Time parsing
- ✅ `standardize_time_columns()` - Time standardization

### Survey Design
- ✅ `as_day_svydesign()` - Create day-level design
- ✅ `as_survey_design()` - Convert to survey design
- ✅ `as_svrep_design()` - Convert to replicate design
- ✅ `design_access()` - Access point design (legacy)
- ✅ `design_roving()` - Roving design (legacy)
- ✅ `design_busroute()` - Bus route design

### Visualization
- ✅ `plot_design()` - Visualize survey design
- ✅ `plot_effort()` - Plot effort estimates
- 🔴 `plot_estimates_timeseries()` - Time series with CIs (NOT IMPLEMENTED)
- 🔴 `plot_catch_composition()` - Species composition (NOT IMPLEMENTED)
- 🔴 `plot_model_comparison()` - Compare models (NOT IMPLEMENTED)
- 🔴 `plot_length_frequency()` - Length distributions (NOT IMPLEMENTED)

### Survey Planning
- 🔴 `calc_sample_size()` - Sample size calculation (NOT IMPLEMENTED)
- 🔴 `sample_allocation()` - Optimal allocation (NOT IMPLEMENTED)

### Data Quality
- ✅ `validate_interviews()` - Interview validation
- ✅ `validate_counts()` - Count validation
- ✅ `validate_calendar()` - Calendar validation
- 🔴 `detect_outliers()` - Outlier detection (NOT IMPLEMENTED)
- 🔴 `qa_report()` - Quality assurance report (NOT IMPLEMENTED)

### Biological Data
- 🔴 `est_length_dist()` - Length frequency (NOT IMPLEMENTED)
- 🔴 `est_mean_length()` - Mean length (NOT IMPLEMENTED)

### Analysis & Comparison
- 🔴 `compare_estimates()` - Compare estimates (NOT IMPLEMENTED)
- 🔴 `model_diagnostics()` - Model diagnostics (NOT IMPLEMENTED)
- 🔴 `trend_analysis()` - Temporal trends (NOT IMPLEMENTED)

### Reporting
- 🔴 `creel_report()` - Automated reports (NOT IMPLEMENTED)

**Legend:**
- ✅ Implemented
- 🔴 Not implemented
- 🟡 Partially implemented

---

**End of Roadmap**
