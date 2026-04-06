test_that("setup fixtures can be built", {
  # Simple 2-month instantaneous schedule
  sched_2mo <- generate_schedule(
    start_date = "2025-05-01",
    end_date = "2025-06-30",
    n_periods = 1,
    sampling_rate = c(weekday = 0.5, weekend = 0.8),
    seed = 42
  )
  expect_s3_class(sched_2mo, "creel_schedule")
})

# ---------------------------------------------------------------------------
# Fixtures (built once, shared across tests)
# ---------------------------------------------------------------------------

sched_2mo <- generate_schedule(
  start_date = "2025-05-01",
  end_date = "2025-06-30",
  n_periods = 1,
  sampling_rate = c(weekday = 0.5, weekend = 0.8),
  seed = 42
)

# Bus-route variant: add a circuit column
sched_bus <- new_creel_schedule(
  dplyr::mutate(sched_2mo, circuit = "C1")
)

# include_all = TRUE schedule to test non-sampled rendering
sched_all <- generate_schedule(
  start_date = "2025-05-01",
  end_date = "2025-05-31",
  n_periods = 1,
  sampling_rate = c(weekday = 0.5, weekend = 0.8),
  include_all = TRUE,
  seed = 42
)

# ---------------------------------------------------------------------------
# CAL-01: ASCII console output
# ---------------------------------------------------------------------------

test_that("format.creel_schedule() returns a character vector", {
  out <- format(sched_2mo)
  expect_type(out, "character")
  expect_gt(length(out), 0L)
})

test_that("format.creel_schedule() output contains Sun-Sat header", {
  out <- format(sched_2mo)
  header_line <- out[grep("Sun", out)[1]]
  expect_match(header_line, "Sun")
  expect_match(header_line, "Mon")
  expect_match(header_line, "Sat")
  # All 7 day names present
  for (day in c("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")) {
    expect_true(any(grepl(day, out)), info = paste("Missing day:", day))
  }
})

test_that("sampled weekday cell contains WEEKD abbreviation", {
  out <- format(sched_2mo)
  expect_true(any(grepl("WEEKD", out)))
})

test_that("sampled weekend cell contains WEEKE abbreviation (collision resolved)", {
  out <- format(sched_2mo)
  expect_true(any(grepl("WEEKE", out)))
})

test_that("weekday and weekend abbreviations are distinct", {
  abbrevs <- tidycreel:::make_day_abbrevs(c("weekday", "weekend"))
  expect_length(unique(abbrevs), 2L)
  # Both must be 5 characters (k=5 needed for collision resolution)
  expect_true(all(nchar(abbrevs) == 5L))
  expect_equal(sort(unname(abbrevs)), c("WEEKD", "WEEKE"))
})

test_that("non-sampled date shows only date number, not an abbreviation", {
  out <- format(sched_all)
  # Non-sampled dates should appear as plain date numbers without WEEKD/WEEKE
  # Check that output contains bare date numbers (e.g., "15")
  # and that not every day has an abbreviation
  expect_true(any(grepl("[0-9]", out)))
  # The output should NOT have WEEKD/WEEKE for every day
  # (some cells should be date-number only)
  non_abbrev_lines <- out[!grepl("WEEKD|WEEKE", out)]
  expect_gt(length(non_abbrev_lines), 0L)
})

test_that("bus-route schedule cell contains abbreviation and circuit", {
  out <- format(sched_bus)
  expect_true(any(grepl("C1", out)))
  expect_true(any(grepl("WEEKD|WEEKE", out)))
})

test_that("multi-month schedule contains both month labels", {
  out <- format(sched_2mo)
  expect_true(any(grepl("May 2025", out)))
  expect_true(any(grepl("June 2025", out)))
})

test_that("print.creel_schedule() returns the object invisibly", {
  result <- withVisible(print(sched_2mo))
  expect_false(result$visible)
  expect_identical(result$value, sched_2mo)
})

# ---------------------------------------------------------------------------
# CAL-02: Document knit_print output
# ---------------------------------------------------------------------------

test_that("knit_print.creel_schedule() returns an object with class 'knit_asis'", {
  skip_if_not_installed("knitr")
  out <- knitr::knit_print(sched_2mo)
  expect_s3_class(out, "knit_asis")
})

test_that("knit_print.creel_schedule() output contains pandoc pipe table syntax", {
  skip_if_not_installed("knitr")
  out <- knitr::knit_print(sched_2mo)
  content <- as.character(out)
  # Pandoc pipe table separator: one or more dashes between pipes
  expect_match(content, "|--", fixed = TRUE)
})

test_that("bus-route schedule produces cell content with <br> separator", {
  skip_if_not_installed("knitr")
  out <- knitr::knit_print(sched_bus)
  content <- as.character(out)
  expect_match(content, "<br>", fixed = TRUE)
})

test_that("each month has a '### Month YYYY' heading in knit_print output", {
  skip_if_not_installed("knitr")
  out <- knitr::knit_print(sched_2mo)
  content <- as.character(out)
  expect_match(content, "### May 2025")
  expect_match(content, "### June 2025")
})
