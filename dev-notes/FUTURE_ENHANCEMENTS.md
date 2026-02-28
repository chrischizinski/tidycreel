# Future Enhancements for tidycreel

## 📊 Survey Table Integration (High Priority)

### Overview
[surveytable](https://github.com/CDCgov/surveytable) is a CDC package that builds on the survey package to provide publication-ready tables with minimal code.

### Why This Matters for tidycreel
- **Complementary**: surveytable focuses on presentation, we focus on estimation
- **Publication-ready**: Generates formatted tables with CI, SE automatically
- **Quality Assurance**: Built-in low-precision flagging (NCHS algorithms)
- **Output Flexibility**: HTML, PDF, Excel export

### Key Functions We Could Leverage
1. **Tabulation**: Estimated counts and percentages with CIs
2. **Summary Statistics**: For numeric variables
3. **Hypothesis Testing**: Built-in testing capabilities
4. **Reliability Flagging**: Automatic low-precision warnings

### Integration Approach

#### Option 1: Wrapper Functions
Create tidycreel wrappers that convert our estimator output to surveytable format:

```r
#' Present tidycreel Results as Publication-Ready Table
#'
#' Converts tidycreel estimation results to publication-ready tables
#' using the surveytable package.
#'
#' @param tidycreel_result Output from any tidycreel estimator
#' @param format Output format: "html", "pdf", "excel"
#' @param precision_flags Logical, include precision warnings
#'
#' @export
tc_present_table <- function(tidycreel_result,
                             format = c("html", "pdf", "excel"),
                             precision_flags = TRUE) {

  # Convert tidycreel result to surveytable format
  # Apply formatting
  # Add precision flags if requested
  # Generate publication-ready output
}
```

#### Option 2: Direct Integration
Add surveytable capabilities directly to estimator functions:

```r
est_effort.instantaneous <- function(
  ...,
  variance_method = "survey",
  present_as_table = FALSE,    # NEW
  table_format = "html"         # NEW
) {

  # Standard estimation
  result <- ...

  # If table presentation requested
  if (present_as_table) {
    result <- tc_present_table(result, format = table_format)
  }

  return(result)
}
```

#### Option 3: Separate Presentation Layer
Keep estimation and presentation separate (RECOMMENDED):

```r
# Estimation (what we have now)
effort_est <- est_effort.instantaneous(counts, svy = design)

# Presentation (new layer)
tc_present(effort_est, format = "html", precision_flags = TRUE)
```

### Benefits of Integration

1. **Publication-Ready Output**: Users get formatted tables immediately
2. **Quality Assurance**: Automatic precision warnings
3. **Standardization**: CDC-vetted presentation standards
4. **Flexibility**: Multiple output formats (HTML, PDF, Excel)
5. **Best Practices**: Built-in best practices for survey reporting

### Implementation Timeline

**Phase 1** (After current rebuild complete):
- Evaluate surveytable capabilities thoroughly
- Design integration architecture
- Create prototype wrapper functions

**Phase 2**:
- Implement tc_present_table() function
- Add surveytable to Suggests dependencies
- Create vignette: "Publication-Ready Output with surveytable"

**Phase 3**:
- Integrate precision flagging into tidycreel output
- Add table formatting options to print methods
- Enhanced export capabilities

### Considerations

**Dependencies**:
- Add surveytable to Suggests (not Imports) to keep it optional
- Graceful fallback if surveytable not installed

**Design Philosophy**:
- Keep estimation and presentation separate
- surveytable for presentation, tidycreel for estimation
- Users can choose to use surveytable or not

**Backward Compatibility**:
- surveytable features completely optional
- Default behavior unchanged

### Example Usage (Future)

```r
library(tidycreel)
library(surveytable)

# 1. Estimate with tidycreel (our core strength)
effort <- est_effort.instantaneous(
  counts,
  svy = design,
  variance_method = "bootstrap",
  decompose_variance = TRUE,
  design_diagnostics = TRUE
)

# 2. Present with surveytable (publication-ready)
tc_present(
  effort,
  format = "html",
  precision_flags = TRUE,
  include_diagnostics = TRUE,
  title = "Angler Effort Estimates by Location"
)

# Output:
# Publication-ready HTML table with:
# - Formatted estimates with proper decimals
# - Confidence intervals
# - Precision warnings (low sample sizes, high CVs)
# - Design diagnostics summary
# - Professional formatting
```

---

## 🔬 Other Future Enhancements

### 1. Enhanced Survey Internals Access
**Status**: Partially implemented (svyrecvar method exists but needs enhancement)

**TODO**:
- Full implementation of `variance_method = "svyrecvar"`
- Direct access to `survey:::multistage` for complex designs
- Rcpp acceleration where available

### 2. Advanced Calibration Methods
**Status**: Basic calibration exists in aerial estimator

**TODO**:
- Generalized calibration across all estimators
- Multiple calibration methods (linear, raking, logit, etc.)
- Calibration diagnostics and validation

### 3. Small Area Estimation
**Status**: Not implemented

**TODO**:
- Small area estimation methods for sparse data
- Hierarchical Bayes approaches
- Model-based estimators as alternatives to design-based

### 4. Spatial Analysis Integration
**Status**: Not implemented

**TODO**:
- Spatial survey design support
- Geographic visualization of estimates
- Spatial variance components

### 5. Time Series Extensions
**Status**: Not implemented

**TODO**:
- Time series analysis of creel data
- Trend estimation
- Seasonal adjustment

### 6. Interactive Dashboards
**Status**: Not implemented

**TODO**:
- Shiny dashboard for estimate exploration
- Interactive variance decomposition visualization
- Design diagnostics dashboard
- Real-time sample size planning

### 7. Machine Learning Integration
**Status**: Not implemented

**TODO**:
- ML-based prediction intervals
- Automated anomaly detection
- Smart sample allocation using ML

### 8. Comprehensive Simulation Framework
**Status**: Not implemented

**TODO**:
- Power analysis tools
- Sample size planning
- Design comparison via simulation
- Monte Carlo variance validation

---

## Priority Ranking

1. **HIGH**: surveytable integration (complements current work perfectly)
2. **HIGH**: Enhanced survey internals access (finish what we started)
3. **MEDIUM**: Advanced calibration methods
4. **MEDIUM**: Interactive dashboards (user experience)
5. **LOW**: Small area estimation (specialized use case)
6. **LOW**: ML integration (experimental)
7. **LOW**: Spatial analysis (specialized use case)

---

## Notes

**Current Focus**: Complete ground-up survey integration rebuild
**Next Priority**: surveytable integration for publication-ready output
**Long Term**: Advanced methods and specialized tools

*This document is living and should be updated as priorities shift.*
