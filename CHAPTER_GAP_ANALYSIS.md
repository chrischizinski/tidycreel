# Tidycreel Package Gap Analysis
## Comprehensive Feature Comparison with Creel Survey Chapter

**Document Date:** 2025-10-24
**Package Version:** 0.0.0.9000
**Source:** *Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition* Chapter 17: Creel Surveys

---

## Executive Summary

The **tidycreel** package provides a solid foundation for creel survey design and analysis with modern R tools, focusing on:
- Survey-first design-based inference using the `survey` package
- Support for instantaneous, progressive, and bus route designs
- Tidy data workflows with pipe-friendly interfaces
- Design-based variance estimation

However, the comprehensive textbook chapter reveals **significant gaps** across multiple dimensions:

### Critical Gaps (High Priority)
1. **No roving/incomplete trip interview estimators** (Pollock et al. 1997 methods)
2. **Missing aerial survey methods** (beyond basic aerial counts)
3. **No remote camera/passive monitoring integration**
4. **Limited variance component decomposition** (within-day, among-day, within-shift)
5. **No sample size determination tools**
6. **Missing angler segmentation framework**
7. **No quality assurance/control validation functions**
8. **Incomplete hybrid survey design support**

### Moderate Gaps (Medium Priority)
9. **Limited stratification guidance** (high-use days, temporal patterns)
10. **No schedule generation with count time randomization**
11. **Missing catch rate calculation edge cases** (very short trips, zero catches)
12. **No tools for non-response bias assessment**
13. **Limited data validation beyond basic schemas**
14. **No integration with other data sources** (tournament data, angler apps)

### Documentation/Enhancement Gaps (Lower Priority)
15. **Limited guidance on choosing estimators**
16. **Missing simulation/power analysis tools**
17. **No built-in diagnostic plots**
18. **Limited integration examples** (aerial + camera + creel)

---

## 1. MISSING FEATURES (High Priority)

### 1.1 Roving/Incomplete Trip Interview Methods

**Chapter Reference:** Section 17.3.2, Box 18.5 (lines 2537-2772)

**Current State:** Package has `est_cpue()` with auto/hybrid mode for complete vs incomplete, but missing:

**Missing Components:**
- **Pollock et al. (1997) roving catch rate estimator** - mean of ratios approach
- **Trip length truncation** - systematic handling of very short trips (< 0.5 hrs)
- **Length-biased sampling correction** - longer trips more likely to be intercepted
- **Incomplete trip expansion** - proper handling when anglers still fishing
- **Access-point vs roving variance formulas** - different estimators for trip completion status

**Formulas from Chapter:**
```
# Roving (incomplete) - Mean of Ratios
rate_i = catch_i / effort_i  (for each party)
mean_rate = Σ(rate_i) / k
var_rate = [Σ(rate_i²) - (Σ rate_i)²/k] / [k(k-1)]

# Access (complete) - Ratio of Means
rate = (Σ catch_i) / (Σ effort_i)
var_rate = (1/k) * rate² * [var_catch/mean_catch² + var_effort/mean_effort² - 2*cov(catch,effort)/(mean_catch*mean_effort)]
```

**Implementation Needed:**
```r
# New function signature
est_cpue_roving(
  interviews,
  response = "catch_total",
  effort_col = "hours_fished",
  min_trip_hours = 0.5,  # Truncation threshold
  correction = c("none", "length_biased"),  # Length-biased sampling
  by = NULL,
  svy = NULL,
  conf_level = 0.95
)
```

### 1.2 Aerial Survey Estimation Methods

**Chapter Reference:** Sections 17.3.1.2 (lines 269-362), 17.5.3 (lines 681-732)

**Current State:** Package has `est_effort.aerial()` stub but no implementation

**Missing Components:**
- **Instantaneous aerial counts** with expansion factors
- **Treatment of boats in transit** vs active fishing
- **Inflation factors** for time-of-day expansion
- **Integration with ground counts** for calibration
- **Weather/visibility adjustments**
- **Flight path design** and coverage probability
- **Cost-effectiveness analysis** (per-site costs)

**Key Formula:**
```
# Instantaneous aerial to daily effort
Daily_Effort = Aerial_Count × Inflation_Factor
Inflation_Factor = (Total_Day_Hours / Peak_Period_Hours) × Activity_Ratio

# Where Activity_Ratio based on complementary high-res data (cameras)
```

**Implementation Needed:**
```r
est_effort_aerial(
  counts,  # Aerial count data
  inflation_factors,  # Time-of-day expansion
  boats_in_transit = c("include", "exclude", "adjust"),
  calibration_data = NULL,  # Ground truth for validation
  flight_coverage = NULL,  # Coverage probability by area
  by = NULL,
  svy = NULL
)

# Companion function for inflation factor calculation
calc_inflation_factors(
  aerial_counts,
  reference_counts,  # High-res camera or complete counts
  time_periods = c("dawn", "morning", "afternoon", "dusk"),
  method = c("ratio", "regression")
)
```

### 1.3 Remote Camera / Passive Monitoring

**Chapter Reference:** Section 17.3.1.2 (lines 317-362)

**Current State:** No implementation

**Missing Components:**
- **Image analysis workflow** - extracting counts from time-lapse cameras
- **Field-of-view correction** - subsample to whole-fishery expansion
- **Missing data imputation** - camera malfunction/vandalism
- **Zero-inflation handling** - high frequency of zero counts
- **Hierarchical Bayesian models** (van Poorten et al. 2015)
- **Integration with aerial counts** for validation
- **Cost per site tracking**

**Implementation Needed:**
```r
# Process camera data
process_camera_counts(
  images,  # Image metadata with timestamps
  field_of_view = c("partial", "complete"),
  missing_data = c("interpolate", "model", "omit"),
  validation_counts = NULL  # Whole-system counts for calibration
)

# Estimate effort from cameras
est_effort_camera(
  camera_counts,
  field_of_view_fraction,  # Proportion of total area visible
  calibration_method = c("ratio", "hierarchical_bayes"),
  whole_system_counts = NULL,  # For calibration
  by = NULL,
  svy = NULL
)
```

### 1.4 Variance Component Decomposition

**Chapter Reference:** Box 18.4 (lines 2253-2536), Rasmussen et al. (1998)

**Current State:** Package uses survey package variance but doesn't decompose components

**Missing Components:**
- **Within-day variance** (variance among counts within a shift)
- **Among-day variance** (variance among days within a stratum)
- **Within-shift variance** (multiple counts per shift)
- **Strata-specific variance** (weekday vs weekend)
- **Variance ratio analysis** for optimal allocation

**Formulas from Chapter:**
```
# Strata estimator with variance decomposition
var(Y_stratum) = ((1 - n/N)/n) * s_b² + (1/(2N)) * s_w²

where:
  s_b² = among-day variance
  s_w² = within-day variance (from multiple counts)
  n = days sampled
  N = total days in stratum
```

**Implementation Needed:**
```r
decompose_variance(
  effort_est,  # Output from est_effort()
  level = c("shift", "day", "stratum", "month"),
  components = c("within_day", "among_day", "within_shift")
)

# Output should include:
# - Variance components table
# - Intraclass correlation
# - Design effects
# - Optimal allocation recommendations
```

### 1.5 Sample Size Determination

**Chapter Reference:** Newman et al. (1997), McCormick & Meyer (2017), Lester et al. (1991)

**Current State:** No implementation

**Missing Components:**
- **Power analysis** for detecting changes
- **Precision-based sample size** for target CV
- **Optimal allocation** between weekdays/weekends
- **Optimal counts per shift**
- **Pilot study analysis** tools
- **Variance ratio methods** (within-day / among-day)

**Implementation Needed:**
```r
calc_sample_size(
  target_cv = 0.15,  # Desired coefficient of variation
  variance_ratio = NULL,  # s_within² / s_among² from pilot
  pilot_data = NULL,  # Or provide pilot data directly
  allocation = c("proportional", "optimal", "equal"),
  strata = c("weekday", "weekend", "highuse"),
  budget_constraint = NULL,
  cost_per_day = NULL
)

# Power analysis for trend detection
calc_power_creel(
  effect_size,  # Minimum detectable change
  years = 5,
  alpha = 0.05,
  days_per_stratum,
  variance_components
)
```

### 1.6 Angler Segmentation Framework

**Chapter Reference:** Section 17.4.2 (lines 503-565)

**Current State:** No dedicated framework; handled via `by` argument

**Missing Components:**
- **Segmentation types**: Geographic, Demographic, Psychographic, Behavioral
- **Bank vs Boat** automatic detection and separate estimation
- **Target species** stratification with proper variance
- **Detection probability adjustment** when segments have different fishing patterns
- **Non-response bias** assessment by segment
- **Harvest propensity** modeling by segment type

**Implementation Needed:**
```r
define_segments(
  interviews,
  segment_type = c("method", "target_species", "demographic", "behavioral"),
  segment_vars = NULL,  # Variables defining segments
  estimate_detection = TRUE  # Adjust for differential detection probability
)

# Enhanced estimation with segmentation
est_effort_segmented(
  counts,
  interviews,
  segments,
  adjust_detection = TRUE,
  test_differences = TRUE,  # Test if segments differ significantly
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
```

### 1.7 Quality Assurance / Quality Control

**Chapter Reference:** Section 17.2.2, Table 17.3 (lines 1534-1585)

**Current State:** Basic schema validation via `data-schemas.R`

**Missing Components:**
- **Common mistakes detection** (skipping zeros, targeting successful parties)
- **Measurement unit consistency** checks (inches vs mm, hours vs minutes)
- **Species misidentification** flagging
- **Party-level effort** validation (accounting for multiple anglers fishing different times)
- **Interview completeness** checks
- **Count coverage** validation (did counts cover entire waterbody?)
- **Data entry error** detection (outliers, impossible values)
- **Training standardization** assessment

**Implementation Needed:**
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
    "missing_data"        # Completeness checks
  ),
  severity = c("error", "warning", "info")
)

# Output: List of issues with severity levels and recommended actions

qc_report(
  data,
  qa_results,
  output_format = c("html", "pdf", "console")
)
```

### 1.8 Hybrid Survey Design Support

**Chapter Reference:** Table 17.4 (lines 1586-1607), Section 17.3.2

**Current State:** Mentioned but not fully implemented

**Missing Components:**
- **Bus route with interviews** (McGlennon & Kinloch 1997)
- **Access + Roving combined** (different estimators per method)
- **Aerial + On-site** integration (Vølstad et al. 2006)
- **Camera + Creel + Aerial** (Smallwood et al. 2012)
- **Postcard surveys** (self-administered follow-up)
- **Variance combination** across multiple data sources

**Implementation Needed:**
```r
design_hybrid(
  methods = c("access", "roving", "aerial", "camera", "postcard"),
  counts_list,  # Named list of count data by method
  interviews_list,  # Named list of interview data by method
  calendar,
  combination_method = c("hierarchical_bayes", "glm", "glmm"),
  weights = "auto"  # Or manual weights by method
)

est_effort_hybrid(
  design,
  method_weights = "auto",  # Effort-based or precision-based weighting
  correlation_structure = NULL,  # Account for correlation between methods
  by = NULL,
  svy = NULL
)
```

---

## 2. ENHANCEMENTS TO EXISTING FEATURES

### 2.1 Bus Route Estimator Enhancements

**Current Implementation:** `/Users/cchizinski2/Dev/tidycreel/R/est-effort-busroute.R`

**Needed Enhancements:**

**2.1.1 Interview-based Expansion**
- Current: Only time-interval method (vehicle counts)
- Missing: Completed trip interview expansion (second method from chapter)

**2.1.2 Sampling Probability Adjustment**
- Current: Uses `inclusion_prob` column
- Missing: Automatic calculation from wait times and travel times
- Formula: `π_j = w_i / T` where w_i is wait time at site i, T is total circuit time

**2.1.3 Non-uniform Probability Sampling**
- Reference: Malvestuto et al. (1978)
- Missing: Explicit handling when sites have different sampling probabilities
- Need: Documentation and validation

**Implementation:**
```r
# Enhance existing function
est_effort.busroute_design(
  x,
  method = c("time_interval", "completed_trips"),  # ADD this choice

  # For time_interval method (existing)
  inclusion_prob_col = "inclusion_prob",

  # For completed_trips method (NEW)
  interview_based = FALSE,
  trip_duration_col = "trip_duration",

  # Probability calculation (NEW)
  auto_calc_pi = TRUE,  # Auto-calculate from schedule
  wait_time_col = "wait_time",
  total_circuit_time_col = "circuit_time"
)
```

### 2.2 Instantaneous Count Estimator Enhancements

**Current Implementation:** `/Users/cchizinski2/Dev/tidycreel/R/est-effort-instantaneous.R`

**Needed Enhancements:**

**2.2.1 Optimal Count Timing**
- Reference: Hoenig et al. (1993)
- Missing: Guidance on minimum time between counts (currently ≥ 1 hour mentioned in text)
- Missing: Validation that counts are truly "instantaneous" (< 1 hour for small waterbodies)

**2.2.2 Within-Day Variance Components**
- Current: Basic within-group variability
- Missing: Formal decomposition of variance by time-of-day
- Missing: Design effect calculations

**Implementation:**
```r
# Add validation
validate_instantaneous_counts(
  counts,
  max_count_duration = 60,  # minutes
  min_interval = 60,  # minutes between counts
  warn = TRUE
)

# Enhanced diagnostics
est_effort.instantaneous(
  ...,
  diagnostics = TRUE,  # Enable detailed diagnostics
  return_components = TRUE  # Return variance components
)
# Returns list with: estimate, variance_components, design_effects, recommendations
```

### 2.3 Progressive Count Enhancements

**Current Implementation:** `/Users/cchizinski2/Dev/tidycreel/R/est-effort-progressive.R`

**Needed Enhancements:**

**2.3.1 Robson (1961) Requirements Validation**
- Missing: Check that route covers entire waterbody
- Missing: Verify random starting location
- Missing: Verify random direction (clockwise/counterclockwise)
- Missing: Validate constant speed (faster than angler movement)

**2.3.2 Multiple Circuits Per Day**
- Current: Handles passes within day
- Missing: Explicit κ (kappa) calculation - number of potential circuits in shift
- Formula: `Effort_shift = Count × τ × κ` where κ = shift_duration / circuit_time

**Implementation:**
```r
validate_progressive_design(
  counts,
  schedule,
  requirements = c(
    "coverage",      # Route covers entire waterbody
    "random_start",  # Starting location randomized
    "random_direction",  # Direction randomized
    "constant_speed"  # Speed constant and faster than anglers
  )
)

# Enhanced estimator
est_effort.progressive(
  ...,
  circuits_per_shift = "auto",  # Or specify κ
  shift_duration_col = "shift_hours",
  validate_design = TRUE
)
```

### 2.4 CPUE Estimator Enhancements

**Current Implementation:** `/Users/cchizinski2/Dev/tidycreel/R/est-cpue.R`

**Needed Enhancements:**

**2.4.1 Short Trip Truncation**
- Current: Has `min_trip_hours = 0.5` but only in auto mode
- Missing: Applied consistently in ratio_of_means mode
- Reference: Hoenig et al. (1997) recommendation

**2.4.2 Zero-Inflation Handling**
- Missing: Explicit handling of zero catches
- Missing: Mixture models for zeros vs non-zeros
- Missing: Target species vs non-target separation

**2.4.3 Species-Specific Rates**
- Current: Works via `by` argument
- Missing: Automatic handling when no associated effort (can't know which parties were targeting which species during counts)
- Missing: Warning when estimating total catch for species-seeking subset

**2.4.4 Multi-Species Aggregation**
- Missing: Tools for aggregating across species groups
- Missing: Variance for sums of correlated catch rates

**Implementation:**
```r
est_cpue(
  ...,

  # Truncation (enhance)
  apply_truncation = TRUE,
  truncation_diagnostic = TRUE,  # Report how many truncated

  # Zero-inflation (NEW)
  zero_handling = c("standard", "mixture", "hurdle"),

  # Species handling (NEW)
  species_col = "species_caught",
  target_col = "species_targeted",
  warn_no_effort = TRUE,  # Warn if estimating species-specific total

  # Multi-species (NEW)
  aggregate_species = NULL,  # Vector of species to aggregate
  correlation_adj = TRUE  # Adjust variance for correlation
)
```

### 2.5 Catch/Harvest Total Estimator

**Current Implementation:** `/Users/cchizinski2/Dev/tidycreel/R/est-catch.R`, `/Users/cchizinski2/Dev/tidycreel/R/est-total-harvest.R`

**Needed Enhancements:**

**2.5.1 Effort × CPUE Method**
- Current: Direct total from interviews
- Missing: Multiplication estimator (Total = Effort_est × CPUE_est)
- Missing: Variance for product of two estimates

**2.5.2 Separate By Completion Status**
- Missing: Automatic separation of complete vs incomplete interviews
- Missing: Different estimators applied appropriately

**2.5.3 Size Structure Estimation**
- Reference: Length data from anglers (inches) vs biologists (mm)
- Missing: Handling mixed units (precision limited to 25mm = 1 inch)
- Missing: Size-specific harvest rates

**Implementation:**
```r
est_total_catch(
  effort_est,  # From est_effort()
  cpue_est,    # From est_cpue()
  method = c("product", "direct"),  # NEW choice
  correlation = NULL  # For product variance
)

# Enhanced with size structure
est_catch(
  ...,
  size_bins = c(0, 250, 500, 750, 1000),  # mm
  size_col = "length_mm",
  handle_mixed_units = TRUE,  # Auto-convert inches to mm (25mm bins)
  by_size = TRUE  # Estimate by size class
)
```

---

## 3. VALIDATION CHECKS NEEDED

### 3.1 Data Validation Framework

**Current State:** Basic schemas in `data-schemas.R`

**Missing Validations:**

**3.1.1 Count Data Validation**
```r
validate_counts(
  counts,
  design_type = c("instantaneous", "progressive", "busroute", "aerial"),
  required_cols = NULL,  # Auto-determined from design_type

  # Temporal checks
  check_temporal_coverage = TRUE,
  check_random_times = TRUE,

  # Spatial checks
  check_spatial_coverage = TRUE,

  # Value checks
  check_zero_counts = TRUE,  # Warn if no zeros
  check_outliers = TRUE,
  check_negatives = TRUE,

  # Design-specific
  check_design_requirements = TRUE
)
```

**3.1.2 Interview Data Validation**
```r
validate_interviews(
  interviews,
  survey_type = c("access", "roving", "hybrid", "postcard"),

  # Required fields
  has_effort = TRUE,
  has_catch = TRUE,
  has_completion = FALSE,  # trip_complete

  # Value checks
  check_effort_bounds = c(0, 24),  # Hours per day
  check_species_list = NULL,  # Valid species codes
  check_party_size = c(1, 20),

  # Consistency checks
  check_catch_effort_ratio = TRUE,  # Flag impossible CPUEs
  check_harvest_catch = TRUE,  # Harvest ≤ Catch
  check_units = TRUE  # Consistent measurement units
)
```

**3.1.3 Schedule Validation**
```r
validate_schedule(
  schedule,
  calendar,

  # Coverage checks
  check_strata_coverage = TRUE,
  min_days_per_stratum = 2,

  # Randomization checks
  check_random_selection = TRUE,
  check_start_times = TRUE,
  check_count_times = TRUE,

  # Balance checks
  check_allocation = TRUE,
  target_allocation = c("proportional", "optimal", "equal")
)
```

### 3.2 Estimation Validation

**3.2.1 Assumption Checks**
```r
check_assumptions(
  effort_est,  # or cpue_est, catch_est

  assumptions = c(
    "independence",      # Counts/interviews independent
    "unbiased_counts",   # Counts unbiased estimate of true anglers
    "random_sampling",   # Days randomly selected
    "coverage",         # Counts cover entire fishery
    "no_avoidance"      # Anglers don't avoid clerks
  ),

  diagnostic_plots = TRUE
)
```

**3.2.2 Estimate Reasonableness**
```r
validate_estimates(
  estimates,

  # Range checks
  effort_range = NULL,  # Expected range
  cpue_range = NULL,
  catch_range = NULL,

  # Comparison checks
  compare_to_previous = NULL,  # Historical estimates
  flag_percent_change = 50,  # Flag if >50% change

  # Precision checks
  max_cv = 0.30,  # Flag if CV > 30%
  min_sample_size = 30
)
```

---

## 4. DATA STRUCTURES NEEDED

### 4.1 Creel Design Objects

**Current State:** Basic structure in design constructors

**Enhancements Needed:**

```r
# Enhanced creel_design class
creel_design <- list(
  # Current fields
  design_type = "instantaneous",  # or progressive, busroute, aerial, etc
  calendar = calendar_df,
  strata_vars = c("day_type", "month"),

  # NEW fields for comprehensive design
  survey_period = list(
    start_date = "2024-04-01",
    end_date = "2024-10-31",
    seasons = c("spring", "summer", "fall")
  ),

  sampling_frame = list(
    population = "all_anglers",  # or specific segments
    exclusions = c("age < 16"),  # Who is excluded
    spatial_extent = "entire_waterbody",
    temporal_extent = "daylight_hours"
  ),

  allocation = list(
    method = "proportional",  # or optimal, equal
    weekday_days = 10,
    weekend_days = 6,
    highuse_days = 2
  ),

  variance_components = list(
    pilot_data = pilot_df,
    within_day_var = 0.15,
    among_day_var = 0.45,
    variance_ratio = 0.33,  # within/among
    optimal_counts_per_day = 3
  ),

  segmentation = list(
    segments = c("bank", "boat"),
    segment_vars = "fishing_method",
    estimate_separately = TRUE
  ),

  quality_control = list(
    qa_checks = qa_results,
    validation_rules = validation_spec,
    data_issues = issues_log
  )
)

# S3 class with print, summary, plot methods
class(creel_design) <- c("creel_design", "list")
```

### 4.2 Estimate Objects

**Enhancement:**
```r
# Enhanced estimate output
creel_estimate <- tibble(
  # Current fields
  estimate = numeric(),
  se = numeric(),
  ci_low = numeric(),
  ci_high = numeric(),
  n = integer(),
  method = character(),

  # NEW fields
  cv = numeric(),  # Coefficient of variation
  df = integer(),  # Degrees of freedom
  design_effect = numeric(),  # Deff from complex survey

  # Variance components (when available)
  var_total = numeric(),
  var_within = numeric(),
  var_among = numeric(),

  # Quality metrics
  truncated = integer(),  # Number truncated
  warnings = list(),  # Any warnings

  # Metadata
  estimation_date = Sys.Date(),
  package_version = "0.1.0",

  diagnostics = list()  # Nested diagnostics
)

class(creel_estimate) <- c("creel_estimate", "tbl_df", "tbl", "data.frame")
```

### 4.3 Interview Data Standard

**Current State:** No formal standard

**Proposed Standard:**
```r
# Tidycreel interview data schema
interview_schema <- list(
  # Identifiers (REQUIRED)
  party_id = "character",  # Unique party identifier
  interview_date = "Date",
  interview_time = "POSIXct",

  # Effort (REQUIRED)
  hours_fished = "numeric",  # Or minutes, converted to hours
  num_anglers = "integer",  # In party

  # Catch (REQUIRED for CPUE/harvest)
  catch_total = "integer",   # Total caught (kept + released)
  catch_kept = "integer",    # Harvest
  catch_released = "integer",  # Released

  # Trip information (REQUIRED)
  trip_complete = "logical",  # TRUE = complete, FALSE = incomplete
  trip_type = "character",    # "complete" or "incomplete" (alt)

  # Species-specific (OPTIONAL but recommended)
  species_caught = "character",
  species_targeted = "character",

  # Size data (OPTIONAL)
  length_mm = "numeric",  # Prefer mm; or length_in for inches
  weight_g = "numeric",   # Prefer grams

  # Segmentation (OPTIONAL)
  fishing_method = "character",  # "bank", "boat", "wade", etc
  gear_type = "character",
  residency = "character",  # "resident", "non-resident"

  # Design variables (REQUIRED for stratified designs)
  day_type = "character",  # "weekday", "weekend", "highuse"
  shift = "character",     # "morning", "afternoon", "evening"
  location = "character",  # Site/access point

  # Weights (OPTIONAL, for survey design)
  sampling_weight = "numeric",

  # Quality (OPTIONAL but helpful)
  data_quality = "character",  # "good", "questionable", "poor"
  interviewer_id = "character",
  notes = "character"
)
```

### 4.4 Count Data Standard

```r
# Tidycreel count data schema
count_schema <- list(
  # Identifiers (REQUIRED)
  count_id = "character",
  count_date = "Date",
  count_time = "POSIXct",

  # Count (REQUIRED)
  count = "integer",  # Number of anglers/boats counted

  # Timing (REQUIRED, design-specific)
  # For instantaneous:
  interval_minutes = "numeric",  # Duration this count represents
  total_day_minutes = "numeric", # Total day duration

  # For progressive:
  circuit_minutes = "numeric",   # Time to complete circuit
  pass_id = "integer",           # Which pass/circuit

  # For bus route:
  wait_time = "numeric",         # Wait time at site
  travel_time = "numeric",       # Travel to next site
  site_id = "character",

  # For aerial:
  flight_minutes = "numeric",
  boats_in_transit = "integer",  # Separate from active fishing

  # Design variables (REQUIRED)
  day_type = "character",
  shift = "character",
  location = "character",

  # Segmentation (OPTIONAL)
  count_type = "character",  # "bank", "boat", "total"

  # Quality (OPTIONAL)
  weather = "character",
  visibility = "character",  # For aerial
  observer_id = "character",
  notes = "character"
)
```

---

## 5. DOCUMENTATION IMPROVEMENTS

### 5.1 Missing Vignettes/Articles

**Needed Articles:**

1. **"Choosing the Right Estimator"**
   - Decision tree: instantaneous vs progressive vs bus route vs aerial
   - Complete vs incomplete trip considerations
   - Sample size and precision requirements
   - Cost-effectiveness comparison

2. **"Variance Decomposition and Sample Size"**
   - Understanding variance components
   - Optimal allocation between strata
   - Calculating required sample size
   - Pilot study analysis

3. **"Angler Segmentation in Creel Surveys"**
   - Why segment?
   - Methods for defining segments
   - Estimating by segment
   - Combining segment estimates
   - Assessing non-response bias

4. **"Quality Assurance for Creel Surveys"**
   - Common mistakes (Table 17.3)
   - Data validation workflows
   - Training standardization
   - Dealing with dirty data

5. **"Hybrid and Integrated Approaches"**
   - Combining aerial + camera + creel
   - Hierarchical models for integration
   - Variance from multiple sources
   - Cost-benefit analysis

6. **"Advanced Topics in Creel Estimation"**
   - Length-biased sampling
   - Zero-inflation
   - Non-response bias
   - Mark-recapture for angler counts (Hansen & Van Kirk 2018)

### 5.2 Function Documentation Enhancements

**Needed in Existing Functions:**

- **When to use** section in Description
- **Assumptions** explicitly listed
- **Limitations** clearly stated
- **References** to primary literature (Pollock et al. 1994, 1997; Malvestuto 1996)
- **Worked examples** with real data
- **Comparison with alternative methods**
- **Diagnostic interpretation** guidance

### 5.3 Method Papers / Technical Notes

**Recommended Additions:**

1. **Technical note on variance estimation**
   - How survey package calculates variance
   - When to use replicate weights
   - Lonely PSU options
   - Finite population corrections

2. **Comparison with other software**
   - RMark for creel surveys
   - Fisheries toolbox (NMFS)
   - State agency custom tools

3. **Validation studies**
   - Comparison with known populations
   - Simulation validation
   - Sensitivity analyses

---

## 6. SPECIFIC FORMULAS FROM CHAPTER NOT IN PACKAGE

### 6.1 Effort Estimation Formulas

**Instantaneous (Box 18.3, lines 1993-2040):**
```r
# Single count
f_t = C × T

# Multiple counts
f_t = (Σ C_i / m) × T

# Where:
#   C = count of anglers
#   T = time interval (hours)
#   m = number of counts
```
**Status:** ✅ Implemented in `est_effort.instantaneous()`

**Progressive (Box 18.3, lines 2041-2080):**
```r
# Single circuit
f_p = C × τ

# Multiple circuits per shift
f_p = C × τ × κ

# Where:
#   C = count of anglers on circuit
#   τ = time to complete circuit (hours)
#   κ = number of potential circuits in shift (T/τ)
```
**Status:** ⚠️ Partially implemented - missing explicit κ calculation

**Bus Route (Box 18.3, lines 2082-2252):**
```r
E = T × Σ(i=1 to n) [1/w_i × Σ(j=1 to m) e_ij/π_j]

# Where:
#   T = total circuit time (wait + travel)
#   w_i = wait time at site i
#   e_ij = time jth vehicle at site i
#   π_j = inclusion probability (typically = 0.5 for day/night sampling)
```
**Status:** ✅ Implemented but needs documentation improvements

### 6.2 Mean Daily vs Strata Estimator (Box 18.4)

**Mean Daily Estimator (lines 2290-2402):**
```r
# Weighted daily estimate
daily_effort = Σ(strata) [(n_days_strata / n_days_total) × mean_effort_strata]

# Variance
var_daily = Σ(strata) [(weight² × var_strata) / n_sampled_strata] -
             Σ(strata) [(weight × var_strata) / n_days_total]

# Monthly total
monthly_effort = daily_effort × n_days_total
```
**Status:** ❌ Not explicitly implemented as option

**Strata Estimator (lines 2404-2536):**
```r
# Within-stratum
strata_effort = mean_strata_effort × n_days_strata

# Within-day variance component
var_within = Σ(diff²) / [n_sampled × (n_counts - 1)]

# Total variance
var_strata = (n_days_strata²) × [((1 - n_sampled/n_days) / n_sampled) × sb² +
                                   (1 / (2×n_days)) × sw²]

# Monthly
monthly_effort = Σ(strata) strata_effort
monthly_var = Σ(strata) strata_var
```
**Status:** ⚠️ Partially - survey package handles but not explicitly documented

### 6.3 Catch/CPUE Formulas

**Access Point - Ratio of Means (Box 18.5, lines 2637-2680):**
```r
# Catch rate
rate = (Σ catch) / (Σ effort)

# Variance
var_rate = (1/k) × rate² × [var_catch/mean_catch² +
                             var_effort/mean_effort² -
                             2×cov(catch,effort)/(mean_catch×mean_effort)]
```
**Status:** ✅ Implemented via `est_cpue(mode = "ratio_of_means")`

**Roving - Mean of Ratios (Box 18.5, lines 2694-2728):**
```r
# Per-party rate
rate_i = catch_i / effort_i  (truncate if effort < 0.5 hrs)

# Mean rate
mean_rate = Σ(rate_i) / k

# Variance
var_rate = [Σ(rate_i²) - (Σ rate_i)² / k] / [k(k-1)]
```
**Status:** ✅ Implemented via `est_cpue(mode = "mean_of_ratios")`

**Hybrid Complete + Incomplete (Box 18.5, lines 2748-2760):**
```r
# Combine complete and incomplete
catch_total = Σ(strata) [strata_catch_complete + strata_catch_incomplete]

# Variance
var_total = Σ(strata) [var_complete + var_incomplete]
```
**Status:** ✅ Implemented via `est_cpue(mode = "auto")` hybrid approach

---

## 7. EMERGING APPLICATIONS FROM CHAPTER

### 7.1 Technology Integration (Section 17.5.4, lines 733-770)

**Drones/UAVs:**
- Autonomous aerial counts
- Higher frequency than manned aircraft
- Lower cost per flight
- Regulatory considerations

**Implementation Needed:**
```r
est_effort_drone(
  flight_data,  # GPS tracks with counts
  coverage_area,
  flight_altitude,
  detection_probability,  # Function of altitude
  ...
)
```

**Angler Apps (Papenfuss et al. 2015; Venturelli et al. 2017):**
- Self-reported catch via smartphone apps
- Integration with on-site creel
- Validation and bias correction

**Implementation Needed:**
```r
integrate_angler_app(
  app_data,      # Self-reported from app
  creel_data,    # Traditional creel
  calibration_method = c("ratio", "regression", "bayesian"),
  bias_correction = TRUE
)
```

**Web Crawlers and Social Media:**
- Fishing reports from websites
- Social media posts
- Sentiment analysis
- Effort proxy

**Implementation Needed:**
```r
analyze_social_media(
  posts,  # Social media data
  sentiment = TRUE,
  effort_proxy = c("mentions", "photos", "check-ins"),
  temporal_patterns = TRUE
)
```

### 7.2 Network Analysis (Section 17.6, lines 776-787; Box 18.6)

**Bipartite Networks:**
- Species caught × Species targeted
- Anglers × Waterbodies
- Substitute fisheries
- Co-occurrence patterns

**Current Code in Chapter (lines 2773-2886):**
- Uses `bipartite` package
- `plotweb()`, `networklevel()`, `grouplevel()`

**Implementation Needed:**
```r
# Build network from interview data
build_angler_network(
  interviews,
  network_type = c("species_target_catch", "angler_waterbody"),
  standardize_effort = TRUE  # CPUE × 3 hours in example
)

# Network metrics
analyze_network(
  network,
  metrics = c(
    "connectance",
    "nestedness",
    "modularity",
    "centrality"
  )
)

# Visualization
plot_network(
  network,
  layout = c("bipartite", "circular", "force"),
  node_size = "degree",
  edge_weight = "cpue"
)
```

### 7.3 Big Data Integration (Section 17.6, lines 789-800)

**Crosswalking Datasets:**
- Multi-state databases
- Regional coordination
- Transboundary fisheries
- Data gap filling

**Implementation Needed:**
```r
crosswalk_datasets(
  dataset_list,  # List of state/agency datasets
  common_fields,
  harmonization_rules,
  privacy_protection = TRUE,
  output_format = c("tidycreel", "standard")
)
```

### 7.4 Surrogate Biology (Section 17.6, lines 802-828)

**Using Creel for Population Assessment:**
- Catch rates → density proxy
- Trophy catch → production of large fish
- Length/age structure from harvest
- Sex ratios
- Condition indices

**Cautions:** Always warranted (Shuter et al. 1987; Novinger 1990)

**Implementation Needed:**
```r
# Biological surrogates from creel
est_population_metrics(
  interviews,
  metrics = c(
    "density_proxy",      # From CPUE
    "size_structure",     # From length data
    "age_structure",      # From age data
    "sex_ratio",
    "condition",          # From length-weight
    "trophy_production"   # Large fish CPUE
  ),
  validation_data = NULL,  # Independent population data
  bias_assessment = TRUE   # Assess bias from angler selectivity
)
```

---

## 8. IMPLEMENTATION ROADMAP

### Phase 1: Critical Gaps (3-6 months)
**Priority: High - Core functionality missing**

1. ✅ **Roving/Incomplete Trip Estimators** (2-3 weeks)
   - Implement Pollock et al. (1997) roving catch rate
   - Add truncation for short trips
   - Length-biased sampling correction
   - Comprehensive documentation

2. ✅ **Aerial Survey Methods** (3-4 weeks)
   - Full aerial effort estimation
   - Inflation factor calculation
   - Boats in transit handling
   - Integration with ground counts

3. ✅ **Variance Decomposition** (2 weeks)
   - Within-day/among-day/within-shift components
   - Design effect calculations
   - Optimal allocation tools

4. ✅ **Sample Size Determination** (2-3 weeks)
   - Power analysis
   - Precision-based sample size
   - Pilot study tools
   - Optimal allocation

5. ✅ **QA/QC Framework** (2-3 weeks)
   - Comprehensive validation functions
   - Error detection (Table 17.3 mistakes)
   - Data quality reporting

### Phase 2: Enhancements (2-4 months)
**Priority: Medium - Improve existing features**

6. ✅ **Enhanced Bus Route** (1-2 weeks)
   - Interview-based expansion
   - Auto probability calculation
   - Better documentation

7. ✅ **Progressive Enhancements** (1 week)
   - Design validation (Robson requirements)
   - κ (circuits per shift) handling
   - Diagnostic tools

8. ✅ **CPUE Enhancements** (2 weeks)
   - Zero-inflation models
   - Species-specific warnings
   - Multi-species aggregation

9. ✅ **Angler Segmentation** (2-3 weeks)
   - Framework for segments
   - Detection probability adjustment
   - Non-response bias tools

10. ✅ **Hybrid Designs** (2-3 weeks)
    - Multiple method integration
    - Hierarchical models
    - Variance combination

### Phase 3: Advanced Features (3-6 months)
**Priority: Lower - Nice to have**

11. ✅ **Remote Camera Integration** (3-4 weeks)
    - Image processing workflow
    - Field-of-view correction
    - Missing data imputation

12. ✅ **Network Analysis** (2 weeks)
    - Bipartite network tools
    - Integration with `bipartite` package
    - Visualization

13. ✅ **Technology Integration** (4-6 weeks)
    - Drone/UAV data handling
    - Angler app integration
    - Social media analysis

14. ✅ **Surrogate Biology** (2-3 weeks)
    - Population metric estimation
    - Bias assessment
    - Validation tools

### Phase 4: Documentation (Ongoing)
**Priority: High - Critical for usability**

15. ✅ **Core Vignettes** (4-6 weeks)
    - Choosing estimators
    - Variance & sample size
    - QA/QC guide
    - Hybrid methods

16. ✅ **Technical Documentation** (2-3 weeks)
    - Method papers
    - Validation studies
    - Comparison with other software

17. ✅ **Enhanced Function Docs** (Ongoing)
    - Assumptions
    - When to use
    - Worked examples
    - References

---

## 9. SPECIFIC REFERENCES TO IMPLEMENT

### Key Papers Cited in Chapter

**Foundational Methods:**
1. **Pollock et al. (1994)** - *Angler Survey Methods and Their Applications*
   - Comprehensive reference book
   - Should cite in package DESCRIPTION

2. **Pollock et al. (1997)** - *Catch rate estimation for roving and access point surveys*
   - Core theory for roving vs access
   - Implemented in `est_cpue` but needs better documentation

3. **Malvestuto (1996)** - *Sampling the recreational creel* (Fisheries Techniques 2nd ed)
   - Standard reference
   - Bus route, stratification

4. **Robson & Jones (1989)** - *The theoretical basis of an access site angler survey design*
   - Bus route theory
   - Needs citation in bus route functions

5. **Hoenig et al. (1993)** - *Scheduling counts in the instantaneous and progressive count methods*
   - Optimal count timing
   - Should inform validation functions

6. **Hoenig et al. (1997)** - *Calculation of catch rate and total catch in roving surveys*
   - Short trip truncation (0.5 hrs)
   - Length-biased sampling

**Variance Estimation:**
7. **Rasmussen et al. (1998)** - *Bias and confidence interval coverage of creel survey estimators*
   - Strata estimator with variance components
   - Key for variance decomposition implementation

8. **Newman et al. (1997)** - *Comparison of stratified, instantaneous count creel survey with complete mandatory census*
   - Validation study
   - Sample size considerations

**Sample Size:**
9. **McCormick & Meyer (2017)** - *Sample size estimation for on-site creel surveys*
   - Recent methods
   - Should implement

10. **Lester et al. (1991)** - *Sample size determination in roving creel surveys*
    - Classic reference

**Aerial/Remote:**
11. **Askey et al. (2018)** - *Angler effort estimates from instantaneous aerial counts*
    - High-frequency time-lapse camera + aerial
    - GLMMs for integration

12. **van Poorten et al. (2015)** - *Imputing recreational angling effort from time-lapse cameras using hierarchical Bayesian model*
    - Missing data imputation
    - Hierarchical Bayes

**Integrated Approaches:**
13. **Smallwood et al. (2012)** - *Expanding aerial-roving surveys to include counts of shore-based fishers from remote cameras*
    - Aerial + camera + creel integration
    - Benefits, limitations, cost-effectiveness

---

## 10. TESTING AND VALIDATION NEEDS

### 10.1 Unit Tests

**Missing Test Coverage:**

1. **Estimator Edge Cases**
   - Zero counts (effort = 0)
   - Single count per stratum
   - All incomplete trips
   - Very short trips (< min threshold)
   - Missing data patterns

2. **Variance Calculations**
   - Variance components sum correctly
   - Replicate weights produce valid estimates
   - Lonely PSU handling

3. **Data Validation**
   - All QA checks trigger appropriately
   - Invalid data rejected
   - Warning messages accurate

### 10.2 Integration Tests

**Needed Tests:**

1. **End-to-End Workflows**
   - Complete instantaneous survey workflow
   - Complete bus route workflow
   - Hybrid aerial + creel workflow

2. **Comparison with Known Populations**
   - Simulate fishery with known effort
   - Apply creel methods
   - Compare estimates to truth

3. **Comparison with Other Software**
   - Compare tidycreel estimates to RMark
   - Compare to published case studies
   - Document differences

### 10.3 Validation Studies

**Recommended:**

1. **Simulation Study**
   - Generate data under various scenarios
   - Apply all estimators
   - Assess bias, precision, coverage
   - Publish as vignette or paper

2. **Case Study Analysis**
   - Re-analyze published datasets
   - Compare to published estimates
   - Document any differences

3. **Benchmark Dataset**
   - Create standard test dataset
   - Include all survey types
   - Known true values
   - Use for CI testing

---

## 11. PRIORITY MATRIX

### Prioritization Criteria
- **Impact:** How much it affects core functionality
- **Effort:** Development time required
- **Dependencies:** What else depends on it
- **User Demand:** How often requested/needed

### Top 10 Priorities

| Rank | Feature | Impact | Effort | Dependencies | User Demand |
|------|---------|--------|--------|--------------|-------------|
| 1 | Roving/Incomplete Trip Estimators | ⭐⭐⭐⭐⭐ | Medium | None | High |
| 2 | QA/QC Framework | ⭐⭐⭐⭐⭐ | Medium | None | High |
| 3 | Variance Decomposition | ⭐⭐⭐⭐ | Low | None | High |
| 4 | Sample Size Tools | ⭐⭐⭐⭐ | Medium | Variance decomp | High |
| 5 | Aerial Survey Methods | ⭐⭐⭐⭐ | Medium | None | Medium |
| 6 | Angler Segmentation | ⭐⭐⭐⭐ | Medium | None | Medium |
| 7 | Enhanced Bus Route | ⭐⭐⭐ | Low | None | Low |
| 8 | Documentation (Vignettes) | ⭐⭐⭐⭐⭐ | High | All above | Very High |
| 9 | Hybrid Design Support | ⭐⭐⭐ | High | Multiple methods | Medium |
| 10 | Remote Camera Integration | ⭐⭐⭐ | High | Aerial methods | Low-Medium |

---

## 12. CONCLUSION

The **tidycreel** package has established a solid modern foundation for creel survey analysis using design-based inference and tidy workflows. However, comparison with the comprehensive textbook chapter reveals substantial gaps across multiple dimensions.

### Immediate Actions Recommended:

1. **Implement roving/incomplete trip estimators** - Critical gap for one of the most common survey types

2. **Build QA/QC framework** - Essential for data quality, addresses Table 17.3 mistakes

3. **Add variance decomposition** - Needed for optimal allocation and understanding precision

4. **Create sample size tools** - Frequently requested, builds on variance work

5. **Enhance documentation** - Most critical for adoption and correct usage

### Strategic Directions:

- **Embrace the full design landscape** - Not just instantaneous/progressive, but aerial, cameras, hybrid
- **Provide decision support** - Help users choose appropriate methods
- **Enable integrated approaches** - Modern surveys combine multiple data sources
- **Support emerging technologies** - Drones, apps, social media
- **Maintain statistical rigor** - Always provide valid variance estimates

### Long-Term Vision:

Position tidycreel as the **comprehensive R solution** for creel surveys, rivaling specialized software while maintaining:
- Tidy data principles
- Pipe-friendly workflows
- Design-based inference
- Integration with the broader R ecosystem
- Excellent documentation and examples

The chapter provides a detailed roadmap. Systematic implementation of these features will transform tidycreel from a solid start into the definitive tool for creel survey analysis in R.

---

## APPENDIX A: Quick Reference - Chapter Formulas

### Effort Formulas

| Method | Formula | Variables |
|--------|---------|-----------|
| Instantaneous (single) | `f = C × T` | C=count, T=interval hours |
| Instantaneous (multiple) | `f = (ΣC/m) × T` | m=num counts |
| Progressive (single) | `f = C × τ` | τ=circuit time |
| Progressive (shift) | `f = C × τ × κ` | κ=circuits per shift |
| Bus Route | `E = T Σ(1/w_i) Σ(e_ij/π_j)` | w=wait, e=vehicle time, π=prob |

### CPUE Formulas

| Method | Formula | Use When |
|--------|---------|----------|
| Ratio of Means | `R = (Σ catch) / (Σ effort)` | Complete trips |
| Mean of Ratios | `R = Σ(catch_i/effort_i) / k` | Incomplete trips (truncate < 0.5 hr) |

### Variance Formulas

| Component | Formula |
|-----------|---------|
| Strata total | `Y_strata = ȳ_strata × N_strata` |
| Strata variance | `V = N² [(1-n/N)/n × s_b² + 1/(2N) × s_w²]` |
| Monthly total | `Y_month = Σ(strata) Y_strata` |
| Monthly variance | `V_month = Σ(strata) V_strata` |

Where:
- `s_b²` = among-day variance
- `s_w²` = within-day variance (from multiple counts)
- `n` = days sampled
- `N` = total days in stratum

---

## APPENDIX B: Common Mistakes (Table 17.3)

| Mistake | Effect | tidycreel Check |
|---------|--------|-----------------|
| Skipping zeros | Overestimates effort, catch, harvest | `check_zero_counts()` |
| Targeting successful parties | Overestimates catch/harvest rates | `check_interview_location()` |
| Measuring biggest fish only | Overestimates size structure | `check_subsampling()` |
| Counts don't cover entire area | Unknown bias | `validate_coverage()` |
| Interviews exclude groups | Unknown bias | `assess_nonresponse()` |
| Mixing units | Variability in precision | `check_unit_consistency()` |
| Species misidentification | Unknown bias | `validate_species()` |
| Over/under party effort | Under/overestimates rates | `validate_party_effort()` |
| Lack of standardized training | Data loss | `assess_data_quality()` |
| No QA-QC | Inaccurate data | `qa_report()` |

---

**END OF GAP ANALYSIS**
