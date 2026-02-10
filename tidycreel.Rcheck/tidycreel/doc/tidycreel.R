## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----design-------------------------------------------------------------------
library(tidycreel)

# Load example calendar data
data(example_calendar)
head(example_calendar)

# Create a creel design with weekday/weekend strata
design <- creel_design(example_calendar, date = date, strata = day_type)
print(design)

## ----counts-------------------------------------------------------------------
# Load example count data
data(example_counts)
head(example_counts)

# Attach counts to the design
design <- add_counts(design, example_counts)
print(design)

## ----total--------------------------------------------------------------------
# Estimate total effort
result <- estimate_effort(design)
print(result)

## ----grouped------------------------------------------------------------------
# Estimate effort by day_type
result_by_day <- estimate_effort(design, by = day_type)
print(result_by_day)

## ----variance-----------------------------------------------------------------
# Bootstrap variance estimation (500 replicates)
set.seed(123) # For reproducibility
result_boot <- estimate_effort(design, variance = "bootstrap")
print(result_boot)

# Jackknife variance estimation
result_jk <- estimate_effort(design, variance = "jackknife")
print(result_jk)

## ----grouped_variance---------------------------------------------------------
# Grouped estimation with bootstrap variance
set.seed(123)
result_grouped_boot <- estimate_effort(design, by = day_type, variance = "bootstrap")
print(result_grouped_boot)
