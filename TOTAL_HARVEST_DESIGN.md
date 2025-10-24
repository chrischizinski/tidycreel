# Total Harvest/Catch Estimator - Design Document

**Function:** `est_total_harvest()`
**Status:** Design phase
**Priority:** P0 - Critical blocking function

---

## Overview

Estimates total harvest, catch, or releases by multiplying effort estimates with CPUE estimates, properly propagating variance using the delta method. Supports both general population estimates and target species-specific estimates (caught while sought).

---

## Function Signatures

### Primary Function

```r
est_total_harvest(
  effort_est,                    # Tibble from est_effort()
  cpue_est,                      # Tibble from est_cpue()
  by = NULL,                     # Grouping variables (must match)
  response = c("catch_total", "catch_kept", "catch_released"),
  species_groups = NULL,         # Named list for species aggregation
  aggregate_level = "species",   # "species", "group", "all"
  method = "product",            # "product", "separate_ratio"
  correlation = NULL,            # Optional: correlation between E and CPUE
  conf_level = 0.95,
  diagnostics = TRUE
)
```

**Returns:** Standard tidycreel tibble
```r
tibble(
  [grouping_vars],
  estimate,        # Total harvest/catch/release
  se,              # Standard error
  ci_low,          # Lower confidence limit
  ci_high,         # Upper confidence limit
  n,               # Sample size
  method,          # "product" or "separate_ratio"
  diagnostics      # List-column with details
)
```

---

### Variant: Caught While Sought (Target Species)

```r
est_total_harvest_sought(
  effort_est,                    # Total effort (all anglers)
  cpue_est_targeted,             # CPUE from anglers targeting this species
  target_proportion,             # Proportion of effort targeting species
  by = NULL,
  response = c("catch_total", "catch_kept", "catch_released"),
  method = "product",
  conf_level = 0.95,
  diagnostics = TRUE
)
```

**Alternative approach:** Build this into main function via parameters

```r
est_total_harvest(
  effort_est,
  cpue_est,
  by = NULL,
  response = "catch_total",
  target_species_only = FALSE,   # If TRUE, filter to targeted effort
  target_species_col = "target_species",
  method = "product",
  correlation = NULL,
  conf_level = 0.95,
  diagnostics = TRUE
)
```

---

## Response Types

### 1. `"catch_total"` (Total Catch)
All fish caught, including kept and released.
- **Numerator:** Total catch from interviews
- **CPUE:** Catch per unit effort (fish/hour)
- **Result:** Total catch = Effort × CPUE_total

### 2. `"catch_kept"` (Total Harvest)
Fish kept/harvested only.
- **Numerator:** Kept fish from interviews
- **CPUE:** Harvest per unit effort (kept fish/hour)
- **Result:** Total harvest = Effort × CPUE_kept

### 3. `"catch_released"` (Total Released)
Fish caught and released.
- **Numerator:** Released fish from interviews
- **CPUE:** Release rate (released fish/hour)
- **Result:** Total released = Effort × CPUE_released

**Relationship Check:**
```r
# Should hold approximately:
catch_total ≈ catch_kept + catch_released
```

---

## Species Aggregation Framework

### Overview

Creel surveys require flexible species aggregation to support multiple reporting levels:
1. **Individual Species:** Species-specific estimates (e.g., largemouth bass, smallmouth bass)
2. **Species Groups:** Taxonomic or management groups (e.g., black bass, panfish, catfish)
3. **All Species Combined:** Total fishery harvest across all species

**Key Principle:** Aggregation must occur at the CPUE level BEFORE multiplying by effort, using survey-design-based aggregation to properly account for sampling variance.

### Aggregation Levels

#### Level 1: Individual Species (Default)
```r
est_total_harvest(effort_est, cpue_est, by = "species")
```

Returns estimates for each species separately:
```
species          estimate    se
largemouth_bass      1500   200
smallmouth_bass       800   120
bluegill             600    90
```

#### Level 2: Species Groups
```r
species_groups <- list(
  black_bass = c("largemouth_bass", "smallmouth_bass", "spotted_bass"),
  panfish = c("bluegill", "redear_sunfish", "green_sunfish", "pumpkinseed"),
  catfish = c("channel_catfish", "flathead_catfish", "blue_catfish"),
  centrarchids = c("black_bass", "panfish")  # Can reference other groups
)

est_total_harvest(
  effort_est,
  cpue_est,
  by = "species",
  species_groups = species_groups,
  aggregate_level = "group"
)
```

Returns estimates for each group:
```
species_group  estimate    se
black_bass         2300   235
panfish            1800   180
catfish             900   130
```

#### Level 3: All Species Combined
```r
est_total_harvest(
  effort_est,
  cpue_est,
  aggregate_level = "all"
)
```

Returns single estimate across all species:
```
estimate    se
    5000   350
```

### Statistical Approach: Survey-Based Aggregation

**CRITICAL:** Must aggregate CPUE estimates using survey design, NOT simple addition of harvest estimates.

**Correct Approach:**
1. Aggregate CPUE at species group level using `survey::svyby()` or `survey::svytotal()`
2. Multiply aggregated CPUE by effort
3. Propagate variance using delta method

**Incorrect Approach (DO NOT DO):**
```r
# WRONG - Don't add harvest estimates directly
harvest_bass_total <- harvest_largemouth$estimate + harvest_smallmouth$estimate
```

This ignores covariance between species and produces incorrect variance estimates.

### Implementation Strategy

#### Option A: Pre-aggregate CPUE (Recommended)

User aggregates CPUE before calling `est_total_harvest()`:

```r
# 1. Calculate species-level CPUE
cpue_by_species <- est_cpue(svy_int, by = "species", response = "catch_kept")

# 2. Aggregate CPUE to groups using survey design
# Helper function needed: aggregate_cpue()
cpue_black_bass <- aggregate_cpue(
  cpue_data = interviews,  # Raw interview data
  svy_design = svy_int,
  species_col = "species",
  species_values = c("largemouth_bass", "smallmouth_bass"),
  group_name = "black_bass",
  response = "catch_kept"
)

# 3. Calculate total harvest for group
harvest_black_bass <- est_total_harvest(effort_est, cpue_black_bass)
```

**Advantage:** Clear two-step process, explicit about survey-based aggregation
**Disadvantage:** Requires helper function `aggregate_cpue()`

#### Option B: Integrated Aggregation (User-Friendly)

`est_total_harvest()` handles aggregation internally:

```r
species_groups <- list(
  black_bass = c("largemouth_bass", "smallmouth_bass")
)

harvest_by_group <- est_total_harvest(
  effort_est,
  cpue_est,
  by = "species",
  species_groups = species_groups,
  aggregate_level = "group",
  cpue_data = interviews,   # Need raw data for aggregation
  svy_design = svy_int      # Need survey design
)
```

**Advantage:** One-step process, user-friendly
**Disadvantage:** Function becomes more complex, requires raw data + design

**RECOMMENDATION:** Start with Option A (separate aggregation), add Option B if demand exists.

### Helper Function: `aggregate_cpue()`

```r
#' Aggregate CPUE Across Species Using Survey Design
#'
#' Combines CPUE estimates for multiple species into a single aggregate,
#' properly accounting for survey design and covariance between species.
#'
#' @param cpue_data Interview data (raw, before estimation)
#' @param svy_design Survey design object (svydesign/svrepdesign)
#' @param species_col Column name containing species
#' @param species_values Character vector of species to aggregate
#' @param group_name Name for the aggregated group
#' @param by Additional grouping variables (e.g., location, date)
#' @param response Type of catch ("catch_total", "catch_kept", "catch_released")
#' @param effort_col Effort column (default "hours_fished")
#'
#' @return Tibble with aggregated CPUE estimates (same schema as est_cpue)
#'
#' @details
#' Uses survey package to properly aggregate species:
#' 1. Filters to specified species
#' 2. Sums catch across species within each interview
#' 3. Estimates aggregate CPUE using survey design
#' 4. Returns in standard tidycreel format
#'
#' @examples
#' \dontrun{
#' # Aggregate largemouth and smallmouth bass
#' cpue_black_bass <- aggregate_cpue(
#'   cpue_data = interviews,
#'   svy_design = svy_int,
#'   species_col = "species",
#'   species_values = c("largemouth_bass", "smallmouth_bass"),
#'   group_name = "black_bass",
#'   response = "catch_kept"
#' )
#'
#' # Use in total harvest calculation
#' harvest_black_bass <- est_total_harvest(effort_est, cpue_black_bass)
#' }
#'
#' @export
aggregate_cpue <- function(
  cpue_data,
  svy_design,
  species_col = "species",
  species_values,
  group_name,
  by = NULL,
  response = c("catch_total", "catch_kept", "catch_released"),
  effort_col = "hours_fished"
) {
  # Implementation:
  # 1. Validate inputs
  # 2. Create aggregated catch variable
  # 3. Update survey design with aggregated data
  # 4. Call est_cpue() on aggregated design
  # 5. Add group_name to results
}
```

### Species Group Definitions

Common groupings in fisheries management:

```r
# Standard taxonomic groups
standard_groups <- list(
  # Sunfish family (Centrarchidae)
  black_bass = c("largemouth_bass", "smallmouth_bass", "spotted_bass",
                 "guadalupe_bass", "shoal_bass"),
  panfish = c("bluegill", "redear_sunfish", "green_sunfish",
              "pumpkinseed", "longear_sunfish", "warmouth",
              "white_crappie", "black_crappie"),

  # Catfish (Ictaluridae)
  catfish = c("channel_catfish", "flathead_catfish", "blue_catfish",
              "bullhead_spp"),

  # Temperate bass (Moronidae)
  temperate_bass = c("white_bass", "striped_bass", "hybrid_striped_bass"),

  # Pike family (Esocidae)
  pike = c("northern_pike", "muskellunge", "tiger_muskie", "chain_pickerel"),

  # Walleye/Sauger (Percidae - predators)
  walleye_sauger = c("walleye", "sauger", "saugeye"),

  # Trout/Salmon (Salmonidae)
  trout = c("rainbow_trout", "brown_trout", "brook_trout", "lake_trout",
            "cutthroat_trout"),
  salmon = c("chinook_salmon", "coho_salmon", "sockeye_salmon",
             "pink_salmon", "chum_salmon"),

  # All centrarchids (sunfish family)
  centrarchids = c("black_bass", "panfish")  # References other groups
)

# Management-based groups
management_groups <- list(
  gamefish = c("black_bass", "pike", "walleye_sauger", "trout", "salmon"),
  sportfish = c("gamefish", "catfish", "temperate_bass"),
  nongame = c("carp", "gar", "bowfin", "buffalo")
)
```

### Hierarchical Aggregation

Support nested groupings (groups containing other groups):

```r
species_groups <- list(
  # Base groups (species level)
  black_bass = c("largemouth_bass", "smallmouth_bass"),
  panfish = c("bluegill", "redear_sunfish"),

  # Meta-groups (group level)
  centrarchids = c("black_bass", "panfish"),

  # Top level (all gamefish)
  gamefish = c("centrarchids", "pike", "walleye")
)
```

**Resolution Algorithm:**
1. Expand group references recursively
2. Detect circular references (error)
3. Aggregate from bottom up (species → groups → meta-groups)

### Multiple Stratification Levels

Support estimation at multiple strata simultaneously:

```r
# By location and species group
est_total_harvest(
  effort_by_location,           # Effort stratified by location
  cpue_by_location_species,     # CPUE by location × species
  by = c("location", "species"),
  species_groups = standard_groups,
  aggregate_level = "group"
)
```

Returns:
```
location  species_group  estimate    se
North     black_bass         1500   200
North     panfish             800   120
South     black_bass         2000   250
South     panfish            1200   150
```

### Special Cases

#### 1. Mixed Aggregation Levels
User wants some species individually and some as groups:

```r
# Want: largemouth (individual), other bass (grouped), panfish (grouped)
cpue_largemouth <- est_cpue(svy_int, filter_species = "largemouth_bass")
cpue_other_bass <- aggregate_cpue(
  svy_int, species = c("smallmouth_bass", "spotted_bass"),
  group_name = "other_bass"
)
cpue_panfish <- aggregate_cpue(
  svy_int, species = panfish_species, group_name = "panfish"
)

# Combine for reporting
harvest_detailed <- bind_rows(
  est_total_harvest(effort_est, cpue_largemouth),
  est_total_harvest(effort_est, cpue_other_bass),
  est_total_harvest(effort_est, cpue_panfish)
)
```

#### 2. All Species Combined
```r
# Aggregate CPUE across ALL species
cpue_all <- aggregate_cpue(
  cpue_data = interviews,
  svy_design = svy_int,
  species_col = "species",
  species_values = unique(interviews$species),  # All species
  group_name = "all_species",
  response = "catch_kept"
)

harvest_total <- est_total_harvest(effort_est, cpue_all)
```

#### 3. Conditional Grouping
Group by species only in certain locations:

```r
# Black bass grouped in reservoirs, separate in rivers
est_total_harvest(
  effort_est,
  cpue_est,
  by = c("waterbody_type", "species"),
  species_groups = list(
    black_bass = c("largemouth_bass", "smallmouth_bass")
  ),
  aggregate_condition = waterbody_type == "reservoir"
)
```

### Validation & Error Handling

```r
# Check for species not in data
validate_species_groups <- function(species_groups, cpue_data, species_col) {
  all_species <- unique(cpue_data[[species_col]])

  for (group_name in names(species_groups)) {
    group_species <- species_groups[[group_name]]
    missing <- setdiff(group_species, all_species)

    if (length(missing) > 0) {
      cli::cli_warn(c(
        "!" = "Species group {.field {group_name}} includes species not in data.",
        "i" = "Missing species: {.val {missing}}",
        ">" = "These will be ignored in aggregation."
      ))
    }
  }
}

# Detect circular references
detect_circular_refs <- function(species_groups) {
  # Graph-based cycle detection
  # Error if circular reference found
}
```

### Performance Considerations

- **Survey aggregation is computationally intensive** for large datasets
- Cache intermediate aggregations when doing multiple harvest calculations
- Consider parallel processing for multiple groups
- Document computational complexity in vignettes

---

## Statistical Methods

### Method 1: Product Estimator (Default)

**Estimate:**
```
H = E × C
```

Where:
- `H` = Total harvest
- `E` = Total effort (angler-hours)
- `C` = CPUE (catch per angler-hour)

**Variance (Delta Method):**

When E and C are **independent** (from different surveys):
```
Var(H) = E² × Var(C) + C² × Var(E)
```

When E and C are **correlated** (from same survey):
```
Var(H) = E² × Var(C) + C² × Var(E) + 2 × E × C × Cov(E,C)
```

**Standard Error:**
```
SE(H) = sqrt(Var(H))
```

**Confidence Interval (Wald):**
```
CI = H ± z_(α/2) × SE(H)
```

---

### Method 2: Separate Ratio Estimator

Alternative approach treating this as a ratio estimation problem.

**Estimate:**
```
H = (Σw_i × catch_i) / (Σw_i × effort_i) × E_total
```

Where we use survey weights to estimate the ratio, then multiply by total effort.

**Variance:**
Use Taylor linearization or replicate weights from the survey design.

---

### Correlation Between Effort and CPUE

**When are they correlated?**
- When CPUE is calculated from interviews that also contribute to effort estimates
- When both estimates use same survey design/weights

**When are they independent?**
- Effort from count data, CPUE from separate interview data
- Different survey designs/time periods

**Estimating Correlation:**
If not provided by user, can estimate from data when both from same survey:

```r
# If both estimates are from same source data
cor_est <- estimate_correlation(effort_data, cpue_data)
```

Default behavior:
- If `correlation = NULL`, assume independent (conservative)
- If `correlation = "auto"`, attempt to estimate from data
- If `correlation = numeric`, use provided value

---

## Target Species ("Caught While Sought")

### Conceptual Framework

**Total Catch of Species S:**
```
Total_S = Effort_all × CPUE_S_targeted × Prop_targeted +
          Effort_all × CPUE_S_incidental × (1 - Prop_targeted)
```

Simplified when incidental catch is negligible:
```
Total_S_sought = Effort_targeted_S × CPUE_S_targeted
```

Where:
- `Effort_targeted_S` = Effort by anglers targeting species S
- `CPUE_S_targeted` = CPUE of species S among those targeting it

### Implementation Options

#### Option A: Separate Function (Cleaner)

```r
est_total_harvest_sought(
  effort_est,                    # Total effort
  cpue_est_targeted,             # CPUE from targeted anglers
  target_proportion,             # Proportion targeting
  by = c("species", "location"),
  response = "catch_kept"
)
```

#### Option B: Integrated Function (More flexible)

```r
est_total_harvest(
  effort_est,
  cpue_est,
  by = c("species", "location"),
  response = "catch_kept",
  target_species_only = TRUE,    # NEW parameter
  target_col = "target_species"  # Column identifying target
)
```

**Recommendation:** Start with Option B (integrated) for flexibility.

---

## Data Requirements

### Input: effort_est

Tibble from `est_effort()` with required columns:
```r
- [grouping_vars] : character/factor (e.g., date, location)
- estimate        : numeric (angler-hours)
- se              : numeric (standard error)
- ci_low          : numeric
- ci_high         : numeric
- n               : integer
- method          : character
- diagnostics     : list
```

### Input: cpue_est

Tibble from `est_cpue()` with required columns:
```r
- [grouping_vars] : character/factor (must match effort_est)
- estimate        : numeric (catch per hour)
- se              : numeric (standard error)
- ci_low          : numeric
- ci_high         : numeric
- n               : integer
- method          : character
- diagnostics     : list
```

### Validation

Function must check:
1. ✅ Grouping variables match between inputs
2. ✅ No missing values in estimate/se columns
3. ✅ Positive values for estimates and SE
4. ✅ Same number of groups in both inputs
5. ⚠️ Warn if methods differ (e.g., instantaneous effort with ratio-of-means CPUE)
6. ⚠️ Warn if sample sizes differ substantially

---

## Implementation Plan

### Phase 1: Core Product Estimator (Week 1)

**File:** `R/est-total-harvest.R`

```r
#' Total Harvest/Catch Estimator (survey-first)
#'
#' Estimates total harvest, catch, or releases by multiplying effort and CPUE
#' estimates with proper variance propagation using the delta method.
#'
#' @param effort_est Tibble from \code{\link{est_effort}} with effort estimates
#' @param cpue_est Tibble from \code{\link{est_cpue}} with CPUE estimates
#' @param by Character vector of grouping variables (must match between inputs)
#' @param response Type of catch: "catch_total", "catch_kept", "catch_released"
#' @param method Estimation method: "product" (default) or "separate_ratio"
#' @param correlation Correlation between effort and CPUE. NULL (independent),
#'   "auto" (estimate from data), or numeric value between -1 and 1.
#' @param conf_level Confidence level for Wald CIs (default 0.95)
#' @param diagnostics Include diagnostic information (default TRUE)
#'
#' @return Tibble with grouping columns, estimate, se, ci_low, ci_high, n,
#'   method, and diagnostics list-column
#'
#' @details
#' Combines effort and CPUE estimates to calculate total harvest/catch:
#'
#' \deqn{H = E \times C}
#'
#' where \eqn{E} is total effort (angler-hours) and \eqn{C} is CPUE.
#'
#' **Variance Propagation (Delta Method):**
#'
#' When effort and CPUE are independent:
#' \deqn{Var(H) = E^2 \times Var(C) + C^2 \times Var(E)}
#'
#' When correlated (e.g., from same survey):
#' \deqn{Var(H) = E^2 \times Var(C) + C^2 \times Var(E) + 2EC \times Cov(E,C)}
#'
#' @examples
#' \dontrun{
#' # Complete workflow
#' library(tidycreel)
#' library(survey)
#'
#' # 1. Estimate effort from counts
#' svy_day <- as_day_svydesign(calendar, day_id = "date",
#'                              strata_vars = c("day_type"))
#' effort_est <- est_effort(svy_day, counts, method = "instantaneous",
#'                          by = c("location"))
#'
#' # 2. Estimate CPUE from interviews
#' svy_int <- svydesign(ids = ~1, weights = ~1, data = interviews)
#' cpue_est <- est_cpue(svy_int, by = c("location", "species"),
#'                      response = "catch_kept")
#'
#' # 3. Calculate total harvest
#' harvest_total <- est_total_harvest(
#'   effort_est,
#'   cpue_est,
#'   by = c("location", "species"),
#'   response = "catch_kept",
#'   method = "product"
#' )
#'
#' # 4. Total catch and releases
#' catch_total <- est_total_harvest(effort_est, cpue_total,
#'                                  response = "catch_total")
#' releases <- est_total_harvest(effort_est, cpue_released,
#'                               response = "catch_released")
#'
#' # 5. Verify relationship
#' catch_total$estimate ≈ harvest_total$estimate + releases$estimate
#' }
#'
#' @references
#' Seber, G.A.F. 1982. The Estimation of Animal Abundance. 2nd edition.
#'   Charles Griffin, London.
#'
#' Pollock, K.H., C.M. Jones, and T.L. Brown. 1994. Angler Survey Methods
#'   and Their Applications in Fisheries Management. American Fisheries
#'   Society Special Publication 25.
#'
#' @seealso
#' \code{\link{est_effort}}, \code{\link{est_cpue}}, \code{\link{est_catch}}
#'
#' @export
est_total_harvest <- function(
  effort_est,
  cpue_est,
  by = NULL,
  response = c("catch_total", "catch_kept", "catch_released"),
  method = c("product", "separate_ratio"),
  correlation = NULL,
  conf_level = 0.95,
  diagnostics = TRUE
) {
  # Implementation here
}
```

### Phase 2: Target Species Variant (Week 2)

Add parameters to main function:
```r
est_total_harvest(
  ...,
  target_species_only = FALSE,
  target_col = "target_species",
  target_value = NULL
)
```

Or separate function:
```r
est_total_harvest_sought(...)
```

### Phase 3: Testing (Week 2-3)

**Test File:** `tests/testthat/test-est-total-harvest.R`

Test cases:
1. Basic product estimator with known values
2. Grouped estimates (by species, location)
3. Variance propagation validation
4. Correlation handling (independent, correlated)
5. Different response types (total, kept, released)
6. Edge cases (zero effort, zero CPUE, single group)
7. Input validation (mismatched groups, missing columns)
8. Target species filtering
9. Integration with actual survey data

### Phase 4: Documentation (Week 3)

**Vignette:** `vignettes/complete-creel-workflow.Rmd`

Sections:
1. Introduction - Complete creel analysis workflow
2. Survey Design - Creating day-level and interview designs
3. Effort Estimation - From count data
4. CPUE Estimation - From interview data
5. Total Harvest Calculation - **NEW**
   - Total catch, harvest, and releases
   - Variance propagation
   - Interpretation
6. Target Species Analysis - **NEW**
   - Caught while sought
   - Species-specific effort
7. Visualization - Time series, comparisons
8. Reporting - Tables and figures

---

## API Design Decisions

### Decision 1: Single Function vs Multiple Functions

**Option A: Single comprehensive function**
```r
est_total_harvest(effort_est, cpue_est, ..., target_species_only = FALSE)
```
✅ Pros: Flexible, fewer functions to document
❌ Cons: More complex parameter handling

**Option B: Separate functions**
```r
est_total_harvest(effort_est, cpue_est, ...)
est_total_harvest_sought(effort_est, cpue_est, target_col, ...)
```
✅ Pros: Clearer intent, simpler parameters
❌ Cons: More functions, potential code duplication

**DECISION:** Start with Option A, add Option B if needed.

---

### Decision 2: Correlation Handling

**Option A: User provides correlation**
```r
correlation = 0.3  # User must know/estimate
```
✅ Pros: Explicit, user control
❌ Cons: Requires user knowledge

**Option B: Auto-estimate when possible**
```r
correlation = "auto"  # Function attempts to estimate
```
✅ Pros: Convenient, less user burden
❌ Cons: May be incorrect if data structure unclear

**Option C: Always assume independent (default)**
```r
correlation = NULL  # Conservative assumption
```
✅ Pros: Safe default, wider CIs
❌ Cons: May be overly conservative

**DECISION:** Support all three, default to Option C (NULL = independent).

---

### Decision 3: Response Type Consistency

Match existing pattern from `est_cpue()` and `est_catch()`:
```r
response = c("catch_total", "catch_kept", "weight_total")
```

**ADD:** `"catch_released"`

**DECISION:**
- Keep existing response types
- Add `"catch_released"`
- Document relationship: `catch_total = catch_kept + catch_released`

---

## Diagnostics Output

The `diagnostics` list-column should include:

```r
list(
  effort_method = "instantaneous",           # From effort estimate
  cpue_method = "ratio_of_means",           # From CPUE estimate
  correlation_assumed = 0,                   # Correlation used
  correlation_source = "user",               # "user", "auto", "independent"
  effort_n = 45,                            # Sample size from effort
  cpue_n = 120,                             # Sample size from CPUE
  variance_components = list(               # Breakdown
    var_from_effort = 1000,
    var_from_cpue = 500,
    var_from_covariance = 0
  ),
  warnings = character(),                    # Any warnings generated
  target_species_filter = FALSE,            # If filtered to target species
  target_species_value = NULL               # Value used for filtering
)
```

---

## Error Messages & Warnings

### Errors (abort execution)

```r
# Mismatched grouping variables
cli::cli_abort(c(
  "x" = "Grouping variables don't match between effort and CPUE estimates.",
  "i" = "effort_est groups: {.field {names(effort_est)}}",
  "i" = "cpue_est groups: {.field {names(cpue_est)}}",
  "!" = "Ensure 'by' parameter matches for both est_effort() and est_cpue()."
))

# Missing required columns
cli::cli_abort(c(
  "x" = "Required columns missing from {.arg effort_est}.",
  "i" = "Need: {.field estimate, se}",
  "!" = "Received: {.field {names(effort_est)}}"
))

# Invalid correlation value
cli::cli_abort(c(
  "x" = "Correlation must be between -1 and 1.",
  "!" = "Received: {.val {correlation}}"
))
```

### Warnings (continue with caution)

```r
# Different methods used
cli::cli_warn(c(
  "!" = "Effort and CPUE used different estimation methods.",
  "i" = "Effort: {.field {effort_method}}",
  "i" = "CPUE: {.field {cpue_method}}",
  ">" = "Ensure methods are compatible for your analysis."
))

# Large difference in sample sizes
cli::cli_warn(c(
  "!" = "Sample sizes differ substantially between effort and CPUE.",
  "i" = "Effort n: {.val {effort_n}}",
  "i" = "CPUE n: {.val {cpue_n}}",
  ">" = "Consider whether estimates represent same population."
))

# Assuming independence
cli::cli_inform(c(
  "i" = "Assuming independence between effort and CPUE (conservative).",
  ">" = "If correlated, provide correlation parameter for more accurate variance."
))
```

---

## Testing Strategy

### Unit Tests

**File:** `tests/testthat/test-est-total-harvest.R`

```r
test_that("product estimator multiplies correctly", {
  effort <- tibble(estimate = 1000, se = 100)
  cpue <- tibble(estimate = 2, se = 0.2)

  result <- est_total_harvest(effort, cpue, correlation = NULL)

  expect_equal(result$estimate, 2000)
})

test_that("variance propagation uses delta method", {
  E <- 1000
  SE_E <- 100
  C <- 2
  SE_C <- 0.2

  # Expected variance (independent)
  var_expected <- E^2 * SE_C^2 + C^2 * SE_E^2
  se_expected <- sqrt(var_expected)

  effort <- tibble(estimate = E, se = SE_E)
  cpue <- tibble(estimate = C, se = SE_C)

  result <- est_total_harvest(effort, cpue, correlation = NULL)

  expect_equal(result$se, se_expected, tolerance = 0.01)
})

test_that("correlation increases/decreases variance appropriately", {
  effort <- tibble(estimate = 1000, se = 100)
  cpue <- tibble(estimate = 2, se = 0.2)

  # Independent
  result_ind <- est_total_harvest(effort, cpue, correlation = NULL)

  # Positive correlation
  result_pos <- est_total_harvest(effort, cpue, correlation = 0.5)

  # Negative correlation
  result_neg <- est_total_harvest(effort, cpue, correlation = -0.5)

  # Positive correlation should increase variance
  expect_gt(result_pos$se, result_ind$se)

  # Negative correlation should decrease variance
  expect_lt(result_neg$se, result_ind$se)
})

test_that("grouped estimates work correctly", {
  effort <- tibble(
    species = c("bass", "pike"),
    estimate = c(1000, 800),
    se = c(100, 80),
    ci_low = c(800, 640),
    ci_high = c(1200, 960),
    n = c(50, 40),
    method = "instantaneous",
    diagnostics = list(NULL, NULL)
  )

  cpue <- tibble(
    species = c("bass", "pike"),
    estimate = c(2, 1.5),
    se = c(0.2, 0.15),
    ci_low = c(1.6, 1.2),
    ci_high = c(2.4, 1.8),
    n = c(100, 80),
    method = "ratio_of_means",
    diagnostics = list(NULL, NULL)
  )

  result <- est_total_harvest(effort, cpue, by = "species")

  expect_equal(nrow(result), 2)
  expect_equal(result$estimate[1], 2000)  # bass
  expect_equal(result$estimate[2], 1200)  # pike
})

test_that("response types work correctly", {
  effort <- tibble(estimate = 1000, se = 100, n = 50, method = "instantaneous",
                   ci_low = 800, ci_high = 1200, diagnostics = list(NULL))
  cpue_total <- tibble(estimate = 3, se = 0.3, n = 100, method = "ratio_of_means",
                       ci_low = 2.4, ci_high = 3.6, diagnostics = list(NULL))
  cpue_kept <- tibble(estimate = 2, se = 0.2, n = 100, method = "ratio_of_means",
                      ci_low = 1.6, ci_high = 2.4, diagnostics = list(NULL))
  cpue_released <- tibble(estimate = 1, se = 0.1, n = 100, method = "ratio_of_means",
                          ci_low = 0.8, ci_high = 1.2, diagnostics = list(NULL))

  total <- est_total_harvest(effort, cpue_total, response = "catch_total")
  kept <- est_total_harvest(effort, cpue_kept, response = "catch_kept")
  released <- est_total_harvest(effort, cpue_released, response = "catch_released")

  # Relationship should approximately hold
  expect_equal(total$estimate, kept$estimate + released$estimate, tolerance = 0.01)
})

test_that("input validation catches errors", {
  effort <- tibble(estimate = 1000, se = 100, species = "bass",
                   n = 50, method = "instantaneous", ci_low = 800,
                   ci_high = 1200, diagnostics = list(NULL))
  cpue <- tibble(estimate = 2, se = 0.2, location = "lake",
                 n = 100, method = "ratio_of_means", ci_low = 1.6,
                 ci_high = 2.4, diagnostics = list(NULL))

  # Mismatched grouping variables
  expect_error(
    est_total_harvest(effort, cpue, by = c("species", "location")),
    "Grouping variables"
  )
})

test_that("zero values handled appropriately", {
  effort <- tibble(estimate = 0, se = 0, n = 50, method = "instantaneous",
                   ci_low = 0, ci_high = 0, diagnostics = list(NULL))
  cpue <- tibble(estimate = 2, se = 0.2, n = 100, method = "ratio_of_means",
                 ci_low = 1.6, ci_high = 2.4, diagnostics = list(NULL))

  result <- est_total_harvest(effort, cpue)

  expect_equal(result$estimate, 0)
  expect_equal(result$se, 0)
})

test_that("target species filtering works", {
  # This will test the target_species_only functionality once implemented
  skip("Target species filtering not yet implemented")
})
```

### Integration Tests

Test with real survey workflow:
1. Create survey design
2. Estimate effort from counts
3. Estimate CPUE from interviews
4. Calculate total harvest
5. Verify results are reasonable

---

## Documentation Examples

### Example 1: Basic Usage

```r
library(tidycreel)
library(survey)

# 1. Effort from counts
svy_day <- as_day_svydesign(calendar, day_id = "date",
                             strata_vars = c("day_type"))
effort_est <- est_effort(svy_day, counts, method = "instantaneous")

# 2. CPUE from interviews
svy_int <- svydesign(ids = ~1, weights = ~1, data = interviews)
cpue_est <- est_cpue(svy_int, response = "catch_kept")

# 3. Total harvest
harvest <- est_total_harvest(effort_est, cpue_est, response = "catch_kept")

print(harvest)
#   estimate    se ci_low ci_high    n method     diagnostics
#       2000   250   1510    2490   NA product   <list [1]>
```

### Example 2: By Species and Location

```r
# Estimate by groups
effort_by_loc <- est_effort(svy_day, counts, by = "location",
                            method = "instantaneous")
cpue_by_species <- est_cpue(svy_int, by = c("location", "species"),
                             response = "catch_kept")

# Total harvest by location and species
harvest_detailed <- est_total_harvest(
  effort_by_loc,
  cpue_by_species,
  by = c("location", "species"),
  response = "catch_kept"
)

print(harvest_detailed)
#   location species estimate    se ci_low ci_high    n method diagnostics
#   North    bass        1500   200   1108    1892   NA product <list [1]>
#   North    pike         800   120    565    1035   NA product <list [1]>
#   South    bass        2200   280   1651    2749   NA product <list [1]>
#   South    pike        1100   150    806    1394   NA product <list [1]>
```

### Example 3: Total Catch Accounting

```r
# Calculate total catch, harvest, and releases
cpue_total <- est_cpue(svy_int, response = "catch_total")
cpue_kept <- est_cpue(svy_int, response = "catch_kept")
cpue_released <- est_cpue(svy_int, response = "catch_released")

catch_total <- est_total_harvest(effort_est, cpue_total,
                                 response = "catch_total")
catch_kept <- est_total_harvest(effort_est, cpue_kept,
                                response = "catch_kept")
catch_released <- est_total_harvest(effort_est, cpue_released,
                                    response = "catch_released")

# Verify relationship
summary_table <- tibble(
  metric = c("Total Catch", "Harvest (Kept)", "Released"),
  estimate = c(catch_total$estimate, catch_kept$estimate, catch_released$estimate),
  se = c(catch_total$se, catch_kept$se, catch_released$se)
)

print(summary_table)
#   metric          estimate    se
#   Total Catch         5000   500
#   Harvest (Kept)      3000   350
#   Released            2000   300
```

### Example 4: Target Species (Caught While Sought)

```r
# Future implementation
harvest_bass_sought <- est_total_harvest(
  effort_est,
  cpue_est,
  by = "species",
  response = "catch_kept",
  target_species_only = TRUE,
  target_col = "target_species",
  target_value = "bass"
)

print(harvest_bass_sought)
#   species estimate    se ci_low ci_high    n method     diagnostics
#   bass        1200   180    847    1553   NA product   <list [1]>
```

---

## Next Steps

1. ✅ Design document complete
2. ⬜ Implement core function (`est_total_harvest`)
3. ⬜ Write unit tests
4. ⬜ Integration testing with real data
5. ⬜ Documentation and vignettes
6. ⬜ Add target species variant
7. ⬜ Peer review and validation

---

## Questions for Discussion

1. **Correlation default:** Should we default to `NULL` (independent), `"auto"`, or require user to specify?

2. **Target species:** Separate function or integrated with parameters?

3. **Response types:** Add `"catch_released"` or calculate as `catch_total - catch_kept`?

4. **Method options:** Start with just "product" or also implement "separate_ratio"?

5. **Diagnostics:** What additional information should be included?

---

**Author:** Planning document generated by Claude Code
**Date:** October 24, 2025
**Status:** Awaiting implementation
