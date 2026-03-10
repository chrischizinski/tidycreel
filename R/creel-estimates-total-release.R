# Total Release Estimation Functions ----

#' Estimate total extrapolated release by combining effort and release rate
#'
#' Computes total release estimates by multiplying effort x RPUE with variance
#' propagation via the delta method. Requires a creel design with count data
#' (for effort estimation), interview data (for effort), and catch data
#' (via \code{\link{add_catch}}) containing released records.
#'
#' @param design A creel_design object with counts (via \code{\link{add_counts}}),
#'   interviews (via \code{\link{add_interviews}}), and catch data (via
#'   \code{\link{add_catch}}) attached. Catch data must include records with
#'   \code{catch_type = "released"}.
#' @param by Optional tidy selector for grouping variables. Accepts bare column
#'   names (e.g., \code{by = day_type}, \code{by = species}), multiple columns,
#'   or tidyselect helpers.
#' @param variance Character string specifying variance estimation method:
#'   "taylor" (default), "bootstrap", or "jackknife". Applied to BOTH effort
#'   and release rate estimation, then combined via delta method.
#' @param conf_level Numeric confidence level (default: 0.95).
#'
#' @return A creel_estimates S3 object with method = "product-total-release".
#'   Estimates tibble has columns: estimate, se, ci_lower, ci_upper, n (plus
#'   any grouping columns).
#'
#' @details
#' Total release is computed as Effort x RPUE. Variance is propagated using the
#' delta method: Var(E x R) = E^2 * Var(R) + R^2 * Var(E).
#'
#' @seealso \code{\link{estimate_total_harvest}}, \code{\link{estimate_release_rate}},
#'   \code{\link{add_catch}}
#'
#' @examples
#' library(tidycreel)
#' data(example_calendar)
#' data(example_counts)
#' data(example_interviews)
#' data(example_catch)
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_counts(design, example_counts)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished,
#'   trip_status = trip_status, trip_duration = trip_duration
#' )
#' design <- add_catch(design, example_catch,
#'   catch_uid = interview_id, interview_uid = interview_id,
#'   species = species, count = count, catch_type = catch_type
#' )
#'
#' # Total releases (all species combined)
#' total_rel <- estimate_total_release(design)
#' print(total_rel)
#'
#' # Total releases by species
#' total_rel_sp <- estimate_total_release(design, by = species)
#' print(total_rel_sp)
#' @export
estimate_total_release <- function(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95
) {
  by_quo <- rlang::enquo(by)

  # Validate variance parameter
  valid_methods <- c("taylor", "bootstrap", "jackknife")
  if (!variance %in% valid_methods) {
    cli::cli_abort(c(
      "Invalid variance method: {.val {variance}}",
      "x" = "Must be one of: {.val {valid_methods}}",
      "i" = "Default is {.val taylor} (Taylor linearization)"
    ))
  }

  # Validate input is creel_design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Validate catch data (releases come from add_catch)
  if (is.null(design[["catch"]])) {
    cli::cli_abort(c(
      "No catch data available.",
      "x" = "Call {.fn add_catch} before estimating total release.",
      "i" = "Release data comes from catch records with catch_type = 'released'."
    ))
  }

  # Validate design compatibility (counts AND interviews required for effort)
  validate_design_compatibility(design) # nolint: object_usage_linter

  # Detect species-level grouping
  by_info <- resolve_species_by(by_quo, design) # nolint: object_usage_linter

  if (!is.null(by_info$species_var)) {
    # Species-level total release
    estimates_df <- estimate_total_release_species( # nolint: object_usage_linter
      design,
      species_col       = by_info$species_var,
      interview_by_vars = by_info$interview_vars,
      variance_method   = variance,
      conf_level        = conf_level
    )
    return(new_creel_estimates( # nolint: object_usage_linter
      estimates       = tibble::as_tibble(estimates_df),
      method          = "product-total-release",
      variance_method = variance,
      design          = design,
      conf_level      = conf_level,
      by_vars         = by_info$all_vars
    ))
  }

  # Standard (non-species) routing
  if (rlang::quo_is_null(by_quo)) {
    return(estimate_total_release_ungrouped(design, variance, conf_level)) # nolint: object_usage_linter
  } else {
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = design$counts,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)
    validate_grouping_compatibility(design, by_vars) # nolint: object_usage_linter
    return(estimate_total_release_grouped(design, by_vars, variance, conf_level)) # nolint: object_usage_linter
  }
}

#' @keywords internal
#' @noRd
estimate_total_release_ungrouped <- function(design, variance_method, conf_level) { # nolint: object_length_linter
  effort_result <- estimate_effort(design, variance = variance_method, conf_level = conf_level) # nolint: object_usage_linter
  release_result <- estimate_release_rate(design, variance = variance_method, conf_level = conf_level) # nolint: object_usage_linter

  effort_est <- effort_result$estimates$estimate
  rpue_est <- release_result$estimates$estimate
  effort_se <- effort_result$estimates$se
  rpue_se <- release_result$estimates$se

  estimate <- effort_est * rpue_est
  effort_var <- effort_se^2
  rpue_var <- rpue_se^2
  product_var <- (effort_est^2 * rpue_var) + (rpue_est^2 * effort_var)
  se <- sqrt(product_var)
  z_value <- stats::qnorm(1 - (1 - conf_level) / 2)
  ci_lower <- estimate - (z_value * se)
  ci_upper <- estimate + (z_value * se)
  n <- release_result$estimates$n

  estimates_df <- tibble::tibble(
    estimate = estimate, se = se, ci_lower = ci_lower, ci_upper = ci_upper, n = n
  )

  new_creel_estimates( # nolint: object_usage_linter
    estimates       = estimates_df,
    method          = "product-total-release",
    variance_method = variance_method,
    design          = design,
    conf_level      = conf_level,
    by_vars         = NULL
  )
}

#' @keywords internal
#' @noRd
estimate_total_release_grouped <- function(design, by_vars, variance_method, conf_level) {
  if (length(by_vars) == 1L) {
    by_sym <- rlang::sym(by_vars)
  } else {
    by_sym <- rlang::syms(by_vars)
  }

  effort_result <- estimate_effort(design, by = !!by_sym, variance = variance_method, conf_level = conf_level) # nolint: object_usage_linter
  release_result <- estimate_release_rate(design, by = !!by_sym, variance = variance_method, conf_level = conf_level) # nolint: object_usage_linter

  effort_df <- effort_result$estimates
  release_df <- release_result$estimates

  merged <- merge(effort_df, release_df, by = by_vars, suffixes = c("_effort", "_rpue"), sort = FALSE)

  n_groups <- nrow(merged)
  estimates_list <- vector("list", n_groups)

  for (i in seq_len(n_groups)) {
    effort_est <- merged$estimate_effort[i]
    rpue_est <- merged$estimate_rpue[i]
    effort_se <- merged$se_effort[i]
    rpue_se <- merged$se_rpue[i]
    estimate <- effort_est * rpue_est
    effort_var <- effort_se^2
    rpue_var <- rpue_se^2
    product_var <- (effort_est^2 * rpue_var) + (rpue_est^2 * effort_var)
    se <- sqrt(product_var)
    z_value <- stats::qnorm(1 - (1 - conf_level) / 2)
    estimates_list[[i]] <- list(
      estimate = estimate, se = se,
      ci_lower = estimate - (z_value * se),
      ci_upper = estimate + (z_value * se),
      n = merged$n_rpue[i]
    )
  }

  estimates_df <- tibble::as_tibble(merged[by_vars])
  estimates_df$estimate <- sapply(estimates_list, `[[`, "estimate")
  estimates_df$se <- sapply(estimates_list, `[[`, "se")
  estimates_df$ci_lower <- sapply(estimates_list, `[[`, "ci_lower")
  estimates_df$ci_upper <- sapply(estimates_list, `[[`, "ci_upper")
  estimates_df$n <- sapply(estimates_list, `[[`, "n")

  new_creel_estimates( # nolint: object_usage_linter
    estimates       = estimates_df,
    method          = "product-total-release",
    variance_method = variance_method,
    design          = design,
    conf_level      = conf_level,
    by_vars         = by_vars
  )
}

#' Species-level total release estimation
#'
#' @keywords internal
#' @noRd
estimate_total_release_species <- function(design, species_col, interview_by_vars,
                                           variance_method, conf_level) {
  all_species <- sort(unique(design[["catch"]][[species_col]]))
  results_list <- vector("list", length(all_species))

  # Get all species release rates in one call (avoid redundant loops)
  all_release_df <- estimate_release_rate_species( # nolint: object_usage_linter
    design,
    species_col       = species_col,
    interview_by_vars = interview_by_vars,
    variance_method   = variance_method,
    conf_level        = conf_level
  )

  # Get effort estimate (not grouped by species)
  if (is.null(interview_by_vars)) {
    effort_result <- estimate_effort(design, variance = variance_method, conf_level = conf_level) # nolint: object_usage_linter
  } else {
    by_sym <- if (length(interview_by_vars) == 1L) {
      rlang::sym(interview_by_vars)
    } else {
      rlang::syms(interview_by_vars)
    }
    effort_result <- estimate_effort(design, by = !!by_sym, variance = variance_method, conf_level = conf_level) # nolint: object_usage_linter
  }
  effort_df <- effort_result$estimates

  for (i in seq_along(all_species)) {
    sp <- all_species[[i]]

    sp_release_df <- all_release_df[all_release_df[[species_col]] == sp, , drop = FALSE]

    if (is.null(interview_by_vars)) {
      effort_est <- effort_df$estimate
      rpue_est <- sp_release_df$estimate
      effort_se <- effort_df$se
      rpue_se <- sp_release_df$se
      estimate <- effort_est * rpue_est
      pv <- (effort_est^2 * rpue_se^2) + (rpue_est^2 * effort_se^2)
      se <- sqrt(pv)
      z_value <- stats::qnorm(1 - (1 - conf_level) / 2)
      sp_result <- data.frame(
        estimate = estimate, se = se,
        ci_lower = estimate - (z_value * se),
        ci_upper = estimate + (z_value * se),
        n = sp_release_df$n,
        stringsAsFactors = FALSE
      )
    } else {
      # Merge on interview_by_vars (drop species col from release df for merge)
      release_no_sp <- sp_release_df[, setdiff(names(sp_release_df), species_col), drop = FALSE]
      merged <- merge(
        effort_df, release_no_sp,
        by = interview_by_vars, suffixes = c("_effort", "_rpue"), sort = FALSE
      )
      n_groups <- nrow(merged)
      estimates_list <- vector("list", n_groups)
      for (j in seq_len(n_groups)) {
        e_est <- merged$estimate_effort[j]
        r_est <- merged$estimate_rpue[j]
        e_se <- merged$se_effort[j]
        r_se <- merged$se_rpue[j]
        est <- e_est * r_est
        pv <- (e_est^2 * r_se^2) + (r_est^2 * e_se^2)
        z <- stats::qnorm(1 - (1 - conf_level) / 2)
        estimates_list[[j]] <- list(
          estimate = est, se = sqrt(pv),
          ci_lower = est - z * sqrt(pv), ci_upper = est + z * sqrt(pv),
          n = merged$n_rpue[j]
        )
      }
      sp_result <- tibble::as_tibble(merged[interview_by_vars])
      sp_result$estimate <- sapply(estimates_list, `[[`, "estimate")
      sp_result$se <- sapply(estimates_list, `[[`, "se")
      sp_result$ci_lower <- sapply(estimates_list, `[[`, "ci_lower")
      sp_result$ci_upper <- sapply(estimates_list, `[[`, "ci_upper")
      sp_result$n <- sapply(estimates_list, `[[`, "n")
    }

    sp_result[[species_col]] <- sp
    sp_result <- sp_result[c(species_col, setdiff(names(sp_result), species_col))]
    results_list[[i]] <- sp_result
  }

  do.call(rbind, results_list)
}
