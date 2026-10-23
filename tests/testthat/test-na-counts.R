# GH #561: an NA count is unknown, not zero. Placeholder rows (a scheduled count
# that was not made) arrive as NA counts and used to be named only by an
# unrelated "repeated sampling unit" warning. The default keeps them -- an NA
# count is not a deleted row, the rule camera designs follow (#215) -- and says
# so; missing_count = "exclude" is the explicit way to drop them.

na_counts_design <- function() creel_design(example_calendar, date = date, strata = day_type)

with_na <- function(rows) {
  cn <- example_counts
  cn$effort_hours[rows] <- NA
  cn
}

test_that("an NA count is kept by default and named in a warning", {
  cn <- with_na(1)
  expect_warning(
    add_counts(na_counts_design(), cn),
    format(cn$date[1]),
    class = "creel_warning_na_counts"
  )
  d <- suppressWarnings(add_counts(na_counts_design(), cn))
  expect_equal(nrow(d$counts), nrow(cn))
  expect_null(d$excluded_counts)
  # kept, so the estimate is unknown -- not a total that silently omits the row
  e <- suppressWarnings(suppressMessages(estimate_effort(d)))$estimates
  expect_true(is.na(e$estimate))
})

test_that("missing_count = 'exclude' is the same as removing the rows by hand", {
  q <- function(x) suppressWarnings(suppressMessages(x))
  d <- q(add_counts(na_counts_design(), with_na(c(1, 5)), missing_count = "exclude"))
  by_hand <- q(add_counts(na_counts_design(), example_counts[-c(1, 5), ]))
  e <- q(estimate_effort(d))$estimates
  h <- q(estimate_effort(by_hand))$estimates
  expect_equal(e$estimate, h$estimate)
  expect_equal(e$se, h$se)
  expect_true(is.finite(e$estimate) && is.finite(e$se))
  expect_equal(nrow(d$excluded_counts), 2)
})

test_that("excluding counts is announced with its count, and does not also warn", {
  expect_message(
    d <- add_counts(na_counts_design(), with_na(1), missing_count = "exclude"),
    "Excluded 1 count row",
    class = "creel_message_na_counts_excluded"
  )
  expect_no_warning(
    suppressMessages(add_counts(na_counts_design(), with_na(1), missing_count = "exclude")),
    class = "creel_warning_na_counts"
  )
})

test_that("a saved design excludes the same counts when read back", {
  q <- function(x) suppressWarnings(suppressMessages(x))
  d <- q(add_counts(na_counts_design(), with_na(1), missing_count = "exclude"))
  p <- file.path(withr::local_tempdir(), "na-counts")
  write_design(d, p)
  r <- q(read_design(p))
  expect_equal(nrow(r$excluded_counts), 1)
  expect_equal(q(estimate_effort(r))$estimates$estimate, q(estimate_effort(d))$estimates$estimate)
})

test_that("counts with no NA are untouched and raise nothing", {
  expect_no_warning(
    suppressMessages(add_counts(na_counts_design(), example_counts)),
    class = "creel_warning_na_counts"
  )
  d <- suppressWarnings(add_counts(na_counts_design(), example_counts))
  expect_null(d$excluded_counts)
  expect_equal(nrow(d$counts), nrow(example_counts))
})

test_that("an excluded row is still checked against the calendar", {
  # Excluding a placeholder must not excuse a row that could never have been a
  # count of this design (a date outside the calendar).
  cn <- with_na(1)
  cn$date[1] <- max(example_calendar$date) + 30
  expect_error(suppressWarnings(suppressMessages(
    add_counts(na_counts_design(), cn, missing_count = "exclude")
  )))
})
