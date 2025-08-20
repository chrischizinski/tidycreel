# Unit tests for conversion helpers: as_survey_design and as_svrep_design
library(testthat)
library(tidycreel)

# Use test data generators from helper-testdata.R
source("helper-testdata.R")

# Test as_survey_design for access_design

test_that("as_survey_design extracts survey design from access_design", {
  interviews <- create_test_interviews()
  calendar <- create_test_calendar()
  design <- design_access(interviews = interviews, calendar = calendar)
  svy <- as_survey_design(design)
  expect_s3_class(svy, "survey.design")
  expect_true(inherits(svy, "survey.design"))
  na_weights <- sum(is.na(design$design_weights))
  total_weights <- length(design$design_weights)
  cat("\n[DIAGNOSTIC] NA weights:", na_weights, "out of", total_weights, "\n")
  cat("[DIAGNOSTIC] Interview rows:", nrow(interviews), "\n")
  cat("[DIAGNOSTIC] Structure of survey design object:\n")
  print(str(svy))
  # Access data slot using svy$variables (current survey package)
  if (!is.null(svy$variables)) {
    cat("[DIAGNOSTIC] Survey variables rows:", nrow(svy$variables), "\n")
  } else {
    cat("[DIAGNOSTIC] No accessible data slot found in survey design object.\n")
  }
  if (all(is.na(design$design_weights))) {
    fail("All design weights are NA. Check for mismatched strata or locations in test data.")
  }
})

# Test as_survey_design for roving_design

test_that("as_survey_design extracts survey design from roving_design", {
  interviews <- create_test_interviews()
  counts <- create_test_counts()
  calendar <- create_test_calendar()
  design <- design_roving(interviews = interviews, counts = counts, calendar = calendar)
  svy <- as_survey_design(design)
  expect_s3_class(svy, "survey.design")
  expect_true(inherits(svy, "survey.design"))
})

# Test as_svrep_design for repweights_design

test_that("as_svrep_design extracts svyrep.design from repweights_design", {
  interviews <- create_test_interviews()
  calendar <- create_test_calendar()
  base_design <- design_access(interviews = interviews, calendar = calendar)
  rep_design <- design_repweights(base_design = base_design, method = "bootstrap")
  svyrep <- as_svrep_design(rep_design)
  expect_s3_class(svyrep, "svyrep.design")
  expect_true(inherits(svyrep, "svyrep.design"))
})

# Error handling

test_that("as_survey_design errors on non-creel_design input", {
  expect_error(as_survey_design(list()), "creel_design")
})

test_that("as_svrep_design errors on non-repweights_design input", {
  expect_error(as_svrep_design(list()), "repweights_design")
})

test_that("as_survey_design errors if no embedded survey design", {
  fake <- structure(list(), class = c("creel_design", "list"))
  expect_error(as_survey_design(fake), "No embedded survey design")
})

test_that("as_svrep_design errors if no embedded svrepdesign", {
  fake <- structure(list(), class = c("repweights_design", "creel_design", "list"))
  expect_error(as_svrep_design(fake), "No embedded svrepdesign")
})
