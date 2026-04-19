#!/usr/bin/env Rscript
# 03-bench-variance-methods.R
#
# Purpose: Compare performance of Taylor linearization, jackknife, and
# bootstrap variance methods for estimate_total_catch() at realistic scale.
#
# Run from the package root:
#   Rscript inst/profiling/03-bench-variance-methods.R
#
# NOTE: bootstrap uses 500 survey replicates by default — it is slow by design.
# min_iterations = 5 keeps total runtime reasonable.
#
# IMPORTANT: Do NOT source() or library() this script from package code.
# It is a standalone development tool in inst/profiling/ only.

if (!requireNamespace("bench", quietly = TRUE)) install.packages("bench", repos = "https://cran.r-project.org")
pkgload::load_all(".")

design_realistic <- readRDS("inst/profiling/fixtures/design-realistic.rds")

# ---------------------------------------------------------------------------
# Variance method comparison — realistic scale only
# ---------------------------------------------------------------------------
cat("\n=== Variance Method Comparison (realistic scale) ===\n")
bm_var <- bench::mark(
  taylor = estimate_total_catch(design_realistic, variance = "taylor"),
  jackknife = estimate_total_catch(design_realistic, variance = "jackknife"),
  bootstrap = estimate_total_catch(design_realistic, variance = "bootstrap"),
  check = FALSE,
  min_iterations = 5
)
print(bm_var[c("expression", "min", "median", "itr/sec", "mem_alloc", "n_gc")])

# Speedup ratios relative to taylor
expr_labels <- as.character(bm_var$expression)
taylor_ms <- as.numeric(bm_var$median[expr_labels == "taylor"])
jk_ms <- as.numeric(bm_var$median[expr_labels == "jackknife"])
bs_ms <- as.numeric(bm_var$median[expr_labels == "bootstrap"])

cat("\nSpeedup ratios relative to taylor:\n")
cat("jackknife / taylor:", round(jk_ms / taylor_ms, 1), "x\n")
cat("bootstrap / taylor:", round(bs_ms / taylor_ms, 1), "x\n")

cat("\nConclusion guide:\n")
cat("  jackknife/taylor < 5x  → jackknife is viable for interactive use\n")
cat("  bootstrap/taylor > 50x → bootstrap should be opt-in only\n")
cat("  Use these ratios in 75-PERFORMANCE-ANALYSIS.md go/no-go recommendation\n")
