# GH #511: every refusal shares one parent class, `creel_error`, as every
# warning shares `creel_warning`. Code can then catch "any tidycreel refusal"
# without matching message text, and a specific refusal where it has its own
# class. 613 of 789 aborts had no class at all before.

test_that("a refusal with its own class keeps it and gains creel_error", {
  err <- tryCatch(creel_design(data.frame(x = 1), date = date), error = function(e) e) # nolint: object_usage_linter
  expect_s3_class(err, "creel_error")
  # The specific class still comes first.
  expect_identical(class(err)[1], "creel_error_schema_validation")
})

test_that("a refusal that had no class now carries creel_error", {
  # The issue's example: two numeric candidate count columns, no count_col.
  data(example_calendar, envir = environment())
  d <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  counts <- data.frame(
    date = example_calendar$date[1:4], day_type = example_calendar$day_type[1:4], # nolint: object_usage_linter
    a = 1:4, b = 5:8
  )
  err <- tryCatch(suppressWarnings(suppressMessages(add_counts(d, counts))), error = function(e) e) # nolint: object_usage_linter
  expect_s3_class(err, "creel_error")
})

test_that("creel_abort() reports the caller's call and interpolates in the caller", {
  f <- function(n) creel_abort("Got {n} item{?s}.", class = "creel_error_test")
  err <- tryCatch(f(3), error = function(e) e)
  expect_identical(conditionMessage(err), "Got 3 items.")
  expect_identical(deparse(conditionCall(err)), "f(3)")
  expect_identical(class(err)[1:2], c("creel_error_test", "creel_error"))
  # Named once even when the caller already gave it.
  err2 <- tryCatch(creel_abort("x", class = c("a", "creel_error")), error = function(e) e)
  expect_identical(sum(class(err2) == "creel_error"), 1L)
})

test_that("no abort in the package bypasses creel_abort()", {
  # A direct cli::cli_abort() would raise a refusal without the parent class.
  files <- list.files(test_path("..", "..", "R"), pattern = "\\.R$", full.names = TRUE)
  skip_if(length(files) == 0L, "package sources not available")
  hits <- unlist(lapply(files, function(f) {
    if (basename(f) == "creel-abort.R") {
      return(character())
    }
    calls <- utils::getParseData(parse(f, keep.source = TRUE))
    i <- which(calls$token == "SYMBOL_FUNCTION_CALL" & calls$text == "cli_abort")
    if (length(i)) paste(basename(f), calls$line1[i], sep = ":") else character()
  }))
  expect_identical(hits, character())
})
