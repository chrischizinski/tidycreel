library(testthat)
library(tidycreel)

# CRAN runs a core subset; everywhere else runs the full suite.
#
# CRAN asked for the check time to come down (8.0.0: tests took 14 min of a
# 21 min check on r-devel-windows, against a 10 min budget). The full suite --
# including the statistical-audit tests, which are the ones that have caught
# plausible-but-wrong numbers -- still runs wherever NOT_CRAN is "true":
# devtools::test() sets it, and the R-CMD-check and test-coverage workflows set
# it explicitly, because rcmdcheck does not.
#
# The core files cover the main workflow: design, counts, interviews, effort,
# catch rate, total catch, and the CRAN policy guard. test-cran-subset.R checks
# that every name here still matches a test file, so a rename cannot quietly
# leave CRAN running nothing.
cran_core_tests <- c(
  "creel-design",
  "add-counts",
  "add-interviews",
  "estimate-effort",
  "estimate-catch-rate",
  "estimate-total-catch",
  "cran-policy-guard",
  "cran-subset"
)

if (identical(Sys.getenv("NOT_CRAN"), "true")) {
  test_check("tidycreel")
} else {
  test_check("tidycreel", filter = paste0("^(", paste(cran_core_tests, collapse = "|"), ")$"))
}
