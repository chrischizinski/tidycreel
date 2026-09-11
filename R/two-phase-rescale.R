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
#' are not species-resolved; it reads `design$catch` instead. Every other
#' grouping uses the interview-level column -- including release, which has no
#' column of its own and is implied as caught - harvested from the two that do.
#' Release is deliberately NOT read from `design$catch` for a non-species group;
#' see the comment on that branch for why the identity requires a single source.
#'
#' The species branch applies the `add_catch()` catch-type model through
#' `species_counts_per_interview()`, so the optional-`"caught"`-row fallback is
#' decided per species-interview pair and in one place (GH #318). It refuses
#' when none of THIS GROUP's own interviews records the species -- on the key,
#' not the value -- rather than when the species is absent from the whole table
#' (GH #317).
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
  #
  # The mask is built HERE, before the reported total is read, because the
  # validation below must judge only the interviews this group actually uses. An
  # interview outside the group contributes nothing to this group either way, so
  # letting a missing or contradictory count in one abort the whole request is a
  # refusal the caller cannot act on -- the offending row is not in the data the
  # request asked about.
  keep <- rep(TRUE, nrow(interviews))
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
    for (v in other_vars) {
      target <- group_info[[v]][1]
      # NA is a group like any other here. `x == NA` is NA for every row, and
      # blanket-converting that to FALSE emptied the group -- so a grouping
      # column with missing values reported a total of 0, and the whole
      # distribution for that group came back as zero fish with no warning. The
      # NA group must match the rows that are themselves NA.
      #
      # Character comparison for the same reason as the species filter above:
      # factors with different level sets error rather than compare.
      col <- interviews[[v]]
      keep <- keep & if (is.na(target)) {
        is.na(col)
      } else {
        !is.na(col) & as.character(col) == as.character(target)
      }
    }
  }

  # Names the group in a refusal. "No reported catch for walleye" reads as a
  # claim about the whole fishery, which is wrong when only one group of the
  # walleye interviews is the empty one.
  group_label <- if (length(other_vars) > 0L && !is.null(group_info)) { # nolint: object_usage_linter
    paste0(
      " in ",
      paste0(
        other_vars, " = ",
        vapply(other_vars, function(v) as.character(group_info[[v]][1]), character(1)),
        collapse = ", "
      )
    )
  } else {
    ""
  }

  catch_type_for <- c(catch = "caught", harvest = "harvested", release = "released")

  base_total <- if (is_species_group) {
    if (is.null(catch_df) || is.null(species_col)) {
      return(NULL)
    }
    uid_col <- design$catch_interview_uid_col
    count_col <- design$catch_count_col
    type_col <- design$catch_type_col

    # The add_catch() catch-type model is applied by the one helper that owns it,
    # per SPECIES-INTERVIEW pair (GH #318). Deciding the "caught" fallback once
    # per species instead -- "does a caught row exist anywhere for this species?"
    # -- read every pair holding only harvested/released rows as a catch of zero
    # as soon as any one pair recorded a caught row, and the distribution was
    # then scaled onto that understated total.
    species_val <- group_info[[frame_species_col]][1]
    agg <- species_counts_per_interview(
      catch_df, species_val, catch_type_for[[type]],
      uid_col = uid_col, species_col = species_col,
      type_col = type_col, count_col = count_col
    )

    # Matched as character on both sides. The catch table and the length/age
    # table are attached separately, so a caller can easily have factors with
    # different level sets in each -- and `Ops.factor` does not return NA there,
    # it errors outright with "level sets of factors are different".
    row_map <- match(
      as.character(interviews[[uid_col]]),
      as.character(agg$uid)
    )

    # The refusal is judged on THIS GROUP's own interviews, and on the KEY --
    # does any of them record this species at all -- not on the value. Testing
    # the whole species instead let a group whose own interviews report nothing
    # scale onto a total of zero, because some other group's interviews carried
    # the species' rows. A recorded count that happens to be zero is data and is
    # kept; no record at all is the contradiction.
    if (!any(keep & !is.na(row_map))) {
      # Refusing rather than returning zero. Measured fish with no reported rows
      # is contradictory data, and scaling them by a total of 0 reports "no fish
      # here" with the same confidence as a real estimate -- the
      # silent-wrong-number failure this issue exists to remove.
      cli::cli_abort(
        c(
          "No reported {type} is recorded for {.val {species_val}}{group_label}.",
          "x" = "Its length or age records cannot be scaled onto a total that
                 does not exist.",
          "i" = "Add the missing rows to {.fn add_catch}, or drop the
                 {.field {frame_species_col}} value from the request."
        ),
        class = "creel_error_no_rescale_total",
        call = error_call
      )
    }
    out <- agg$count[row_map]
    out[is.na(out)] <- 0
    as.numeric(out)
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
    # Only this group's interviews are judged. See the mask above.
    in_group <- implied[keep]
    if (anyNA(in_group)) {
      cli::cli_abort(
        c(
          "{sum(is.na(in_group))} interview{?s} {?has/have} no usable release count.",
          "x" = "{.field {catch_col}} or {.field {harvest_col}} is {.val {NA}}, so
                 caught - harvested is unknown -- not zero.",
          "i" = "Fill the missing values, or group by species so released rows
                 are read from {.fn add_catch} directly."
        ),
        class = "creel_error_na_rescale_total",
        call = error_call
      )
    }
    if (any(in_group < 0, na.rm = TRUE)) {
      cli::cli_abort(
        c(
          "Implied release count is negative for
           {sum(in_group < 0, na.rm = TRUE)} interview{?s}.",
          "x" = "{.field {harvest_col}} exceeds {.field {catch_col}}, so
                 caught - harvested is not a release count.",
          "i" = "Fix the interview data, or group by species so released rows
                 are read from {.fn add_catch} directly."
        ),
        class = "creel_error_negative_release",
        call = error_call
      )
    }
    implied
  } else {
    col <- switch(type,
      catch = design[["catch_col"]],
      harvest = design[["harvest_col"]]
    )
    if (is.null(col) || !col %in% names(interviews)) {
      return(NULL)
    }
    vals <- as.numeric(interviews[[col]])
    # An NA here is an unknown count, not a zero, and carrying it forward poisons
    # svytotal() for the whole group. Only this group's interviews are judged --
    # see the mask above.
    in_group <- vals[keep]
    if (anyNA(in_group)) {
      cli::cli_abort(
        c(
          "{sum(is.na(in_group))} interview{?s} {?has/have} a missing {.field {col}}.",
          "x" = "The reported total is the scale factor for every bin, so an
                 unknown count cannot be treated as zero.",
          "i" = "Fill the missing values before estimating a distribution."
        ),
        class = "creel_error_na_rescale_total",
        call = error_call
      )
    }
    vals
  }

  # Restrict to the group's own interviews. Species is already handled above by
  # filtering the catch table; every other grouping variable is an interview
  # attribute by the check at the top of this function.
  #
  # Assigned, not multiplied: `NA * FALSE` is NA, so multiplying could not clear
  # an out-of-group unknown -- and out-of-group unknowns are exactly what the
  # masked validation above now tolerates.
  base_total[!keep] <- 0

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
#' Stacking those gradients gives the Jacobian G, and the rescaled bins' full
#' covariance is G V G' with V the covariance from the same `svytotal()` call.
#' The cross-bin and bin-total covariances are therefore carried, not assumed
#' zero.
#'
#' The whole matrix is returned, not only its diagonal. The bins partition the
#' same fish and fish cluster within interviews, so the off-diagonal terms are
#' large -- on the package's own example data the maximum off-diagonal
#' correlation is 1.0 and the terms sum to +3.79. Any ratio of these bins, which
#' is what every consumer forms, needs them: dropping them made
#' `est_compliance()` report a standard error 32% below an independently
#' computed `survey::svyratio()` reference (GH #311).
#'
#' `se` is `sqrt(diag(vcov))` by construction, so returning the matrix moves no
#' number that was already being reported.
#'
#' @param meas Numeric vector of measured-fish bin totals.
#' @param total Numeric scalar, the estimated reported total.
#' @param v Covariance matrix of `c(meas, total)`, in that order.
#'
#' @return List with `estimate` and `se`, each length `length(meas)`, and
#'   `vcov`, the `length(meas)` square covariance matrix of the rescaled bins.
#'
#' @keywords internal
#' @noRd
two_phase_rescale <- function(meas, total, v) {
  h_n <- length(meas)
  s <- sum(meas)
  if (!is.finite(s) || s <= 0) {
    return(list(
      estimate = rep(NA_real_, h_n),
      se = rep(NA_real_, h_n),
      vcov = matrix(NA_real_, h_n, h_n)
    ))
  }
  p <- meas / s
  est <- p * total

  # The Jacobian, one row per bin. Built as a matrix rather than one gradient
  # at a time so the off-diagonal terms survive: the per-bin loop it replaces
  # could only ever produce a diagonal.
  g_mat <- matrix(0, nrow = h_n, ncol = h_n + 1L)
  for (h in seq_len(h_n)) {
    g_mat[h, seq_len(h_n)] <- -total * meas[h] / s^2
    g_mat[h, h] <- total * (s - meas[h]) / s^2
    g_mat[h, h_n + 1L] <- p[h]
  }
  vcov_est <- g_mat %*% v %*% t(g_mat)
  # Exactly symmetric. G V G' is symmetric in exact arithmetic, and a consumer
  # forming w' Sigma w should not get a different answer for w and its mirror
  # because of floating-point asymmetry in the last bits.
  vcov_est <- (vcov_est + t(vcov_est)) / 2

  # Unchanged from the per-bin form this replaces, and deliberately so: `se` is
  # the diagonal of the same quadratic form, with the same clamp.
  tol <- .Machine$double.eps^0.5 * max(1, abs(total)^2)
  se <- vapply(seq_len(h_n), function(h) {
    var_h <- vcov_est[h, h]
    if (!is.finite(var_h)) {
      return(NA_real_)
    }
    # A quadratic form in a PSD matrix is non-negative in exact arithmetic, so a
    # small negative is rounding noise and clamps to zero. Only a materially
    # negative value -- which would mean the covariance is not PSD -- becomes
    # NA, because that is a real problem and must not be reported as a zero SE.
    if (var_h < -tol) {
      return(NA_real_)
    }
    sqrt(max(var_h, 0))
  }, numeric(1))

  list(estimate = est, se = se, vcov = vcov_est)
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
