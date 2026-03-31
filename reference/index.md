# Package index

## Survey Design

Build a creel survey design object and attach observational data. All
estimation functions accept a `creel_design` object as their first
argument.

- [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
  : Create a creel survey design
- [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  : Attach count data to a creel design
- [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  : Attach interview data to a creel design
- [`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md)
  : Attach species-level catch data to a creel design
- [`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md)
  : Attach fish length frequency data to a creel design
- [`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md)
  : Register spatial sections for a creel survey design
- [`as_survey_design()`](https://chrischizinski.github.io/tidycreel/reference/as_survey_design.md)
  : Extract internal survey design object for advanced use
- [`compute_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_effort.md)
  : Resolve fishing effort from timestamps or self-reported time
- [`compute_angler_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_angler_effort.md)
  : Normalize fishing effort to angler-hours

## Estimation

Design-based estimators for effort, catch rates, and totals. Functions
dispatch automatically on survey type.

- [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
  : Estimate total effort from a creel survey design
- [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
  : Estimate CPUE (Catch Per Unit Effort) from a creel survey design
- [`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md)
  : Estimate harvest (HPUE: Harvest Per Unit Effort) from a creel survey
  design
- [`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md)
  : Estimate release rate (RPUE: Released fish Per Unit Effort) from a
  creel survey design
- [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
  : Estimate total catch by combining effort and CPUE
- [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
  : Estimate total harvest by combining effort and HPUE
- [`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
  : Estimate total extrapolated release by combining effort and release
  rate

## Reporting & Diagnostics

Summarize interview data by angler characteristics, validate designs,
and check data completeness.

- [`summarize_trips()`](https://chrischizinski.github.io/tidycreel/reference/summarize_trips.md)
  : Summarize trip metadata for interview data
- [`summarize_refusals()`](https://chrischizinski.github.io/tidycreel/reference/summarize_refusals.md)
  : Tabulate refused vs accepted interviews by month
- [`summarize_by_day_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_day_type.md)
  : Tabulate interviews by day type and month
- [`summarize_by_angler_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_angler_type.md)
  : Tabulate interviews by angler type and month
- [`summarize_by_method()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_method.md)
  : Tabulate interviews by fishing method and month
- [`summarize_by_species_sought()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_species_sought.md)
  : Tabulate interviews by species sought and month
- [`summarize_by_trip_length()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_trip_length.md)
  : Tabulate interviews by trip length bin
- [`summarize_cws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_cws_rates.md)
  : Compute caught-while-sought (CWS) rates by group
- [`summarize_hws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_hws_rates.md)
  : Compute harvested-while-sought (HWS) rates by group
- [`summarize_length_freq()`](https://chrischizinski.github.io/tidycreel/reference/summarize_length_freq.md)
  : Compute length frequency distribution from creel interview data
- [`summarize_successful_parties()`](https://chrischizinski.github.io/tidycreel/reference/summarize_successful_parties.md)
  : Tabulate successful parties by angler type and species sought
- [`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md)
  : Assemble pre-computed creel estimates into a report-ready wide
  tibble
- [`validate_incomplete_trips()`](https://chrischizinski.github.io/tidycreel/reference/validate_incomplete_trips.md)
  : Validate incomplete trip estimates using TOST equivalence testing
- [`validate_design()`](https://chrischizinski.github.io/tidycreel/reference/validate_design.md)
  : Validate a proposed creel survey design against sample size targets
- [`check_completeness()`](https://chrischizinski.github.io/tidycreel/reference/check_completeness.md)
  : Check post-season data completeness for a creel design

## Planning & Sample Size

Pre-survey tools for sample size determination and power analysis.

- [`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md)
  : Calculate sampling days required to achieve a target CV on effort
- [`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md)
  : Calculate interviews required to achieve a target CV on CPUE
- [`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md)
  : Estimate statistical power to detect a change in CPUE between
  seasons
- [`cv_from_n()`](https://chrischizinski.github.io/tidycreel/reference/cv_from_n.md)
  : Compute the expected CV achievable with a known sample size

## Scheduling

Generate, validate, read, and write creel survey schedules.

- [`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md)
  : Generate a creel survey sampling schedule
- [`generate_bus_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_bus_schedule.md)
  : Generate a bus-route sampling frame
- [`new_creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/new_creel_schedule.md)
  : Create a creel_schedule S3 object
- [`validate_creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schedule.md)
  : Validate a creel_schedule object
- [`read_schedule()`](https://chrischizinski.github.io/tidycreel/reference/read_schedule.md)
  : Read a schedule file into a validated creel_schedule object
- [`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md)
  : Write a creel schedule to a CSV or xlsx file

## Bus-Route Helpers

Exported helpers for bus-route Horvitz-Thompson estimation components.
For advanced users who need direct access to enumeration values.

- [`get_enumeration_counts()`](https://chrischizinski.github.io/tidycreel/reference/get_enumeration_counts.md)
  : Get enumeration counts from a bus-route creel design with interviews
- [`get_inclusion_probs()`](https://chrischizinski.github.io/tidycreel/reference/get_inclusion_probs.md)
  : Get inclusion probabilities from a bus-route design
- [`get_sampling_frame()`](https://chrischizinski.github.io/tidycreel/reference/get_sampling_frame.md)
  : Extract the sampling frame from a bus-route creel design
- [`get_site_contributions()`](https://chrischizinski.github.io/tidycreel/reference/get_site_contributions.md)
  : Extract per-site effort contributions from a bus-route estimate

## Camera Survey

Preprocessing for camera-monitored creel surveys.

- [`preprocess_camera_timestamps()`](https://chrischizinski.github.io/tidycreel/reference/preprocess_camera_timestamps.md)
  : Preprocess camera ingress-egress timestamps

## Example Datasets

Simulated datasets illustrating each supported survey type. Used in
vignettes and function examples.

- [`example_calendar`](https://chrischizinski.github.io/tidycreel/reference/example_calendar.md)
  : Example calendar data for creel survey
- [`example_counts`](https://chrischizinski.github.io/tidycreel/reference/example_counts.md)
  : Example count data for creel survey
- [`example_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md)
  : Example interview data for creel survey
- [`example_catch`](https://chrischizinski.github.io/tidycreel/reference/example_catch.md)
  : Example species catch data for creel survey
- [`example_lengths`](https://chrischizinski.github.io/tidycreel/reference/example_lengths.md)
  : Example fish length data for creel survey
- [`example_sections_calendar`](https://chrischizinski.github.io/tidycreel/reference/example_sections_calendar.md)
  : Example calendar for spatially stratified creel survey
- [`example_sections_counts`](https://chrischizinski.github.io/tidycreel/reference/example_sections_counts.md)
  : Example effort counts for spatially stratified creel survey
- [`example_sections_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_sections_interviews.md)
  : Example interview data for spatially stratified creel survey
- [`example_ice_sampling_frame`](https://chrischizinski.github.io/tidycreel/reference/example_ice_sampling_frame.md)
  : Example sampling frame for ice fishing creel survey
- [`example_ice_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_ice_interviews.md)
  : Example interview data for ice fishing creel survey
- [`example_camera_counts`](https://chrischizinski.github.io/tidycreel/reference/example_camera_counts.md)
  : Example camera counts dataset (counter mode)
- [`example_camera_timestamps`](https://chrischizinski.github.io/tidycreel/reference/example_camera_timestamps.md)
  : Example camera timestamps dataset (ingress-egress mode)
- [`example_camera_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_camera_interviews.md)
  : Example interview data for camera-monitored creel survey
- [`example_aerial_counts`](https://chrischizinski.github.io/tidycreel/reference/example_aerial_counts.md)
  : Example aerial angler count dataset
- [`example_aerial_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_aerial_interviews.md)
  : Example angler interview data for aerial creel survey
