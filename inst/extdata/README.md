# Example Datasets for tidycreel

These datasets are real creel survey data from the **Pawnee Reservoir 2016** creel survey
conducted by the Nebraska Game and Parks Commission.

## Files

- **toy_calendar.csv**: Survey design calendar with sampling dates and strata
  - 34 days
  - Columns: date, day_type, month, weekend, actual_sample, target_sample

- **toy_counts.csv**: Instantaneous angler counts at access points
  - 68 count observations
  - Columns: date, location, shift_block, time_start, count, count_duration, total_minutes, interviewer

- **toy_interviews.csv**: Completed angler interviews with catch data
  - 1333 interviews
  - Columns: date, location, shift_block, interview_id, party_size, hours_fished,
    trip_complete, target_species, angler_type, method_type,
    catch_kept, catch_released, catch_total

## Source

Data retrieved from the University of Nebraska-Lincoln Creel Survey API on 2025-12-01.

- Creel UID: 90f5375c-afe0-e511-80bf-0050568372f9
- Creel Name: Pawnee Reservoir 2016
- Waterbody: Pawnee Reservoir, NE
- Survey Period: 2016-04-01 to 2016-05-31
- Subset: First ~2 months of data for manageable toy dataset

## Usage

These datasets are designed for use in vignettes and examples demonstrating
the survey-first workflow:

```r
# Load datasets
calendar <- read.csv(system.file('extdata', 'toy_calendar.csv', package = 'tidycreel'))
counts <- read.csv(system.file('extdata', 'toy_counts.csv', package = 'tidycreel'))
interviews <- read.csv(system.file('extdata', 'toy_interviews.csv', package = 'tidycreel'))

# Create day-level survey design
library(tidycreel)
svy_day <- as_day_svydesign(calendar, day_id = 'date',
                            strata_vars = c('day_type', 'month'))

# Estimate effort
effort <- est_effort(svy_day, counts, method = 'instantaneous', by = 'location')

# Estimate CPUE
cpue <- est_cpue(svy_day, interviews, by = 'location', response = 'catch_total')
```

## Privacy

This is public research data with no personally identifiable information (PII).
All sensitive data has been excluded per tidycreel data protection protocols.

