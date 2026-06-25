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
#' @param target Character string specifying the effort domain supplied to
#'   [estimate_effort()]. Options are `"sampled_days"` (default),
#'   `"stratum_total"`, or `"period_total"`. This controls which effort domain
#'   is multiplied by release rate so total release stays aligned with the
#'   requested temporal target.
#' @param aggregate_sections Logical. When the design was created with
#'   \code{\link{add_sections}}, should a \code{.lake_total} row be appended
#'   that sums the per-section estimates? Default \code{TRUE}. Set to
#'   \code{FALSE} to return only the per-section rows without the lake total.
#' @param missing_sections Character(1). Action when a registered section is
#'   absent from either count data or interview data: \code{"warn"} (default)
#'   inserts an NA row with \code{data_available = FALSE}, \code{"error"}
#'   raises a hard error.
#'
#' @return A creel_estimates S3 object with method = "product-total-release".
#'   Estimates tibble has columns: estimate, se, ci_lower, ci_upper, n (plus
#'   any grouping columns).
#'
#' @details
#' Total release is computed as Effort x RPUE. Variance is propagated using the
#' delta method: Var(E x R) = E^2 * Var(R) + R^2 * Var(E).
#'
#' \strong{Sectioned designs:}
#' When \code{\link{add_sections}} has been called on the design, each section
#' is estimated independently. The lake-wide total is \code{sum(TR_i)}, not
#' \code{E_total * RPUE_pooled}. The lake-wide SE uses the zero-covariance
#' assumption: \code{sqrt(sum(se_i^2))}.
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
#' @family "Estimation"
#' @export
estimate_total_release <- function(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  target = c("sampled_days", "stratum_total", "period_total"),
  aggregate_sections = TRUE,
  missing_sections = "warn"
) {
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
    estimates_df <- estimate_total_release_species(
      # nolint: object_usage_linter
      design,
      species_col = by_info$species_var,
      interview_by_vars = by_info$interview_vars,
      variance_method = variance,
      conf_level = conf_level,
      target = target
    )
    return(new_creel_estimates(
      # nolint: object_usage_linter
      estimates = tibble::as_tibble(estimates_df),
      method = "product-total-release",
      variance_method = variance,
      design = design,
      conf_level = conf_level,
      by_vars = by_info$all_vars,
      effort_target = target
    ))
  }

  # Section dispatch guard (v0.7.0+ — only fires when add_sections() was called)
  if (!is.null(design[["sections"]])) {
    return(estimate_total_release_sections(
      # nolint: object_usage_linter
      design,
      by_quo,
      variance,
      conf_level,
      aggregate_sections,
      missing_sections,
      target = target
    ))
  }

  # Standard (non-species) routing
  if (rlang::quo_is_null(by_quo)) {
    return(estimate_total_release_ungrouped(design, variance, conf_level, target = target)) # nolint: object_usage_linter
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
    return(estimate_total_release_grouped(design, by_vars, variance, conf_level, target = target)) # nolint: object_usage_linter
  }
}

#' @keywords internal
#' @noRd
rpue_for_stratum_product <- function(design, by_vars, variance_method, conf_level) {
  strata_cols <- design$strata_cols
  strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0L) {
    stats::reformulate(strata_cols)
  } else {
    NULL
  }

  release_data <- estimate_release_build_data(design, species = NULL)
  release_data$.release_effort <- release_data[[design$angler_effort_col]]

  design_rel <- design
  design_rel$interviews <- release_data
  design_rel$catch_col <- ".release_count"
  design_rel$angler_effort_col <- ".release_effort"
  design_rel$interview_survey <- build_interview_survey(
    release_data,
    strata = strata_formula
  )

  if (length(by_vars) == 0L) {
    result <- estimate_cpue_total(design_rel, variance_method, conf_level)
  } else {
    result <- estimate_cpue_grouped(design_rel, by_vars, variance_method, conf_level)
  }
  result$method <- "ratio-of-means-rpue"
  result
}

#' @keywords internal
#' @noRd
estimate_total_release_ungrouped <- function(
  design,
  variance_method,
  conf_level,
  target = "sampled_days"
) {
  # nolint: object_length_linter
  strata_cols <- design$strata_cols %||% character(0)

  if (length(strata_cols) == 0L) {
    effort_result <- estimate_effort_total(design, variance_method, conf_level, target = target)
  } else {
    effort_result <- estimate_effort_grouped(
      design,
      strata_cols,
      variance_method,
      conf_level,
      target = target
    )
  }
  effort_df <- effort_result$estimates

  rpue_result <- rpue_for_stratum_product(design, strata_cols, variance_method, conf_level)
  rpue_df <- rpue_result$estimates

  warn_missing_rate_strata(effort_df, rpue_df, strata_cols, "estimate_total_release") # nolint: object_usage_linter

  estimates_df <- compute_stratum_product_sum(
    # nolint: object_usage_linter
    effort_df = effort_df,
    rate_df = rpue_df,
    stratum_by_vars = strata_cols,
    interview_by_vars = NULL,
    conf_level = conf_level,
    rate_suffix = "rpue"
  )

  new_creel_estimates(
    # nolint: object_usage_linter
    estimates = tibble::as_tibble(estimates_df),
    method = "product-total-release",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL,
    effort_target = target
  )
}

#' @keywords internal
#' @noRd
estimate_total_release_grouped <- function(
  design,
  by_vars,
  variance_method,
  conf_level,
  target = "sampled_days"
) {
  strata_cols <- design$strata_cols %||% character(0)
  stratum_by_vars <- unique(c(strata_cols, by_vars))

  effort_result <- estimate_effort_grouped(
    design,
    stratum_by_vars,
    variance_method,
    conf_level,
    target = target
  )
  effort_df <- effort_result$estimates

  rpue_result <- rpue_for_stratum_product(design, stratum_by_vars, variance_method, conf_level)
  rpue_df <- rpue_result$estimates

  warn_missing_rate_strata(effort_df, rpue_df, stratum_by_vars, "estimate_total_release(by=)") # nolint: object_usage_linter

  estimates_df <- compute_stratum_product_sum(
    # nolint: object_usage_linter
    effort_df = effort_df,
    rate_df = rpue_df,
    stratum_by_vars = stratum_by_vars,
    interview_by_vars = if (length(by_vars) > 0L) by_vars else NULL,
    conf_level = conf_level,
    rate_suffix = "rpue"
  )

  new_creel_estimates(
    # nolint: object_usage_linter
    estimates = tibble::as_tibble(estimates_df),
    method = "product-total-release",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars,
    effort_target = target
  )
}

#' Species-level total release estimation
#'
#' @keywords internal
#' @noRd
estimate_total_release_species <- function(
  design,
  species_col,
  interview_by_vars,
  variance_method,
  conf_level,
  target = "sampled_days"
) {
  strata_cols <- design$strata_cols %||% character(0)
  stratum_by_vars <- unique(c(strata_cols, interview_by_vars))

  # Per-stratum species release rates
  rate_by <- if (length(stratum_by_vars) > 0L) stratum_by_vars else NULL
  all_rate_df <- estimate_release_rate_species(
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
    context = "species total release"
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
      rate_suffix = "rpue"
    )

    sp_result[[species_col]] <- sp
    sp_result <- sp_result[c(species_col, setdiff(names(sp_result), species_col))]
    results_list[[i]] <- sp_result
  }

  do.call(rbind, results_list)
}

#' Per-section total release estimation (product estimator)
#'
#' @keywords internal
#' @noRd
estimate_total_release_sections <- function(
  design,
  by_quo,
  variance_method, # nolint: object_length_linter
  conf_level,
  aggregate_sections,
  missing_sections,
  target = "sampled_days"
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
        result <- estimate_total_release_grouped(
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
        # Ungrouped path: call internal helpers directly to bypass sample-size validation.
        # Build release data inline (mirrors estimate_release_rate_sections pattern).
        effort_res <- estimate_effort_total(
          sec_design,
          variance_method,
          conf_level,
          target = target
        ) # nolint: object_usage_linter
        release_data <- estimate_release_build_data(sec_design, species = NULL) # nolint: object_usage_linter
        release_data$.release_effort <- release_data[[sec_design$angler_effort_col]]
        design_rel <- sec_design
        design_rel$interviews <- release_data
        design_rel$catch_col <- ".release_count"
        design_rel$angler_effort_col <- ".release_effort"
        strata_cols <- sec_design$strata_cols
        strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0L) {
          stats::reformulate(strata_cols)
        } else {
          NULL
        }
        design_rel$interview_survey <- build_interview_survey(
          # nolint: object_usage_linter
          release_data,
          strata = strata_formula
        )
        rpue_res <- estimate_cpue_total(design_rel, variance_method, conf_level) # nolint: object_usage_linter
        effort_est <- effort_res$estimates$estimate
        rpue_est <- rpue_res$estimates$estimate
        effort_se <- effort_res$estimates$se
        rpue_se <- rpue_res$estimates$se
        sec_estimate <- effort_est * rpue_est
        sec_var <- (effort_est^2 * rpue_se^2) + (rpue_est^2 * effort_se^2)
        sec_se <- sqrt(sec_var)
        sec_n <- rpue_res$estimates$n
        z_val <- stats::qt(1 - (1 - conf_level) / 2, df = max(1L, sec_n - 1L))
        section_rows[[sec]] <- tibble::tibble(
          section = sec,
          estimate = sec_estimate,
          se = sec_se,
          ci_lower = sec_estimate - z_val * sec_se,
          ci_upper = sec_estimate + z_val * sec_se,
          n = sec_n,
          prop_of_lake_total = NA_real_,
          data_available = TRUE
        )
      }
    }
  }

  result_df <- dplyr::bind_rows(section_rows)

  # Compute prop_of_lake_total (ungrouped path only; denominator = sum(TR_i))
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

  new_creel_estimates(
    # nolint: object_usage_linter
    estimates = result_df,
    method = "product-total-release-sections",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = if (!is.null(by_vars)) c("section", by_vars) else "section",
    effort_target = target
  )
}
