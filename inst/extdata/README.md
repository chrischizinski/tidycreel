# tidycreel Example Datasets

This directory contains realistic creel survey datasets for examples and vignettes.

## Lake Clearwater Summer 2024 Survey

A simulated 2-month summer creel survey (June 1 - July 31, 2024) with realistic patterns and distributions.

### Survey Design

- **Locations**: 3 access points
  - North Ramp (40% of effort) - Bass and walleye fishing
  - South Ramp (35% of effort) - Mixed species
  - East Pier (25% of effort) - Bank fishing for panfish/catfish
- **Temporal Stratification**:
  - Weekdays vs weekends (higher effort on weekends)
  - Morning (6am-12pm) and afternoon (2pm-8pm) shifts
- **Sampling**: Stratified random sampling
  - Target: 40% of weekdays, 80% of weekends
  - Actual: 92% success rate (missed days due to weather)

### Datasets

#### `example_calendar.csv` (366 rows)

Sampling calendar with target and actual samples per shift×location×day.

**Columns**:
- `date`: Survey date
- `location`: Access point name
- `shift_block`: "morning" or "afternoon"
- `day_type`: "weekday" or "weekend"
- `month`: Month abbreviation
- `season`: "summer"
- `weekend`: TRUE/FALSE
- `target_sample`: 1 if targeted for sampling, 0 otherwise
- `actual_sample`: 1 if actually sampled, 0 otherwise

**Summary**:
- 61 days × 3 locations × 2 shifts = 366 possible shift-location combinations
- 194 targeted samples, 179 actual samples (92% success rate)

#### `example_interviews.csv` (756 rows)

Interview data from access-point surveys.

**Columns**:
- `interview_id`: Unique interview identifier
- `date`, `location`, `shift_block`, `day_type`, `month`: Survey context
- `time_start`, `time_end`: Trip start/end times (POSIXct)
- `hours_fished`: Trip duration in hours
- `party_size`, `anglers`: Number of people in party
- `target_species`: Primary species targeted ("Bass", "Walleye", "Panfish", "Catfish")
- `catch_total`: Total fish caught
- `catch_kept`: Number of fish harvested
- `catch_released`: Number of fish released
- `trip_complete`: TRUE if trip was complete at interview time
- `interview_complete`, `refused`: Interview status flags

**Summary**:
- 756 interviews across 179 sampled shifts
- Mean trip duration: 4.0 hours
- Mean catch: 6 fish per interview
- 459 weekend interviews, 297 weekday interviews
- 85% complete trips (rest were in-progress)

**Realistic patterns**:
- More interviews on weekends (2-3x weekdays)
- Trip duration ~ Gamma(shape=4, scale=1)
- Catch rates vary by species and location
- Harvest rates: Bass 20%, Walleye 60%, Panfish 80%, Catfish 50%

#### `example_counts_instantaneous.csv` (443 rows)

Instantaneous (snapshot) angler counts.

**Columns**:
- `count_id`: Unique count identifier
- `date`, `location`, `shift_block`: Survey context
- `time`: Count observation time (POSIXct)
- `count`: Number of anglers observed
- `interval_minutes`: Duration of count (5-15 minutes)
- `total_day_minutes`: Total minutes in shift (240)

**Summary**:
- 443 counts across 179 sampled shifts
- 2-3 counts per sampled shift
- Mean count: 10.8 anglers per observation
- Counts taken every ~2 hours during shift

**Realistic patterns**:
- Higher counts on weekends vs weekdays
- North Ramp busiest, East Pier least busy
- Counts vary by time of day

#### `example_counts_progressive.csv` (684 rows)

Progressive (roving) counts with multiple passes along routes.

**Columns**:
- `count_id`: Unique count identifier
- `date`, `location`, `shift_block`: Survey context
- `pass_id`: Pass identifier (e.g., "C1P2" = Circuit 1, Pass 2)
- `time`: Pass start time (POSIXct)
- `count`: Anglers counted along route
- `route_minutes`: Time to complete route (mean ~30 minutes)

**Summary**:
- 684 pass observations
- 1-2 circuits per sampled shift
- 2-3 passes per circuit
- 59 unique circuits total
- Mean count: 6.9 anglers per pass

**Realistic patterns**:
- Multiple passes capture temporal variation within shifts
- Route takes ~30 minutes (slight variation)
- Counts slightly lower than instantaneous (partial coverage)

#### `example_aerial_counts.csv` (23 rows)

Aerial boat counts from fixed-wing aircraft flights over Lake Clearwater.

**Columns**:
- `flight_id`: Unique flight identifier
- `date`, `month`, `season`, `day_type`, `time_of_day`: Survey context
- `flight_time`: Start of flight (POSIXct)
- `flight_minutes`: Duration of flight
- `altitude_feet`, `speed_mph`: Flight parameters
- `cloud_cover`: "clear", "partly_cloudy", or "overcast"
- `glare`: Sun glare level ("none", "moderate", "high")
- `wind_mph`: Wind speed
- `observer`, `observer_experience`: Observer ID and experience level
- `visibility_correction`: Detection probability (0-1, accounts for weather/glare/experience)
- `calibration_factor`: Correction for undercounting (from ground-truth studies, ≥1.0)
- `boats_observed`: Number of boats counted
- `total_anglers_observed`: Estimated anglers (boats × ~2 anglers/boat)

**Summary**:
- 23 flights over 18 days (2-3 flights per week)
- Mean 19 boats and 36 anglers observed per flight
- Mean visibility correction: 0.678 (detection probability)
- Flights stratified: more on weekdays, some on weekends

**Realistic patterns**:
- Visibility affected by cloud cover, glare, and observer experience
- Veteran observers have better detection (less correction needed)
- Clear mornings/afternoons have high glare → lower visibility
- Calibration factors account for systematic undercounting

#### `example_busroute_counts.csv` (51 rows)

Angler counts from Highway 41 fishing access point surveys with unequal probability sampling.

**Columns**:
- `count_id`: Unique count identifier
- `date`, `month`, `season`, `day_type`: Survey context
- `stop_id`, `stop_name`: Access point identifier and name
- `stop_sequence`: Order of visit (1-8)
- `arrival_time`, `departure_time`: When observer arrived/left (POSIXct)
- `stop_minutes`: Time spent counting (2-5 minutes)
- `inclusion_prob`: Probability this stop is visited (0.06-0.80)
- `frame_size`: Total angler-hours available at this stop on this day
- `anglers_count`: Number of anglers counted
- `weather`, `surveyor`: Survey conditions and team

**Summary**:
- 51 stop visits across 19 survey days (~3 times per week)
- 8 potential stops along highway route
- Mean 2.7 stops visited per route (based on inclusion probabilities)
- Mean 0.4 anglers per stop
- Inclusion probabilities: 0.06 to 0.80 (unequal probability design)

**Realistic patterns**:
- High-probability stops: close to road, more parking, popular
- Low-probability stops: remote, limited access, less popular
- Frame sizes account for total fishing opportunity per stop
- Not all stops visited each time (probability-based selection)

#### `example_busroute_schedule.csv` (8 rows)

Frame file with inclusion probabilities and frame sizes for each Highway 41 access point.

**Columns**:
- `stop_id`, `stop_name`: Access point identifiers
- `road_distance_km`: Distance from main road (affects access)
- `parking_spaces`: Available parking capacity
- `popularity`: Historical use index (0-1)
- `stop_minutes`: Time required to count anglers (2-5 min)
- `inclusion_prob`: Probability of being sampled (0.06-0.80)
- `frame_size_weekday`, `frame_size_weekend`: Total angler-hours available
- `sampling_weight`: 1 / inclusion_prob (for design-based estimation)
- `accessibility`: "easy", "moderate", or "difficult"

**Summary**:
- 8 stops with varying accessibility and popularity
- Inclusion probabilities based on road distance, parking, and historical use
- Frame sizes: mean 44 weekday, 81 weekend angler-hours per stop
- Used to construct unequal probability survey designs

**Purpose**:
This frame file is used with `est_effort.busroute()` to create proper survey designs accounting for unequal selection probabilities.

## Usage Examples

### Create Day-Level Survey Design

```r
library(tidycreel)
library(survey)

# Load calendar
calendar <- read.csv(
  system.file("extdata/example_calendar.csv", package = "tidycreel")
)

# Create survey design
svy_day <- as_day_svydesign(
  calendar,
  day_id = "date",
  strata_vars = c("day_type", "month")
)
```

### Estimate Effort from Instantaneous Counts

```r
# Load counts
counts <- read.csv(
  system.file("extdata/example_counts_instantaneous.csv", package = "tidycreel")
)
counts$date <- as.Date(counts$date)

# Estimate effort by location
effort_est <- est_effort.instantaneous(
  counts = counts,
  by = c("location"),
  svy = svy_day,
  day_id = "date",
  minutes_col = "interval_minutes",
  total_minutes_col = "total_day_minutes"
)
```

### Estimate CPUE from Interviews

```r
# Load interviews
interviews <- read.csv(
  system.file("extdata/example_interviews.csv", package = "tidycreel")
)
interviews$date <- as.Date(interviews$date)

# Join weights from survey design
interviews_weighted <- interviews %>%
  left_join(svy_day$variables %>% select(date, .w), by = "date")

# Create interview-level design
svy_int <- survey::svydesign(
  ids = ~1,
  weights = ~.w,
  data = interviews_weighted
)

# Estimate CPUE by species
cpue_est <- est_cpue(
  svy_int,
  by = c("target_species"),
  response = "catch_total"
)
```

### Estimate Effort from Aerial Counts

```r
# Load aerial counts
aerial <- read.csv(
  system.file("extdata/example_aerial_counts.csv", package = "tidycreel")
)
aerial$date <- as.Date(aerial$date)
aerial$flight_time <- as.POSIXct(aerial$flight_time)

# Estimate effort with visibility and calibration corrections
effort_aerial <- est_effort.aerial(
  counts = aerial,
  by = NULL,  # Lakewide estimate
  svy = svy_day,
  day_id = "date",
  minutes_col = "flight_minutes",
  visibility_col = "visibility_correction",
  calibration_col = "calibration_factor"
)
```

### Estimate Effort from Bus-Route Counts

```r
# Load bus-route data
busroute <- read.csv(
  system.file("extdata/example_busroute_counts.csv", package = "tidycreel")
)
busroute$date <- as.Date(busroute$date)

# Load route schedule (frame)
schedule <- read.csv(
  system.file("extdata/example_busroute_schedule.csv", package = "tidycreel")
)

# Estimate effort accounting for unequal probabilities
effort_busroute <- est_effort.busroute(
  counts = busroute,
  by = c("stop_name"),
  svy = svy_day,
  day_id = "date"
)
```

## Data Generation

The datasets were generated using two scripts in this directory:

### Access-Point, Roving, and Interview Data
`generate_realistic_data.R` creates:
1. Realistic sampling calendar with stratified design
2. Interviews with biologically realistic patterns
3. Instantaneous and progressive counts
4. Proper statistical distributions (Gamma, Poisson, etc.)

```bash
Rscript inst/extdata/generate_realistic_data.R
```

### Aerial and Bus-Route Data
`generate_additional_data.R` creates:
1. Aerial counts with visibility/calibration corrections
2. Bus-route counts with unequal probability sampling
3. Frame file with inclusion probabilities and frame sizes

```bash
Rscript inst/extdata/generate_additional_data.R
```

## Legacy Datasets

The `toy_*.csv` files are minimal examples for quick tests but lack realistic patterns. **Use the `example_*.csv` files for vignettes and meaningful analyses.**

---

For questions about these datasets, see the tidycreel documentation or GitHub issues.
