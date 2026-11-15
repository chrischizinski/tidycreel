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
audit_strata.creel_design <- function(x, rse_target = 0.20, ...) {
  # nolint: object_name_linter
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

  # Strata are matched on a key no label can contain, and shown as "a / b"
  # (as plot_design() does); pasting with sep = "" merged distinct strata.
  strata_key <- function(df) {
    if (length(strata_cols) == 1) {
      as.character(df[[strata_cols]])
    } else {
      do.call(paste, c(df[strata_cols], sep = "\u001f"))
    }
  }

  # A missing stratum value is unknown, not a stratum: paste() would turn it
  # into the label "NA" and merge it with a real "NA" value (GH #440 review).
  na_strata <- strata_cols[vapply(strata_cols, function(col) {
    anyNA(design$calendar[[col]]) || anyNA(design$counts[[col]])
  }, logical(1))]
  if (length(na_strata) > 0L) {
    cli::cli_abort(
      c(
        "Strata must be known on every calendar day and count row.",
        "x" = "Missing values in {.field {na_strata}}.",
        "i" = "Assign each day to a stratum before auditing."
      ),
      class = "creel_error_strata_missing"
    )
  }

  # Day totals below are sums over a day's units; a day missing one is not a
  # day total, and its RSE would describe effort nobody counted (GH #442).
  refuse_partial_unit_coverage(design) # nolint: object_usage_linter

  # N_h: population days per stratum, from the helper the estimators use.
  # Counting calendar ROWS inflated it whenever the calendar carried several
  # rows per date (a multi-period schedule, or one with count windows
  # attached) (GH #440, as #436).
  # Ungrouped: a calendar grouped by a non-stratum column would split N_h
  # (the estimators still do -- GH #441).
  pop <- stratum_population_days(dplyr::ungroup(design$calendar), strata_cols, design$date_col)
  available_by_strata <- stats::setNames(pop$.N_avail, strata_key(pop))

  counts_data <- design$counts
  count_var <- resolve_count_col( # nolint: object_usage_linter
    counts = counts_data,
    excluded = c(design$date_col, design$strata_cols, design$psu_col),
    count_col = design$count_col
  )

  # n_h, ybar_h and s2_h are per DAY, as N_h is (GH #440). Rows that share a
  # sampling-unit key are repeat looks at one unit (aerial flights kept for the
  # GLMM) and are averaged; distinct units within a day (`unit_cols` such as
  # bank and boat, sites, a site-day PSU) are summed into the day's total.
  # Counting rows made n_h exceed the days sampled and could report a false
  # census. An NA unit keeps its day NA.
  unit_key <- psu_key_cols(design, design$psu_col, counts_data, design$unit_cols) # nolint: object_usage_linter
  day_cols <- unique(c(strata_cols, design$date_col))
  counts_data <- counts_data |>
    dplyr::ungroup() |>
    dplyr::group_by(dplyr::across(dplyr::all_of(unique(c(day_cols, unit_key))))) |>
    dplyr::summarise(!!count_var := mean(.data[[count_var]]), .groups = "drop") |>
    dplyr::group_by(dplyr::across(dplyr::all_of(day_cols))) |>
    dplyr::summarise(!!count_var := sum(.data[[count_var]]), .groups = "drop")

  counts_data$.strata_key <- strata_key(counts_data)

  strata_keys <- unique(counts_data$.strata_key)

  n_h_vals <- integer(length(strata_keys))
  N_h_vals <- integer(length(strata_keys))
  ybar_h_vals <- numeric(length(strata_keys))
  s2_h_vals <- numeric(length(strata_keys))

  for (i in seq_along(strata_keys)) {
    sk <- strata_keys[i]
    rows <- counts_data$.strata_key == sk
    n_h_i <- sum(rows)
    n_h_vals[i] <- n_h_i # nolint: object_name_linter
    N_h_vals[i] <- as.integer(available_by_strata[sk]) # nolint: object_name_linter
    ybar_h_vals[i] <- mean(counts_data[[count_var]][rows]) # nolint: object_name_linter
    s2_h_vals[i] <- if (n_h_i >= 2L) var(counts_data[[count_var]][rows]) else NA_real_ # nolint: object_name_linter
  }

  strata_labels <- gsub("\u001f", " / ", strata_keys, fixed = TRUE)
  # Labels name strata downstream (simulate_strata_collapse()), so two strata
  # must never share one, as ("a / b", "c") and ("a", "b / c") would.
  if (anyDuplicated(strata_labels)) {
    dup <- unique(strata_labels[duplicated(strata_labels)]) # nolint: object_usage_linter
    cli::cli_abort(
      c(
        "Two different strata would share the label {.val {dup}}.",
        "x" = "Their values contain {.code /} between spaces, which joins multi-column strata labels.",
        "i" = "Rename those strata values."
      ),
      class = "creel_error_strata_label_collision"
    )
  }
  names(n_h_vals) <- strata_labels # nolint: object_name_linter
  names(N_h_vals) <- strata_labels # nolint: object_name_linter
  names(ybar_h_vals) <- strata_labels # nolint: object_name_linter
  names(s2_h_vals) <- strata_labels # nolint: object_name_linter

  .build_strata_audit(
    N_h = N_h_vals, # nolint: object_name_linter
    n_h = n_h_vals, # nolint: object_name_linter
    ybar_h = ybar_h_vals, # nolint: object_name_linter
    s2_h = s2_h_vals, # nolint: object_name_linter
    rse_target = rse_target,
    stratum = strata_labels
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
audit_strata.default <- function(x, n_h, ybar_h, s2_h, rse_target = 0.20, ...) {
  # nolint: object_name_linter
  N_h <- x # nolint: object_name_linter
  checkmate::assert_numeric(N_h, lower = 1, min.len = 1, names = "named") # nolint: object_name_linter
  checkmate::assert_numeric(n_h, lower = 1, len = length(N_h), names = "named") # nolint: object_name_linter
  checkmate::assert_numeric(ybar_h, lower = 0, len = length(N_h)) # nolint: object_name_linter
  checkmate::assert_numeric(s2_h, lower = 0, len = length(N_h)) # nolint: object_name_linter
  checkmate::assert_number(rse_target, lower = 1e-6, upper = 1.0)

  .build_strata_audit(
    N_h = N_h, # nolint: object_name_linter
    n_h = n_h, # nolint: object_name_linter
    ybar_h = ybar_h, # nolint: object_name_linter
    s2_h = s2_h, # nolint: object_name_linter
    rse_target = rse_target,
    stratum = names(N_h) # nolint: object_name_linter
  )
}

# Internal: shared computation for both audit_strata methods.
.build_strata_audit <- function(N_h, n_h, ybar_h, s2_h, rse_target, stratum) {
  # nolint: object_name_linter
  single_day <- names(n_h)[n_h == 1L] # nolint: object_name_linter
  if (length(single_day) > 0) {
    creel_warn(c(
      "Single-day strata cannot estimate variance.",
      "i" = "RSE, DEFF, and {.field meets_target} are {.val NA} for: {.val {single_day}}",
      "i" = "Add at least one more sampled day per affected stratum."
    ),
    class = c("creel_warning_single_day_strata", "creel_warning")
    )
  }

  N <- sum(N_h) # nolint: object_name_linter
  n <- sum(n_h) # nolint: object_name_linter

  se_h <- sqrt((1 - n_h / N_h) * s2_h / n_h) # nolint: object_name_linter
  rse_h <- se_h / ybar_h # nolint: object_name_linter

  s2_overall <- sum(N_h * s2_h, na.rm = TRUE) / N # nolint: object_name_linter
  Var_SRS <- (1 - n / N) * s2_overall / n # nolint: object_name_linter
  Var_strat <- sum((N_h / N)^2 * (1 - n_h / N_h) * s2_h / n_h, na.rm = TRUE) # nolint: object_name_linter
  deff_overall <- if (!is.na(Var_SRS) && Var_SRS > .Machine$double.eps) {
    # nolint: object_name_linter
    Var_strat / Var_SRS # nolint: object_name_linter
  } else {
    NA_real_
  }

  deff_h <- ((1 - n_h / N_h) * s2_h / n_h) / ((1 - n / N) * s2_overall / n) # nolint: object_name_linter

  structure(
    list(
      strata = tibble::tibble(
        stratum = stratum,
        N_h = as.integer(N_h), # nolint: object_name_linter
        n_h = as.integer(n_h), # nolint: object_name_linter
        ybar_h = ybar_h, # nolint: object_name_linter
        s2_h = s2_h, # nolint: object_name_linter
        RSE = rse_h, # nolint: object_name_linter
        DEFF = deff_h, # nolint: object_name_linter
        meets_target = rse_h <= rse_target
      ),
      rse_target = rse_target,
      n_total = as.integer(n),
      deff = deff_overall
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

  strata_tbl <- audit$strata
  rse_target <- audit$rse_target
  N_total <- sum(strata_tbl$N_h) # nolint: object_name_linter
  n_total <- sum(strata_tbl$n_h)
  s2_overall <- sum(strata_tbl$N_h * strata_tbl$s2_h, na.rm = TRUE) / N_total # nolint: object_name_linter
  Var_SRS_denom <- (1 - n_total / N_total) * s2_overall / n_total # nolint: object_name_linter

  .rse_deff <- function(N_h_i, n_h_i, ybar_h_i, s2_h_i) {
    # nolint: object_name_linter
    rse_i <- sqrt((1 - n_h_i / N_h_i) * s2_h_i / n_h_i) / ybar_h_i # nolint: object_name_linter
    deff_i <- if (!is.na(Var_SRS_denom) && Var_SRS_denom > .Machine$double.eps) {
      # nolint: object_name_linter
      ((1 - n_h_i / N_h_i) * s2_h_i / n_h_i) / Var_SRS_denom # nolint: object_name_linter
    } else {
      NA_real_
    }
    list(RSE = rse_i, DEFF = deff_i, meets_target = rse_i <= rse_target)
  }

  before_rows <- lapply(seq_len(nrow(strata_tbl)), function(i) {
    s <- strata_tbl[i, ]
    rd <- .rse_deff(s$N_h, s$n_h, s$ybar_h, s$s2_h) # nolint: object_name_linter
    tibble::tibble(
      state = "before",
      stratum = s$stratum,
      N_h = s$N_h, # nolint: object_name_linter
      n_h = s$n_h, # nolint: object_name_linter
      RSE = rd$RSE,
      DEFF = rd$DEFF,
      meets_target = rd$meets_target
    )
  })

  merge_rows <- strata_tbl[strata_tbl$stratum %in% merge_strata, ]
  keep_rows <- strata_tbl[!strata_tbl$stratum %in% merge_strata, ]

  N_merged <- sum(merge_rows$N_h) # nolint: object_name_linter
  n_merged <- sum(merge_rows$n_h)
  ybar_merged <- sum(merge_rows$N_h * merge_rows$ybar_h) / N_merged # nolint: object_name_linter
  s2_merged <- sum(merge_rows$n_h * merge_rows$s2_h, na.rm = TRUE) / n_merged # nolint: object_name_linter
  merged_label <- paste(merge_strata, collapse = "+")
  rd_merged <- .rse_deff(N_merged, n_merged, ybar_merged, s2_merged) # nolint: object_name_linter

  merged_row <- tibble::tibble(
    state = "after",
    stratum = merged_label,
    N_h = as.integer(N_merged), # nolint: object_name_linter
    n_h = as.integer(n_merged),
    RSE = rd_merged$RSE,
    DEFF = rd_merged$DEFF,
    meets_target = rd_merged$meets_target
  )

  after_keep <- lapply(seq_len(nrow(keep_rows)), function(i) {
    s <- keep_rows[i, ]
    rd <- .rse_deff(s$N_h, s$n_h, s$ybar_h, s$s2_h) # nolint: object_name_linter
    tibble::tibble(
      state = "after",
      stratum = s$stratum,
      N_h = s$N_h, # nolint: object_name_linter
      n_h = s$n_h, # nolint: object_name_linter
      RSE = rd$RSE,
      DEFF = rd$DEFF,
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
#'   strata. Must be at least `sum(pmin(min_n, N_h))` and at most `sum(N_h)`.
#' @param N_h Named numeric vector. Total available days per stratum: whole
#'   numbers >= 1.
#' @param s2_h Numeric vector of the same length as `N_h`. Pilot variance of
#'   effort per day per stratum. Values must be >= 0.
#' @param min_n Positive integer. The fewest days any stratum may get, so its
#'   variance can be estimated. Default `2`. A stratum with fewer days than
#'   `min_n` is sampled completely.
#'
#' @details
#' Neyman allocation (Cochran 1977 eq. 5.24) gives stratum \eqn{h} the share
#' \eqn{n \, N_h s_h / \sum N_h s_h} of the `n_total` days. The result is a
#' plan the season can carry out:
#'
#' - **No stratum gets more days than it has, and every stratum gets at least
#'   `min_n`** (or all its days, if it has fewer), so its variance can be
#'   estimated. The share is \eqn{\lambda N_h s_h} clamped to that range, with
#'   \eqn{\lambda} chosen so the shares spend `n_total`: a stratum held at its
#'   cap or floor frees or takes days, and the others absorb them in proportion
#'   to their Neyman weights. This is the Neyman allocation with bounds.
#'   Strata with zero pilot variance stay at the floor unless every other
#'   stratum is full.
#' - **The days sum to `n_total` exactly.** Shares are rounded by largest
#'   remainder: each stratum gets the whole part of its share, and the days
#'   left over go to the largest fractional parts.
#'
#' An `n_total` larger than the season (`sum(N_h)`) or too small to give every
#' stratum its floor is refused. Before tidycreel 9.0.0 each share was rounded
#' up independently and nothing was capped, so the plan could exceed both the
#' budget and a stratum's days (GH #384).
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
reallocate_strata <- function(n_total, N_h, s2_h, min_n = 2L) {
  # nolint start: object_name_linter
  checkmate::assert_integerish(n_total, lower = 1, len = 1)
  checkmate::assert_numeric(N_h, lower = 1, min.len = 1, names = "named")
  checkmate::assert_integerish(N_h)
  checkmate::assert_numeric(s2_h, lower = 0, len = length(N_h))
  checkmate::assert_int(min_n, lower = 1)

  floor_h <- pmin(min_n, N_h)
  if (n_total > sum(N_h) || n_total < sum(floor_h)) {
    cli::cli_abort(
      c(
        "{.arg n_total} = {n_total} cannot be allocated across these strata.",
        "x" = if (n_total > sum(N_h)) {
          "The strata have {sum(N_h)} day{?s} in all."
        } else {
          "Giving every stratum at least {.arg min_n} = {min_n} day{?s} needs {sum(floor_h)}."
        },
        "i" = "Choose {.arg n_total} between {sum(floor_h)} and {sum(N_h)}."
      ),
      class = "creel_error_invalid_input"
    )
  }

  # Continuous Neyman shares within bounds. Minimising the stratified variance
  # sum(N_h^2 s2_h / n_h) subject to floor_h <= n_h <= N_h and sum(n_h) =
  # n_total gives n_h = clamp(lambda * N_h * s_h, floor_h, N_h) for the lambda
  # that spends n_total (the bounded form of Cochran eq. 5.24). The sum is
  # nondecreasing in lambda, so bisection finds it. Fixing capped strata one
  # pass at a time instead can strand the others below their floor when the
  # budget is tight.
  w <- N_h * sqrt(s2_h)
  share <- bounded_shares(n_total, w, floor_h, N_h)
  # Strata with zero variance stay at their floor under Neyman weights. If the
  # others are all full and days remain, give those days by stratum size.
  if (sum(share) < n_total - 1e-9) {
    zero <- w <= 0
    share[zero] <- bounded_shares(
      n_total - sum(share[!zero]), N_h[zero], floor_h[zero], N_h[zero]
    )
  }

  # Largest-remainder rounding: whole parts first, leftover days to the
  # largest fractional parts. Shares lie within [floor_h, N_h], so whole parts
  # respect the floor and a stratum with a fractional part has room for one
  # more day.
  n_h <- floor(share + 1e-9)
  short <- n_total - sum(n_h)
  if (short > 0) {
    frac <- share - n_h
    n_h[order(-frac)[seq_len(short)]] <- n_h[order(-frac)[seq_len(short)]] + 1
  }

  n_h <- as.integer(round(n_h))
  names(n_h) <- names(N_h)
  n_h
  # nolint end: object_name_linter
}

# clamp(lambda * w, lo, hi) summed to `total`, by bisection on lambda. Returns
# lo where w is 0. Assumes sum(lo) <= total; returns hi everywhere w > 0 when
# even that cannot reach total. Internal to reallocate_strata() (GH #384).
#' @noRd
bounded_shares <- function(total, w, lo, hi) {
  at <- function(lambda) pmin(hi, pmax(lo, lambda * w))
  if (!any(w > 0)) {
    return(lo)
  }
  upper <- max(hi[w > 0] / w[w > 0])
  if (sum(at(upper)) <= total) {
    return(at(upper))
  }
  lower <- 0
  for (i in seq_len(200L)) {
    mid <- (lower + upper) / 2
    if (sum(at(mid)) < total) lower <- mid else upper <- mid
  }
  at(upper)
}
