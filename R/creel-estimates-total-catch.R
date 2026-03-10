# Total Catch Estimation Functions ----

#' Estimate total catch by combining effort and CPUE
#'
#' Computes total catch estimates by multiplying effort × CPUE with variance
#' propagation via the delta method. Requires a creel design with both count
#' data (for effort estimation) and interview data (for CPUE estimation).
#'
#' @param design A creel_design object with both counts (via
#'   \code{\link{add_counts}}) and interviews (via \code{\link{add_interviews}})
#'   attached. Both count and interview survey objects must exist.
#' @param by Optional tidy selector for grouping variables. When specified,
#'   must match across both effort and CPUE estimates (same calendar strata
#'   or interview variables). Accepts bare column names, multiple columns, or
#'   tidyselect helpers.
#' @param variance Character string specifying variance estimation method:
#'   "taylor" (default), "bootstrap", or "jackknife". Applied to BOTH effort
#'   and CPUE estimation, then combined via delta method.
#' @param conf_level Numeric confidence level (default: 0.95)
#' @param verbose Logical. If TRUE, prints an informational message identifying
#'   which estimator path was used. Default FALSE.
#'
#' @return A creel_estimates S3 object with method = "product-total-catch".
#'   For bus-route designs, returns a bus-route HT estimate with method = "total"
#'   and a "site_contributions" attribute.
#'
#' @details
#' Total catch is computed as Effort × CPUE. Variance is propagated using the
#' delta method, which accounts for uncertainty in both estimates. The formula
#' for independent estimates is approximately:
#'
#' \deqn{Var(E \times C) \approx E^2 \cdot Var(C) + C^2 \cdot Var(E)}
#'
#' The function uses survey::svycontrast() to compute variance automatically
#' via symbolic differentiation and Taylor series approximation.
#'
#' \strong{Design compatibility requirements:}
#' \itemize{
#'   \item Count data must be attached via \code{add_counts()} for effort estimation
#'   \item Interview data must be attached via \code{add_interviews()} for CPUE estimation
#'   \item Grouped estimation requires identical grouping variables for both estimates
#'   \item Calendar stratification must be shared between counts and interviews
#' }
#'
#' @examples
#' library(tidycreel)
#' data(example_calendar)
#' data(example_counts)
#' data(example_interviews)
#'
#' # Create design with both counts and interviews
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_counts(design, example_counts)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished,
#'   trip_status = trip_status, trip_duration = trip_duration
#' )
#'
#' # Estimate total catch
#' total_catch <- estimate_total_catch(design)
#' print(total_catch)
#'
#' # Compare components
#' effort_est <- estimate_effort(design)
#' cpue_est <- estimate_cpue(design)
#' # total_catch$estimates$estimate approximately equals effort_est * cpue_est
#'
#' # Note: Grouped estimation requires n >= 10 per group
#' # Check sample sizes before grouping:
#' # table(design$interviews$day_type)
#' # total_catch_by_type <- estimate_total_catch(design, by = day_type)
#'
#' # Verbose dispatch message (shows which estimator was used for bus-route designs)
#' # result_verbose <- estimate_total_catch(design, verbose = TRUE)
#'
#' @seealso \code{\link{estimate_effort}}, \code{\link{estimate_cpue}}
#' @export
estimate_total_catch <- function(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  verbose = FALSE
) {
  # Capture by parameter BEFORE validation
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

  # Bus-route dispatch (before standard survey NULL check)
  if (!is.null(design$design_type) && design$design_type == "bus_route") {
    if (verbose) {
      cli::cli_inform(c(
        "i" = "Using bus-route estimator (Jones & Pollock 2012, Eq. 19.5)"
      ))
    }
    if (rlang::quo_is_null(by_quo)) {
      by_vars_br <- NULL
    } else {
      by_cols_br <- tidyselect::eval_select(
        by_quo,
        data = design$interviews,
        allow_rename = FALSE,
        allow_empty = FALSE,
        error_call = rlang::caller_env()
      )
      by_vars_br <- names(by_cols_br)
    }
    return(estimate_total_catch_br( # nolint: object_usage_linter
      design, by_vars_br, variance, conf_level,
      verbose = FALSE
    ))
  }

  # Validate design compatibility (counts AND interviews required)
  validate_design_compatibility(design) # nolint: object_usage_linter

  # Detect species-level grouping
  by_info <- resolve_species_by(by_quo, design) # nolint: object_usage_linter

  if (!is.null(by_info$species_var)) {
    if (is.null(design[["catch"]])) {
      cli::cli_abort(c(
        "Species-level total catch requires catch data.",
        "x" = "Call {.fn add_catch} before using species grouping in {.fn estimate_total_catch}."
      ))
    }
    estimates_df <- estimate_total_catch_species( # nolint: object_usage_linter
      design,
      species_col       = by_info$species_var,
      interview_by_vars = by_info$interview_vars,
      variance_method   = variance,
      conf_level        = conf_level
    )
    return(new_creel_estimates( # nolint: object_usage_linter
      estimates       = tibble::as_tibble(estimates_df),
      method          = "product-total-catch",
      variance_method = variance,
      design          = design,
      conf_level      = conf_level,
      by_vars         = by_info$all_vars
    ))
  }

  # Standard (non-species) routing
  if (rlang::quo_is_null(by_quo)) {
    # Ungrouped estimation
    return(estimate_total_catch_ungrouped(design, variance, conf_level)) # nolint: object_usage_linter
  } else {
    # Grouped estimation
    # Resolve by parameter to column names
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = design$counts, # Use counts as reference
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)

    # Validate grouping compatibility
    validate_grouping_compatibility(design, by_vars) # nolint: object_usage_linter

    return(estimate_total_catch_grouped(design, by_vars, variance, conf_level)) # nolint: object_usage_linter
  }
}

#' Ungrouped total catch estimation (delta method product)
#'
#' @keywords internal
#' @noRd
estimate_total_catch_ungrouped <- function(design, variance_method, conf_level) {
  # Call estimate_effort() and estimate_cpue() with specified variance method
  effort_result <- estimate_effort(design, variance = variance_method, conf_level = conf_level) # nolint: object_usage_linter
  cpue_result <- estimate_cpue(design, variance = variance_method, conf_level = conf_level) # nolint: object_usage_linter

  # Extract estimates
  effort_est <- effort_result$estimates$estimate
  cpue_est <- cpue_result$estimates$estimate
  effort_se <- effort_result$estimates$se
  cpue_se <- cpue_result$estimates$se

  # Compute product estimate
  estimate <- effort_est * cpue_est

  # Compute variance using delta method for product of independent estimates
  # Var(X * Y) = X^2 * Var(Y) + Y^2 * Var(X) # nolint: commented_code_linter
  # where X = effort, Y = cpue
  effort_var <- effort_se^2
  cpue_var <- cpue_se^2
  product_var <- (effort_est^2 * cpue_var) + (cpue_est^2 * effort_var)
  se <- sqrt(product_var)

  # Compute confidence interval using normal approximation
  z_value <- stats::qnorm(1 - (1 - conf_level) / 2)
  ci_lower <- estimate - (z_value * se)
  ci_upper <- estimate + (z_value * se)

  # Sample size: use CPUE sample size (interview count)
  n <- cpue_result$estimates$n

  # Build estimates tibble
  estimates_df <- tibble::tibble(
    estimate = estimate,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    n = n
  )

  # Return creel_estimates object
  new_creel_estimates( # nolint: object_usage_linter
    estimates = estimates_df,
    method = "product-total-catch",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL
  )
}

#' Grouped total catch estimation using delta method
#'
#' @keywords internal
#' @noRd
estimate_total_catch_grouped <- function(design, by_vars, variance_method, conf_level) {
  # Convert by_vars to symbols for NSE
  if (length(by_vars) == 1) {
    by_sym <- rlang::sym(by_vars)
  } else {
    by_sym <- rlang::syms(by_vars)
  }

  # Call grouped estimation for both effort and CPUE
  effort_result <- estimate_effort(design, by = !!by_sym, variance = variance_method, conf_level = conf_level) # nolint: object_usage_linter
  cpue_result <- estimate_cpue(design, by = !!by_sym, variance = variance_method, conf_level = conf_level) # nolint: object_usage_linter

  # Extract estimates data frames (include group columns)
  effort_df <- effort_result$estimates
  cpue_df <- cpue_result$estimates

  # Merge on grouping variables to align rows
  merged <- merge(
    effort_df,
    cpue_df,
    by = by_vars,
    suffixes = c("_effort", "_cpue"),
    sort = FALSE
  )

  # Apply delta method for each group
  n_groups <- nrow(merged)
  estimates_list <- vector("list", n_groups)

  for (i in seq_len(n_groups)) {
    effort_est <- merged$estimate_effort[i]
    cpue_est <- merged$estimate_cpue[i]
    effort_se <- merged$se_effort[i]
    cpue_se <- merged$se_cpue[i]

    # Compute product estimate for this group
    estimate <- effort_est * cpue_est

    # Compute variance using delta method
    effort_var <- effort_se^2
    cpue_var <- cpue_se^2
    product_var <- (effort_est^2 * cpue_var) + (cpue_est^2 * effort_var)
    se <- sqrt(product_var)

    # Compute confidence interval
    z_value <- stats::qnorm(1 - (1 - conf_level) / 2)
    ci_lower <- estimate - (z_value * se)
    ci_upper <- estimate + (z_value * se)

    estimates_list[[i]] <- list(
      estimate = estimate,
      se = se,
      ci_lower = ci_lower,
      ci_upper = ci_upper,
      n = merged$n_cpue[i] # Use interview sample size
    )
  }

  # Build result tibble
  estimates_df <- tibble::as_tibble(merged[by_vars])
  estimates_df$estimate <- sapply(estimates_list, `[[`, "estimate")
  estimates_df$se <- sapply(estimates_list, `[[`, "se")
  estimates_df$ci_lower <- sapply(estimates_list, `[[`, "ci_lower")
  estimates_df$ci_upper <- sapply(estimates_list, `[[`, "ci_upper")
  estimates_df$n <- sapply(estimates_list, `[[`, "n")

  # Return creel_estimates object
  new_creel_estimates( # nolint: object_usage_linter
    estimates = estimates_df,
    method = "product-total-catch",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars
  )
}

#' Species-level total catch estimation
#'
#' @keywords internal
#' @noRd
estimate_total_catch_species <- function(design, species_col, interview_by_vars,
                                         variance_method, conf_level) {
  all_species <- sort(unique(design[["catch"]][[species_col]]))
  results_list <- vector("list", length(all_species))

  # Get all-species CPUE in one call (covers all species in one loop)
  all_cpue_df <- estimate_cpue_species( # nolint: object_usage_linter
    design,
    species_col       = species_col,
    interview_by_vars = interview_by_vars,
    variance_method   = variance_method,
    conf_level        = conf_level
  )

  # Get effort estimate (not species-grouped)
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

    cpue_sp_df <- all_cpue_df[all_cpue_df[[species_col]] == sp, , drop = FALSE]

    if (is.null(interview_by_vars)) {
      effort_est <- effort_df$estimate
      cpue_est <- cpue_sp_df$estimate
      effort_se <- effort_df$se
      cpue_se <- cpue_sp_df$se
      estimate <- effort_est * cpue_est
      pv <- (effort_est^2 * cpue_se^2) + (cpue_est^2 * effort_se^2)
      se <- sqrt(pv)
      z <- stats::qnorm(1 - (1 - conf_level) / 2)
      sp_result <- data.frame(
        estimate = estimate, se = se,
        ci_lower = estimate - z * se, ci_upper = estimate + z * se,
        n = cpue_sp_df$n, stringsAsFactors = FALSE
      )
    } else {
      cpue_no_sp <- cpue_sp_df[, setdiff(names(cpue_sp_df), species_col), drop = FALSE]
      merged <- merge(
        effort_df, cpue_no_sp,
        by = interview_by_vars, suffixes = c("_effort", "_cpue"), sort = FALSE
      )
      n_groups <- nrow(merged)
      estimates_list <- vector("list", n_groups)
      for (j in seq_len(n_groups)) {
        e_est <- merged$estimate_effort[j]
        c_est <- merged$estimate_cpue[j]
        e_se <- merged$se_effort[j]
        c_se <- merged$se_cpue[j]
        est <- e_est * c_est
        pv <- (e_est^2 * c_se^2) + (c_est^2 * e_se^2)
        z <- stats::qnorm(1 - (1 - conf_level) / 2)
        estimates_list[[j]] <- list(
          estimate = est, se = sqrt(pv),
          ci_lower = est - z * sqrt(pv), ci_upper = est + z * sqrt(pv),
          n = merged$n_cpue[j]
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
