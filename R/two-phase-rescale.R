# Two-phase (double sampling) rescaling for measured-fish distributions --------
#
# Lengths and ages are measured on a SUBSAMPLE of the catch. Expanding that
# subsample through the interview design estimates "total fish that happened to
# get measured", not "total fish caught" -- on the package's own example data,
# 14 against a harvest total of 77 (GH #310).
#
# The correct estimator is two-phase, the same structure already used for the
# camera ratio in #236 (Cochran 1977 §12.9): take the bin proportion among
# measured fish, and scale it by the design-estimated REPORTED total.
#
# The bin proportion among measured fish, times the reported total: p_h is
# N_h(measured) over the sum of N_j(measured), and the reported bin total is
# p_h times T.
#
# Both parts are estimated from the same interview design, in ONE svytotal()
# call, so the covariance between a bin and the reported total is available
# rather than assumed away. See two_phase_rescale() for the variance.

#' Reported total for one group, per interview
#'
#' The second-phase scale factor. Returns the reported count each interview
#' contributes to this group, aligned to `design$interviews` rows, or `NULL`
#' when the design cannot supply it -- the caller refuses rather than falling
#' back to the unscaled subsample.
#'
#' A species group cannot use the interview-level catch/harvest columns, which
#' are not species-resolved; it reads `design$catch` instead. Everything else
#' uses the interview-level column, except release, which has no interview-level
#' column in this package and always comes from `design$catch`.
#'
#' @param design A creel_design object.
#' @param type One of "catch", "harvest", "release".
#' @param group_info One-row data frame of this group's by= values, or NULL.
#' @param by_vars Character vector of grouping variable names.
#' @param frame_species_col Name of the species column in the frame `by=` was
#'   resolved against (`design$lengths_species_col` / `ages_species_col`). This
#'   is NOT `catch_species_col`: `by=` on these paths resolves against the
#'   length or age table, and the two frames may name the column differently.
#'
#' @return Numeric vector, one value per interview, or NULL.
#'
#' @keywords internal
#' @noRd
reported_total_per_interview <- function(design, type, group_info, by_vars,
                                         frame_species_col = NULL,
                                         error_call = rlang::caller_env()) {
  interviews <- design$interviews
  species_col <- design[["catch_species_col"]]
  catch_df <- design[["catch"]]

  is_species_group <- !is.null(frame_species_col) &&
    !is.null(group_info) &&
    frame_species_col %in% by_vars

  # Any grouping other than species has to restrict the reported total to the
  # interviews in that group, or every group is scaled by the whole fishery's
  # total and the parts sum to more than the whole -- by = length_type gave 127
  # to each of two groups against a reported catch of 127.
  other_vars <- setdiff(by_vars, frame_species_col)
  if (length(other_vars) > 0L && !is.null(group_info)) {
    not_interview <- setdiff(other_vars, names(interviews))
    if (length(not_interview) > 0L) {
      # The reported total is recorded per interview. A grouping variable that
      # lives only in the length/age table cannot restrict it, and scaling such
      # a group by the whole total would silently overstate it.
      cli::cli_abort(
        c(
          "Cannot scale a distribution grouped by {.field {not_interview}}.",
          "x" = "The reported total is recorded per interview, and
                 {cli::qty(length(not_interview))}{?this column is/these columns are}
                 not an interview attribute.",
          "i" = "Group by species, or by a column of {.code design$interviews}."
        ),
        class = "creel_error_ungroupable_rescale",
        call = error_call
      )
    }
  }

  catch_type_for <- c(catch = "caught", harvest = "harvested", release = "released")

  base_total <- if (is_species_group) {
    if (is.null(catch_df) || is.null(species_col)) {
      return(NULL)
    }
    uid_col <- design$catch_interview_uid_col
    count_col <- design$catch_count_col
    type_col <- design$catch_type_col

    # Filter to the species FIRST. Testing the whole table for "caught" rows
    # before narrowing meant one species having them suppressed the fallback for
    # every other species, which then scaled to a reported total of zero.
    rows <- catch_df[catch_df[[species_col]] == group_info[[frame_species_col]][1], ,
                     drop = FALSE]
    typed <- rows[rows[[type_col]] == catch_type_for[[type]], , drop = FALSE]
    if (identical(type, "catch") && nrow(typed) == 0L) {
      # add_catch() makes a "caught" row optional: absent, catch is
      # harvested + released. Applied per species, not per table.
      typed <- rows[rows[[type_col]] %in% c("harvested", "released"), , drop = FALSE]
    }
    if (nrow(typed) == 0L) {
      rep(0, nrow(interviews))
    } else {
      agg <- stats::aggregate(typed[[count_col]], by = list(uid = typed[[uid_col]]), FUN = sum)
      names(agg) <- c("uid", "total")
      out <- agg$total[match(interviews[[uid_col]], agg$uid)]
      out[is.na(out)] <- 0
      as.numeric(out)
    }
  } else if (identical(type, "release")) {
    # Release has no interview-level column, but the catch model says
    # caught = harvested + released. Deriving it from the interview columns --
    # rather than from the catch table's released rows -- is what keeps
    # harvest + release = catch for a non-species request: the identity only
    # holds when all three come from the same source. This package's own example
    # data disagrees between the two records (127 caught in the interviews
    # against 50 in the catch table), so the choice is load-bearing.
    catch_col <- design[["catch_col"]]
    harvest_col <- design[["harvest_col"]]
    if (is.null(catch_col) || is.null(harvest_col) ||
          !all(c(catch_col, harvest_col) %in% names(interviews))) {
      return(NULL)
    }
    implied <- as.numeric(interviews[[catch_col]]) - as.numeric(interviews[[harvest_col]])
    if (any(implied < 0, na.rm = TRUE)) {
      cli::cli_abort(
        c(
          "Implied release count is negative for
           {sum(implied < 0, na.rm = TRUE)} interview{?s}.",
          "x" = "{.field {harvest_col}} exceeds {.field {catch_col}}, so
                 caught - harvested is not a release count.",
          "i" = "Fix the interview data, or group by species so released rows
                 are read from {.fn add_catch} directly."
        ),
        class = "creel_error_negative_release",
        call = error_call
      )
    }
    implied[is.na(implied)] <- 0
    implied
  } else {
    col <- switch(type,
      catch = design[["catch_col"]],
      harvest = design[["harvest_col"]]
    )
    if (is.null(col) || !col %in% names(interviews)) {
      return(NULL)
    }
    as.numeric(interviews[[col]])
  }

  # Restrict to the group's own interviews. Species is already handled above by
  # filtering the catch table; every other grouping variable is an interview
  # attribute by the check at the top of this function.
  if (length(other_vars) > 0L && !is.null(group_info)) {
    keep <- rep(TRUE, nrow(interviews))
    for (v in other_vars) {
      keep <- keep & (interviews[[v]] == group_info[[v]][1])
    }
    keep[is.na(keep)] <- FALSE
    base_total <- base_total * keep
  }

  base_total
}

#' Rescale measured-fish bin totals onto the reported total
#'
#' Delta method over the joint `svytotal()` of the bin columns and the reported
#' total. With theta = (N_1, ..., N_H, T), S = sum_j N_j and p_h = N_h / S:
#'
#'   dN_h/dN_h = T (S - N_h) / S^2
#'   dN_h/dN_j = -T N_h / S^2      (j != h)
#'   dN_h/dT   = p_h
#'
#' and Var(N_h) = g' V g with V the full covariance from the same call. The
#' cross-bin and bin-total covariances are therefore carried, not assumed zero
#' -- unlike the ratio consumers, which still assume independence (GH #311).
#'
#' @param meas Numeric vector of measured-fish bin totals.
#' @param total Numeric scalar, the estimated reported total.
#' @param v Covariance matrix of `c(meas, total)`, in that order.
#'
#' @return List with `estimate` and `se`, each length `length(meas)`.
#'
#' @keywords internal
#' @noRd
two_phase_rescale <- function(meas, total, v) {
  h_n <- length(meas)
  s <- sum(meas)
  if (!is.finite(s) || s <= 0) {
    return(list(estimate = rep(NA_real_, h_n), se = rep(NA_real_, h_n)))
  }
  p <- meas / s
  est <- p * total

  se <- vapply(seq_len(h_n), function(h) {
    g <- numeric(h_n + 1L)
    g[seq_len(h_n)] <- -total * meas[h] / s^2
    g[h] <- total * (s - meas[h]) / s^2
    g[h_n + 1L] <- p[h]
    var_h <- as.numeric(t(g) %*% v %*% g)
    if (!is.finite(var_h) || var_h < 0) NA_real_ else sqrt(var_h)
  }, numeric(1))

  list(estimate = est, se = se)
}

#' Warn once that a distribution was rescaled onto the reported total
#'
#' @param measured Total measured fish (design-weighted).
#' @param reported Total reported fish (design-weighted).
#' @param what "length" or "age".
#'
#' @keywords internal
#' @noRd
warn_two_phase_rescale <- function(measured, reported, what) {
  if (!is.finite(measured) || !is.finite(reported) || measured <= 0) {
    return(invisible(NULL))
  }
  if (isTRUE(all.equal(measured, reported))) {
    return(invisible(NULL))
  }
  cli::cli_warn(
    c(
      "!" = "{what} totals were rescaled onto the reported catch.",
      "i" = "Measured fish (weighted): {format(measured, digits = 6)}; reported:
             {format(reported, digits = 6)} -- a factor of
             {format(reported / measured, digits = 3)}.",
      "i" = "{.field estimate}, {.field se} and the confidence bounds describe the
             REPORTED catch, estimated from the measured subsample. Shares
             ({.field percent}) are unaffected."
    ),
    class = "creel_warn_two_phase_rescale"
  )
  invisible(NULL)
}
