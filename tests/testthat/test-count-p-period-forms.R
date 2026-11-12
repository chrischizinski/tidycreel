# GH #466: add_counts() and creel_design() decided "column or number" for
# p_period with different rules. creel_design() (bus-route, ice) accepted a
# tidyselect helper and a variable holding a column name; add_counts() treated
# only a bare name or a string as a column, so `p_period = all_of("pp")` and
# `p_period = cn` (cn <- "pp") failed there. One resolver now serves both.

cpp_add <- function(...) {
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:7,
    day_type = rep(c("weekday", "weekday", "weekend", "weekend"), 2)
  )
  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    anglers = c(10, 14, 6, 9, 22, 30, 18, 25),
    hours = 7,
    pp = 0.5
  )
  d <- suppressMessages(creel_design(cal, date = date, strata = day_type))
  suppressWarnings(suppressMessages(add_counts(
    d, counts, count_col = anglers, period_length_col = hours, ...
  )))
}

cpp_effort <- function(d) {
  suppressWarnings(suppressMessages(estimate_effort(d, target = "sampled_days")))$estimates$estimate
}

test_that("#466: add_counts() takes p_period through all_of(), as creel_design() does", {
  expect_equal(cpp_effort(cpp_add(p_period = tidyselect::all_of("pp"))),
               cpp_effort(cpp_add(p_period = pp)))
})

test_that("#466: add_counts() takes p_period from a variable holding a column name", {
  cn <- "pp"
  expect_equal(cpp_effort(cpp_add(p_period = cn)), cpp_effort(cpp_add(p_period = pp)))
})

test_that("#466: a number is still never a column position in add_counts()", {
  # `pp` holds 0.5 and is column 5; p_period = 1 must mean probability 1.
  expect_equal(cpp_effort(cpp_add(p_period = 1)), cpp_effort(cpp_add()))
  expect_equal(cpp_effort(cpp_add(p_period = 0.5)), cpp_effort(cpp_add(p_period = pp)))
})

test_that("#466: add_counts() keeps its own error class", {
  cn <- "not_a_column"
  expect_error(cpp_add(p_period = cn), class = "creel_error_p_period_invalid")
  expect_error(cpp_add(p_period = 2), class = "creel_error_p_period_invalid")
  expect_error(cpp_add(p_period = c(0.5, 0.5)), class = "creel_error_p_period_invalid")
})

test_that("#466: a numeric vector is refused, never read as column positions", {
  # tidyselect reads c(1, 2) as columns 1 and 2 -- the #463 trap with more
  # than one number. Both resolvers now refuse any numeric of length > 1.
  expect_error(cpp_add(p_period = c(1, 2)), class = "creel_error_p_period_invalid")
  cal <- build_property_calendar(6L)
  frame <- data.frame(p_site = c(0.5, 0.5), site = c("S1", "S2"), circuit = "C1", ones = 1)
  expect_error(
    creel_design(cal, date = date, strata = day_type, survey_type = "bus_route",
                 sampling_frame = frame, site = site, circuit = circuit,
                 p_site = p_site, p_period = c(1, 2)),
    class = "creel_error_invalid_input"
  )
})
