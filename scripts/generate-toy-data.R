# Generate Toy Datasets for Vignettes
# This script queries the Creel Survey API to create realistic example datasets
# for use in package vignettes and examples.

library(jsonlite)
library(dplyr)
library(tidyr)
library(lubridate)
library(here)

# API base URL (using HTTPS)
api_base <- "https://creelsurvey.unl.edu/api/"

# Select a moderate-sized creel with good data
# Using "Pawnee 2016" - good example with complete data
creel_uid <- "90f5375c-afe0-e511-80bf-0050568372f9"
creel_name <- "pawnee_2016"

cat("Fetching data from Creel Survey API...\n")
cat("Creel: Pawnee 2016\n\n")

# Fetch counts
counts_url <- paste0(api_base, "AnalysisData/GetCountData?Creel_UIDs=", creel_uid)
cat("Fetching counts...\n")
counts_raw <- fromJSON(counts_url)
cat("  -> Got", nrow(counts_raw), "rows\n")

# Fetch interviews
interviews_url <- paste0(api_base, "AnalysisData/GetInterviewData?Creel_UIDs=", creel_uid)
cat("Fetching interviews...\n")
interviews_raw <- fromJSON(interviews_url)
cat("  -> Got", nrow(interviews_raw), "rows\n")

# Fetch catch
catch_url <- paste0(api_base, "AnalysisData/GetCatchData?Creel_UIDs=", creel_uid)
cat("Fetching catch...\n")
catch_raw <- fromJSON(catch_url)
cat("  -> Got", nrow(catch_raw), "rows\n\n")

cat("=== Creating Toy Datasets ===\n\n")

# 1. Process counts data
# Combine bank anglers and boat anglers for total count
counts_full <- counts_raw %>%
  mutate(
    date = as.Date(cd_Date),
    location = cd_Section,
    shift_block = case_when(
      cd_Period == 1 ~ "morning",
      cd_Period == 2 ~ "afternoon",
      TRUE ~ "evening"
    ),
    time_start = c_CountTime,
    count = c_BankAnglers + c_AnglerBoats,
    count_duration = 30, # Assume 30-minute count
    total_minutes = 720, # 12-hour fishing day
    interviewer = NA
  ) %>%
  select(date, location, shift_block, time_start, count, count_duration, total_minutes, interviewer) %>%
  filter(!is.na(count), !is.na(date)) %>%
  arrange(date, time_start)

# Filter to first 60 days
first_date <- min(counts_full$date, na.rm = TRUE)
cutoff_date <- first_date + 60

counts <- counts_full %>%
  filter(date <= cutoff_date)

cat(
  "✓ Created counts:", nrow(counts), "count records (filtered from",
  nrow(counts_full), ")\n"
)
cat(
  "  Date range:", format(first_date, "%Y-%m-%d"), "to",
  format(cutoff_date, "%Y-%m-%d"), "\n"
)

# 2. Process interviews data
interviews_full <- interviews_raw %>%
  mutate(
    date = as.Date(cd_Date),
    location = cd_Section,
    shift_block = case_when(
      cd_Period == 1 ~ "morning",
      cd_Period == 2 ~ "afternoon",
      TRUE ~ "evening"
    ),
    interview_id = rowID,
    party_size = ii_NumberAnglers,
    hours_fished = ii_TimeFishedHours + ii_TimeFishedMinutes / 60,
    trip_complete = ii_TripType == 1, # 1 = completed trip
    target_species = ii_SpeciesSought,
    angler_type = ii_AnglerType,
    method_type = ii_AnglerMethod
  ) %>%
  select(
    date, location, shift_block, interview_id, party_size, hours_fished,
    trip_complete, target_species, angler_type, method_type
  ) %>%
  filter(!is.na(interview_id), !is.na(date)) %>%
  arrange(date, interview_id)

# Filter to match counts date range
interviews <- interviews_full %>%
  filter(date >= first_date, date <= cutoff_date)

cat(
  "✓ Created interviews:", nrow(interviews), "interviews (filtered from",
  nrow(interviews_full), ")\n"
)

# 3. Process catch data
catch_full <- catch_raw %>%
  mutate(
    interview_id = rowID,
    species = ir_Species,
    catch_kept = if_else(CatchType == "H", Num, 0),
    catch_released = if_else(CatchType == "R", Num, 0),
    catch_total = Num
  ) %>%
  filter(!is.na(interview_id)) %>%
  group_by(interview_id) %>%
  # Sum catch across all species per interview
  summarise(
    catch_kept = sum(catch_kept, na.rm = TRUE),
    catch_released = sum(catch_released, na.rm = TRUE),
    catch_total = sum(catch_total, na.rm = TRUE),
    .groups = "drop"
  )

# Merge catch with interviews
interviews_with_catch <- interviews %>%
  left_join(catch_full, by = "interview_id") %>%
  mutate(
    catch_kept = replace_na(catch_kept, 0),
    catch_released = replace_na(catch_released, 0),
    catch_total = replace_na(catch_total, 0)
  )

cat("✓ Created catch data:", nrow(catch_full), "catch records\n")
cat("✓ Merged with interviews:", nrow(interviews_with_catch), "total rows\n")

# 4. Create calendar from actual survey dates
all_dates <- sort(unique(c(counts$date, interviews_with_catch$date)))

calendar <- tibble(
  date = all_dates,
  day_type = ifelse(weekdays(date) %in% c("Saturday", "Sunday"), "weekend", "weekday"),
  month = format(date, "%B"),
  weekend = weekdays(date) %in% c("Saturday", "Sunday")
) %>%
  # Add sampling activity indicators
  left_join(
    counts %>% count(date, name = "actual_sample"),
    by = "date"
  ) %>%
  mutate(
    actual_sample = replace_na(actual_sample, 0),
    target_sample = 2 # Assume 2 count periods per day
  ) %>%
  arrange(date)

cat("✓ Created calendar:", nrow(calendar), "days from actual survey dates\n")

# 5. Save datasets to inst/extdata/
output_dir <- here("inst", "extdata")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

cat("\n=== Saving Datasets ===\n\n")

# Save calendar
write.csv(calendar, file.path(output_dir, "toy_calendar.csv"), row.names = FALSE)
cat("✓ Saved calendar to toy_calendar.csv\n")

# Save counts
write.csv(counts, file.path(output_dir, "toy_counts.csv"), row.names = FALSE)
cat("✓ Saved counts to toy_counts.csv\n")

# Save interviews
write.csv(interviews_with_catch, file.path(output_dir, "toy_interviews.csv"), row.names = FALSE)
cat("✓ Saved interviews with catch to toy_interviews.csv\n")

# 6. Create README
readme_content <- paste0(
  "# Example Datasets for tidycreel

These datasets are real creel survey data from the **Pawnee Reservoir 2016** creel survey
conducted by the Nebraska Game and Parks Commission.

## Files

- **toy_calendar.csv**: Survey design calendar with sampling dates and strata
  - ", nrow(calendar), " days
  - Columns: date, day_type, month, weekend, actual_sample, target_sample

- **toy_counts.csv**: Instantaneous angler counts at access points
  - ", nrow(counts), " count observations
  - Columns: date, location, shift_block, time_start, count, count_duration, total_minutes, interviewer

- **toy_interviews.csv**: Completed angler interviews with catch data
  - ", nrow(interviews_with_catch), " interviews
  - Columns: date, location, shift_block, interview_id, party_size, hours_fished,
    trip_complete, target_species, angler_type, method_type,
    catch_kept, catch_released, catch_total

## Source

Data retrieved from the University of Nebraska-Lincoln Creel Survey API on ",
  Sys.Date(), ".

- Creel UID: ", creel_uid, "
- Creel Name: Pawnee Reservoir 2016
- Waterbody: Pawnee Reservoir, NE
- Survey Period: ", paste(min(calendar$date), "to", max(calendar$date)), "
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
"
)

writeLines(readme_content, file.path(output_dir, "README.md"))
cat("✓ Saved README.md\n")

cat("\n=== Summary ===\n")
cat("Toy datasets created from Pawnee 2016 creel\n")
cat("Output directory:", output_dir, "\n")
cat("  - toy_calendar.csv:", nrow(calendar), "days\n")
cat("  - toy_counts.csv:", nrow(counts), "count records\n")
cat("  - toy_interviews.csv:", nrow(interviews_with_catch), "interviews\n")
cat("\nTo use in vignettes, reference these files with:\n")
cat("  system.file('extdata', 'toy_calendar.csv', package = 'tidycreel')\n")
cat("  system.file('extdata', 'toy_counts.csv', package = 'tidycreel')\n")
cat("  system.file('extdata', 'toy_interviews.csv', package = 'tidycreel')\n")
