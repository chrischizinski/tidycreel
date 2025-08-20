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
# tidycreel Design Constructors: Architecture & Usage
---

## Survey Design Conversion
- **Accessing Data:**
	- Use `svy$variables` (not `svy$data`) to access the data in survey design objects.
	- Example:
		```r
		svy <- as_survey_design(design)
		head(svy$variables)
		```
- **Object Structure:**
	- Survey design objects contain slots for clusters, strata, probabilities, and variables.
	- Use `str(svy)` to inspect the full structure.

## Diagnostics and Robustness
- **Test Diagnostics:**
	- Unit tests print diagnostics for NA weights and dropped rows.
	- If all or most weights are NA, tests will fail with a clear message.
- **Constructor Warnings:**
	- `design_access()` and `design_roving()` issue warnings if all or most weights are NA.
	- Warnings help catch mismatches in strata, locations, or calendar data early.

## Best Practices
- Always check for NA weights after constructing a design object.
- Use summary and print methods to verify design integrity.
- If you see warnings about NA weights, review your strata variables and input data for mismatches.

## Edge Cases & Troubleshooting
- **All weights NA:**
		- This typically means interview strata do not match calendar strata.
	- Check that all required columns and values are present and aligned.
- **Partial NA weights:**
		- This can show incomplete overlap between interview and calendar data.
	- Review stratification variables and data sources.
- **Survey design object has zero rows:**
		- Check for NA weights, missing stratification columns, or filtering in the survey package.

## Example Usage
```r
interviews <- readr::read_csv("inst/extdata/toy_interviews.csv")
calendar <- readr::read_csv("inst/extdata/toy_calendar.csv")
design <- design_access(interviews, calendar)
svy <- as_survey_design(design)
summary(design)
head(svy$variables)
```

---

_Last updated: 2025-08-20_

This living document explains the architecture, principles, and usage of design constructors in the tidycreel package. We actively maintain and expand it as the project evolves.

## Core Principle
All design constructors in tidycreel build on the survey package (`survey::svydesign` or `survey::svrepdesign`) to ensure design-based inference, statistical rigor, and compatibility with established survey analysis workflows.

## Constructors

### Access-Point Design (`design_access`)

### Roving Design (`design_roving`)

### Replicate Weights Design (`design_repweights`)

### Bus Route Design (`design_busroute`)
### Bus Route Design (`design_busroute`)
- Checks and preprocesses interview, count, calendar, and route schedule data.
- Merges interview data with route schedule to link probabilities and frame sizes.
- Builds and stores a `survey::svydesign` object using unequal probability weights and strata.
- Returns a list with metadata, weights, probabilities, frame sizes, and the survey design object.

## Consistency
All design constructors:
All design constructors:
- Check input data using schema functions.
- Calculate or merge appropriate weights and probabilities.
- Build and store a survey design object for downstream analysis.
- Return a list with metadata, input data, and the survey design object.

## Next Steps
## Usage Examples

### Visualizing Survey Design Coverage
```r
library(tidycreel)
access_design <- design_access(
	interviews = read.csv("sample_data/toy_interviews.csv"),
	calendar = read.csv("sample_data/toy_calendar.csv")
)
plot_design(access_design) # Shows interviews by date/shift, faceted by location
```


### Access-Point Design
```r
	interviews = read.csv("sample_data/toy_interviews.csv"),
	calendar = read.csv("sample_data/toy_calendar.csv")
library(tidycreel)
interviews <- readr::read_csv("inst/extdata/toy_interviews.csv")
calendar <- readr::read_csv("inst/extdata/toy_calendar.csv")
design <- design_access(interviews, calendar)
print(design) # S3 print method for creel_design
summary(design) # S3 summary method for creel_design
plot_design(design)
svy <- as_survey_design(design)
head(svy$variables)
```

### Roving Design
```r
	interviews = read.csv("sample_data/toy_interviews.csv"),
	counts = read.csv("sample_data/toy_counts.csv"),
	calendar = read.csv("sample_data/toy_calendar.csv")
library(tidycreel)
interviews <- readr::read_csv("inst/extdata/toy_interviews.csv")
counts <- readr::read_csv("inst/extdata/toy_counts.csv")
calendar <- readr::read_csv("inst/extdata/toy_calendar.csv")
design <- design_roving(interviews, counts, calendar)
print(design) # S3 print method for creel_design
summary(design) # S3 summary method for creel_design
plot_design(design)
svy <- as_survey_design(design)
head(svy$variables)
```

### Replicate Weights Design
```r
	base_design = access_design,
	method = "bootstrap"
library(tidycreel)
interviews <- readr::read_csv("inst/extdata/toy_interviews.csv")
calendar <- readr::read_csv("inst/extdata/toy_calendar.csv")
base_design <- design_access(interviews, calendar)
rep_design <- design_repweights(base_design, replicates = 50, method = "bootstrap")
print(rep_design) # S3 print method for creel_design
summary(rep_design) # S3 summary method for creel_design
svyrep <- as_svrep_design(rep_design)
head(svyrep$variables)
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

## Bridging tidycreel and survey: Conversion Helpers

All tidycreel design objects (access-point, roving, replicate weights, bus route) embed a survey design object (`survey::svydesign` or `survey::svrepdesign`).

### Why Conversion Helpers?
- The survey package is powerful but complex; tidycreel provides a tidy, pipe-friendly interface and stores the survey design for you.
- Use `as_survey_design()` to extract the embedded survey design for analysis with survey or srvyr functions.
- Use `as_svrep_design()` for advanced resampling-based inference (bootstrap, jackknife, BRR).

### Usage Examples
```r
library(tidycreel)
access_design <- design_access(
  interviews = read.csv("sample_data/toy_interviews.csv"),
  calendar = read.csv("sample_data/toy_calendar.csv")
)
svy <- as_survey_design(access_design)
summary(svy)

rep_design <- design_repweights(
  base_design = access_design,
  method = "bootstrap"
)
svyrep <- as_svrep_design(rep_design)
summary(svyrep)
```

### Best Practices
- Always validate input data before constructing a design object.
- Use conversion helpers for downstream analysis, variance estimation, and domain estimation.
- Document assumptions and edge cases in code and in this file.
- See also: [creel_foundations.md](creel_foundations.md), [creel_chapter.md](creel_chapter.md)

_Last updated: 2025-08-20_
