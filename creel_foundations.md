
# Part A – Statistical Foundations for Creel Survey Analysis

## Overview of Creel Surveys in Recreational Fisheries
Creel surveys (on-site angler surveys) are a cornerstone of recreational fisheries monitoring, used to estimate total angling effort, catch, and harvest from sampled anglers【9†L75-L83】. In these surveys, field personnel combine **angler counts** (to measure fishing effort) with **angler interviews** (to measure catch per unit effort, or *CPUE*)【9†L75-L83】. By multiplying the estimated effort by the catch rate, managers obtain total catch and harvest estimates for a fishery【9†L75-L83】. Such data inform management decisions on harvest regulations, stocking, and angler satisfaction【6†L125-L133】.

## Established Creel Survey Designs
- **Access-Point Surveys:** Clerks interview anglers at the end of their fishing trip【9†L58-L66】. Complete-trip data avoids biases from incomplete trips. Effort is measured by counts or logs; best when anglers exit through defined points【39†L5638-L5646】.
- **Roving Surveys:** Clerks move through the fishery counting anglers and interviewing mid-trip or at completion【9†L62-L70】. Requires special handling for incomplete trips. Variants include roving-access and roving-roving.
- **Aerial Surveys:** Aircraft or drones count anglers/boats from the air, paired with ground-based interviews【9†L56-L64】. Efficient for large areas, may require visibility bias correction.

**Best Practices:** Surveys are typically stratified by time (weekday/weekend, monthly waves)【9†L92-L100】, with random selection of days/shifts to ensure a probability sample【46†L1-L4】.

## Core Statistical Estimation Methods
- **Effort:** Derived from instantaneous or progressive counts, expanded to day/season totals. Adjust for subsampled hours and multi-stage sampling.
- **Catch & Harvest:** CPUE from ratio-of-means (preferred for incomplete trips) or mean-of-ratios (complete trips)【33†L1-L8】【39†L5679-L5687】. Multiply CPUE × effort for totals.
- **Variance:** Stratified and multi-stage sampling formulas, delta method for products, bootstrap or replicate weights for complex cases【13†L1-L4】.

## Bias Considerations
- **Incomplete-trip bias:** Longer trips more likely intercepted mid-trip; ratio-of-means reduces bias【39†L5679-L5687】.
- **Targeted vs non-targeted:** Effort and catch should be differentiated when possible【39†L5710-L5718】.
- **Nonresponse:** Apply weighting or calibration to known totals.



# Part B – R Package Design & Implementation Recommendations

## Package Goals
Develop a flexible, generalizable package for analyzing creel survey data from multiple designs (access-point, roving, aerial), grounded in design-based inference and best-practice estimators.

## Data Structure
- **Counts Table:** date, time, location, count type (instantaneous/progressive/aerial), angler units counted, stratum IDs【9†L81-L89】.
- **Interviews Table:** date, location, trip status (complete/incomplete), party size, trip effort, species-specific catch/harvest【9†L85-L93】.
- **Metadata Table:** survey type, strata definitions, sampling frame sizes, inclusion probabilities【41†L59-L67】.

## Core Functions
- `creel_design()` – builds a survey design object (wraps `survey::svydesign`).
- `est_effort()` – computes angler-hours/trips by stratum and overall.
- `est_catch()` – computes catch/harvest totals by species.
- `est_cpue()` – calculates CPUE using correct estimator for design.
- All functions return estimates with SE/CI and metadata.

## Architecture
- Base inference via `survey` and `srvyr`.
- S3 classes: `creel_design` (design object) and `creel_estimate` (result object).
- Accept tidy data; output tibbles with SE/CI.
- Handle multi-stage designs and domain estimation.

## Additional Features
- Scheduling & simulation tools (integrate concepts from `AnglerCreelSurveySimulation`【37†L3-L7】).
- Automated reporting (Quarto/Rmd) with tables/plots.
- Data validation/cleaning helpers (logical checks, missing values).
- Extensibility to marine/off-site surveys by allowing external effort inputs.

## Output
- CSV/Excel export with metadata.
- Plots: effort trends, CPUE by stratum/species, harvest composition.
- Integration with GIS for mapping results.

## Documentation
- Vignettes for each survey design type.
- References to foundational literature (Pollock et al. 1994【36†L66-L70】, Lockwood 2000, Bernard et al. 1998).
- Best-practice guidance embedded in function documentation.
