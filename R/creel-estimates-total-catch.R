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
#' @param target Character string specifying the effort domain supplied to
#'   [estimate_effort()]. Options are `"sampled_days"` (default),
#'   `"stratum_total"`, or `"period_total"`. This controls which effort domain
#'   is multiplied by CPUE so total catch stays aligned with the requested
#'   temporal target.
#' @param aggregate_sections Logical. When the design was created with
#'   \code{\link{add_sections}}, should a \code{.lake_total} row be appended
#'   that sums the per-section estimates? Default \code{TRUE}. Set to
#'   \code{FALSE} to return only the per-section rows without the lake total.
#' @param missing_sections Character(1). Action when a registered section is
#'   absent from either count data or interview data: \code{"warn"} (default)
#'   inserts an NA row with \code{data_available = FALSE}, \code{"error"}
#'   raises a hard error.
#' @param verbose Logical. If TRUE, prints an informational message identifying
#'   which estimator path was used. Default FALSE.
#'
#' @return A creel_estimates S3 object with method = "product-total-catch".
#'   For bus-route designs, returns a bus-route HT estimate with method = "total"
#'   and a "site_contributions" attribute.
#'   For sectioned designs, returns per-section rows plus (by default) a
#'   \code{.lake_total} row. The lake-wide total is computed as
#'   \code{sum(TC_i)} over sections, never as \code{E_total * CPUE_pooled}.
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
#' \strong{Sectioned designs:}
#' When \code{\link{add_sections}} has been called on the design, each section
#' is estimated independently using its own count survey (via
#' \code{rebuild_counts_survey}) and interview survey (via
#' \code{rebuild_interview_survey}). The lake-wide total is the arithmetic sum
#' \code{sum(TC_i)}, not \code{E_total * CPUE_pooled}. The lake-wide SE uses
#' the zero-covariance assumption: \code{sqrt(sum(se_i^2))}. Cross-section
#' covariance between count-based effort and interview-based CPUE designs is not
#' identified and is therefore assumed zero.
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
#' cpue_est <- estimate_catch_rate(design)
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
#' @seealso \code{\link{estimate_effort}}, \code{\link{estimate_catch_rate}}
#' @family "Estimation"
#' @export
estimate_total_catch <- function(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  target = c("sampled_days", "stratum_total", "period_total"),
  aggregate_sections = TRUE,
  missing_sections = "warn",
  verbose = FALSE
) {
  # Capture by parameter BEFORE validation
  by_quo <- rlang::enquo(by)
  target <- match.arg(target)

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

  # Bus-route / ice dispatch (before standard survey NULL check)
  if (!is.null(design$design_type) && design$design_type %in% c("bus_route", "ice")) {
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

  # Section dispatch guard (v0.7.0+ — only fires when add_sections() was called)
  if (!is.null(design[["sections"]])) {
    return(estimate_total_catch_sections( # nolint: object_usage_linter
      design, by_quo, variance, conf_level, aggregate_sections, missing_sections,
      target = target
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
      conf_level        = conf_level,
      target            = target
    )
    return(new_creel_estimates( # nolint: object_usage_linter
      estimates       = tibble::as_tibble(estimates_df),
      method          = "product-total-catch",
      variance_method = variance,
      design          = design,
      conf_level      = conf_level,
      by_vars         = by_info$all_vars,
      effort_target   = target
    ))
  }

  # Standard (non-species) routing
  if (rlang::quo_is_null(by_quo)) {
    # Ungrouped estimation
    return(estimate_total_catch_ungrouped(design, variance, conf_level, target = target)) # nolint: object_usage_linter
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

    return(estimate_total_catch_grouped(design, by_vars, variance, conf_level, target = target)) # nolint: object_usage_linter
  }
}

#' CPUE helper that respects trip filtering for the stratified-sum product path
#'
#' Mirrors the trip-filtering logic of estimate_catch_rate() (complete-only default)
#' then calls estimate_cpue_total() or estimate_cpue_grouped() directly. This
#' avoids NSE complexity while preserving the same n= counts as the public API.
#' Called from estimate_total_catch_ungrouped() and estimate_total_catch_grouped().
#'
#' @param design A creel_design object.
#' @param by_vars Character vector of grouping column names (may be length-0).
#' @param variance_method Character. Variance estimation method.
#' @param conf_level Numeric confidence level.
#'
#' @return A creel_estimates object.
#'
#' @keywords internal
#' @noRd
cpue_for_stratum_product <- function(design, by_vars, variance_method, conf_level) {
  # Mirror the complete-trip filtering that estimate_catch_rate() applies by default
  trip_status_col <- design$trip_status_col
  if (!is.null(trip_status_col)) {
    complete_interviews <- design$interviews[
      design$interviews[[trip_status_col]] == "complete", ,
      drop = FALSE
    ]
    design <- rebuild_interview_survey(design, complete_interviews) # nolint: object_usage_linter
  }

  if (length(by_vars) == 0L) {
    estimate_cpue_total(design, variance_method, conf_level, "ratio-of-means") # nolint: object_usage_linter
  } else {
    estimate_cpue_grouped(design, by_vars, variance_method, conf_level, "ratio-of-means") # nolint: object_usage_linter
  }
}

#' Ungrouped total catch estimation (stratified-sum product estimator)
#'
#' Uses compute_stratum_product_sum() with per-stratum effort and CPUE so that
#' for multi-strata designs the result equals sum(per-species estimates).
#' When strata_cols is empty (no strata), reduces to the simple delta-method
#' product (the length-0 branch of compute_stratum_product_sum).
#'
#' @keywords internal
#' @noRd
estimate_total_catch_ungrouped <- function(design, variance_method, conf_level, target = "sampled_days") {
  strata_cols <- design$strata_cols %||% character(0)

  # Per-stratum effort
  if (length(strata_cols) == 0L) {
    effort_result <- estimate_effort_total(design, variance_method, conf_level, target = target) # nolint: object_usage_linter
  } else {
    effort_result <- estimate_effort_grouped(design, strata_cols, variance_method, conf_level, target = target) # nolint: object_usage_linter
  }
  effort_df <- effort_result$estimates

  # Per-stratum CPUE (catch rate), grouped by strata_cols.
  # Use the public estimate_catch_rate() API so trip filtering (complete-only)
  # and survey rebuilding are applied consistently with the grouped path.
  cpue_result <- cpue_for_stratum_product( # nolint: object_usage_linter
    design, strata_cols, variance_method, conf_level
  )
  cpue_df <- cpue_result$estimates

  # Stratified-sum product estimator: sum(E_h * CPUE_h) across strata h
  estimates_df <- compute_stratum_product_sum( # nolint: object_usage_linter
    effort_df         = effort_df,
    rate_df           = cpue_df,
    stratum_by_vars   = strata_cols,
    interview_by_vars = NULL,
    conf_level        = conf_level,
    rate_suffix       = "cpue"
  )

  new_creel_estimates( # nolint: object_usage_linter
    estimates       = tibble::as_tibble(estimates_df),
    method          = "product-total-catch",
    variance_method = variance_method,
    design          = design,
    conf_level      = conf_level,
    by_vars         = NULL,
    effort_target   = target
  )
}

#' Grouped total catch estimation (stratified-sum product estimator)
#'
#' Diagnosis: the old implementation called estimate_effort(by = by_vars) and
#' estimate_catch_rate(by = by_vars), grouping only by the user's by_vars. For
#' multi-strata designs where by_vars does not include strata_cols, this is a
#' combined-ratio bug: pooled-stratum effort * pooled-stratum CPUE instead of
#' sum(E_h * CPUE_h). Fixed by using stratum_by_vars = union(strata_cols, by_vars)
#' for per-stratum products, then summing within by_vars groups.
#'
#' @keywords internal
#' @noRd
estimate_total_catch_grouped <- function(design, by_vars, variance_method, conf_level, target = "sampled_days") {
  strata_cols <- design$strata_cols %||% character(0)
  # Union of calendar strata and user grouping: ensures per-stratum products
  stratum_by_vars <- unique(c(strata_cols, by_vars))

  # Per-stratum effort grouped by union of strata and user vars
  effort_result <- estimate_effort_grouped(design, stratum_by_vars, variance_method, conf_level, target = target) # nolint: object_usage_linter
  effort_df <- effort_result$estimates

  # Per-stratum CPUE grouped by same union.
  # Use the public estimate_catch_rate() API so trip filtering (complete-only)
  # and survey rebuilding are applied consistently.
  cpue_result <- cpue_for_stratum_product( # nolint: object_usage_linter
    design, stratum_by_vars, variance_method, conf_level
  )
  cpue_df <- cpue_result$estimates

  # Stratified-sum within each by_vars group
  estimates_df <- compute_stratum_product_sum( # nolint: object_usage_linter
    effort_df         = effort_df,
    rate_df           = cpue_df,
    stratum_by_vars   = stratum_by_vars,
    interview_by_vars = if (length(by_vars) > 0L) by_vars else NULL,
    conf_level        = conf_level,
    rate_suffix       = "cpue"
  )

  new_creel_estimates( # nolint: object_usage_linter
    estimates       = tibble::as_tibble(estimates_df),
    method          = "product-total-catch",
    variance_method = variance_method,
    design          = design,
    conf_level      = conf_level,
    by_vars         = by_vars,
    effort_target   = target
  )
}

#' Species-level total catch estimation (stratum-sum product estimator)
#'
#' Implements the statistically correct stratified estimator: per-stratum CPUE
#' times per-stratum effort, summed across strata (McCormick & Meyer 2024,
#' Rasmussen et al. 1998). When no strata are defined, reduces to the simple
#' pooled delta-method product.
#'
#' @keywords internal
#' @noRd
estimate_total_catch_species <- function(design, species_col, interview_by_vars,
                                         variance_method, conf_level,
                                         target = "sampled_days") {
  strata_cols <- design$strata_cols %||% character(0)
  stratum_by_vars <- unique(c(strata_cols, interview_by_vars))

  # Per-stratum species CPUE (grouped by strata + interview grouping vars)
  rate_by <- if (length(stratum_by_vars) > 0L) stratum_by_vars else NULL
  all_rate_df <- estimate_cpue_species( # nolint: object_usage_linter
    design,
    species_col       = species_col,
    interview_by_vars = rate_by,
    variance_method   = variance_method,
    conf_level        = conf_level,
    validate          = FALSE
  )

  # Per-stratum effort (grouped by same vars)
  if (length(stratum_by_vars) == 0L) {
    effort_result <- estimate_effort_total(design, variance_method, conf_level, target = target) # nolint: object_usage_linter
  } else {
    effort_result <- estimate_effort_grouped(design, stratum_by_vars, variance_method, conf_level, target = target) # nolint: object_usage_linter
  }
  effort_df <- effort_result$estimates

  warn_missing_rate_strata( # nolint: object_usage_linter
    effort_df = effort_df,
    rate_df = all_rate_df[, setdiff(names(all_rate_df), species_col), drop = FALSE],
    stratum_by_vars = stratum_by_vars,
    context = "species total catch"
  )

  all_species <- sort(unique(design[["catch"]][[species_col]]))
  results_list <- vector("list", length(all_species))

  for (i in seq_along(all_species)) {
    sp <- all_species[[i]]
    rate_sp_df <- all_rate_df[all_rate_df[[species_col]] == sp, , drop = FALSE]
    rate_no_sp <- rate_sp_df[, setdiff(names(rate_sp_df), species_col), drop = FALSE]

    sp_result <- compute_stratum_product_sum( # nolint: object_usage_linter
      effort_df         = effort_df,
      rate_df           = rate_no_sp,
      stratum_by_vars   = stratum_by_vars,
      interview_by_vars = interview_by_vars,
      conf_level        = conf_level,
      rate_suffix       = "cpue"
    )

    sp_result[[species_col]] <- sp
    sp_result <- sp_result[c(species_col, setdiff(names(sp_result), species_col))]
    results_list[[i]] <- sp_result
  }

  do.call(rbind, results_list)
}

#' Per-section total catch estimation (product estimator)
#'
#' @keywords internal
#' @noRd
estimate_total_catch_sections <- function(design, by_quo, variance_method, # nolint: object_length_linter
                                          conf_level, aggregate_sections,
                                          missing_sections,
                                          target = "sampled_days") {
  section_col <- design[["section_col"]]
  registered_sections <- design$sections[[section_col]]
  present_count_sections <- unique(design$counts[[section_col]])
  present_interview_sections <- unique(design$interviews[[section_col]])
  absent_sections <- setdiff(
    registered_sections,
    intersect(present_count_sections, present_interview_sections)
  )

  # Handle missing sections
  if (length(absent_sections) > 0) {
    n_absent <- length(absent_sections) # nolint: object_usage_linter
    if (missing_sections == "error") {
      cli::cli_abort(c(
        "{n_absent} missing section(s) in count or interview data.",
        "x" = "Section(s) not found: {.val {absent_sections}}",
        "i" = "All registered sections must have both count and interview data, or use {.arg missing_sections = 'warn'}." # nolint: line_length_linter
      ))
    } else {
      cli::cli_warn(c(
        "{n_absent} missing section(s) in count or interview data.",
        "!" = "Section(s) not found: {.val {absent_sections}}",
        "i" = "Inserting NA row(s) with {.field data_available = FALSE}."
      ))
    }
  }

  # Resolve by= ONCE before the section loop (no species dispatch in v0.7.0 section path)
  if (rlang::quo_is_null(by_quo)) {
    by_vars <- NULL
  } else {
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = design$counts,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)
  }

  section_rows <- vector("list", length(registered_sections))
  names(section_rows) <- registered_sections

  for (sec in registered_sections) {
    if (sec %in% absent_sections) {
      na_row <- tibble::tibble(
        section = sec,
        estimate = NA_real_,
        se = NA_real_,
        ci_lower = NA_real_,
        ci_upper = NA_real_,
        n = 0L,
        prop_of_lake_total = NA_real_,
        data_available = FALSE
      )
      section_rows[[sec]] <- na_row
    } else {
      # Build per-section designs — dual rebuild for product estimators.
      # Remove sections slot so the sub-design does not re-trigger section dispatch.
      sec_counts_design <- suppressWarnings(rebuild_counts_survey(design, sec)) # nolint: object_usage_linter
      sec_counts_design[["sections"]] <- NULL
      filtered_interviews <- design$interviews[design$interviews[[section_col]] == sec, ]
      sec_design <- rebuild_interview_survey(sec_counts_design, filtered_interviews) # nolint: object_usage_linter

      if (!is.null(by_vars)) {
        # Grouped path: delegates to existing grouped helper
        result <- estimate_total_catch_grouped( # nolint: object_usage_linter
          sec_design, by_vars, variance_method, conf_level,
          target = target
        )
        row_df <- tibble::add_column(result$estimates, section = sec, .before = 1)
        row_df$data_available <- TRUE
        section_rows[[sec]] <- row_df
      } else {
        # Ungrouped path: call internal helpers directly to bypass sample-size validation
        effort_res <- estimate_effort_total(sec_design, variance_method, conf_level, target = target) # nolint: object_usage_linter
        cpue_res <- estimate_cpue_total(sec_design, variance_method, conf_level, "ratio") # nolint: object_usage_linter
        effort_est <- effort_res$estimates$estimate
        cpue_est <- cpue_res$estimates$estimate
        effort_se <- effort_res$estimates$se
        cpue_se <- cpue_res$estimates$se
        sec_estimate <- effort_est * cpue_est
        sec_var <- (effort_est^2 * cpue_se^2) + (cpue_est^2 * effort_se^2)
        sec_se <- sqrt(sec_var)
        z_val <- stats::qnorm(1 - (1 - conf_level) / 2)
        section_rows[[sec]] <- tibble::tibble(
          section = sec,
          estimate = sec_estimate,
          se = sec_se,
          ci_lower = sec_estimate - z_val * sec_se,
          ci_upper = sec_estimate + z_val * sec_se,
          n = cpue_res$estimates$n,
          prop_of_lake_total = NA_real_,
          data_available = TRUE
        )
      }
    }
  }

  result_df <- dplyr::bind_rows(section_rows)

  # Compute prop_of_lake_total (ungrouped path only; denominator = sum(TC_i))
  if (is.null(by_vars)) {
    present_rows <- result_df[!is.na(result_df$estimate), ]
    lake_sum <- sum(present_rows$estimate)
    result_df$prop_of_lake_total <- result_df$estimate / lake_sum
  }

  # Append .lake_total row if requested (ungrouped path only)
  if (aggregate_sections && is.null(by_vars)) {
    present_rows <- result_df[!is.na(result_df$estimate), ]
    lake_est <- sum(present_rows$estimate)
    lake_se <- sqrt(sum(present_rows$se^2))

    # CI for lake total using t-distribution (consistent with rate section helpers)
    full_svy <- get_variance_design(design$survey, variance_method) # nolint: object_usage_linter
    df <- as.numeric(survey::degf(full_svy))
    alpha <- 1 - conf_level
    t_crit <- qt(1 - alpha / 2, df = df)
    lake_ci_lower <- lake_est - t_crit * lake_se
    lake_ci_upper <- lake_est + t_crit * lake_se

    lake_row <- tibble::tibble(
      section = ".lake_total",
      estimate = lake_est,
      se = lake_se,
      ci_lower = lake_ci_lower,
      ci_upper = lake_ci_upper,
      n = nrow(present_rows),
      prop_of_lake_total = 1.0,
      data_available = TRUE
    )
    result_df <- dplyr::bind_rows(result_df, lake_row)
  }

  new_creel_estimates( # nolint: object_usage_linter
    estimates       = result_df,
    method          = "product-total-catch-sections",
    variance_method = variance_method,
    design          = design,
    conf_level      = conf_level,
    by_vars         = if (!is.null(by_vars)) c("section", by_vars) else "section",
    effort_target   = target
  )
}
