# Helpers for the statistical-audit test family (test-statistical-audit-*.R).
# See README-statistical-audit.md in this directory for the framework's purpose
# and conventions. These helpers deliberately avoid tidycreel internals so that
# reference calculations cannot share a bug with the code under test.

# Return df with rows permuted deterministically. Used for row-order-invariance
# metamorphic tests: an estimate that changes under permutation is reading
# information from row position rather than from the data.
sa_shuffle_rows <- function(df, seed = 1L) {
  old_seed <- if (exists(".Random.seed", envir = globalenv())) {
    get(".Random.seed", envir = globalenv())
  }
  # A fresh session has no .Random.seed until something draws. Restoring only
  # the non-NULL case would leave this helper's seed behind, so a later test
  # relying on ambient RNG state would pass alone and fail in suite order --
  # exactly the kind of order dependence these helpers exist to rule out.
  on.exit(
    if (is.null(old_seed)) {
      if (exists(".Random.seed", envir = globalenv())) {
        rm(".Random.seed", envir = globalenv())
      }
    } else {
      assign(".Random.seed", old_seed, envir = globalenv())
    },
    add = TRUE
  )
  set.seed(seed)
  df[sample.int(nrow(df)), , drop = FALSE]
}

# Sort an estimates tibble by its identifier (non-numeric) columns so two
# results can be compared regardless of internal row order.
sa_sort_estimates <- function(est) {
  id_cols <- names(est)[!vapply(est, is.numeric, logical(1))]
  if (length(id_cols) > 0L) {
    est <- est[do.call(order, est[id_cols]), , drop = FALSE]
  }
  rownames(est) <- NULL
  est
}

# Compare the estimates tibbles of two creel_estimates objects: identical
# identifiers, numerically equal estimates and uncertainty. Both point value
# AND se/ci are compared — a seam bug can preserve one and corrupt the other.
sa_expect_same_estimates <- function(a, b, tolerance = 1e-10) {
  ea <- sa_sort_estimates(a$estimates)
  eb <- sa_sort_estimates(b$estimates)
  testthat::expect_identical(names(ea), names(eb))
  for (col in names(ea)) {
    if (is.numeric(ea[[col]])) {
      testthat::expect_equal(ea[[col]], eb[[col]], tolerance = tolerance)
    } else {
      testthat::expect_identical(ea[[col]], eb[[col]])
    }
  }
  invisible(TRUE)
}
