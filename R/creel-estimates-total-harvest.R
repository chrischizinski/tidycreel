# Total Harvest Estimation Functions ----

#' Estimate total harvest by combining effort and HPUE
#'
#' Computes total harvest estimates by multiplying effort × HPUE with variance
#' propagation via the delta method. Requires a creel design with both count
#' data (for effort estimation) and interview data (for HPUE estimation).
#'
#' @param design A creel_design object with both counts (via
#'   \code{\link{add_counts}}) and interviews (via \code{\link{add_interviews}})
#'   attached. Both count and interview survey objects must exist. Interview
#'   data must include harvest column (specified via harvest parameter in
#'   add_interviews).
#' @param by Optional tidy selector for grouping variables. When specified,
#'   must match across both effort and HPUE estimates (same calendar strata
#'   or interview variables). Accepts bare column names, multiple columns, or
#'   tidyselect helpers.
#' @param variance Character string specifying variance estimation method:
#'   "taylor" (default), "bootstrap", or "jackknife". Applied to BOTH effort
#'   and HPUE estimation, then combined via delta method.
#' @param conf_level Numeric confidence level (default: 0.95)
#'
#' @return A creel_estimates S3 object with method = "product-total-harvest"
#'
#' @details
#' Total harvest is computed as Effort × HPUE. Variance is propagated using the
#' delta method, which accounts for uncertainty in both estimates. The formula
#' for independent estimates is approximately:
#'
#' \deqn{Var(E \times H) \approx E^2 \cdot Var(H) + H^2 \cdot Var(E)}
#'
#' The function uses survey::svycontrast() to compute variance automatically
#' via symbolic differentiation and Taylor series approximation.
#'
#' \strong{Design compatibility requirements:}
#' \itemize{
#'   \item Count data must be attached via \code{add_counts()} for effort estimation
#'   \item Interview data must be attached via \code{add_interviews()} for HPUE estimation
#'   \item Harvest column must be specified in add_interviews (harvest parameter)
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
#' # Create design with both counts and interviews including harvest
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_counts(design, example_counts)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, harvest = catch_kept, effort = hours_fished
#' )
#'
#' # Estimate total harvest
#' total_harvest <- estimate_total_harvest(design)
#' print(total_harvest)
#'
#' # Compare components
#' effort_est <- estimate_effort(design)
#' hpue_est <- estimate_harvest(design)
#' # total_harvest$estimates$estimate approximately equals effort_est * hpue_est
#'
#' # Note: Grouped estimation requires n >= 10 per group
#' # Check sample sizes before grouping:
#' # table(design$interviews$day_type)
#' # total_harvest_by_type <- estimate_total_harvest(design, by = day_type)
#'
#' @seealso \code{\link{estimate_effort}}, \code{\link{estimate_harvest}},
#'   \code{\link{estimate_total_catch}}
#' @export
estimate_total_harvest <- function(design, by = NULL, variance = "taylor", conf_level = 0.95) {
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

  # Validate design compatibility (counts AND interviews required)
  validate_design_compatibility(design) # nolint: object_usage_linter

  # Validate design$harvest_col exists
  if (is.null(design$harvest_col)) {
    cli::cli_abort(c(
      "No harvest column available.",
      "x" = "Design must have harvest_col set.",
      "i" = "Call {.fn add_interviews} with the harvest parameter.",
      "i" = paste(
        "Example: {.code design <- add_interviews(design, interviews,",
        "catch = catch_total, harvest = catch_kept, effort = hours_fished)}"
      )
    ))
  }

  # Route to grouped or ungrouped estimation
  if (rlang::quo_is_null(by_quo)) {
    # Ungrouped estimation
    return(estimate_total_harvest_ungrouped(design, variance, conf_level)) # nolint: object_usage_linter
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

    return(estimate_total_harvest_grouped(design, by_vars, variance, conf_level)) # nolint: object_usage_linter
  }
}

#' Ungrouped total harvest estimation (delta method product)
#'
#' @keywords internal
#' @noRd
estimate_total_harvest_ungrouped <- function(design, variance_method, conf_level) { # nolint: object_length_linter
  # Call estimate_effort() and estimate_harvest() with specified variance method
  effort_result <- estimate_effort(design, variance = variance_method, conf_level = conf_level) # nolint: object_usage_linter
  hpue_result <- estimate_harvest(design, variance = variance_method, conf_level = conf_level) # nolint: object_usage_linter

  # Extract estimates
  effort_est <- effort_result$estimates$estimate
  hpue_est <- hpue_result$estimates$estimate
  effort_se <- effort_result$estimates$se
  hpue_se <- hpue_result$estimates$se

  # Compute product estimate
  estimate <- effort_est * hpue_est

  # Compute variance using delta method for product of independent estimates
  # Var(X * Y) = X^2 * Var(Y) + Y^2 * Var(X) # nolint: commented_code_linter
  # where X = effort, Y = hpue
  effort_var <- effort_se^2
  hpue_var <- hpue_se^2
  product_var <- (effort_est^2 * hpue_var) + (hpue_est^2 * effort_var)
  se <- sqrt(product_var)

  # Compute confidence interval using normal approximation
  z_value <- stats::qnorm(1 - (1 - conf_level) / 2)
  ci_lower <- estimate - (z_value * se)
  ci_upper <- estimate + (z_value * se)

  # Sample size: use HPUE sample size (interview count)
  n <- hpue_result$estimates$n

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
    method = "product-total-harvest",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL
  )
}

#' Grouped total harvest estimation using delta method
#'
#' @keywords internal
#' @noRd
estimate_total_harvest_grouped <- function(design, by_vars, variance_method, conf_level) {
  # Convert by_vars to symbols for NSE
  if (length(by_vars) == 1) {
    by_sym <- rlang::sym(by_vars)
  } else {
    by_sym <- rlang::syms(by_vars)
  }

  # Call grouped estimation for both effort and HPUE
  effort_result <- estimate_effort(design, by = !!by_sym, variance = variance_method, conf_level = conf_level) # nolint: object_usage_linter
  hpue_result <- estimate_harvest(design, by = !!by_sym, variance = variance_method, conf_level = conf_level) # nolint: object_usage_linter

  # Extract estimates data frames (include group columns)
  effort_df <- effort_result$estimates
  hpue_df <- hpue_result$estimates

  # Merge on grouping variables to align rows
  merged <- merge(
    effort_df,
    hpue_df,
    by = by_vars,
    suffixes = c("_effort", "_hpue"),
    sort = FALSE
  )

  # Apply delta method for each group
  n_groups <- nrow(merged)
  estimates_list <- vector("list", n_groups)

  for (i in seq_len(n_groups)) {
    effort_est <- merged$estimate_effort[i]
    hpue_est <- merged$estimate_hpue[i]
    effort_se <- merged$se_effort[i]
    hpue_se <- merged$se_hpue[i]

    # Compute product estimate for this group
    estimate <- effort_est * hpue_est

    # Compute variance using delta method
    effort_var <- effort_se^2
    hpue_var <- hpue_se^2
    product_var <- (effort_est^2 * hpue_var) + (hpue_est^2 * effort_var)
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
      n = merged$n_hpue[i] # Use interview sample size
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
    method = "product-total-harvest",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars
  )
}
