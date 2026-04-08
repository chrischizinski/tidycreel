## Design Assumptions

All tidycreel survey constructors rely on key statistical and operational assumptions:

- **Random sampling within stratum:** The survey randomly selects each unit (angler, party, or time block) within its stratum to ensure unbiased estimates.
- **Strata are correctly defined:** Temporal and spatial strata (e.g., weekday/weekend, shift blocks, locations) reflect true variation in effort and catch.
- **Complete coverage or known probabilities:** For access-point designs, interviewers survey all exiting anglers or use known inclusion probabilities. For roving and bus route designs, the survey estimates or provides probabilities.
- **Nonresponse is random or accounted for:** Any nonresponse (e.g., anglers refusing interviews) occurs randomly or is corrected using weights or imputation.
- **Effort and catch are accurately reported:** Interviewed anglers provide truthful and accurate information about their fishing effort and catch.
- **No double-counting:** The survey counts or interviews each angler or party only once per sampling unit.
- **Replicate weights reflect true sampling variability:** For variance estimation, the survey builds replicate weights (bootstrap, jackknife, BRR) to mimic the actual sampling process.

Review and document assumptions for each survey design. If you find violations, adjust the design, run sensitivity analyses, or apply explicit bias correction.
# tidycreel Survey-First Architecture & Usage
---

## Survey-First Approach

The tidycreel package has evolved to a survey-first framework where day-PSU survey designs (`svydesign`) are the primary interface for statistical analysis.

### Key Changes
- Legacy design constructors (`design_access`, `design_roving`, `design_repweights`) have been **removed**
- Primary workflow now uses `as_day_svydesign()` to create survey designs from sampling calendars
- Estimators work directly with survey designs and data tables
- All variance estimation handled through the survey package backbone

## Survey Design Workflow
- **Day-PSU Designs:** Use `as_day_svydesign(calendar, day_id, strata_vars)` to create the statistical foundation
- **Data Integration:** Pass survey designs and data tables directly to estimators
- **Accessing Data:** Use `svy$variables` to access data in survey design objects
- **Object Structure:** Survey design objects contain slots for clusters, strata, probabilities, and variables

## Example Usage
```r
library(tidycreel)
calendar <- readr::read_csv("inst/extdata/toy_calendar.csv")
interviews <- readr::read_csv("inst/extdata/toy_interviews.csv")

# Create day-PSU survey design
svy_day <- as_day_svydesign(calendar, day_id = "date", strata_vars = c("day_type", "month"))
summary(svy_day)

# Use with estimators
cpue_estimates <- est_cpue(svy_day, interviews = interviews, by = c("target_species"))
```

---

_Last updated: 2025-08-27_

This living document explains the survey-first architecture in the tidycreel package. We actively maintain and expand it as the project evolves.

## Core Principle
The survey-first approach builds on the survey package (`survey::svydesign` or `survey::svrepdesign`) to ensure design-based inference, statistical rigor, and compatibility with established survey analysis workflows.

## Current Design Functions

### Day-PSU Survey Design (`as_day_svydesign`)
- Creates day-level survey designs from sampling calendars
- Handles stratification, clustering, and sampling weights
- Provides statistical foundation for all downstream estimation

### Bus Route Design (`design_busroute`)
- Specialized design for bus route sampling methodology
- Checks and preprocesses interview, count, calendar, and route schedule data
- Builds and stores a `survey::svydesign` object using unequal probability weights and strata
- Returns a list with metadata, weights, probabilities, frame sizes, and the survey design object

## Survey Design Integration
The survey-first approach:
- Creates robust statistical foundations using established survey methodology
- Integrates seamlessly with survey and srvyr packages
- Provides consistent variance estimation across all estimators
- Supports complex sampling designs and weighting schemes
## Usage Examples

### Creating Day-PSU Survey Designs
```r
library(tidycreel)
calendar <- readr::read_csv("inst/extdata/toy_calendar.csv")

# Basic day-PSU survey design
svy_day <- as_day_svydesign(
  calendar,
  day_id = "date",
  strata_vars = c("day_type", "month")
)
summary(svy_day)
```

### Effort Estimation with Survey Designs
```r
# Instantaneous counts with survey design
counts_inst <- readr::read_csv("inst/extdata/toy_counts.csv")
effort_est <- est_effort.instantaneous(
  counts_inst,
  by = c("location"),
  minutes_col = "count_duration",
  total_minutes_col = "total_day_minutes",
  day_id = "date",
  svy = svy_day
)
```

### CPUE and Catch Estimation
```r
interviews <- readr::read_csv("inst/extdata/toy_interviews.csv")

# CPUE estimation with survey design
cpue_est <- est_cpue(
  svy_day,
  interviews = interviews,
  by = c("target_species"),
  response = "catch_total"
)

# Catch estimation
catch_est <- est_catch(
  svy_day,
  interviews = interviews,
  by = c("target_species"),
  response = "catch_kept"
)
```

### Replicate Weight Designs
```r
# Create bootstrap replicate design for robust variance estimation
svy_rep <- survey::as.svrepdesign(svy_day, type = "bootstrap", replicates = 50, mse = TRUE)
summary(svy_rep)
```

### Bus Route Design
```r
library(tidycreel)
busroute_design <- design_busroute(
	interviews = read.csv("sample_data/toy_interviews.csv"),
	counts = read.csv("sample_data/toy_counts.csv"),
	calendar = read.csv("sample_data/toy_calendar.csv"),
	route_schedule = read.csv("sample_data/toy_routes.csv")
)
print(busroute_design) # S3 print method for creel_design
summary(busroute_design) # S3 summary method for creel_design
```

## Working with Survey Designs

The survey-first approach uses standard survey package objects directly, eliminating the need for conversion helpers.

### Survey Package Integration
- Survey designs (`svydesign` and `svrepdesign`) are the primary objects for statistical analysis
- All tidycreel estimators accept survey designs directly
- Full compatibility with survey and srvyr package functions for advanced analysis

### Best Practices
- Always validate calendar data before creating survey designs
- Use `summary()` to inspect survey design structure and weights
- Consider replicate weight designs for robust variance estimation
- Document stratification decisions and sampling assumptions
- See also: [creel_foundations.md](creel_foundations.md), [creel_chapter.md](creel_chapter.md)

_Last updated: 2025-08-27_
