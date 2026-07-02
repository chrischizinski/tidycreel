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
#' @param target Character string specifying the effort domain supplied to
#'   [estimate_effort()]. Options are `"sampled_days"` (default),
#'   `"stratum_total"`, or `"period_total"`. This controls which effort domain
#'   is multiplied by HPUE so total harvest stays aligned with the requested
#'   temporal target.
#' @param aggregate_sections Logical. When the design was created with
#'   \code{\link{add_sections}}, should a \code{.lake_total} row be appended
#'   that sums the per-section estimates? Default \code{TRUE}. Set to
#'   \code{FALSE} to return only the per-section rows without the lake total.
#' @param missing_sections Character(1). Action when a registered section is
#'   absent from either count data or interview data: \code{"warn"} (default)
#'   inserts an NA row with \code{data_available = FALSE}, \code{"error"}
#'   raises a hard error.
#' @param ci_method character. \code{"delta"} (default) returns only
#'   delta-method CIs. \code{"bootstrap"} additionally returns
#'   \code{ci_lo_boot}/\code{ci_hi_boot} using survey bootstrap resampling.
#'   Only applies to bus-route/ice designs.
#' @param product_variance character. Variance formula for the product
#'   \eqn{E \times H}. \code{"goodman"} (default) uses the exact Goodman
#'   (1960) three-term formula. \code{"first_order"} drops the cross-term.
#' @param ci_type character. Shape of the confidence interval.
#'   \code{"symmetric"} (default) gives \eqn{\hat\theta \pm z \cdot SE}
#'   clamped at zero. \code{"log"} applies a log-transform for a
#'   strictly positive CI.
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
#' Variance is computed via a stratified delta-method sum in
#' \code{compute_stratum_product_sum()}, not via \code{survey::svycontrast()}.
#'
#' \strong{Sectioned designs:}
#' When \code{\link{add_sections}} has been called on the design, each section
#' is estimated independently. The lake-wide total is \code{sum(TH_i)}, not
#' \code{E_total * HPUE_pooled}. The lake-wide SE uses the zero-covariance
#' assumption: \code{sqrt(sum(se_i^2))}.
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
#'   catch = catch_total, harvest = catch_kept, effort = hours_fished,
#'   trip_status = trip_status, trip_duration = trip_duration
#' )
#'
#' # Estimate total harvest
#' total_harvest <- estimate_total_harvest(design)
#' print(total_harvest)
#'
#' # Compare components
#' effort_est <- estimate_effort(design)
#' hpue_est <- estimate_harvest_rate(design)
#' # total_harvest$estimates$estimate approximately equals effort_est * hpue_est
#'
#' # Note: Grouped estimation requires n >= 10 per group
#' # Check sample sizes before grouping:
#' # table(design$interviews$day_type)
#' # total_harvest_by_type <- estimate_total_harvest(design, by = day_type)
#'
#' @seealso \code{\link{estimate_effort}}, \code{\link{estimate_harvest_rate}},
#'   \code{\link{estimate_total_catch}}
#' @family "Estimation"
#' @export
estimate_total_harvest <- function(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  target = c("sampled_days", "stratum_total", "period_total"),
  aggregate_sections = TRUE,
  missing_sections = "warn",
  ci_method = c("delta", "bootstrap"),
  product_variance = c("goodman", "first_order"),
  ci_type = c("symmetric", "log")
) {
  # Capture by parameter BEFORE validation
  by_quo <- rlang::enquo(by)
  target <- match.arg(target)
  ci_method <- match.arg(ci_method)
  product_variance <- match.arg(product_variance)
  ci_type <- match.arg(ci_type)

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
    return(estimate_total_harvest_br(
      # nolint: object_usage_linter
      design,
      by_vars_br,
      variance,
      conf_level,
      verbose = FALSE,
      ci_method = ci_method
    ))
  }

  # Validate design compatibility (counts AND interviews required)
  validate_design_compatibility(design) # nolint: object_usage_linter

  # Detect species-level grouping
  by_info <- resolve_species_by(by_quo, design) # nolint: object_usage_linter

  if (!is.null(by_info$species_var)) {
    if (is.null(design[["catch"]])) {
      cli::cli_abort(c(
        "Species-level total harvest requires catch data.",
        "x" = "Call {.fn add_catch} before using species grouping in {.fn estimate_total_harvest}."
      ))
    }
    estimates_df <- estimate_total_harvest_species(
      # nolint: object_usage_linter
      design,
      species_col = by_info$species_var,
      interview_by_vars = by_info$interview_vars,
      variance_method = variance,
      conf_level = conf_level,
      target = target,
      product_variance = product_variance
    )
    return(new_creel_estimates(
      # nolint: object_usage_linter
      estimates = tibble::as_tibble(estimates_df),
      method = "product-total-harvest",
      variance_method = variance,
      design = design,
      conf_level = conf_level,
      by_vars = by_info$all_vars,
      effort_target = target
    ))
  }

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

  # Section dispatch guard (v0.7.0+ — only fires when add_sections() was called)
  if (!is.null(design[["sections"]])) {
    return(estimate_total_harvest_sections(
      # nolint: object_usage_linter
      design,
      by_quo,
      variance,
      conf_level,
      aggregate_sections,
      missing_sections,
      target = target,
      product_variance = product_variance,
      ci_type = ci_type
    ))
  }

  # Route to grouped or ungrouped estimation
  if (rlang::quo_is_null(by_quo)) {
    # Ungrouped estimation
    return(estimate_total_harvest_ungrouped(design, variance, conf_level, target = target, product_variance = product_variance, ci_type = ci_type)) # nolint: object_usage_linter
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

    return(estimate_total_harvest_grouped(design, by_vars, variance, conf_level, target = target, product_variance = product_variance, ci_type = ci_type)) # nolint: object_usage_linter
  }
}

#' Ungrouped total harvest estimation (stratified-sum product estimator)
#'
#' Uses compute_stratum_product_sum() with per-stratum effort and HPUE so that
#' total harvest equals sum(E_h * HPUE_h) across calendar strata h, not the
#' biased pooled-stratum product E_total * HPUE_pooled.
#'
#' @keywords internal
#' @noRd
estimate_total_harvest_ungrouped <- function(
  design,
  variance_method,
  conf_level,
  target = "sampled_days",
  product_variance = "goodman",
  ci_type = "symmetric"
) {
  # nolint: object_length_linter
  strata_cols <- design$strata_cols %||% character(0)

  # Per-stratum effort
  if (length(strata_cols) == 0L) {
    effort_result <- estimate_effort_total(design, variance_method, conf_level, target = target) # nolint: object_usage_linter
  } else {
    effort_result <- estimate_effort_grouped(
      design,
      strata_cols,
      variance_method,
      conf_level,
      target = target
    ) # nolint: object_usage_linter
  }
  effort_df <- effort_result$estimates

  # Per-stratum HPUE
  if (length(strata_cols) == 0L) {
    hpue_result <- estimate_harvest_total(design, variance_method, conf_level) # nolint: object_usage_linter
  } else {
    hpue_result <- estimate_harvest_grouped(design, strata_cols, variance_method, conf_level) # nolint: object_usage_linter
  }
  hpue_df <- hpue_result$estimates

  warn_missing_rate_strata(effort_df, hpue_df, strata_cols, "estimate_total_harvest") # nolint: object_usage_linter

  # Stratified-sum product estimator: sum(E_h * HPUE_h) across strata h
  estimates_df <- compute_stratum_product_sum(
    # nolint: object_usage_linter
    effort_df = effort_df,
    rate_df = hpue_df,
    stratum_by_vars = strata_cols,
    interview_by_vars = NULL,
    conf_level = conf_level,
    rate_suffix = "hpue",
    product_variance = product_variance,
    ci_type = ci_type
  )

  new_creel_estimates(
    # nolint: object_usage_linter
    estimates = tibble::as_tibble(estimates_df),
    method = "product-total-harvest",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL,
    effort_target = target
  )
}

#' Grouped total harvest estimation (stratified-sum product estimator)
#'
#' Fixes combined-ratio bug: groups by union(strata_cols, by_vars) so per-stratum
#' products E_h * HPUE_h are computed first, then summed within each by_vars group.
#'
#' @keywords internal
#' @noRd
estimate_total_harvest_grouped <- function(
  design,
  by_vars,
  variance_method,
  conf_level,
  target = "sampled_days",
  product_variance = "goodman",
  ci_type = "symmetric"
) {
  strata_cols <- design$strata_cols %||% character(0)
  stratum_by_vars <- unique(c(strata_cols, by_vars))

  effort_result <- estimate_effort_grouped(
    design,
    stratum_by_vars,
    variance_method,
    conf_level,
    target = target
  ) # nolint: object_usage_linter
  effort_df <- effort_result$estimates

  hpue_result <- estimate_harvest_grouped(design, stratum_by_vars, variance_method, conf_level) # nolint: object_usage_linter
  hpue_df <- hpue_result$estimates

  warn_missing_rate_strata(effort_df, hpue_df, stratum_by_vars, "estimate_total_harvest(by=)") # nolint: object_usage_linter

  estimates_df <- compute_stratum_product_sum(
    # nolint: object_usage_linter
    effort_df = effort_df,
    rate_df = hpue_df,
    stratum_by_vars = stratum_by_vars,
    interview_by_vars = if (length(by_vars) > 0L) by_vars else NULL,
    conf_level = conf_level,
    rate_suffix = "hpue",
    product_variance = product_variance,
    ci_type = ci_type
  )

  new_creel_estimates(
    # nolint: object_usage_linter
    estimates = tibble::as_tibble(estimates_df),
    method = "product-total-harvest",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars,
    effort_target = target
  )
}

#' Species-level total harvest estimation
#'
#' @keywords internal
#' @noRd
estimate_total_harvest_species <- function(
  design,
  species_col,
  interview_by_vars,
  variance_method,
  conf_level,
  target = "sampled_days",
  product_variance = "goodman",
  ci_type = "symmetric"
) {
  strata_cols <- design$strata_cols %||% character(0)
  stratum_by_vars <- unique(c(strata_cols, interview_by_vars))

  # Per-stratum species HPUE
  rate_by <- if (length(stratum_by_vars) > 0L) stratum_by_vars else NULL
  all_rate_df <- estimate_hpue_species(
    # nolint: object_usage_linter
    design,
    species_col = species_col,
    interview_by_vars = rate_by,
    variance_method = variance_method,
    conf_level = conf_level,
    validate = FALSE
  )

  # Per-stratum effort
  if (length(stratum_by_vars) == 0L) {
    effort_result <- estimate_effort_total(design, variance_method, conf_level, target = target) # nolint: object_usage_linter
  } else {
    effort_result <- estimate_effort_grouped(
      design,
      stratum_by_vars,
      variance_method,
      conf_level,
      target = target
    ) # nolint: object_usage_linter
  }
  effort_df <- effort_result$estimates

  warn_missing_rate_strata(
    # nolint: object_usage_linter
    effort_df = effort_df,
    rate_df = all_rate_df[, setdiff(names(all_rate_df), species_col), drop = FALSE],
    stratum_by_vars = stratum_by_vars,
    context = "species total harvest"
  )

  all_species <- sort(unique(design[["catch"]][[species_col]]))
  results_list <- vector("list", length(all_species))

  for (i in seq_along(all_species)) {
    sp <- all_species[[i]]
    rate_sp_df <- all_rate_df[all_rate_df[[species_col]] == sp, , drop = FALSE]
    rate_no_sp <- rate_sp_df[, setdiff(names(rate_sp_df), species_col), drop = FALSE]

    sp_result <- compute_stratum_product_sum(
      # nolint: object_usage_linter
      effort_df = effort_df,
      rate_df = rate_no_sp,
      stratum_by_vars = stratum_by_vars,
      interview_by_vars = interview_by_vars,
      conf_level = conf_level,
      rate_suffix = "hpue",
      product_variance = product_variance,
      ci_type = ci_type
    )

    sp_result[[species_col]] <- sp
    sp_result <- sp_result[c(species_col, setdiff(names(sp_result), species_col))]
    results_list[[i]] <- sp_result
  }

  do.call(rbind, results_list)
}

#' Per-section total harvest estimation (product estimator)
#'
#' @keywords internal
#' @noRd
estimate_total_harvest_sections <- function(
  design,
  by_quo,
  variance_method, # nolint: object_length_linter
  conf_level,
  aggregate_sections,
  missing_sections,
  target = "sampled_days",
  product_variance = "goodman",
  ci_type = "symmetric"
) {
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

  # Resolve by= ONCE before the section loop
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
        result <- estimate_total_harvest_grouped(
          # nolint: object_usage_linter
          sec_design,
          by_vars,
          variance_method,
          conf_level,
          target = target
        )
        row_df <- tibble::add_column(result$estimates, section = sec, .before = 1)
        row_df$data_available <- TRUE
        section_rows[[sec]] <- row_df
      } else {
        # Ungrouped path: call internal helpers directly to bypass sample-size validation
        effort_res <- estimate_effort_total(
          sec_design,
          variance_method,
          conf_level,
          target = target
        ) # nolint: object_usage_linter
        hpue_res <- estimate_harvest_total(sec_design, variance_method, conf_level) # nolint: object_usage_linter
        effort_est <- effort_res$estimates$estimate
        hpue_est <- hpue_res$estimates$estimate
        effort_se <- effort_res$estimates$se
        hpue_se <- hpue_res$estimates$se
        sec_estimate <- effort_est * hpue_est
        cross_term <- if (product_variance == "goodman") hpue_se^2 * effort_se^2 else 0
        sec_var <- (effort_est^2 * hpue_se^2) + (hpue_est^2 * effort_se^2) + cross_term
        sec_se <- sqrt(sec_var)
        sec_n <- hpue_res$estimates$n
        z_val <- stats::qt(1 - (1 - conf_level) / 2, df = max(1L, sec_n - 1L))
        section_rows[[sec]] <- tibble::tibble(
          section = sec,
          estimate = sec_estimate,
          se = sec_se,
          ci_lower = if (ci_type == "log" && sec_estimate > 0) sec_estimate * exp(-z_val * sec_se / sec_estimate) else pmax(0, sec_estimate - z_val * sec_se),
          ci_upper = if (ci_type == "log" && sec_estimate > 0) sec_estimate * exp(z_val * sec_se / sec_estimate) else sec_estimate + z_val * sec_se,
          n = sec_n,
          prop_of_lake_total = NA_real_,
          data_available = TRUE
        )
      }
    }
  }

  result_df <- dplyr::bind_rows(section_rows)

  # Compute prop_of_lake_total (ungrouped path only; denominator = sum(TH_i))
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

    # CI for lake total: sum(section n) - n_sections (consistent with compute_stratum_product_sum)
    df_lake <- max(1L, sum(present_rows$n) - nrow(present_rows))
    t_crit <- qt(1 - (1 - conf_level) / 2, df = df_lake)
    lake_ci_lower <- if (ci_type == "log" && lake_est > 0) lake_est * exp(-t_crit * lake_se / lake_est) else pmax(0, lake_est - t_crit * lake_se)
    lake_ci_upper <- if (ci_type == "log" && lake_est > 0) lake_est * exp(t_crit * lake_se / lake_est) else lake_est + t_crit * lake_se

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

  new_creel_estimates(
    # nolint: object_usage_linter
    estimates = result_df,
    method = "product-total-harvest-sections",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = if (!is.null(by_vars)) c("section", by_vars) else "section",
    effort_target = target
  )
}
