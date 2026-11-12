# GH #637: a sectioned total with no section estimate reports an unknown lake
# total (NA), never 0.
#
# The lake total is the sum of the sections that have an estimate. With none,
# sum() of nothing is 0, and the totals reported a lake total of 0 with SE 0 --
# an unknown total presented as a known zero. #636 refuses the inputs that
# reached this at the public entry points, so the test calls the sectioned
# functions directly with every section's counts moved outside the register.

na_lake_design <- function() {
  data("example_sections_calendar", package = "tidycreel", envir = environment())
  data("example_sections_counts", package = "tidycreel", envir = environment())
  data("example_sections_interviews", package = "tidycreel", envir = environment())
  d <- creel_design(example_sections_calendar, date = date, strata = day_type)
  d <- add_sections(d, data.frame(section = c("North", "Central", "South")),
    section_col = section
  )
  d <- suppressWarnings(suppressMessages(add_counts(d, example_sections_counts)))
  d <- suppressWarnings(suppressMessages(add_interviews(d, example_sections_interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = trip_duration, n_anglers = 1
  )))
  iv <- d$interviews
  catch <- data.frame(
    interview_id = rep(iv$interview_id, each = 2),
    species = "walleye",
    count = as.vector(rbind(iv$catch_total, iv$catch_total - iv$catch_kept)),
    catch_type = rep(c("caught", "released"), nrow(iv))
  )
  d <- suppressWarnings(suppressMessages(add_catch(d, catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  )))
  # Every count now sits outside the register: no section has effort.
  d$counts$section <- paste0(d$counts$section, "_unregistered")
  d
}

lake_row <- function(f, d) {
  res <- suppressWarnings(suppressMessages(f(
    d,
    by_quo = rlang::quo(NULL), variance_method = "taylor", conf_level = 0.95,
    aggregate_sections = TRUE, missing_sections = "warn"
  )))
  est <- res$estimates
  list(sections = est[est$section != ".lake_total", ], lake = est[est$section == ".lake_total", ])
}

for (nm in c("catch", "harvest", "release")) {
  test_that(paste0("#637: total ", nm, " reports an unknown lake total as NA, not 0"), {
    f <- get(paste0("estimate_total_", nm, "_sections"), envir = asNamespace("tidycreel"))
    r <- lake_row(f, na_lake_design())
    expect_true(all(is.na(r$sections$estimate))) # the premise: no section is known
    expect_identical(nrow(r$lake), 1L)
    expect_true(is.na(r$lake$estimate))
    expect_true(is.na(r$lake$se))
    expect_true(is.na(r$lake$ci_lower) && is.na(r$lake$ci_upper))
    expect_false(r$lake$data_available)
  })
}
