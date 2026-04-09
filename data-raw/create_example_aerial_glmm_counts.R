# Create example_aerial_glmm_counts dataset
# Multiple-flight aerial overflight data: 12 survey days x 4 flights per day = 48 rows
# Designed for GLMM-based effort estimation following Askey (2018) NAJFM methodology
# Uses a diurnal count curve with day-level random effects

set.seed(42)

# Survey dates: 12 days spaced 3 days apart, starting 2024-06-03
survey_dates <- seq.Date(as.Date("2024-06-03"), by = "3 days", length.out = 12)

# Day types derived from calendar
day_types_vec <- ifelse(
  weekdays(survey_dates) %in% c("Saturday", "Sunday"),
  "weekend", "weekday"
)

# Flight hours per day: 4 overflights at fixed hours
flight_hours <- c(7.0, 10.0, 13.0, 16.0)

# Day-level random effects (simulate day-level heterogeneity)
day_effects <- rnorm(12, mean = 0, sd = 0.3)

# Build 48-row dataset: all combinations of dates x flight hours
rows <- vector("list", length(survey_dates))
for (i in seq_along(survey_dates)) {
  h <- flight_hours
  # Diurnal curve: mu = exp(3.5 + 0.8*(h-12)/5 - 1.2*((h-12)/5)^2 + day_effect)
  # Peak near mid-morning; low at dawn and late afternoon
  mu <- exp(3.5 + 0.8 * (h - 12) / 5 - 1.2 * ((h - 12) / 5)^2 + day_effects[i])
  # Poisson noise on expected counts
  n_anglers <- rpois(n = length(h), lambda = mu)
  rows[[i]] <- data.frame(
    date = survey_dates[i],
    day_type = day_types_vec[i],
    n_anglers = as.integer(n_anglers),
    time_of_flight = h,
    stringsAsFactors = FALSE
  )
}

example_aerial_glmm_counts <- do.call(rbind, rows)
rownames(example_aerial_glmm_counts) <- NULL

# Data quality assertions
stopifnot(nrow(example_aerial_glmm_counts) == 48L)
stopifnot(all(c("date", "day_type", "n_anglers", "time_of_flight") %in%
  names(example_aerial_glmm_counts)))
stopifnot(all(example_aerial_glmm_counts$n_anglers > 0))
stopifnot(inherits(example_aerial_glmm_counts$date, "Date"))
stopifnot(all(example_aerial_glmm_counts$day_type %in% c("weekday", "weekend")))
stopifnot(all(example_aerial_glmm_counts$time_of_flight %in% c(7.0, 10.0, 13.0, 16.0)))

usethis::use_data(example_aerial_glmm_counts, overwrite = TRUE)
