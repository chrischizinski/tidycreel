#!/usr/bin/env Rscript
# 02-bench-estimators.R
#
# Purpose: Run bench::mark() on core tidycreel estimators at realistic and
# stress scales to empirically identify performance bottlenecks.
#
# Run from the package root:
#   Rscript inst/profiling/02-bench-estimators.R
#
# IMPORTANT: Do NOT source() or library() this script from package code.
# It is a standalone development tool in inst/profiling/ only.

if (!requireNamespace("bench", quietly = TRUE)) install.packages("bench", repos = "https://cran.r-project.org")
pkgload::load_all(".")

design_realistic <- readRDS("inst/profiling/fixtures/design-realistic.rds")
design_stress <- readRDS("inst/profiling/fixtures/design-stress.rds")

# ---------------------------------------------------------------------------
# 1. estimate_total_catch() — two scales
# ---------------------------------------------------------------------------
cat("\n=== estimate_total_catch() ===\n")
tryCatch(
  {
    bm_catch <- bench::mark(
      `total_catch realistic (n=500)` = estimate_total_catch(design_realistic, variance = "taylor"),
      `total_catch stress (n=5000)` = estimate_total_catch(design_stress, variance = "taylor"),
      check = FALSE, min_iterations = 20
    )
    print(bm_catch[c("expression", "min", "median", "itr/sec", "mem_alloc", "n_gc")])
    cat(
      "Scaling ratio (stress/realistic):",
      round(as.numeric(bm_catch$median[2]) / as.numeric(bm_catch$median[1]), 2),
      "\n"
    )
  },
  error = function(e) {
    cat("ERROR in estimate_total_catch() benchmark:", conditionMessage(e), "\n")
  }
)

# ---------------------------------------------------------------------------
# 2. estimate_effort() — two scales
# ---------------------------------------------------------------------------
cat("\n=== estimate_effort() ===\n")
tryCatch(
  {
    bm_effort <- bench::mark(
      `effort realistic` = estimate_effort(design_realistic, target = "sampled_days"),
      `effort stress` = estimate_effort(design_stress, target = "sampled_days"),
      check = FALSE, min_iterations = 20
    )
    print(bm_effort[c("expression", "min", "median", "itr/sec", "mem_alloc", "n_gc")])
    cat(
      "Scaling ratio (stress/realistic):",
      round(as.numeric(bm_effort$median[2]) / as.numeric(bm_effort$median[1]), 2),
      "\n"
    )
  },
  error = function(e) {
    cat("ERROR in estimate_effort() benchmark:", conditionMessage(e), "\n")
  }
)

# ---------------------------------------------------------------------------
# 3. estimate_harvest_rate() — realistic scale only (stress may be slow)
# NOTE: Requires species-level catch data AND harvest column in interviews.
# The synthetic fixture uses total catch only; harvest_rate may error on
# species-level indexing. The bench::mark() tryCatch will report the error.
# ---------------------------------------------------------------------------
cat("\n=== estimate_harvest_rate() ===\n")
tryCatch(
  {
    bm_hr <- bench::mark(
      `harvest_rate realistic` = estimate_harvest_rate(design_realistic),
      check = FALSE, min_iterations = 10
    )
    print(bm_hr[c("expression", "min", "median", "itr/sec", "mem_alloc", "n_gc")])
  },
  error = function(e) {
    cat("SKIP: estimate_harvest_rate() failed on synthetic fixture:", conditionMessage(e), "\n")
    cat("      This is expected — the fixture uses total catch only, not species-level harvest data.\n")
    cat("      Cost is captured indirectly via estimate_total_catch() above.\n")
  }
)

# ---------------------------------------------------------------------------
# Note: rebuild_counts_survey() and rebuild_interview_survey() are internal
# functions (not exported). Their cost is captured indirectly via
# estimate_total_catch() benchmarks above. Use profvis (01-profvis-workflow.R)
# to inspect call-level hot spots within those estimators.
# ---------------------------------------------------------------------------
cat("\nNote: Internal rebuild_*_survey() functions captured via estimate_total_catch() above.\n")
cat("      Use profvis artifacts in .planning/phases/75-performance-optimization/ for line-level detail.\n")
