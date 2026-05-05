#' Audit per-stratum effort precision from a completed creel design or pilot statistics
#'
#' @description
#' `audit_strata()` is an S3 generic. Two methods are provided:
#' - `audit_strata.creel_design()` extracts stratum summaries from a completed
#'   design object and computes per-stratum RSE, DEFF, and meets-target flag.
#' - `audit_strata.default()` accepts pilot summary statistics (N_h, n_h,
#'   ybar_h, s2_h) directly.
#'
#' @param x A `creel_design` object (for the `creel_design` method) or a named
#'   numeric vector `N_h` of total available days per stratum (for the `default`
#'   method).
#' @param ... Additional arguments passed to methods.
#'
#' @return A `creel_strata_audit` S3 object. See `audit_strata.default()` for
#'   the complete field description.
#'
#' @family "Planning & Sample Size"
#' @importFrom stats var
#' @export
audit_strata <- function(x, ...) UseMethod("audit_strata")

#' @rdname audit_strata
#' @param rse_target Numeric scalar. Target relative standard error threshold.
#'   Default 0.20 (20 percent). Must be in (0, 1].
#' @export
audit_strata.creel_design <- function(x, rse_target = 0.20, ...) {  # nolint: object_name_linter
  design <- x
  checkmate::assert_number(rse_target, lower = 1e-6, upper = 1.0)

  if (is.null(design$counts)) {
    cli::cli_abort(c(
      "Design has no count data.",
      "x" = "{.arg x} must have counts attached via {.fn add_counts} before auditing strata.",
      "i" = "Call {.code add_counts(design, counts_df)} first."
    ))
  }

  strata_cols <- design$strata_cols
  cal         <- design$calendar

  if (length(strata_cols) == 1) {
    cal$.strata_key <- as.character(cal[[strata_cols]])
  } else {
    cal$.strata_key <- do.call(paste, c(cal[strata_cols], sep = ""))
  }
  available_by_strata <- table(cal$.strata_key)

  counts_data   <- design$counts
  excluded_cols <- c(design$date_col, design$strata_cols, design$psu_col)
  numeric_cols  <- names(counts_data)[vapply(counts_data, is.numeric, logical(1L))]
  count_vars    <- setdiff(numeric_cols, excluded_cols)

  if (length(count_vars) == 0) {
    cli::cli_abort(c(
      "No count variable found in count data.",
      "x" = "Count data must have at least one numeric column.",
      "i" = "Numeric columns found: {.field {numeric_cols}}",
      "i" = "Design metadata columns: {.field {excluded_cols}}"
    ))
  }
  count_var <- count_vars[1]

  if (length(strata_cols) == 1) {
    counts_data$.strata_key <- as.character(counts_data[[strata_cols]])
  } else {
    counts_data$.strata_key <- do.call(paste, c(counts_data[strata_cols], sep = ""))
  }

  strata_keys <- unique(counts_data$.strata_key)

  n_h_vals    <- integer(length(strata_keys))
  N_h_vals    <- integer(length(strata_keys))
  ybar_h_vals <- numeric(length(strata_keys))
  s2_h_vals   <- numeric(length(strata_keys))

  for (i in seq_along(strata_keys)) {
    sk           <- strata_keys[i]
    rows         <- counts_data$.strata_key == sk
    n_h_i        <- sum(rows)
    n_h_vals[i]    <- n_h_i  # nolint: object_name_linter
    N_h_vals[i]    <- as.integer(available_by_strata[sk])  # nolint: object_name_linter
    ybar_h_vals[i] <- mean(counts_data[[count_var]][rows])  # nolint: object_name_linter
    s2_h_vals[i]   <- if (n_h_i >= 2L) var(counts_data[[count_var]][rows]) else NA_real_  # nolint: object_name_linter
  }

  names(n_h_vals)    <- strata_keys  # nolint: object_name_linter
  names(N_h_vals)    <- strata_keys  # nolint: object_name_linter
  names(ybar_h_vals) <- strata_keys  # nolint: object_name_linter
  names(s2_h_vals)   <- strata_keys  # nolint: object_name_linter

  .build_strata_audit(
    N_h        = N_h_vals,  # nolint: object_name_linter
    n_h        = n_h_vals,  # nolint: object_name_linter
    ybar_h     = ybar_h_vals,  # nolint: object_name_linter
    s2_h       = s2_h_vals,  # nolint: object_name_linter
    rse_target = rse_target,
    stratum    = strata_keys
  )
}

#' @rdname audit_strata
#' @param n_h Named numeric vector of the same length as `x`. Observed sample
#'   counts per stratum. Values must be >= 1.
#' @param ybar_h Numeric vector of the same length as `x`. Observed mean effort
#'   per day per stratum. Values must be >= 0.
#' @param s2_h Numeric vector of the same length as `x`. Observed variance of
#'   effort per day per stratum. Values must be >= 0.
#'
#' @details
#' The per-stratum RSE (relative standard error, equivalent to CV) is computed
#' with the finite-population correction (FPC):
#'
#' `RSE_h = sqrt((1 - n_h / N_h) * s2_h / n_h) / ybar_h`
#'
#' When `n_h = 1` for any stratum, `var()` cannot be estimated; RSE, DEFF, and
#' `meets_target` are set to `NA` for those strata and a warning is issued. The
#' function continues processing valid strata.
#'
#' The per-stratum design effect (DEFF_h) compares the actual stratum variance
#' to the pooled-SRS variance baseline:
#'
#' `DEFF_h = ((1 - n_h/N_h) * s2_h / n_h) / ((1 - n/N) * s2_overall / n)`
#'
#' where `n = sum(n_h)`, `N = sum(N_h)`, and
#' `s2_overall = sum(N_h * s2_h) / sum(N_h)` (N_h-weighted pooled within-stratum
#' variance). The aggregate DEFF stored in `$deff` is `Var_strat / Var_SRS`
#' (Cochran 1977).
#'
#' @return A `creel_strata_audit` S3 object — a named list with fields:
#' \describe{
#'   \item{`$strata`}{Tibble with columns: `stratum`, `N_h`, `n_h`, `ybar_h`,
#'     `s2_h`, `RSE`, `DEFF`, `meets_target`.}
#'   \item{`$rse_target`}{Scalar. The RSE threshold supplied by the caller.}
#'   \item{`$n_total`}{Integer. Total sampled days across all strata.}
#'   \item{`$deff`}{Scalar. Aggregate design effect (Var_strat / Var_SRS).}
#' }
#'
#' @references
#' Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.
#'
#' McCormick, J.L. and Quist, M.C. 2017. Sample size estimation for on-site
#' creel surveys. North American Journal of Fisheries Management 37:970-983.
#' \doi{10.1080/02755947.2017.1342723}
#'
#' @family "Planning & Sample Size"
#' @export
#'
#' @examples
#' # Two-stratum weekday/weekend pilot example
#' audit <- audit_strata(
#'   c(weekday = 65, weekend = 28),
#'   n_h    = c(weekday = 22, weekend = 14),
#'   ybar_h = c(50, 60),
#'   s2_h   = c(400, 500),
#'   rse_target = 0.20
#' )
#' audit$strata
#' audit$deff
audit_strata.default <- function(x, n_h, ybar_h, s2_h, rse_target = 0.20, ...) {  # nolint: object_name_linter
  N_h <- x  # nolint: object_name_linter
  checkmate::assert_numeric(N_h, lower = 1, min.len = 1, names = "named")  # nolint: object_name_linter
  checkmate::assert_numeric(n_h, lower = 1, len = length(N_h), names = "named")  # nolint: object_name_linter
  checkmate::assert_numeric(ybar_h, lower = 0, len = length(N_h))  # nolint: object_name_linter
  checkmate::assert_numeric(s2_h, lower = 0, len = length(N_h))  # nolint: object_name_linter
  checkmate::assert_number(rse_target, lower = 1e-6, upper = 1.0)

  .build_strata_audit(
    N_h        = N_h,  # nolint: object_name_linter
    n_h        = n_h,  # nolint: object_name_linter
    ybar_h     = ybar_h,  # nolint: object_name_linter
    s2_h       = s2_h,  # nolint: object_name_linter
    rse_target = rse_target,
    stratum    = names(N_h)  # nolint: object_name_linter
  )
}

# Internal: shared computation for both audit_strata methods.
.build_strata_audit <- function(N_h, n_h, ybar_h, s2_h, rse_target, stratum) {  # nolint: object_name_linter
  single_day <- names(n_h)[n_h == 1L]  # nolint: object_name_linter
  if (length(single_day) > 0) {
    cli::cli_warn(c(
      "Single-day strata cannot estimate variance.",
      "i" = "RSE, DEFF, and {.field meets_target} are {.val NA} for: {.val {single_day}}",
      "i" = "Add at least one more sampled day per affected stratum."
    ))
  }

  N  <- sum(N_h)  # nolint: object_name_linter
  n  <- sum(n_h)  # nolint: object_name_linter

  se_h  <- sqrt((1 - n_h / N_h) * s2_h / n_h)  # nolint: object_name_linter
  rse_h <- se_h / ybar_h  # nolint: object_name_linter

  s2_overall <- sum(N_h * s2_h, na.rm = TRUE) / N  # nolint: object_name_linter
  Var_SRS    <- (1 - n / N) * s2_overall / n  # nolint: object_name_linter
  Var_strat  <- sum((N_h / N)^2 * (1 - n_h / N_h) * s2_h / n_h, na.rm = TRUE)  # nolint: object_name_linter
  deff_overall <- if (!is.na(Var_SRS) && Var_SRS > .Machine$double.eps) {  # nolint: object_name_linter
    Var_strat / Var_SRS  # nolint: object_name_linter
  } else {
    NA_real_
  }

  deff_h <- ((1 - n_h / N_h) * s2_h / n_h) / ((1 - n / N) * s2_overall / n)  # nolint: object_name_linter

  structure(
    list(
      strata = tibble::tibble(
        stratum      = stratum,
        N_h          = as.integer(N_h),  # nolint: object_name_linter
        n_h          = as.integer(n_h),  # nolint: object_name_linter
        ybar_h       = ybar_h,  # nolint: object_name_linter
        s2_h         = s2_h,  # nolint: object_name_linter
        RSE          = rse_h,  # nolint: object_name_linter
        DEFF         = deff_h,  # nolint: object_name_linter
        meets_target = rse_h <= rse_target
      ),
      rse_target = rse_target,
      n_total    = as.integer(n),
      deff       = deff_overall
    ),
    class = "creel_strata_audit"
  )
}

#' Simulate the effect of collapsing strata on precision
#'
#' Compares per-stratum RSE and DEFF before and after merging a set of strata
#' into a single combined stratum.
#'
#' @param audit A `creel_strata_audit` object returned by `audit_strata()`.
#' @param merge_strata Character vector. Names of strata to merge (must all
#'   appear in `audit$strata$stratum`).
#'
#' @details
#' Merged strata are pooled using population-weighted means:
#' - `N_merged = sum(N_h[merge_strata])`
#' - `n_merged = sum(n_h[merge_strata])`
#' - `ybar_merged = sum(N_h * ybar_h) / N_merged` (population-weighted)
#' - `s2_merged = sum(n_h * s2_h) / n_merged` (sample-size-weighted pooled
#'   within-stratum variance)
#'
#' RSE and DEFF for the merged stratum are computed using the same FPC-corrected
#' formulas as `audit_strata()`. Unmerged strata appear identically in both
#' `"before"` and `"after"` rows.
#'
#' @return A plain tibble (no S3 class) with columns: `state` (`"before"` or
#'   `"after"`), `stratum`, `N_h`, `n_h`, `RSE`, `DEFF`, `meets_target`.
#'
#' @references
#' Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.
#'
#' @family "Planning & Sample Size"
#' @export
#'
#' @examples
#' audit <- audit_strata(
#'   c(early_season = 30, mid_season = 30, late_season = 20),
#'   n_h    = c(early_season = 10, mid_season = 12, late_season = 8),
#'   ybar_h = c(40, 45, 38),
#'   s2_h   = c(300, 320, 280)
#' )
#' simulate_strata_collapse(audit, merge_strata = c("early_season", "mid_season"))
simulate_strata_collapse <- function(audit, merge_strata) {
  if (!inherits(audit, "creel_strata_audit")) {
    cli::cli_abort(c(
      "{.arg audit} must be a {.cls creel_strata_audit} object.",
      "x" = "Got class: {.cls {class(audit)}}"
    ))
  }
  checkmate::assert_character(merge_strata, min.len = 1)

  bad <- setdiff(merge_strata, audit$strata$stratum)
  if (length(bad) > 0) {
    cli::cli_abort(c(
      "Unknown stratum name in {.arg merge_strata}.",
      "x" = "Not found: {.val {bad}}",
      "i" = "Valid strata: {.val {audit$strata$stratum}}"
    ))
  }

  strata_tbl    <- audit$strata
  rse_target    <- audit$rse_target
  N_total       <- sum(strata_tbl$N_h)  # nolint: object_name_linter
  n_total       <- sum(strata_tbl$n_h)
  s2_overall    <- sum(strata_tbl$N_h * strata_tbl$s2_h, na.rm = TRUE) / N_total  # nolint: object_name_linter
  Var_SRS_denom <- (1 - n_total / N_total) * s2_overall / n_total  # nolint: object_name_linter

  .rse_deff <- function(N_h_i, n_h_i, ybar_h_i, s2_h_i) {  # nolint: object_name_linter
    rse_i  <- sqrt((1 - n_h_i / N_h_i) * s2_h_i / n_h_i) / ybar_h_i  # nolint: object_name_linter
    deff_i <- if (!is.na(Var_SRS_denom) && Var_SRS_denom > .Machine$double.eps) {  # nolint: object_name_linter
      ((1 - n_h_i / N_h_i) * s2_h_i / n_h_i) / Var_SRS_denom  # nolint: object_name_linter
    } else {
      NA_real_
    }
    list(RSE = rse_i, DEFF = deff_i, meets_target = rse_i <= rse_target)
  }

  before_rows <- lapply(seq_len(nrow(strata_tbl)), function(i) {
    s  <- strata_tbl[i, ]
    rd <- .rse_deff(s$N_h, s$n_h, s$ybar_h, s$s2_h)  # nolint: object_name_linter
    tibble::tibble(
      state        = "before",
      stratum      = s$stratum,
      N_h          = s$N_h,  # nolint: object_name_linter
      n_h          = s$n_h,  # nolint: object_name_linter
      RSE          = rd$RSE,
      DEFF         = rd$DEFF,
      meets_target = rd$meets_target
    )
  })

  merge_rows   <- strata_tbl[strata_tbl$stratum %in% merge_strata, ]
  keep_rows    <- strata_tbl[!strata_tbl$stratum %in% merge_strata, ]

  N_merged     <- sum(merge_rows$N_h)  # nolint: object_name_linter
  n_merged     <- sum(merge_rows$n_h)
  ybar_merged  <- sum(merge_rows$N_h * merge_rows$ybar_h) / N_merged  # nolint: object_name_linter
  s2_merged    <- sum(merge_rows$n_h * merge_rows$s2_h, na.rm = TRUE) / n_merged  # nolint: object_name_linter
  merged_label <- paste(merge_strata, collapse = "+")
  rd_merged    <- .rse_deff(N_merged, n_merged, ybar_merged, s2_merged)  # nolint: object_name_linter

  merged_row <- tibble::tibble(
    state        = "after",
    stratum      = merged_label,
    N_h          = as.integer(N_merged),  # nolint: object_name_linter
    n_h          = as.integer(n_merged),
    RSE          = rd_merged$RSE,
    DEFF         = rd_merged$DEFF,
    meets_target = rd_merged$meets_target
  )

  after_keep <- lapply(seq_len(nrow(keep_rows)), function(i) {
    s  <- keep_rows[i, ]
    rd <- .rse_deff(s$N_h, s$n_h, s$ybar_h, s$s2_h)  # nolint: object_name_linter
    tibble::tibble(
      state        = "after",
      stratum      = s$stratum,
      N_h          = s$N_h,  # nolint: object_name_linter
      n_h          = s$n_h,  # nolint: object_name_linter
      RSE          = rd$RSE,
      DEFF         = rd$DEFF,
      meets_target = rd$meets_target
    )
  })

  do.call(rbind, c(before_rows, list(merged_row), after_keep))
}

#' Compute Neyman-optimal sample allocation across strata
#'
#' Given a fixed total sampling budget, allocates days across strata using the
#' Neyman optimal allocation formula (Cochran 1977 eq. 5.24), which assigns more
#' days to strata with larger variability and more calendar days.
#'
#' @param n_total Positive integer. Total sampling days available across all
#'   strata.
#' @param N_h Named numeric vector. Total available days per stratum. Values
#'   must be >= 1.
#' @param s2_h Numeric vector of the same length as `N_h`. Pilot variance of
#'   effort per day per stratum. Values must be >= 0.
#'
#' @details
#' Neyman allocation: `n_h = ceiling(n_total * (N_h * sqrt(s2_h)) / sum(N_h * sqrt(s2_h)))`.
#'
#' Because each stratum's allocation is ceiling-ed independently, the sum of
#' returned values may slightly exceed `n_total`.
#'
#' @return A named integer vector. Elements named after strata in `N_h` give the
#'   Neyman-optimal sampling days per stratum.
#'
#' @references
#' Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.
#'
#' @family "Planning & Sample Size"
#' @export
#'
#' @examples
#' reallocate_strata(
#'   n_total = 36,
#'   N_h     = c(weekday = 65, weekend = 28),
#'   s2_h    = c(400, 500)
#' )
reallocate_strata <- function(n_total, N_h, s2_h) {  # nolint: object_name_linter
  checkmate::assert_integerish(n_total, lower = 1, len = 1)
  checkmate::assert_numeric(N_h, lower = 1, min.len = 1, names = "named")  # nolint: object_name_linter
  checkmate::assert_numeric(s2_h, lower = 0, len = length(N_h))  # nolint: object_name_linter

  alloc_weights  <- N_h * sqrt(s2_h)  # nolint: object_name_linter
  n_h_opt        <- ceiling(n_total * alloc_weights / sum(alloc_weights))  # nolint: object_name_linter
  names(n_h_opt) <- names(N_h)  # nolint: object_name_linter
  storage.mode(n_h_opt) <- "integer"
  n_h_opt  # nolint: object_name_linter
}
