# Bus-route effort estimation ----
# Implements Jones & Pollock (2012) Eq. 19.4: E_hat = sum(e_i / pi_i)
# where e_i = raw_effort * expansion (enumeration expansion factor)
# Called by estimate_effort() when design$design_type == "bus_route"

#' Bus-route Horvitz-Thompson effort estimator
#'
#' Internal function implementing Jones & Pollock (2012) Eq. 19.4.
#' Called by estimate_effort() after bus-route dispatch.
#'
#' @param design A creel_design object with bus-route interviews attached
#' @param by_vars NULL or character vector of grouping variable names
#' @param variance_method Character string: "taylor", "bootstrap", or "jackknife"
#' @param conf_level Numeric confidence level (0-1)
#' @param verbose Logical. If TRUE, prints informational message about estimator
#'
#' @return A creel_estimates object with site_contributions attribute
#'
#' @keywords internal
#' @noRd
estimate_effort_br <- function(design, by_vars, variance_method, conf_level, verbose) { # nolint: object_usage_linter
  # Retrieve interview data (contains .pi_i and .expansion from add_interviews())
  interviews <- design$interviews

  # Defensive check: .expansion column must exist
  if (!".expansion" %in% names(interviews)) {
    cli::cli_abort(c(
      "Bus-route effort estimation requires .expansion column.",
      "x" = ".expansion not found in interview data.",
      "i" = paste0(
        "Call {.fn add_interviews} with {.arg n_counted} and {.arg n_interviewed} parameters."
      )
    ))
  }

  # Defensive check: .pi_i column must exist
  if (!".pi_i" %in% names(interviews)) {
    cli::cli_abort(c(
      "Bus-route effort estimation requires .pi_i column.",
      "x" = ".pi_i not found in interview data.",
      "i" = "Bus-route design must have inclusion probabilities computed via sampling frame."
    ))
  }

  # Check for missing .pi_i values — hard error listing site+circuit combinations
  if (any(is.na(interviews$.pi_i))) {
    bad_rows <- interviews[is.na(interviews$.pi_i), ]
    site_col <- design$bus_route$site_col
    circuit_col <- design$bus_route$circuit_col
    combos <- unique(bad_rows[c(site_col, circuit_col)])
    n_combos <- nrow(combos) # nolint: object_usage_linter
    combo_strs <- apply(combos, 1, function(r) {
      paste0(site_col, "=", r[[site_col]], ", ", circuit_col, "=", r[[circuit_col]])
    })
    msg_parts <- stats::setNames(combo_strs, rep("*", length(combo_strs)))
    cli::cli_abort(c(
      "Missing inclusion probability (.pi_i) for {n_combos} site+circuit combination{?s}:",
      msg_parts,
      "x" = "All interview site+circuit combinations must appear in the sampling frame.",
      "i" = "Check that interview data site and circuit values match sampling frame."
    ))
  }

  # Identify the effort column stored during add_interviews()
  effort_col <- design$effort_col

  # Compute enumeration-expanded effort per interview row (Jones & Pollock Eq. 19.4)
  # NA expansion with n_counted=0, n_interviewed=0: treat e_i as 0 (zero-effort site)
  interviews$.e_i <- interviews[[effort_col]] * interviews$.expansion

  # Replace NA .e_i where n_counted=0 AND n_interviewed=0 with 0
  n_counted_col <- design$n_counted_col
  n_interviewed_col <- design$n_interviewed_col
  if (!is.null(n_counted_col) && !is.null(n_interviewed_col)) {
    zero_effort_mask <- !is.na(interviews[[n_counted_col]]) &
      interviews[[n_counted_col]] == 0 &
      !is.na(interviews[[n_interviewed_col]]) &
      interviews[[n_interviewed_col]] == 0
    interviews$.e_i[zero_effort_mask] <- 0
  }

  # Compute e_i / pi_i (Eq. 19.4 site contribution)
  interviews$.contribution <- interviews$.e_i / interviews$.pi_i

  # Build per-site attribution table for attribute storage
  site_col <- design$bus_route$site_col
  circuit_col <- design$bus_route$circuit_col
  site_table <- interviews[c(site_col, circuit_col, ".e_i", ".pi_i", ".contribution")]
  names(site_table)[names(site_table) == ".e_i"] <- "e_i"
  names(site_table)[names(site_table) == ".pi_i"] <- "pi_i"
  names(site_table)[names(site_table) == ".contribution"] <- "e_i_over_pi_i"

  # Compute the HT estimate: E_hat = sum(e_i / pi_i)
  if (is.null(by_vars)) {
    # Ungrouped: single total
    total_estimate <- sum(interviews$.contribution, na.rm = TRUE) # nolint: object_usage_linter
    n <- nrow(interviews) # nolint: object_usage_linter

    # Variance via survey package using svytotal on .contribution column
    strata_cols <- design$strata_cols
    if (!is.null(strata_cols) && length(strata_cols) > 0) {
      strata_formula <- stats::reformulate(strata_cols)
      svy_br <- survey::svydesign(ids = ~1, strata = strata_formula, data = interviews)
    } else {
      svy_br <- survey::svydesign(ids = ~1, data = interviews)
    }
    svy_br <- get_variance_design(svy_br, variance_method) # nolint: object_usage_linter
    svy_result <- suppressWarnings(survey::svytotal(~.contribution, svy_br))
    se <- as.numeric(survey::SE(svy_result)) # nolint: object_usage_linter
    ci <- confint(svy_result, level = conf_level)
    ci_lower <- ci[1, 1] # nolint: object_usage_linter
    ci_upper <- ci[1, 2] # nolint: object_usage_linter

    estimates_df <- tibble::tibble(
      estimate = total_estimate,
      se = se,
      ci_lower = ci_lower,
      ci_upper = ci_upper,
      n = n
    )

    result <- new_creel_estimates( # nolint: object_usage_linter
      estimates = estimates_df,
      method = "total",
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = NULL
    )
    attr(result, "site_contributions") <- site_table
    result
  } else {
    # Grouped estimation (e.g., by = "circuit")
    # For by="circuit": compute per-group total, then add proportion of overall
    by_formula <- stats::reformulate(by_vars)
    strata_cols <- design$strata_cols
    if (!is.null(strata_cols) && length(strata_cols) > 0) {
      strata_formula <- stats::reformulate(strata_cols)
      svy_br <- survey::svydesign(ids = ~1, strata = strata_formula, data = interviews)
    } else {
      svy_br <- survey::svydesign(ids = ~1, data = interviews)
    }
    svy_br <- get_variance_design(svy_br, variance_method) # nolint: object_usage_linter

    svy_result <- suppressWarnings(survey::svyby(
      formula = ~.contribution,
      by = by_formula,
      design = svy_br,
      FUN = survey::svytotal,
      vartype = c("se", "ci"),
      ci.level = conf_level,
      keep.names = FALSE
    ))

    estimate <- svy_result[[".contribution"]]
    se <- svy_result[["se"]]
    ci_lower <- svy_result[["ci_l"]]
    ci_upper <- svy_result[["ci_u"]]

    # Compute proportion of overall total for each group
    overall_total <- sum(interviews$.contribution, na.rm = TRUE)
    proportion <- estimate / overall_total

    # Per-group sample sizes
    group_data_for_n <- interviews[by_vars]
    group_data_for_n$.count <- 1
    n_by_group <- stats::aggregate(.count ~ ., data = group_data_for_n, FUN = sum)
    names(n_by_group)[names(n_by_group) == ".count"] <- "n"

    estimates_df <- svy_result[by_vars]
    estimates_df$estimate <- estimate
    estimates_df$se <- se
    estimates_df$ci_lower <- ci_lower
    estimates_df$ci_upper <- ci_upper
    estimates_df$proportion <- proportion
    estimates_df <- merge(estimates_df, n_by_group, by = by_vars, all.x = TRUE, sort = FALSE)
    estimates_df <- tibble::as_tibble(estimates_df)

    # Column order: group cols, estimate cols, proportion, n
    col_order <- c(by_vars, "estimate", "se", "ci_lower", "ci_upper", "proportion", "n")
    estimates_df <- estimates_df[col_order]

    result <- new_creel_estimates( # nolint: object_usage_linter
      estimates = estimates_df,
      method = "total",
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = by_vars
    )
    attr(result, "site_contributions") <- site_table
    result
  }
}
