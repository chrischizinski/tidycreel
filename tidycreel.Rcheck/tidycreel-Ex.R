pkgname <- "tidycreel"
source(file.path(R.home("share"), "R", "examples-header.R"))
options(warn = 1)
base::assign(".ExTimings", "tidycreel-Ex.timings", pos = "CheckExEnv")
base::cat("name\tuser\tsystem\telapsed\n", file = base::get(".ExTimings", pos = "CheckExEnv"))
base::assign(".format_ptime",
  function(x) {
    if (!is.na(x[4L])) x[1L] <- x[1L] + x[4L]
    if (!is.na(x[5L])) x[2L] <- x[2L] + x[5L]
    options(OutDec = ".")
    format(x[1L:3L], digits = 7L)
  },
  pos = "CheckExEnv"
)

### * </HEADER>
library("tidycreel")

base::assign(".oldSearch", base::search(), pos = "CheckExEnv")
base::assign(".old_wd", base::getwd(), pos = "CheckExEnv")
cleanEx()
nameEx("add_counts")
### * add_counts

flush(stderr())
flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: add_counts
### Title: Attach count data to a creel design
### Aliases: add_counts

### ** Examples

# Basic usage - day as PSU (default)
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend")
)
design <- creel_design(calendar, date = date, strata = day_type)

counts <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  count = c(15, 23, 45, 52)
)

design_with_counts <- add_counts(design, counts)
print(design_with_counts)

# Custom PSU column
counts_with_site_psu <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  site_day = paste0("site_", 1:4),
  count = c(15, 23, 45, 52)
)

design2 <- add_counts(design, counts_with_site_psu, psu = "site_day")




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("add_counts", base::get(".format_ptime", pos = "CheckExEnv")(get(".dptime", pos = "CheckExEnv")), "\n", file = base::get(".ExTimings", pos = "CheckExEnv"), append = TRUE, sep = "\t")
cleanEx()
nameEx("as_survey_design")
### * as_survey_design

flush(stderr())
flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: as_survey_design
### Title: Extract internal survey design object for advanced use
### Aliases: as_survey_design

### ** Examples

# Basic workflow
library(survey)
cal <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend")
)
design <- creel_design(cal, date = date, strata = day_type)

counts <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  count = c(15, 23, 45, 52)
)

design2 <- add_counts(design, counts)

# Extract survey object for advanced use
svy <- as_survey_design(design2)

# Use with survey package functions
survey::svytotal(~count, svy)
survey::svymean(~count, svy)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("as_survey_design", base::get(".format_ptime", pos = "CheckExEnv")(get(".dptime", pos = "CheckExEnv")), "\n", file = base::get(".ExTimings", pos = "CheckExEnv"), append = TRUE, sep = "\t")
cleanEx()
nameEx("creel_design")
### * creel_design

flush(stderr())
flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: creel_design
### Title: Create a creel survey design
### Aliases: creel_design

### ** Examples

# Basic design with single stratum
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
  day_type = c("weekday", "weekend", "weekend")
)
design <- creel_design(calendar, date = date, strata = day_type)

# Multiple strata
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02")),
  day_type = c("weekday", "weekend"),
  season = c("summer", "summer")
)
design <- creel_design(calendar, date = date, strata = c(day_type, season))

# With site column for multi-site survey
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02")),
  day_type = c("weekday", "weekend"),
  lake = c("lake_a", "lake_b")
)
design <- creel_design(calendar, date = date, strata = day_type, site = lake)

# Using tidyselect helpers
calendar <- data.frame(
  survey_date = as.Date(c("2024-06-01", "2024-06-02")),
  day_type = c("weekday", "weekend"),
  day_period = c("morning", "evening")
)
design <- creel_design(
  calendar,
  date = starts_with("survey"),
  strata = starts_with("day")
)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("creel_design", base::get(".format_ptime", pos = "CheckExEnv")(get(".dptime", pos = "CheckExEnv")), "\n", file = base::get(".ExTimings", pos = "CheckExEnv"), append = TRUE, sep = "\t")
cleanEx()
nameEx("estimate_effort")
### * estimate_effort

flush(stderr())
flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: estimate_effort
### Title: Estimate total effort from a creel survey design
### Aliases: estimate_effort

### ** Examples

# Basic ungrouped usage
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend")
)
design <- creel_design(calendar, date = date, strata = day_type)

counts <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  effort_hours = c(15, 23, 45, 52)
)

design_with_counts <- add_counts(design, counts)
result <- estimate_effort(design_with_counts)
print(result)

# Grouped by day_type
result_grouped <- estimate_effort(design_with_counts, by = day_type)
print(result_grouped)

# Note: Multiple grouping variables are supported if present in the data
# For example: by = c(day_type, location)

# Custom confidence level
result_90 <- estimate_effort(design_with_counts, conf_level = 0.90)

# Bootstrap variance estimation
result_boot <- estimate_effort(design_with_counts, variance = "bootstrap")
print(result_boot)

# Jackknife variance estimation
result_jk <- estimate_effort(design_with_counts, variance = "jackknife")
print(result_jk)

# Grouped estimation with bootstrap variance
result_grouped_boot <- estimate_effort(design_with_counts, by = day_type, variance = "bootstrap")



base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("estimate_effort", base::get(".format_ptime", pos = "CheckExEnv")(get(".dptime", pos = "CheckExEnv")), "\n", file = base::get(".ExTimings", pos = "CheckExEnv"), append = TRUE, sep = "\t")
cleanEx()
nameEx("example_calendar")
### * example_calendar

flush(stderr())
flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: example_calendar
### Title: Example calendar data for creel survey
### Aliases: example_calendar
### Keywords: datasets

### ** Examples

# Load and inspect
data(example_calendar)
head(example_calendar)

# Create a creel design
design <- creel_design(example_calendar, date = date, strata = day_type)
print(design)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("example_calendar", base::get(".format_ptime", pos = "CheckExEnv")(get(".dptime", pos = "CheckExEnv")), "\n", file = base::get(".ExTimings", pos = "CheckExEnv"), append = TRUE, sep = "\t")
cleanEx()
nameEx("example_counts")
### * example_counts

flush(stderr())
flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: example_counts
### Title: Example count data for creel survey
### Aliases: example_counts
### Keywords: datasets

### ** Examples

# Load and use with a creel design
data(example_calendar)
data(example_counts)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_counts(design, example_counts)
result <- estimate_effort(design)
print(result)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("example_counts", base::get(".format_ptime", pos = "CheckExEnv")(get(".dptime", pos = "CheckExEnv")), "\n", file = base::get(".ExTimings", pos = "CheckExEnv"), append = TRUE, sep = "\t")
### * <FOOTER>
###
cleanEx()
options(digits = 7L)
base::cat("Time elapsed: ", proc.time() - base::get("ptime", pos = "CheckExEnv"), "\n")
grDevices::dev.off()
###
### Local variables: ***
### mode: outline-minor ***
### outline-regexp: "\\(> \\)?### [*]+" ***
### End: ***
quit("no")
