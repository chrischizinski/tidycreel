# Length distribution estimation ----

#' Estimate a weighted length distribution from creel interview data
#'
#' @description
#' `est_length_distribution()` estimates a pressure-weighted length-frequency
#' distribution from fish length data attached via [add_lengths()]. Unlike
#' [summarize_length_freq()], which reports raw sample frequencies,
#' `est_length_distribution()` aggregates interview-level bin counts through the
#' internal interview survey design so the result reflects the survey design
#' rather than only the observed sample.
#'
#' The estimator returns one row per occupied length bin, with weighted totals,
#' standard errors, confidence intervals, and within-group percentages.
#'
#' Lengths are measured on a **subsample** of the catch, so the bin totals are
#' scaled onto the design-estimated reported catch rather than reporting the
#' subsample itself. See the section below; the call warns whenever it rescales,
#' and aborts when the design carries no total to scale to.
#'
#' @param design A `creel_design` object with interviews and lengths attached.
#' @param type Character string indicating which fish to include. One of
#'   `"catch"` (default), `"harvest"`, or `"release"`.
#' @param by Optional tidy selector evaluated against `design$lengths`.
#'   Common choices include `by = species`.
#' @param bin_width Positive numeric bin width in the same units as the attached
#'   length data. Default `1`.
#' @param length_col Optional character column name in `design$lengths` to use
#'   for the length values. Defaults to the column registered by
#'   [add_lengths()].
#' @param variance Character string specifying variance estimation method.
#'   One of `"taylor"` (default), `"bootstrap"`, or `"jackknife"`.
#' @param conf_level Numeric confidence level for confidence intervals.
#'   Default `0.95`.
#'
#' @return A `data.frame` with class
#'   `c("creel_length_distribution", "data.frame")` and columns:
#'   grouping columns (if any), `length_bin` (ordered factor), `bin_lower`,
#'   `bin_upper`, `estimate`, `se`, `ci_lower`, `ci_upper`, `percent`,
#'   `cumulative_percent`, and `n`.
#'
#'   `percent` and `cumulative_percent` are shares of the group's estimated
#'   total, rounded to one decimal for display; `cumulative_percent`
#'   accumulates the unrounded shares, so it reaches 100 rather than drifting.
#'   The exception is a group whose estimated total is zero, where there are no
#'   shares to take and both columns are `0` rather than reaching 100.
#'
#'   `n` is the number of **interviews** contributing at least one measured
#'   fish to the group. It is therefore constant across every bin of a group,
#'   and is neither a per-bin sample size nor a count of fish.
#'
#' @examples
#' data(example_calendar)
#' data(example_interviews)
#' data(example_lengths)
#' data(example_catch)
#'
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status
#' )
#' # Species catch is required to group by species: the totals are scaled onto
#' # the reported catch, and only this table records it per species.
#' design <- add_catch(design, example_catch,
#'   catch_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   count = count,
#'   catch_type = catch_type
#' )
#' design <- add_lengths(design, example_lengths,
#'   length_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   length = length,
#'   length_type = length_type,
#'   count = count,
#'   release_format = "binned"
#' )
#'
#' est_length_distribution(design, by = species, bin_width = 25)
#'
#' @section Two-phase estimation onto the reported catch:
#' Lengths are a second-phase sample: interviews report how many fish were
#' caught, and some subset of those fish get measured. Expanding the measured
#' fish through the interview design alone estimates *the total number of fish
#' that happened to be measured*, which is not the catch — on this package's
#' example data it returns 14 against a reported harvest of 77. Because
#' [est_biomass()] multiplies these counts by weight-at-length and calls the
#' result total biomass, the error propagated to a headline number (GH #310).
#'
#' The estimator is therefore two-phase (double sampling, Cochran 1977 §12.9 —
#' the same structure used for the camera calibration ratio). For bin \eqn{h}:
#' \deqn{\hat{p}_h = \hat{N}_h^{\text{meas}} / \sum_j \hat{N}_j^{\text{meas}},
#'   \qquad \hat{N}_h = \hat{p}_h \hat{T}}
#' where \eqn{\hat{T}} is the design-estimated reported total for the group.
#' Both parts come from a single `svytotal()` call, so the covariance between a
#' bin and the reported total is estimated rather than assumed away, and the
#' standard error is the delta method over that joint covariance.
#'
#' What this changes: `estimate`, `se` and the confidence bounds now describe
#' the reported catch. `percent` and `cumulative_percent` are unchanged — a
#' share is invariant to the subsample size, which is why the *shape* of the
#' distribution was always correct and only its *level* was not.
#'
#' Where \eqn{\hat{T}} comes from depends on the grouping. A species group can
#' only be scaled by that species' own total, which lives in the table attached
#' by [add_catch()]; grouping by species without it is refused rather than
#' scaled by the all-species total. Any other grouping uses the interview-level
#' column (`catch` or `harvest` from [add_interviews()]), with release implied
#' as caught − harvested so that harvest and release sum back to catch.
#'
#' @family "Estimation"
#' @export
est_length_distribution <- function(
  design,
  type = "catch",
  by = NULL,
  bin_width = 1,
  length_col = NULL,
  variance = "taylor",
  conf_level = 0.95
) {
  by_quo <- rlang::enquo(by)

  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  if (is.null(design$interviews) || is.null(design$interview_survey)) {
    cli::cli_abort(c(
      "No interview survey available.",
      "x" = "Attach interviews with {.fn add_interviews} before estimating length distributions."
    ))
  }

  if (is.null(design[["lengths"]])) {
    cli::cli_abort(c(
      "No length data found in design.",
      "x" = "The design object has no length data.",
      "i" = "Attach length data with {.fn add_lengths}."
    ))
  }

  if (!is.numeric(bin_width) || length(bin_width) != 1L || bin_width <= 0) {
    cli::cli_abort(c(
      "{.arg bin_width} must be a single positive number.",
      "x" = "{.arg bin_width} is {.val {bin_width}}."
    ))
  }

  valid_methods <- c("taylor", "bootstrap", "jackknife")
  if (!variance %in% valid_methods) {
    cli::cli_abort(c(
      "Invalid variance method: {.val {variance}}",
      "x" = "Must be one of: {.val {valid_methods}}"
    ))
  }

  if (!is.numeric(conf_level) || length(conf_level) != 1L || conf_level <= 0 || conf_level >= 1) {
    # nolint: indentation_linter
    cli::cli_abort(c(
      "{.arg conf_level} must be a single number in (0, 1).",
      "x" = "{.arg conf_level} is {.val {conf_level}}."
    ))
  }

  type <- match.arg(type, choices = c("catch", "harvest", "release"))

  lengths_data <- design$lengths
  length_col_name <- if (is.null(length_col)) {
    design$lengths_length_col
  } else {
    if (!is.character(length_col) || length(length_col) != 1L) {
      cli::cli_abort("{.arg length_col} must be a single column name when provided.")
    }
    if (!length_col %in% names(lengths_data)) {
      cli::cli_abort(c(
        "Column {.field {length_col}} not found in attached length data.",
        "i" = "Available columns: {.field {names(lengths_data)}}"
      ))
    }
    length_col
  }

  if (rlang::quo_is_null(by_quo)) {
    by_vars <- character(0)
  } else {
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = lengths_data,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- screen_by_vars(
      names(by_cols), by_quo, lengths_data, design,
      extra_key_cols = design$lengths_uid_col,
      error_call = rlang::caller_env()
    )
  }

  records <- build_length_distribution_records(
    lengths_data = lengths_data,
    type = type,
    by_vars = by_vars,
    length_col = length_col_name,
    type_col = design$lengths_type_col,
    count_col = design$lengths_count_col,
    interview_uid_col = design$lengths_uid_col,
    release_format = design$lengths_release_format
  )

  if (nrow(records) == 0) {
    cli::cli_abort(c(
      "No length data found for {.arg type} = {.val {type}}.",
      "i" = "Check that {.fn add_lengths} included rows of this type."
    ))
  }

  max_len <- ceiling(max(records$.length_value) / bin_width) * bin_width
  breaks <- seq(0, max_len + bin_width, by = bin_width)
  bin_labels <- paste0("[", breaks[-length(breaks)], ",", breaks[-1], ")")
  records$length_bin <- cut(
    records$.length_value,
    breaks = breaks,
    labels = bin_labels,
    right = FALSE,
    include.lowest = TRUE
  )
  records$bin_lower <- breaks[as.integer(records$length_bin)]
  records$bin_upper <- records$bin_lower + bin_width

  ordered_labs <- bin_labels[bin_labels %in% as.character(unique(records$length_bin))]
  result_rows <- vector("list", 0)
  vcov_by_group <- vector("list", 0)
  base_interviews <- design$interviews
  uid_col <- design$lengths_interview_uid_col
  measured_total <- 0
  reported_total <- 0

  if (length(by_vars) == 0L) {
    group_indices <- list(seq_len(nrow(records)))
    group_values <- list(NULL)
  } else {
    # group_key(), not a private paste(), and named `record_keys` so it does not
    # shadow that function -- the attribute naming below calls it. R resolves a
    # symbol in call position to the nearest FUNCTION, so the shadowing was not
    # a bug, but a reader cannot tell that at a glance. Routing through the
    # helper also stops a group labelled "NA" colliding with an unknown one,
    # which here would hand one group another group's covariance matrix
    # (GH #248, GH #321).
    record_keys <- group_key(records, by_vars)
    split_idx <- split(seq_len(nrow(records)), record_keys)
    group_indices <- unname(split_idx)
    group_values <- lapply(group_indices, function(idx) records[idx[1], by_vars, drop = FALSE])
  }

  for (i in seq_along(group_indices)) {
    idx <- group_indices[[i]]
    group_records <- records[idx, , drop = FALSE]

    agg <- stats::aggregate(
      group_records$.fish_count,
      by = list(
        uid = group_records$.interview_uid,
        length_bin = group_records$length_bin,
        bin_lower = group_records$bin_lower,
        bin_upper = group_records$bin_upper
      ),
      FUN = sum
    )
    names(agg)[ncol(agg)] <- "bin_count"

    bin_order <- unique(agg[, c("length_bin", "bin_lower", "bin_upper"), drop = FALSE])
    bin_order <- bin_order[order(bin_order$bin_lower), , drop = FALSE]
    bin_col_names <- paste0(".bin_", seq_len(nrow(bin_order)))
    bin_lookup <- data.frame(
      length_bin = as.character(bin_order$length_bin),
      bin_lower = bin_order$bin_lower,
      bin_upper = bin_order$bin_upper,
      bin_col = bin_col_names,
      stringsAsFactors = FALSE
    )

    agg$bin_col <- bin_lookup$bin_col[match(as.character(agg$length_bin), bin_lookup$length_bin)]

    wide <- stats::reshape(
      agg[, c("uid", "bin_col", "bin_count")],
      idvar = "uid",
      timevar = "bin_col",
      direction = "wide"
    )
    names(wide) <- sub("^bin_count\\.", "", names(wide))
    names(wide)[names(wide) == "uid"] <- uid_col

    row_map <- match(base_interviews[[uid_col]], wide[[uid_col]])
    interviews_aug <- base_interviews
    for (col in bin_lookup$bin_col) {
      val <- wide[[col]][row_map]
      val[is.na(val)] <- 0L
      interviews_aug[[col]] <- val
    }

    # The reported total for this group is the second phase's scale factor. It
    # joins the bin columns in ONE svytotal() so their covariance is estimated
    # rather than assumed away (GH #310).
    group_total <- reported_total_per_interview( # nolint: object_usage_linter
      design, type, group_values[[i]], by_vars,
      frame_species_col = design[["lengths_species_col"]],
      error_call = rlang::caller_env()
    )
    if (is.null(group_total)) {
      cli::cli_abort(
        c(
          "Cannot rescale the length distribution onto the reported catch.",
          "x" = "No reported {type} count is available on this design.",
          "i" = "Lengths are measured on a subsample, so the bin totals mean
                 nothing without a total to scale them to.",
          # Release needs BOTH columns, not either: it is derived as
          # caught - harvested. And add_catch() only helps a species grouping --
          # an ungrouped request never consults design$catch.
          "i" = if (identical(type, "release")) {
            "Supply both {.arg catch} and {.arg harvest} to {.fn add_interviews}:
             release is derived as caught - harvested."
          } else if (length(by_vars) > 0L) {
            "Supply {.arg {type}} to {.fn add_interviews}, or attach species catch
             with {.fn add_catch} to group by species."
          } else {
            "Supply {.arg {type}} to {.fn add_interviews}."
          }
        ),
        class = "creel_error_no_rescale_total"
      )
    }
    interviews_aug$.group_total <- group_total

    temp_design <- rebuild_interview_survey(design, interviews_aug) # nolint: object_usage_linter
    svy_design <- get_variance_design(temp_design$interview_survey, variance) # nolint: object_usage_linter
    bin_formula <- stats::reformulate(c(bin_lookup$bin_col, ".group_total"))
    svy_result <- wrap_survey_call(survey::svytotal(bin_formula, svy_design)) # nolint: object_usage_linter

    all_est <- as.numeric(stats::coef(svy_result))
    v_all <- as.matrix(stats::vcov(svy_result))
    n_bins <- length(bin_lookup$bin_col)
    measured <- all_est[seq_len(n_bins)]
    reported <- all_est[n_bins + 1L]

    measured_total <- measured_total + sum(measured)
    reported_total <- reported_total + reported

    rescaled <- two_phase_rescale(measured, reported, v_all) # nolint: object_usage_linter
    estimates <- rescaled$estimate
    ses <- rescaled$se
    # Labelled by bin, not by position. Every consumer aligns its weight vector
    # to this matrix by `length_bin`, so a caller who reorders or drops rows
    # cannot silently pair a bin with another bin's variance (GH #311).
    group_vcov <- rescaled$vcov
    dimnames(group_vcov) <- list(bin_lookup$length_bin, bin_lookup$length_bin)
    vcov_by_group[[length(vcov_by_group) + 1L]] <- group_vcov

    z_ci <- stats::qnorm((1 + conf_level) / 2)
    cis <- cbind(estimates - z_ci * ses, estimates + z_ci * ses)

    group_df <- data.frame(
      length_bin = factor(
        bin_lookup$length_bin,
        levels = ordered_labs,
        ordered = TRUE
      ),
      bin_lower = bin_lookup$bin_lower,
      bin_upper = bin_lookup$bin_upper,
      estimate = estimates,
      se = ses,
      ci_lower = cis[, 1],
      ci_upper = cis[, 2],
      n = nrow(wide),
      stringsAsFactors = FALSE
    )

    total_est <- sum(group_df$estimate)
    if (isTRUE(all.equal(total_est, 0))) {
      group_df$percent <- 0
      group_df$cumulative_percent <- 0
    } else {
      # Accumulate on the unrounded shares, then round. Running cumsum() over
      # the already-rounded column compounds each bin's rounding error into
      # every later bin, so the final entry drifts off 100 -- 99.9 on the
      # package's own example data (GH #313).
      share <- group_df$estimate / total_est * 100
      group_df$percent <- round(share, 1)
      group_df$cumulative_percent <- round(cumsum(share), 1)
    }

    if (length(by_vars) > 0) {
      group_info <- group_values[[i]]
      for (v in by_vars) {
        group_df[[v]] <- group_info[[v]][1]
      }
      group_df <- group_df[,
        c(
          by_vars,
          "length_bin",
          "bin_lower",
          "bin_upper",
          "estimate",
          "se",
          "ci_lower",
          "ci_upper",
          "percent",
          "cumulative_percent",
          "n"
        ),
        drop = FALSE
      ]
    }

    result_rows[[length(result_rows) + 1L]] <- group_df
  }

  result <- do.call(rbind, result_rows)
  rownames(result) <- NULL

  warn_two_phase_rescale(measured_total, reported_total, "Length") # nolint: object_usage_linter

  class(result) <- c("creel_length_distribution", "data.frame")
  attr(result, "method") <- "length-distribution"
  attr(result, "variance_method") <- variance
  attr(result, "conf_level") <- conf_level
  attr(result, "by_vars") <- if (length(by_vars) > 0) by_vars else NULL
  attr(result, "type") <- type
  attr(result, "bin_width") <- bin_width
  # The subsample scale factor, so a caller can see what the totals were
  # multiplied by rather than inferring it. NULL is not possible here: the
  # function aborts above when no reported total is available.
  attr(result, "measured_total") <- measured_total
  attr(result, "reported_total") <- reported_total
  # The bins' full covariance, one matrix per reported group, keyed by the same
  # group key the consumers build. `svytotal()` estimates it and
  # `two_phase_rescale()` propagates it; before GH #311 it died here, and every
  # ratio consumer rebuilt a variance from the diagonal alone -- which made
  # `est_compliance()` report a standard error 32% below an independently
  # computed `survey::svyratio()` reference.
  #
  # An attribute rather than a column because it is one matrix per group, not
  # one value per row. That carries the GH #124 hazard -- `[.data.frame` drops
  # attributes -- so the consumers read it off the object they were HANDED,
  # before any row subsetting of their own, and say so out loud when it is
  # missing rather than falling back to independence in silence.
  names(vcov_by_group) <- if (length(by_vars) > 0L) {
    vapply(group_values, function(g) group_key(g, by_vars), character(1L))
  } else {
    ".all"
  }
  attr(result, "bin_vcov") <- vcov_by_group
  result
}

#' Build per-record data for length-distribution estimation
#'
#' @keywords internal
#' @noRd
build_length_distribution_records <- function(
  lengths_data, # nolint: object_length_linter
  type,
  by_vars,
  length_col,
  type_col,
  count_col,
  interview_uid_col,
  release_format
) {
  if (type == "harvest") {
    lengths_data <- lengths_data[lengths_data[[type_col]] == "harvest", , drop = FALSE]
  } else if (type == "release") {
    lengths_data <- lengths_data[lengths_data[[type_col]] == "release", , drop = FALSE]
  }

  harvest_rows <- lengths_data[lengths_data[[type_col]] == "harvest", , drop = FALSE]
  release_rows <- lengths_data[lengths_data[[type_col]] == "release", , drop = FALSE]

  build_rows <- function(rows, is_binned_release) {
    if (nrow(rows) == 0) {
      out <- data.frame(
        .interview_uid = numeric(0),
        .length_value = numeric(0),
        .fish_count = numeric(0),
        stringsAsFactors = FALSE
      )
      for (v in by_vars) {
        out[[v]] <- rows[[v]]
      }
      return(out)
    }

    if (is_binned_release) {
      parts <- strsplit(as.character(rows[[length_col]]), "-")
      lower_bounds <- suppressWarnings(
        as.numeric(vapply(parts, function(p) p[[1]], character(1)))
      )
      upper_bounds <- suppressWarnings(
        as.numeric(vapply(parts, function(p) p[[2]], character(1)))
      )
      if (any(is.na(lower_bounds)) || any(is.na(upper_bounds))) {
        cli::cli_abort(c(
          "Could not parse bin labels in release length data.",
          "i" = "Expected format: {.val '350-400'} (lower-upper separated by {.code -}).",
          "x" = "Check the {.arg length_col} values in your attached length data."
        ))
      }
      length_values <- (lower_bounds + upper_bounds) / 2
      fish_count <- as.numeric(rows[[count_col]])
    } else {
      length_values <- suppressWarnings(as.numeric(rows[[length_col]]))
      fish_count <- rep(1, nrow(rows))
    }

    if (any(is.na(length_values))) {
      cli::cli_abort(c(
        "Non-numeric length values found after parsing.",
        "i" = "Check that harvest/release individual lengths are numeric and release bins are parseable."
      ))
    }

    out <- data.frame(
      .interview_uid = rows[[interview_uid_col]],
      .length_value = length_values,
      .fish_count = fish_count,
      stringsAsFactors = FALSE
    )
    for (v in by_vars) {
      out[[v]] <- rows[[v]]
    }
    out
  }

  harvest_records <- build_rows(harvest_rows, is_binned_release = FALSE)
  release_records <- build_rows(
    release_rows,
    is_binned_release = (release_format == "binned" && nrow(release_rows) > 0)
  )

  rbind(harvest_records, release_records)
}

# Biomass estimation ----

#' Estimate total biomass from a creel length distribution
#'
#' @description
#' `est_biomass()` converts a pressure-weighted length-frequency distribution
#' produced by [est_length_distribution()] into a total biomass estimate using
#' the allometric length-weight equation \eqn{W = a \cdot L^b}.
#'
#' Variance is propagated via the delta method, carrying the **full covariance**
#' among the estimated fish counts per length bin and treating the length-weight
#' parameters `a` and `b` as known without error unless their standard errors
#' are supplied (see Details). Before GH #311 the bin counts were treated as
#' uncorrelated, which under-estimated the variance.
#'
#' Since GH #310 the counts supplied by [est_length_distribution()] describe the
#' **reported catch** rather than the measured subsample, so `biomass_estimate`
#' is a catch biomass. It previously described only the fish that were measured.
#'
#' @param ld A `creel_length_distribution` object from [est_length_distribution()].
#' @param a Positive numeric allometric coefficient (the \eqn{a} in
#'   \eqn{W = a \cdot L^b}).
#' @param b Numeric allometric exponent (the \eqn{b} in
#'   \eqn{W = a \cdot L^b}). Typical values for fish are 2.5–3.5.
#' @param conf_level Numeric confidence level for confidence intervals.
#'   Defaults to the level stored in `ld` (usually `0.95`).
#' @param alpha_se Optional standard error of the pivot coefficient
#'   \eqn{\alpha = a \cdot L_0^b}, i.e. the fitted intercept on the
#'   \eqn{\log W = \log \alpha + b (\log L - \log L_0)} scale.
#' @param b_se Optional standard error of the exponent `b`.
#' @param L0 Optional pivot length at which the regression was centred, in the
#'   same units as the bin boundaries. Use the geometric mean length of the
#'   length-weight calibration sample.
#'
#'   These three are all-or-nothing: give all of them to propagate the
#'   length-weight regression error, or none to keep the current behaviour.
#'   There is no zero default — see Details.
#'
#' @details
#' For each length bin h with midpoint \eqn{L_h = (\text{bin\_lower} +
#' \text{bin\_upper}) / 2}, per-bin biomass is
#' \eqn{B_h = a \cdot L_h^b \cdot \hat{N}_h}, where \eqn{\hat{N}_h} is the
#' survey-weighted estimated fish count from [est_length_distribution()].
#' Total biomass is \eqn{B = \sum_h B_h}.
#'
#' Variance is the quadratic form
#' \eqn{\widehat{\text{Var}}(B) = w' \Sigma w} with \eqn{w_h = a \cdot L_h^b}
#' and \eqn{\Sigma} the bins' full covariance matrix, carried from the single
#' `svytotal()` that estimated them. Earlier versions used
#' \eqn{\sum_h w_h^2 \widehat{\text{SE}}_h^2} — the same expression with every
#' off-diagonal set to zero — which under-estimated the variance, since the bins
#' partition the same fish and are rescaled onto one reported total.
#'
#' If \eqn{\Sigma} is unavailable — the object was produced by an older version,
#' or was subsetted in a way that dropped the attribute carrying it — the
#' independence form is used and a warning says so. An absent covariance is
#' unknown, not zero.
#'
#' By default `a` and `b` are treated as known constants, so `biomass_se`
#' carries no contribution from their estimation error. In practice they are
#' point estimates from a length-weight regression, often one fitted to a
#' different water body or year. Because \eqn{a \cdot L_h^b} multiplies every
#' bin, that error is perfectly correlated across bins and does not shrink as
#' bins are added — unlike the cross-bin term above.
#'
#' The omission is usually minor relative to count variance: on the example
#' below it adds roughly 2–11% to a coefficient of variation of 40–65%, for
#' regression standard errors spanning well- and poorly-determined fits. It
#' becomes material in two situations — a survey precise enough to bring the
#' count CV near 10%, and `a`/`b` borrowed from a system whose fish differ in
#' size from those measured here, since the contribution scales with the
#' distance between the two samples' mean log lengths.
#'
#' @section Propagating the length-weight regression error:
#' Supply `alpha_se`, `b_se`, and `L0` together to carry that term. The
#' allometry is rewritten about a pivot length \eqn{L_0}:
#' \deqn{W = \alpha \left(\frac{L}{L_0}\right)^b, \qquad \alpha = a L_0^b}
#' and the delta method is applied in \eqn{(\alpha, b)}:
#' \deqn{\widehat{\text{Var}}(B) \approx \sum_h (a L_h^b)^2 \widehat{\text{SE}}_h^2
#'   + \left(\frac{B}{\alpha}\right)^2 \text{Var}(\alpha)
#'   + \left(\sum_h B_h \ln\frac{L_h}{L_0}\right)^2 \text{Var}(b)}
#'
#' The covariance term is absent by construction rather than by assumption.
#' Fitted on the raw \eqn{(a, b)} scale the two parameters are almost perfectly
#' negatively correlated — typically \eqn{\text{cor} < -0.99} — so dropping
#' their covariance there would **overstate** the variance severalfold, in some
#' cases turning a 2–11% contribution into 5–49%. Centring at \eqn{L_0} makes
#' them near-orthogonal, so the omitted term is genuinely negligible. Take
#' \eqn{L_0} as the geometric mean length of the calibration sample, and take
#' `alpha_se` from the intercept of a regression centred there — not the
#' standard error of `a` itself.
#'
#' The contribution grows with \eqn{\ln(L_h / L_0)}, so borrowing parameters
#' from a system whose fish differ in size from these is penalised
#' automatically, which is the intended behaviour.
#'
#' There is deliberately no zero default for these arguments. A zero standard
#' error would produce a `biomass_se` identical to an unpropagated one while
#' appearing to have been propagated — worse than the documented omission it
#' would replace. When they are absent, `attr(x, "biomass_se_params")` is `NULL`
#' rather than `0`, and `biomass_se` should be read as a lower bound.
#'
#' Length and weight units are determined by the user: if lengths are in mm
#' and `a` is calibrated for mm input, weights are returned in the
#' corresponding unit (e.g., grams).
#'
#' @return A `data.frame` with class `c("creel_biomass", "data.frame")` and
#'   columns: grouping columns (if any), `biomass_estimate`, `biomass_se`,
#'   `biomass_ci_lower`, `biomass_ci_upper`.
#'
#' @examples
#' data(example_calendar)
#' data(example_interviews)
#' data(example_lengths)
#' data(example_catch)
#'
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status
#' )
#' # Species catch is required to group by species: the totals are scaled onto
#' # the reported catch, and only this table records it per species.
#' design <- add_catch(design, example_catch,
#'   catch_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   count = count,
#'   catch_type = catch_type
#' )
#' design <- add_lengths(design, example_lengths,
#'   length_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   length = length,
#'   length_type = length_type,
#'   count = count,
#'   release_format = "binned"
#' )
#'
#' ld <- est_length_distribution(design, by = species, bin_width = 25)
#' est_biomass(ld, a = 0.0088, b = 3.1)
#'
#' @family "Estimation"
#' @export
est_biomass <- function(ld, a, b, conf_level = NULL, alpha_se = NULL, b_se = NULL, L0 = NULL) { # nolint: object_name_linter, line_length_linter
  if (!inherits(ld, "creel_length_distribution")) {
    cli::cli_abort(c(
      "{.arg ld} must be a {.cls creel_length_distribution} object.",
      "x" = "{.arg ld} is {.cls {class(ld)[1]}}.",
      "i" = "Create one with {.fn est_length_distribution}."
    ))
  }
  if (!is.numeric(a) || length(a) != 1L || is.na(a) || a <= 0) {
    cli::cli_abort(c(
      "{.arg a} must be a single positive number.",
      "x" = "{.arg a} is {.val {a}}."
    ))
  }
  if (!is.numeric(b) || length(b) != 1L || is.na(b)) {
    cli::cli_abort(c(
      "{.arg b} must be a single numeric value.",
      "x" = "{.arg b} is {.val {b}}."
    ))
  }

  ld_conf <- attr(ld, "conf_level")
  if (is.null(conf_level)) {
    conf_level <- if (!is.null(ld_conf)) ld_conf else 0.95
  } else {
    if (!is.numeric(conf_level) || length(conf_level) != 1L || conf_level <= 0 || conf_level >= 1) {
      # nolint: indentation_linter
      cli::cli_abort(c(
        "{.arg conf_level} must be a single number in (0, 1).",
        "x" = "{.arg conf_level} is {.val {conf_level}}."
      ))
    }
  }

  params <- validate_lw_uncertainty(alpha_se, b_se, L0) # nolint: object_usage_linter

  by_vars <- attr(ld, "by_vars")
  if (is.null(by_vars)) {
    by_vars <- character(0)
  }

  # Normal quantile rather than t: the SE below is propagated from the length
  # distribution's per-bin SEs, so there is no local sample size to key degrees
  # of freedom to. See ?creel_confidence_intervals.
  z <- stats::qnorm((1 + conf_level) / 2)

  se_params <- if (is.null(params)) NULL else numeric(0)

  compute_biomass <- function(rows, key) {
    l_mid <- (rows$bin_lower + rows$bin_upper) / 2
    w_h <- a * l_mid^b
    biomass <- sum(w_h * rows$estimate)
    # Biomass is a weighted SUM of the bin totals rather than a ratio of them,
    # but its variance is the same quadratic form in the same weights, and the
    # cross-bin terms belong in it for the same reason (GH #311). This was the
    # one consumer that documented the omission; it is now no longer an
    # omission, and the documentation says so instead.
    var_counts <- weighted_bin_var(w_h, rows, bin_vcov_for(ld, rows, key), "biomass_se")

    # Length-weight parameter error, on the pivot parameterisation
    # W = alpha * (L / L0)^b with alpha = a * L0^b. Both partials are taken at
    # L0, where the two parameters are near-uncorrelated, which is what makes
    # omitting their covariance defensible rather than a hidden error (GH #117).
    var_params <- 0
    if (!is.null(params)) {
      alpha <- a * params$L0^b
      bin_biomass <- w_h * rows$estimate
      d_alpha <- biomass / alpha
      d_b <- sum(bin_biomass * log(l_mid / params$L0))
      var_params <- d_alpha^2 * params$alpha_se^2 + d_b^2 * params$b_se^2
    }

    se_b <- sqrt(var_counts + var_params)
    if (!is.null(params)) {
      se_params <<- c(se_params, sqrt(var_params))
    }
    data.frame(
      biomass_estimate = biomass,
      biomass_se = se_b,
      biomass_ci_lower = biomass - z * se_b,
      biomass_ci_upper = biomass + z * se_b,
      stringsAsFactors = FALSE
    )
  }

  if (length(by_vars) == 0L) {
    result <- compute_biomass(ld, ".all")
  } else {
    # See est_compliance(): group_key(), not a private paste().
    row_keys <- group_key(ld, by_vars)
    groups <- unique(row_keys)
    result_rows <- vector("list", length(groups))
    for (i in seq_along(groups)) {
      rows <- ld[row_keys == groups[[i]], , drop = FALSE]
      group_info <- rows[1L, by_vars, drop = FALSE]
      result_rows[[i]] <- cbind(
        group_info,
        compute_biomass(rows, groups[[i]]),
        row.names = NULL
      )
    }
    result <- do.call(rbind, result_rows)
  }

  rownames(result) <- NULL
  class(result) <- c("creel_biomass", "data.frame")
  attr(result, "method") <- "biomass"
  attr(result, "a") <- a
  attr(result, "b") <- b
  attr(result, "conf_level") <- conf_level
  attr(result, "by_vars") <- if (length(by_vars) > 0L) by_vars else NULL
  # NULL, not zero, when no regression uncertainty was supplied. A zero would
  # read as "the length-weight parameters were propagated and contributed
  # nothing", which is exactly the claim this function must not make silently.
  attr(result, "biomass_se_params") <- se_params
  attr(result, "L0") <- if (is.null(params)) NULL else params$L0
  result
}


#' Validate optional length-weight regression uncertainty
#'
#' Internal helper. The three arguments are all-or-nothing on purpose. Supplying
#' `alpha_se` and `b_se` without `L0` would leave the pivot undefined, and the
#' covariance between the two parameters could then only be dropped by
#' assumption rather than by construction -- which is the error the pivot
#' parameterisation exists to avoid. Supplying `L0` alone propagates nothing.
#'
#' There is deliberately no zero default. A zero standard error yields a biomass
#' standard error identical to an unpropagated one while appearing propagated,
#' which is strictly worse than the documented omission it would replace.
#'
#' @param alpha_se Standard error of the pivot coefficient, or NULL
#' @param b_se Standard error of the exponent, or NULL
#' @param L0 Pivot length, or NULL
#' @param error_call Calling environment for error reporting
#'
#' @return `NULL` when all three are absent; otherwise a list with `alpha_se`,
#'   `b_se`, and `L0`
#'
#' @keywords internal
#' @noRd
validate_lw_uncertainty <- function(alpha_se, b_se, L0, error_call = rlang::caller_env()) { # nolint: object_name_linter
  supplied <- c(alpha = !is.null(alpha_se), b = !is.null(b_se), L0 = !is.null(L0))

  if (!any(supplied)) {
    return(NULL)
  }
  if (!all(supplied)) {
    missing_args <- c(alpha = "alpha_se", b = "b_se", L0 = "L0")[!supplied] # nolint: object_usage_linter
    cli::cli_abort(
      c(
        "{.arg alpha_se}, {.arg b_se} and {.arg L0} must be given together.",
        "x" = "Missing: {.arg {unname(missing_args)}}.",
        "i" = "The pivot {.arg L0} is what makes the two parameters near-uncorrelated, \\
               so the covariance between them can be dropped by construction.",
        "i" = "Without all three the length-weight error cannot be propagated honestly, \\
               and a partial term would understate it."
      ),
      call = error_call
    )
  }

  check_scalar <- function(x, nm, positive) {
    if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x)) {
      cli::cli_abort(
        c(
          "{.arg {nm}} must be a single finite number.",
          "x" = "{.arg {nm}} is {.val {x}}."
        ),
        call = error_call
      )
    }
    if (positive && x <= 0) {
      cli::cli_abort(
        c(
          "{.arg {nm}} must be greater than zero.",
          "x" = "{.arg {nm}} is {.val {x}}."
        ),
        call = error_call
      )
    }
    if (!positive && x < 0) {
      cli::cli_abort(
        c(
          "{.arg {nm}} must not be negative.",
          "x" = "{.arg {nm}} is {.val {x}}."
        ),
        call = error_call
      )
    }
  }

  check_scalar(alpha_se, "alpha_se", positive = FALSE)
  check_scalar(b_se, "b_se", positive = FALSE)
  check_scalar(L0, "L0", positive = TRUE)

  list(alpha_se = alpha_se, b_se = b_se, L0 = L0)
}

# Mean length estimation ----

#' Estimate design-weighted mean length from a creel length distribution
#'
#' @description
#' `est_mean_length()` computes the pressure-weighted mean fish length from a
#' [est_length_distribution()] object using the ratio estimator
#' \eqn{\bar{L} = \sum_h L_h \hat{N}_h / \sum_h \hat{N}_h}, with
#' delta-method standard error.
#'
#' @param ld A `creel_length_distribution` object from [est_length_distribution()].
#' @param conf_level Numeric confidence level for confidence intervals.
#'   Defaults to the level stored in `ld` (usually `0.95`).
#'
#' @details
#' Bin midpoints \eqn{L_h = (\text{bin\_lower} + \text{bin\_upper}) / 2} serve
#' as representative lengths. Mean length is the ratio of total length-weighted
#' count to total count:
#' \deqn{\bar{L} = \frac{\sum_h L_h \hat{N}_h}{\hat{N}}}
#'
#' Variance is propagated via the delta method for a ratio estimator, using the
#' bins' full covariance matrix \eqn{\Sigma}:
#' \deqn{\widehat{\text{Var}}(\bar{L}) =
#'   \frac{1}{\hat{N}^2} w' \Sigma w, \quad w_h = L_h - \bar{L}}
#' Earlier versions treated the cross-bin covariances as zero, which
#' under-estimated the standard error. If \eqn{\Sigma} is unavailable the
#' independence form is used and a warning says so.
#'
#' @return A `data.frame` with class `c("creel_mean_length", "data.frame")` and
#'   columns: grouping columns (if any), `mean_length`, `mean_length_se`,
#'   `mean_length_ci_lower`, `mean_length_ci_upper`. Rows where the total
#'   estimated fish is zero or negative return `NA` for all numeric columns
#'   with a warning.
#'
#' @examples
#' data(example_calendar)
#' data(example_interviews)
#' data(example_lengths)
#' data(example_catch)
#'
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status
#' )
#' # Species catch is required to group by species: the totals are scaled onto
#' # the reported catch, and only this table records it per species.
#' design <- add_catch(design, example_catch,
#'   catch_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   count = count,
#'   catch_type = catch_type
#' )
#' design <- add_lengths(design, example_lengths,
#'   length_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   length = length,
#'   length_type = length_type,
#'   count = count,
#'   release_format = "binned"
#' )
#'
#' ld <- est_length_distribution(design, by = species, bin_width = 25)
#' est_mean_length(ld)
#'
#' @family "Estimation"
#' @export
est_mean_length <- function(ld, conf_level = NULL) {
  if (!inherits(ld, "creel_length_distribution")) {
    cli::cli_abort(c(
      "{.arg ld} must be a {.cls creel_length_distribution} object.",
      "x" = "{.arg ld} is {.cls {class(ld)[1]}}.",
      "i" = "Create one with {.fn est_length_distribution}."
    ))
  }

  ld_conf <- attr(ld, "conf_level")
  if (is.null(conf_level)) {
    conf_level <- if (!is.null(ld_conf)) ld_conf else 0.95
  } else {
    if (!is.numeric(conf_level) || length(conf_level) != 1L || conf_level <= 0 || conf_level >= 1) {
      # nolint: indentation_linter
      cli::cli_abort(c(
        "{.arg conf_level} must be a single number in (0, 1).",
        "x" = "{.arg conf_level} is {.val {conf_level}}."
      ))
    }
  }

  by_vars <- attr(ld, "by_vars")
  if (is.null(by_vars)) {
    by_vars <- character(0)
  }
  # Normal quantile rather than t: the SE below is propagated from the length
  # distribution's per-bin SEs, so there is no local sample size to key degrees
  # of freedom to. See ?creel_confidence_intervals.
  z <- stats::qnorm((1 + conf_level) / 2)

  compute_mean_length <- function(rows, key) {
    l_mid <- (rows$bin_lower + rows$bin_upper) / 2
    n_total <- sum(rows$estimate)
    if (n_total <= 0) {
      cli::cli_warn("Total estimated fish is zero or negative; mean length cannot be computed.")
      return(data.frame(
        mean_length = NA_real_,
        mean_length_se = NA_real_,
        mean_length_ci_lower = NA_real_,
        mean_length_ci_upper = NA_real_,
        stringsAsFactors = FALSE
      ))
    }
    mean_l <- sum(l_mid * rows$estimate) / n_total
    # Same ratio delta method as est_compliance(), with the bin midpoint in
    # place of the legality indicator, and taken against the bins' full
    # covariance rather than its diagonal (GH #311).
    w <- l_mid - mean_l
    se_l <- sqrt(weighted_bin_var(w, rows, bin_vcov_for(ld, rows, key), "mean_length_se")) /
      n_total
    data.frame(
      mean_length = mean_l,
      mean_length_se = se_l,
      mean_length_ci_lower = mean_l - z * se_l,
      mean_length_ci_upper = mean_l + z * se_l,
      stringsAsFactors = FALSE
    )
  }

  if (length(by_vars) == 0L) {
    result <- compute_mean_length(ld, ".all")
  } else {
    # See est_compliance(): group_key(), not a private paste().
    row_keys <- group_key(ld, by_vars)
    groups <- unique(row_keys)
    result_rows <- vector("list", length(groups))
    for (i in seq_along(groups)) {
      rows <- ld[row_keys == groups[[i]], , drop = FALSE]
      group_info <- rows[1L, by_vars, drop = FALSE]
      result_rows[[i]] <- cbind(
        group_info,
        compute_mean_length(rows, groups[[i]]),
        row.names = NULL
      )
    }
    result <- do.call(rbind, result_rows)
  }

  rownames(result) <- NULL
  class(result) <- c("creel_mean_length", "data.frame")
  attr(result, "method") <- "mean_length"
  attr(result, "conf_level") <- conf_level
  attr(result, "by_vars") <- if (length(by_vars) > 0L) by_vars else NULL
  result
}

# Cross-bin covariance for the ratio consumers (GH #311) ----

#' The bins' covariance matrix for one reported group
#'
#' Internal. `est_length_distribution()` attaches the rescaled bins' full
#' covariance as an attribute, one matrix per reported group. This reads the
#' block for `rows` and aligns it to them BY BIN LABEL, so a caller who
#' reordered or dropped rows cannot pair a bin with another bin's variance.
#'
#' Returns `NULL` rather than a substitute whenever the matrix cannot be
#' produced for these exact rows -- the object predates the attribute, was
#' subsetted with `[` (which drops attributes, GH #124), or carries a bin the
#' matrix does not name. The caller says so out loud; an absent covariance is
#' unknown, not zero, and the whole point of #311 is that assuming zero is the
#' defect.
#'
#' @param ld The `creel_length_distribution` as HANDED to the consumer, before
#'   any row subsetting of its own.
#' @param rows The subset of rows the statistic is being computed over.
#' @param key The group key for `rows`, or `".all"` when ungrouped.
#'
#' @return A square covariance matrix ordered like `rows`, or `NULL`.
#'
#' @keywords internal
#' @noRd
bin_vcov_for <- function(ld, rows, key) {
  mats <- attr(ld, "bin_vcov")
  if (is.null(mats) || is.null(mats[[key]])) {
    return(NULL)
  }
  m <- mats[[key]]
  labs <- as.character(rows$length_bin)
  if (anyNA(labs) || !all(labs %in% rownames(m))) {
    return(NULL)
  }
  m[labs, labs, drop = FALSE]
}


#' A weighted variance over the bins, using their covariance
#'
#' Internal. Every ratio the length path reports -- a compliance proportion, a
#' mean length, a total biomass -- is a weighted sum of the bin totals, so its
#' variance is the quadratic form \eqn{w' \Sigma w} in the same weights.
#'
#' Each consumer used \eqn{\sum_h w_h^2 \widehat{SE}_h^2} instead, which is
#' that form with every off-diagonal set to zero. The bins are a partition of
#' the same fish, rescaled onto a single reported total, so they are strongly
#' dependent and those terms are not a rounding detail: on the package's own
#' example data `est_compliance()` reported a standard error **32% below** an
#' independently computed `survey::svyratio()` reference (GH #311).
#'
#' When the covariance is unavailable the independence form is used and a
#' warning names it as an approximation rather than the estimator.
#'
#' @param w Numeric weight per row of `rows`.
#' @param rows The bin rows the statistic covers.
#' @param sigma Covariance matrix from [bin_vcov_for()], or `NULL`.
#' @param what Character, the statistic being computed, for the warning.
#'
#' @return A single non-negative variance.
#'
#' @keywords internal
#' @noRd
weighted_bin_var <- function(w, rows, sigma, what) {
  if (is.null(sigma)) {
    cli::cli_warn(
      c(
        "Cross-bin covariance is unavailable; {.val {what}} assumes the bins
         are independent.",
        "x" = "The reported standard error is an approximation and is likely
               too SMALL -- the bins partition the same fish.",
        "i" = "This happens when the length distribution was subsetted with
               {.code [} , which drops the attribute carrying the covariance,
               or was built by an older version.",
        "i" = "Pass the object returned by {.fn est_length_distribution}
               directly, and use {.arg by} rather than subsetting it."
      ),
      class = "creel_warning_bin_vcov_unavailable"
    )
    return(sum(w^2 * rows$se^2))
  }
  v <- as.numeric(t(w) %*% sigma %*% w)
  if (!is.finite(v)) {
    return(NA_real_)
  }
  # Same clamp as two_phase_rescale(): a quadratic form in a PSD matrix is
  # non-negative in exact arithmetic, so a small negative is rounding noise.
  tol <- .Machine$double.eps^0.5 * max(1, abs(v))
  if (v < -tol) {
    return(NA_real_)
  }
  max(v, 0)
}


# Compliance estimation ----

#' Estimate design-weighted size-limit compliance from a creel length distribution
#'
#' @description
#' `est_compliance()` estimates the proportion of fish meeting a minimum size
#' limit from a [est_length_distribution()] object.  Fish in bins whose lower
#' bound is at or above `min_length` are classified as legal (conservative:
#' bins straddling the limit are classified as illegal).
#'
#' @param ld A `creel_length_distribution` object from [est_length_distribution()].
#' @param min_length Positive numeric minimum legal length in the same units as
#'   the lengths used to build `ld`.
#' @param conf_level Numeric confidence level for confidence intervals.
#'   Defaults to the level stored in `ld` (usually `0.95`).
#'
#' @details
#' A bin is legal when `bin_lower >= min_length`.  The compliance proportion
#' and its variance use the ratio estimator:
#' \deqn{P = \frac{\sum_h I_h \hat{N}_h}{\hat{N}}}
#' \deqn{\widehat{\text{Var}}(P) =
#'   \frac{1}{\hat{N}^2} w' \Sigma w, \quad w_h = I_h - P}
#' where \eqn{I_h = \mathbf{1}(\text{bin\_lower}_h \geq \text{min\_length})}
#' and \eqn{\Sigma} is the bins' full covariance matrix, carried from the
#' single `svytotal()` that estimated them.
#'
#' Earlier versions used \eqn{\sum_h w_h^2 \widehat{\text{SE}}_h^2} — the same
#' expression with every off-diagonal set to zero. The bins partition the same
#' fish and are rescaled onto one reported total, so they are strongly
#' dependent, and on the package's own example data that form reported a
#' standard error **32% below** an independently computed
#' `survey::svyratio()` reference. If \eqn{\Sigma} is unavailable the
#' independence form is used and a warning says so.
#'
#' Confidence interval bounds are clamped to \eqn{[0, 1]}.
#'
#' Choose `bin_width` in [est_length_distribution()] smaller than the typical
#' variation near the legal limit to minimise classification error for bins
#' that straddle the threshold.
#'
#' @return A `data.frame` with class `c("creel_compliance", "data.frame")` and
#'   columns: grouping columns (if any), `min_length`, `n_legal_est`,
#'   `n_total_est`, `compliance_prop`, `compliance_se`,
#'   `compliance_ci_lower`, `compliance_ci_upper`. Rows where the total
#'   estimated fish is zero or negative return `NA` for all numeric columns
#'   with a warning.
#'
#' @examples
#' data(example_calendar)
#' data(example_interviews)
#' data(example_lengths)
#' data(example_catch)
#'
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status
#' )
#' # Species catch is required to group by species: the totals are scaled onto
#' # the reported catch, and only this table records it per species.
#' design <- add_catch(design, example_catch,
#'   catch_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   count = count,
#'   catch_type = catch_type
#' )
#' design <- add_lengths(design, example_lengths,
#'   length_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   length = length,
#'   length_type = length_type,
#'   count = count,
#'   release_format = "binned"
#' )
#'
#' ld <- est_length_distribution(design, by = species, bin_width = 25)
#' est_compliance(ld, min_length = 356)  # 14-inch limit in mm
#'
#' @family "Estimation"
#' @export
est_compliance <- function(ld, min_length, conf_level = NULL) {
  if (!inherits(ld, "creel_length_distribution")) {
    cli::cli_abort(c(
      "{.arg ld} must be a {.cls creel_length_distribution} object.",
      "x" = "{.arg ld} is {.cls {class(ld)[1]}}.",
      "i" = "Create one with {.fn est_length_distribution}."
    ))
  }
  if (!is.numeric(min_length) || length(min_length) != 1L || is.na(min_length) || min_length <= 0) {
    # nolint: indentation_linter
    cli::cli_abort(c(
      "{.arg min_length} must be a single positive number.",
      "x" = "{.arg min_length} is {.val {min_length}}."
    ))
  }

  ld_conf <- attr(ld, "conf_level")
  if (is.null(conf_level)) {
    conf_level <- if (!is.null(ld_conf)) ld_conf else 0.95
  } else {
    if (!is.numeric(conf_level) || length(conf_level) != 1L || conf_level <= 0 || conf_level >= 1) {
      # nolint: indentation_linter
      cli::cli_abort(c(
        "{.arg conf_level} must be a single number in (0, 1).",
        "x" = "{.arg conf_level} is {.val {conf_level}}."
      ))
    }
  }

  by_vars <- attr(ld, "by_vars")
  if (is.null(by_vars)) {
    by_vars <- character(0)
  }
  # Normal quantile rather than t: the SE below is propagated from the length
  # distribution's per-bin SEs, so there is no local sample size to key degrees
  # of freedom to. See ?creel_confidence_intervals.
  z <- stats::qnorm((1 + conf_level) / 2)

  compute_compliance <- function(rows, key) {
    legal <- rows$bin_lower >= min_length
    n_legal <- sum(rows$estimate[legal])
    n_total <- sum(rows$estimate)
    if (n_total <= 0) {
      cli::cli_warn("Total estimated fish is zero or negative; compliance proportion cannot be computed.")
      return(data.frame(
        min_length = min_length,
        n_legal_est = NA_real_,
        n_total_est = NA_real_,
        compliance_prop = NA_real_,
        compliance_se = NA_real_,
        compliance_ci_lower = NA_real_,
        compliance_ci_upper = NA_real_,
        stringsAsFactors = FALSE
      ))
    }
    p <- n_legal / n_total
    # The delta method for the ratio P = sum_h I_h N_h / sum_h N_h, whose
    # gradient in N_h is (I_h - P) / N. Taken against the bins' FULL
    # covariance: the independence form this replaces is the same expression
    # with every off-diagonal zeroed, and the bins are a partition of the same
    # fish rescaled onto one reported total, so they are anything but
    # independent (GH #311).
    w <- as.numeric(legal) - p
    se_p <- sqrt(weighted_bin_var(w, rows, bin_vcov_for(ld, rows, key), "compliance_se")) /
      n_total
    data.frame(
      min_length = min_length,
      n_legal_est = n_legal,
      n_total_est = n_total,
      compliance_prop = p,
      compliance_se = se_p,
      compliance_ci_lower = pmax(0, p - z * se_p),
      compliance_ci_upper = pmin(1, p + z * se_p),
      stringsAsFactors = FALSE
    )
  }

  if (length(by_vars) == 0L) {
    result <- compute_compliance(ld, ".all")
  } else {
    # group_key(), not a private paste(): a paste renders a missing value as the
    # literal string "NA", so an unknown group and a group labelled "NA" would
    # share a key -- and here that would also hand one group another group's
    # covariance matrix (GH #248, GH #321).
    row_keys <- group_key(ld, by_vars)
    groups <- unique(row_keys)
    result_rows <- vector("list", length(groups))
    for (i in seq_along(groups)) {
      rows <- ld[row_keys == groups[[i]], , drop = FALSE]
      group_info <- rows[1L, by_vars, drop = FALSE]
      result_rows[[i]] <- cbind(
        group_info,
        compute_compliance(rows, groups[[i]]),
        row.names = NULL
      )
    }
    result <- do.call(rbind, result_rows)
  }

  rownames(result) <- NULL
  class(result) <- c("creel_compliance", "data.frame")
  attr(result, "method") <- "compliance"
  attr(result, "min_length") <- min_length
  attr(result, "conf_level") <- conf_level
  attr(result, "by_vars") <- if (length(by_vars) > 0L) by_vars else NULL
  result
}
