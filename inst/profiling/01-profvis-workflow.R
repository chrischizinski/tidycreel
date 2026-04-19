#!/usr/bin/env Rscript
# 01-profvis-workflow.R
#
# Purpose: Profile end-to-end tidycreel estimator workflows using profvis
# flame-graph capture and save HTML artifacts to the planning directory.
#
# Run from the package root (requires an active display for htmlwidgets):
#   Rscript inst/profiling/01-profvis-workflow.R
#
# Output:
#   .planning/phases/75-performance-optimization/profvis-total-catch-realistic.html
#   .planning/phases/75-performance-optimization/profvis-total-catch-stress.html
#   .planning/phases/75-performance-optimization/profvis-effort-realistic.html
#
# IMPORTANT: Do NOT source() or library() this script from package code.
# It is a standalone development tool in inst/profiling/ only.

if (!requireNamespace("profvis", quietly = TRUE)) install.packages("profvis", repos = "https://cran.r-project.org")
if (!requireNamespace("htmlwidgets", quietly = TRUE)) install.packages("htmlwidgets", repos = "https://cran.r-project.org")
pkgload::load_all(".")

design_realistic <- readRDS("inst/profiling/fixtures/design-realistic.rds")
design_stress <- readRDS("inst/profiling/fixtures/design-stress.rds")

out_dir <- ".planning/phases/75-performance-optimization"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# Profile 1: estimate_total_catch() — realistic scale
# ---------------------------------------------------------------------------
cat("Profiling estimate_total_catch() at realistic scale...\n")
p_realistic <- profvis::profvis(
  {
    est <- estimate_total_catch(design_realistic, variance = "taylor")
  },
  interval = 0.01
)
htmlwidgets::saveWidget(
  p_realistic,
  file.path(out_dir, "profvis-total-catch-realistic.html")
)
cat("Profvis artifact saved: profvis-total-catch-realistic.html\n")

# ---------------------------------------------------------------------------
# Profile 2: estimate_total_catch() — stress scale
# ---------------------------------------------------------------------------
cat("Profiling estimate_total_catch() at stress scale...\n")
p_stress <- profvis::profvis(
  {
    est <- estimate_total_catch(design_stress, variance = "taylor")
  },
  interval = 0.01
)
htmlwidgets::saveWidget(
  p_stress,
  file.path(out_dir, "profvis-total-catch-stress.html")
)
cat("Profvis artifact saved: profvis-total-catch-stress.html\n")

# ---------------------------------------------------------------------------
# Profile 3: estimate_effort() — realistic scale
# NOTE: estimate_effort() is fast for bus_route at realistic scale; if profvis
# reports "No data", use bench::mark() in 02-bench-estimators.R instead.
# ---------------------------------------------------------------------------
cat("Profiling estimate_effort() at realistic scale...\n")
p_effort <- profvis::profvis(
  {
    est <- estimate_effort(design_realistic, target = "sampled_days")
  },
  interval = 0.01
)
htmlwidgets::saveWidget(
  p_effort,
  file.path(out_dir, "profvis-effort-realistic.html")
)
cat("Profvis artifact saved: profvis-effort-realistic.html\n")

cat("All profvis artifacts saved to", out_dir, "\n")
