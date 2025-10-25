#' Estimate CPUE for Roving Creel Surveys (Pollock et al. 1997)
#'
#' Design-based CPUE estimation for roving (incomplete trip) interviews with
#' length-biased sampling correction. Uses Pollock et al. (1997) methods
#' specifically designed for roving surveys where anglers are intercepted
#' during their fishing trips.
#'
#' @param design A `svydesign`/`svrepdesign` built on interview data with
#'   incomplete trips (roving surveys).
#' @param by Character vector of grouping variables (e.g., `c("location", "species")`).
#' @param response One of `"catch_total"`, `"catch_kept"`, `"catch_released"`.
#' @param effort_col Interview effort column (default `"hours_fished"`).
#'   For incomplete trips, this is **observed effort at time of interview**.
#' @param min_trip_hours Minimum trip duration for inclusion. Trips shorter
#'   than this threshold are excluded to avoid unstable ratios. Default 0.5
#'   hours (Hoenig et al. 1997 recommendation).
#' @param length_bias_correction Apply length-biased sampling correction
#'   (Pollock et al. 1997). Options:
#'   - `"none"`: No correction (assumes complete trips or no length bias)
#'   - `"pollock"`: Pollock et al. (1997) correction (recommended for roving)
#' @param total_trip_effort_col Column containing **total planned trip effort**
#'   (only needed if `length_bias_correction = "pollock"`). For incomplete trips,
#'   this is the angler's stated total planned fishing time.
#' @param conf_level Confidence level for confidence intervals (default 0.95).
#' @param diagnostics Include diagnostic information in output (default `TRUE`).
#'
#' @return Tibble with standard tidycreel schema:
#'   - Grouping columns (from `by` parameter)
#'   - `estimate`: CPUE estimate (catch per unit effort)
#'   - `se`: Standard error
#'   - `ci_low`, `ci_high`: Confidence interval bounds
#'   - `n`: Sample size (after truncation)
#'   - `method`: Method identifier
#'   - `diagnostics`: List-column with diagnostic information
#'
#' @details
#' ## Statistical Method
#'
#' Roving surveys interview anglers **during their trips**, creating two issues:
#' 1. **Incomplete catch data** - Trip not yet finished
#' 2. **Length-biased sampling** - Longer trips more likely intercepted
#'
#' ### Mean-of-Ratios Estimator (Pollock et al. 1997)
#'
#' For each interview \eqn{i}, calculate individual catch rate:
#' \deqn{r_i = \frac{c_i}{e_i}}
#'
#' where:
#' - \eqn{c_i} = catch at time of interview
#' - \eqn{e_i} = effort at time of interview
#'
#' Mean catch rate:
#' \deqn{\bar{r} = \frac{1}{n} \sum_{i=1}^n r_i}
#'
#' Variance (mean-of-ratios):
#' \deqn{Var(\bar{r}) = \frac{1}{n(n-1)} \sum_{i=1}^n (r_i - \bar{r})^2}
#'
#' ### Length-Biased Sampling Correction
#'
#' When `length_bias_correction = "pollock"`:
#'
#' Correction factor for each observation:
#' \deqn{w_i = \frac{1}{T_i}}
#'
#' where \eqn{T_i} is total planned trip duration.
#'
#' Corrected estimator:
#' \deqn{\bar{r}_{corrected} = \frac{\sum_{i=1}^n w_i r_i}{\sum_{i=1}^n w_i}}
#'
#' ## When to Use This Function
#'
#' **Use `est_cpue_roving()` when:**
#' - Conducting roving (on-water, circuit) surveys
#' - Interviewing anglers **during their trips** (incomplete)
#' - Trip completion times unknown at interview
#' - Need length-bias correction for accurate estimates
#'
#' **Use `est_cpue()` instead when:**
#' - Access-point interviews with **completed trips**
#' - Trip duration and catch fully observed
#' - No length-biased sampling concerns
#'
#' @examples
#' \dontrun{
#' library(tidycreel)
#' library(survey)
#'
#' # Roving survey data (incomplete trips)
#' # hours_fished = observed so far, catch_kept = current
#'
#' # Create survey design
#' svy_roving <- svydesign(
#'   ids = ~1,
#'   strata = ~location,
#'   data = roving_interviews
#' )
#'
#' # Estimate CPUE with Pollock correction (requires total_trip_effort)
#' cpue_roving <- est_cpue_roving(
#'   design = svy_roving,
#'   by = c("location", "species"),
#'   response = "catch_kept",
#'   effort_col = "hours_fished",
#'   total_trip_effort_col = "planned_hours",  # Stated total trip duration
#'   length_bias_correction = "pollock",
#'   min_trip_hours = 0.5
#' )
#'
#' # Without length-bias correction (assumes no bias or complete trips)
#' cpue_simple <- est_cpue_roving(
#'   design = svy_roving,
#'   by = "location",
#'   response = "catch_total",
#'   length_bias_correction = "none"
#' )
#' }
#'
#' @references
#' Pollock, K.H., C.M. Jones, and T.L. Brown. 1994. Angler Survey Methods
#'   and Their Applications in Fisheries Management. American Fisheries
#'   Society Special Publication 25. Bethesda, Maryland.
#'
#' Hoenig, J.M., C.M. Jones, K.H. Pollock, D.S. Robson, and D.L. Wade. 1997.
#'   Calculation of catch rate and total catch in roving and access point
#'   surveys. Biometrics 53:306-317.
#'
#' @seealso
#' [est_cpue()], [est_effort()], [aggregate_cpue()]
#'
#' @export
#' @importFrom stats qnorm update
est_cpue_roving <- function(
  design,
  by = NULL,
  response = c("catch_total", "catch_kept", "catch_released"),
  effort_col = "hours_fished",
  min_trip_hours = 0.5,
  length_bias_correction = c("none", "pollock"),
  total_trip_effort_col = NULL,
  conf_level = 0.95,
  diagnostics = TRUE
) {

  # Match arguments
  response <- match.arg(response)
  length_bias_correction <- match.arg(length_bias_correction)

  # ============================================================================
  # STEP 1: INPUT VALIDATION
  # ============================================================================

  # Derive survey design over interviews
  svy <- tc_interview_svy(design)
  vars <- svy$variables

  # Validate required columns exist
  required_cols <- c(response, effort_col)
  tc_abort_missing_cols(vars, required_cols, context = "est_cpue_roving")

  # Validate min_trip_hours
  if (!is.numeric(min_trip_hours) || length(min_trip_hours) != 1 || min_trip_hours <= 0) {
    cli::cli_abort(c(
      "x" = "{.arg min_trip_hours} must be a positive number.",
      "i" = "Received: {.val {min_trip_hours}}"
    ))
  }

  # Validate conf_level
  if (!is.numeric(conf_level) || length(conf_level) != 1 ||
      conf_level <= 0 || conf_level >= 1) {
    cli::cli_abort(c(
      "x" = "{.arg conf_level} must be between 0 and 1.",
      "i" = "Received: {.val {conf_level}}"
    ))
  }

  # If length-bias correction requested, require total_trip_effort_col
  if (length_bias_correction == "pollock") {
    if (is.null(total_trip_effort_col)) {
      cli::cli_abort(c(
        "x" = "Length-bias correction requires {.arg total_trip_effort_col}.",
        "i" = "This should contain anglers' stated total planned trip duration.",
        ">" = "Use {.code total_trip_effort_col = 'planned_hours'} or similar.",
        ">" = "Or use {.code length_bias_correction = 'none'} if no correction needed."
      ))
    }

    # Validate total_trip_effort_col exists
    if (!total_trip_effort_col %in% names(vars)) {
      cli::cli_abort(c(
        "x" = "Column {.val {total_trip_effort_col}} not found in data.",
        "i" = "Available columns: {.val {names(vars)}}"
      ))
    }
  }

  # Validate and filter grouping variables
  by <- tc_group_warn(by %||% character(), names(vars))

  # ============================================================================
  # STEP 2: TRIP TRUNCATION
  # ============================================================================

  # Count trips before truncation
  n_original <- nrow(vars)

  # Identify short trips
  short_trips <- vars[[effort_col]] < min_trip_hours
  short_trips[is.na(short_trips)] <- FALSE  # Don't truncate NAs yet
  n_truncated <- sum(short_trips)

  # Truncate short trips
  if (n_truncated > 0) {
    truncation_rate <- n_truncated / n_original

    # Warning if high truncation rate
    if (truncation_rate > 0.10) {
      cli::cli_warn(c(
        "!" = "Truncating {n_truncated} trip{?s} (< {min_trip_hours} hours).",
        "i" = "This is {round(100 * truncation_rate, 1)}% of your data.",
        ">" = "Consider lowering {.arg min_trip_hours} if truncation rate is excessive."
      ))
    } else {
      cli::cli_inform(c(
        "i" = "Truncating {n_truncated} short trip{?s} < {min_trip_hours} hours."
      ))
    }

    # Subset survey design to valid trips
    # Use base::subset since survey::subset is not exported
    valid_trips <- vars[[effort_col]] >= min_trip_hours
    valid_trips[is.na(valid_trips)] <- FALSE
    svy$variables <- vars[valid_trips, ]
    svy$prob <- svy$prob[valid_trips]
    if (!is.null(svy$allprob)) svy$allprob <- svy$allprob[valid_trips, , drop = FALSE]
    if (!is.null(svy$strata)) svy$strata <- svy$strata[valid_trips, , drop = FALSE]
    if (!is.null(svy$cluster)) svy$cluster <- svy$cluster[valid_trips, , drop = FALSE]
    if (!is.null(svy$fpc)) {
      svy$fpc$sampsize <- svy$fpc$sampsize[valid_trips]
      svy$fpc$popsize <- svy$fpc$popsize[valid_trips]
    }
    vars <- svy$variables
  }

  # Check if any trips remain
  n_after_truncation <- nrow(vars)
  if (n_after_truncation == 0) {
    cli::cli_abort(c(
      "x" = "No trips remain after truncation (all < {min_trip_hours} hours).",
      "i" = "Original trips: {n_original}",
      "i" = "Truncated: {n_truncated}",
      ">" = "Lower {.arg min_trip_hours} or check your data."
    ))
  }

  # ============================================================================
  # STEP 3: CALCULATE INDIVIDUAL CATCH RATES
  # ============================================================================

  # Calculate catch rate for each interview: r_i = catch_i / effort_i
  catch_rates <- vars[[response]] / vars[[effort_col]]

  # Handle Inf/NaN (zero effort creates Inf, 0/0 creates NaN)
  infinite_rates <- !is.finite(catch_rates)
  n_infinite <- sum(infinite_rates, na.rm = TRUE)

  if (n_infinite > 0) {
    cli::cli_warn(c(
      "!" = "{n_infinite} interview{?s} ha{?s/ve} infinite or undefined catch rates.",
      "i" = "This occurs when effort = 0 or catch/effort is undefined.",
      ">" = "These interviews will be excluded from analysis."
    ))
    catch_rates[infinite_rates] <- NA_real_
  }

  # Add catch rate to survey design
  svy <- stats::update(svy, .catch_rate = catch_rates)

  # ============================================================================
  # STEP 4: LENGTH-BIAS CORRECTION (if requested)
  # ============================================================================

  if (length_bias_correction == "pollock") {
    # Get total trip effort
    total_effort <- vars[[total_trip_effort_col]]

    # Validate: total_effort must be >= observed effort
    observed_effort <- vars[[effort_col]]
    invalid <- total_effort < observed_effort
    invalid[is.na(invalid)] <- FALSE
    n_invalid <- sum(invalid)

    if (n_invalid > 0) {
      cli::cli_warn(c(
        "!" = "{n_invalid} interview{?s} have total planned effort < observed effort.",
        "i" = "This is illogical (can't plan less time than already fished).",
        ">" = "Setting total planned effort = observed effort for these cases."
      ))
      total_effort[invalid] <- observed_effort[invalid]
    }

    # Calculate correction weights: w_i = 1 / T_i
    weights <- 1 / total_effort
    weights[!is.finite(weights)] <- 0  # Handle Inf from total_effort = 0

    # Add weights to survey design
    svy <- stats::update(svy, .length_bias_weights = weights)

    correction_applied <- TRUE

  } else {
    # No correction - equal weights
    svy <- stats::update(svy, .length_bias_weights = 1)
    correction_applied <- FALSE
  }

  # ============================================================================
  # STEP 5: GROUPED OR UNGROUPED ESTIMATION
  # ============================================================================

  if (length(by) > 0) {
    # Grouped estimation
    by_formula <- stats::as.formula(paste("~", paste(by, collapse = "+")))

    if (correction_applied) {
      # Weighted mean of catch rates
      est <- survey::svyby(
        ~.catch_rate,
        by = by_formula,
        design = svy,
        FUN = survey::svymean,
        na.rm = TRUE,
        keep.names = FALSE
      )
    } else {
      # Unweighted mean of catch rates
      est <- survey::svyby(
        ~.catch_rate,
        by = by_formula,
        design = svy,
        FUN = survey::svymean,
        na.rm = TRUE,
        keep.names = FALSE
      )
    }

    # Extract estimates and standard errors
    out <- tibble::as_tibble(est)
    names(out)[names(out) == ".catch_rate"] <- "estimate"

    # Extract SE robustly
    se_try <- try(suppressWarnings(as.numeric(survey::SE(est))), silent = TRUE)
    if (!inherits(se_try, "try-error") && length(se_try) == nrow(out)) {
      out$se <- se_try
    } else {
      # Fallback: extract from variance matrix
      V <- attr(est, "var")
      if (!is.null(V) && length(V) > 0) {
        out$se <- sqrt(diag(as.matrix(V)))
      } else {
        out$se <- rep(NA_real_, nrow(out))
      }
    }

  } else {
    # Ungrouped estimation
    if (correction_applied) {
      est <- survey::svymean(~.catch_rate, svy, na.rm = TRUE)
    } else {
      est <- survey::svymean(~.catch_rate, svy, na.rm = TRUE)
    }

    out <- tibble::tibble(
      estimate = as.numeric(stats::coef(est)),
      se = as.numeric(survey::SE(est))
    )
  }

  # ============================================================================
  # STEP 6: CONFIDENCE INTERVALS
  # ============================================================================

  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  out$ci_low <- out$estimate - z * out$se
  out$ci_high <- out$estimate + z * out$se

  # ============================================================================
  # STEP 7: SAMPLE SIZES
  # ============================================================================

  # Get final variables after all filtering
  vars_final <- svy$variables

  if (length(by) > 0) {
    # Sample size by group (after truncation and infinite removal)
    n_by <- vars_final |>
      dplyr::filter(!is.na(.catch_rate)) |>
      dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
      dplyr::summarise(n = dplyr::n(), .groups = "drop")

    out <- dplyr::left_join(out, n_by, by = by)
  } else {
    out$n <- sum(!is.na(vars_final$.catch_rate))
  }

  # ============================================================================
  # STEP 8: METHOD LABEL
  # ============================================================================

  method_str <- paste0(
    "cpue_roving:mean_of_ratios:",
    response,
    ":",
    length_bias_correction
  )
  out$method <- method_str

  # ============================================================================
  # STEP 9: DIAGNOSTICS
  # ============================================================================

  if (diagnostics) {
    diag_list <- vector("list", nrow(out))

    for (i in seq_len(nrow(out))) {
      # Identify group data if grouped
      if (length(by) > 0) {
        # Filter to this group
        group_vals <- out[i, by, drop = FALSE]
        group_data <- vars_final

        for (col in by) {
          group_data <- group_data[group_data[[col]] == group_vals[[col]], ]
        }
      } else {
        group_data <- vars_final
      }

      # Build diagnostics
      diag_info <- list(
        n_original = n_original,
        n_truncated = n_truncated,
        n_used = sum(!is.na(group_data$.catch_rate)),
        truncation_rate = n_truncated / n_original,
        min_trip_hours = min_trip_hours,
        mean_effort_observed = mean(group_data[[effort_col]], na.rm = TRUE),
        sd_effort_observed = stats::sd(group_data[[effort_col]], na.rm = TRUE),
        mean_catch_rate = mean(group_data$.catch_rate, na.rm = TRUE),
        sd_catch_rate = stats::sd(group_data$.catch_rate, na.rm = TRUE),
        length_bias_correction = length_bias_correction,
        correction_applied = correction_applied
      )

      # Add correction-specific diagnostics
      if (correction_applied && !is.null(total_trip_effort_col)) {
        diag_info$mean_total_effort <- mean(group_data[[total_trip_effort_col]], na.rm = TRUE)
        diag_info$sd_total_effort <- stats::sd(group_data[[total_trip_effort_col]], na.rm = TRUE)
        diag_info$mean_bias_weight <- mean(group_data$.length_bias_weights, na.rm = TRUE)
      }

      diag_list[[i]] <- diag_info
    }

    out$diagnostics <- diag_list

  } else {
    out$diagnostics <- replicate(nrow(out), list(NULL), simplify = FALSE)
  }

  # ============================================================================
  # STEP 10: RETURN TIDY SCHEMA
  # ============================================================================

  # Standard column order
  result_cols <- c(
    if (length(by) > 0) by else character(0),
    "estimate",
    "se",
    "ci_low",
    "ci_high",
    "n",
    "method",
    "diagnostics"
  )

  # Filter to only columns that exist
  result_cols <- intersect(result_cols, names(out))

  dplyr::select(out, dplyr::all_of(result_cols))
}
