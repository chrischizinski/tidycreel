# Guard for the CRAN test subset in tests/testthat.R.
#
# CRAN runs only the files named in `cran_core_tests`, selected by an anchored
# regex. A renamed or deleted file would make its name match nothing, and CRAN
# would silently run fewer tests -- possibly none -- with every check still
# green. This test fails instead.

test_that("every CRAN core test name matches an existing test file", {
  runner <- test_path("..", "testthat.R")
  skip_if_not(file.exists(runner), "tests/testthat.R is not reachable from here")

  env <- new.env()
  exprs <- parse(runner)
  # Evaluate only the assignment, not library() or test_check().
  is_core <- vapply(exprs, function(e) {
    is.call(e) && identical(e[[1]], as.name("<-")) &&
      identical(e[[2]], as.name("cran_core_tests"))
  }, logical(1))
  expect_identical(sum(is_core), 1L)
  eval(exprs[[which(is_core)]], env)

  files <- sub("^test-(.*)[.]R$", "\\1", list.files(test_path(), "^test-.*[.]R$"))
  expect_true(length(env$cran_core_tests) > 0L)
  expect_setequal(intersect(env$cran_core_tests, files), env$cran_core_tests)
})
