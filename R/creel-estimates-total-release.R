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
#' @param product_variance character. Variance formula for the product
#'   \eqn{E \times R}. \code{"goodman"} (default) uses Goodman's (1960)
#'   unbiased estimator \eqn{E^2 Var(R) + R^2 Var(E) - Var(E)Var(R)};
#'   \code{"first_order"} omits the cross-term, which is conservative. Both
#'   assume \eqn{E} and \eqn{R} are independently estimated. When both
#'   components are so imprecise that the subtraction would give a
#'   non-positive variance, the first-order value is used as a floor.
#' @param ci_type character. Shape of the confidence interval.
#'   \code{"symmetric"} (default) gives \eqn{\hat\theta \pm z \cdot SE}
#'   clamped at zero. \code{"log"} applies a log-transform for a
#'   strictly positive CI.
#'
#' @return A creel_estimates S3 object with method = "product-total-release".
#'   Estimates tibble has columns: estimate, se, ci_lower, ci_upper, n (plus
#'   any grouping columns). For bus-route and ice designs, returns a bus-route
#'   HT estimate with method = "ht-total-release" and a "site_contributions"
#'   attribute.
#'
#'   For sectioned designs the per-section rows carry
#'   \code{prop_of_lake_total}, the section's share of the lake-wide total, and
#'   \code{se_prop_of_lake_total}, its standard error. The share is a ratio
#'   whose numerator is one of its own denominator's terms, and whose numerator
#'   and denominator are each products of an effort and a rate estimated from
#'   different designs, so the error is derived by delta method from the same
#'   section variances and covariance the \code{.lake_total} row's own standard
#'   error is built from. The \code{.lake_total} row reports
#'   \code{se_prop_of_lake_total = 0}: its share of itself is exactly 1 by
#'   construction and was never estimated. A section with no data reports
#'   \code{NA} for both. Neither column is produced on the grouped path.
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
#'   catch = catch_total, effort = hours_fished, n_anglers = n_anglers,
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
#' @section Unit of the total:
#'
#' The reported `unit` is derived from the two factors, never declared. A
#' total is `"fish"` only when a per-angler-hour rate multiplies an effort in
#' angler-hours; anything else reports `NA_character_`, meaning unknown.
#'
#' Two ways to fail to cancel:
#'
#' * **The effort unit is unknown.** `design$effort_unit` is `NA` whenever
#'   `add_counts()` received no `period_length_col`, because a bare count
#'   column may be an instantaneous head count or effort the caller already
#'   expanded, and nothing can tell the two apart. Unknown times known is
#'   unknown. Supply `period_length_col` to make the total's unit derivable.
#' * **The denominators disagree.** A rate per party-hour times an effort in
#'   angler-hours is not a count of fish. Pass `n_anglers` to
#'   [add_interviews()] so the rate is per angler-hour.
#'
#' The estimate itself is unaffected in both cases -- only the label changes.
#' Until version 5.2.0 the unit was the literal `"fish"` regardless of either
#' factor (GH #213).
#'
#' @export
estimate_total_release <- function(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  target = c("sampled_days", "stratum_total", "period_total"),
  aggregate_sections = TRUE,
  missing_sections = "warn",
  product_variance = c("goodman", "first_order"),
  ci_type = c("symmetric", "log")
) {
  by_quo <- rlang::enquo(by)
  target <- match.arg(target)
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

  # Validate catch data (releases come from add_catch)
  if (is.null(design[["catch"]])) {
    cli::cli_abort(c(
      "No catch data available.",
      "x" = "Call {.fn add_catch} before estimating total release.",
      "i" = "Release data comes from catch records with catch_type = 'released'."
    ))
  }

  # Bus-route / ice dispatch (before standard survey NULL check), mirroring
  # estimate_total_harvest(). Without it the count-based product path ran on
  # bus-route designs: interview-based releases against a svytotal over count
  # rows, two unrelated effort bases in one design object (GH #110).
  if (!is.null(design$design_type) && design$design_type %in% c("bus_route", "ice")) {
    # See estimate_total_catch(): `by = species` aborted here because eval_select()
    # resolved against the interviews, which carry no species column (finding 19).
    by_info_br <- resolve_species_by(by_quo, design) # nolint: object_usage_linter
    by_vars_br <- by_info_br$interview_vars

    if (!is.null(by_info_br$species_var)) {
      if (is.null(design[["catch"]])) {
        cli::cli_abort(c(
          "Species-level total release requires catch data.",
          "x" = paste(
            "Call {.fn add_catch} before using species grouping in",
            "{.fn estimate_total_release}."
          )
        ))
      }

      return(estimate_total_species_br( # nolint: object_usage_linter
        design,
        species_col = by_info_br$species_var,
        interview_by_vars = by_vars_br,
        variance_method = variance,
        conf_level = conf_level,
        quantity = "release"
      ))
    }

    return(estimate_total_release_br(
      # nolint: object_usage_linter
      design,
      by_vars_br,
      variance,
      conf_level,
      verbose = FALSE
    ))
  }

  # Camera designs reach here with a count of arrivals where effort belongs, and
  # this function multiplies it by a rate per angler-hour (GH #214). Raised here
  # as well as in estimate_effort() because the totals call
  # estimate_effort_total() directly and never hear that refusal. First in the
  # block, so the camera case aborts instead of warning on its way out.
  refuse_camera_design(design, "estimate_total_release") # nolint: object_usage_linter

  # Effort x rate from here on: flag a party-hour rate meeting angler-hour effort
  warn_party_hours_product(design) # nolint: object_usage_linter
  check_product_units(design) # nolint: object_usage_linter
  # Totals call estimate_effort_total() directly, bypassing estimate_effort(),
  # so the finding-13 warning has to be raised here too or this path never
  # hears that the count column had no T_d applied.
  warn_missing_period_length(design) # nolint: object_usage_linter

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
      target = target,
      product_variance = product_variance,
      ci_type = ci_type
    )
    return(new_creel_estimates( # nolint: object_usage_linter
      # nolint: object_usage_linter
      estimates = tibble::as_tibble(estimates_df),
      method = "product-total-release",
      variance_method = variance,
      design = design,
      conf_level = conf_level,
      by_vars = by_info$all_vars,
      effort_target = target,
      unit = product_total_unit(rate_unit(design), design$effort_unit), # nolint: object_usage_linter
      se_expansion = attr(estimates_df, "se_expansion")
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
      target = target,
      product_variance = product_variance,
      ci_type = ci_type
    ))
  }

  # Standard (non-species) routing
  if (rlang::quo_is_null(by_quo)) {
    return(estimate_total_release_ungrouped(design, variance, conf_level, target = target, product_variance = product_variance, ci_type = ci_type)) # nolint: object_usage_linter
  } else {
    by_vars <- eval_select_count_by( # nolint: object_usage_linter
      by_quo,
      design,
      species_route = TRUE,
      error_call = rlang::caller_env()
    )
    validate_grouping_compatibility(design, by_vars) # nolint: object_usage_linter
    return(estimate_total_release_grouped(design, by_vars, variance, conf_level, target = target, product_variance = product_variance, ci_type = ci_type)) # nolint: object_usage_linter
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
  target = "sampled_days",
  product_variance = "goodman",
  ci_type = "symmetric"
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

  estimates_df <- compute_stratum_product_sum( # nolint: object_usage_linter
    # nolint: object_usage_linter
    effort_df = effort_df,
    rate_df = rpue_df,
    stratum_by_vars = strata_cols,
    interview_by_vars = NULL,
    conf_level = conf_level,
    rate_suffix = "rpue",
    product_variance = product_variance,
    ci_type = ci_type,
    expansion_se = named_expansion_se(effort_result, strata_cols), # nolint: object_usage_linter
    expansion_structure = expansion_group_structure(design), # nolint: object_usage_linter
    expansion_decomposition = named_expansion_decomposition(effort_result, strata_cols) # nolint: object_usage_linter
  )

  new_creel_estimates( # nolint: object_usage_linter
    estimates = tibble::as_tibble(estimates_df),
    method = "product-total-release",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL,
    effort_target = target,
    unit = product_total_unit(rate_unit(design), design$effort_unit), # nolint: object_usage_linter
    se_expansion = attr(estimates_df, "se_expansion")
  )
}

#' @keywords internal
#' @noRd
estimate_total_release_grouped <- function(
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
  )
  effort_df <- effort_result$estimates

  rpue_result <- rpue_for_stratum_product(design, stratum_by_vars, variance_method, conf_level)
  rpue_df <- rpue_result$estimates

  warn_missing_rate_strata(effort_df, rpue_df, stratum_by_vars, "estimate_total_release(by=)") # nolint: object_usage_linter

  estimates_df <- compute_stratum_product_sum( # nolint: object_usage_linter
    # nolint: object_usage_linter
    effort_df = effort_df,
    rate_df = rpue_df,
    stratum_by_vars = stratum_by_vars,
    interview_by_vars = if (length(by_vars) > 0L) by_vars else NULL,
    conf_level = conf_level,
    rate_suffix = "rpue",
    product_variance = product_variance,
    ci_type = ci_type,
    expansion_se = named_expansion_se(effort_result, stratum_by_vars), # nolint: object_usage_linter
    expansion_structure = expansion_group_structure(design), # nolint: object_usage_linter
    expansion_decomposition = named_expansion_decomposition(effort_result, stratum_by_vars) # nolint: object_usage_linter
  )

  new_creel_estimates( # nolint: object_usage_linter
    estimates = tibble::as_tibble(estimates_df),
    method = "product-total-release",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars,
    effort_target = target,
    unit = product_total_unit(rate_unit(design), design$effort_unit), # nolint: object_usage_linter
    se_expansion = attr(estimates_df, "se_expansion")
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
  target = "sampled_days",
  product_variance = "goodman",
  ci_type = "symmetric"
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

    sp_result <- compute_stratum_product_sum( # nolint: object_usage_linter
      # nolint: object_usage_linter
      effort_df = effort_df,
      rate_df = rate_no_sp,
      stratum_by_vars = stratum_by_vars,
      interview_by_vars = interview_by_vars,
      conf_level = conf_level,
      rate_suffix = "rpue",
      product_variance = product_variance,
      ci_type = ci_type,
      expansion_se = named_expansion_se(effort_result, stratum_by_vars), # nolint: object_usage_linter
      expansion_structure = expansion_group_structure(design), # nolint: object_usage_linter
      expansion_decomposition = named_expansion_decomposition(effort_result, stratum_by_vars) # nolint: object_usage_linter
    )

    sp_result[[species_col]] <- sp
    sp_result <- sp_result[c(species_col, setdiff(names(sp_result), species_col))]
    results_list[[i]] <- sp_result
  }

  out <- do.call(rbind, results_list)
  # rbind() drops attributes, so the component has to be rebuilt from the pieces
  # in the same row order rather than assumed to survive the bind -- the same
  # reason the expansion carriers are columns and not attributes.
  se_exp <- lapply(results_list, function(x) attr(x, "se_expansion"))
  if (!all(vapply(se_exp, is.null, logical(1L)))) {
    attr(out, "se_expansion") <- unlist(se_exp, use.names = FALSE)
  }
  out
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
    # No species route here: the section dispatch in the public function returns
    # before resolve_species_by(), so `by = <species>` never reaches species
    # apportionment on a sectioned design -- advertising it would be a dead end.
    by_vars <- eval_select_count_by( # nolint: object_usage_linter
      by_quo,
      design,
      species_route = FALSE,
      error_call = rlang::caller_env()
    )
  }

  section_rows <- vector("list", length(registered_sections))
  names(section_rows) <- registered_sections

  # A party-size estimate shared across sections is one random quantity common
  # to all of them, so aggregating to the lake row needs each section's rate and
  # expansion component, not only its standard error (GH #145).
  sec_rate <- stats::setNames(
    rep(NA_real_, length(registered_sections)),
    registered_sections
  )
  sec_expansion_se <- vector("list", length(registered_sections))
  names(sec_expansion_se) <- registered_sections
  sec_decomposition <- vector("list", length(registered_sections))
  names(sec_decomposition) <- registered_sections

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
        se_prop_of_lake_total = NA_real_,
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
        sec_rate[[sec]] <- rpue_est
        sec_expansion_se[[sec]] <- effort_res$se_expansion
        sec_decomposition[[sec]] <- effort_res$expansion_decomposition
        sec_estimate <- effort_est * rpue_est
        sec_var <- product_total_variance(
          effort_est,
          effort_se,
          rpue_est,
          rpue_se,
          product_variance
        )
        sec_se <- sqrt(sec_var)
        sec_n <- rpue_res$estimates$n
        z_val <- stats::qt(1 - (1 - conf_level) / 2, df = max(1L, sec_n - 1L))
        section_rows[[sec]] <- tibble::tibble(
          section = sec,
          estimate = sec_estimate,
          se = sec_se,
          ci_lower = if (ci_type == "log" && sec_estimate > 0) sec_estimate * exp(-z_val * sec_se / sec_estimate) else pmax(0, sec_estimate - z_val * sec_se),
          ci_upper = if (ci_type == "log" && sec_estimate > 0) sec_estimate * exp(z_val * sec_se / sec_estimate) else sec_estimate + z_val * sec_se,
          n = sec_n,
          prop_of_lake_total = NA_real_,
          se_prop_of_lake_total = NA_real_,
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

  # Row-aligned party-size component. Each section's own row is a single total,
  # so it carries just its own contribution; the lake row's combined one is
  # appended with the row below.
  expansion_vec <- section_expansion_vector(sec_expansion_se) # nolint: object_usage_linter
  decomposition_list <- section_decomposition_list(sec_decomposition) # nolint: object_usage_linter
  se_expansion <- if (is.null(expansion_vec)) NULL else unname(abs(sec_rate * expansion_vec))
  # `new_creel_estimates()` requires one entry per row of `estimates`, NULL
  # exactly when `se_expansion` is. A component was reported with no
  # decomposition behind it, so `se_expansion` was recoverable from nothing and
  # a combination over a wider partition had no group index to work from
  # (GH #238).
  #
  # Scaled by the section's own rate for the same reason `se_expansion` is:
  # these are contributions to a product total, which keeps the per-row identity
  # sqrt(sum(decomposition^2)) == se_expansion true on the reported scale.
  expansion_decomposition <- if (is.null(expansion_vec)) {
    NULL
  } else if (is.null(decomposition_list)) {
    # Unreachable while every path that returns a component also attaches its
    # decomposition. Written as a fill rather than a branch to NULL so the entry
    # count stays aligned to the rows whatever arrives.
    vector("list", length(expansion_vec))
  } else {
    unname(Map(
      function(d, r) if (is.null(d)) NULL else d * r,
      decomposition_list,
      as.numeric(sec_rate)
    ))
  }

  # Standard error of prop_of_lake_total (ungrouped path only, GH #243). The
  # combination is hoisted out of the lake row below so both come from the one
  # call: the proportion's denominator variance is then literally the variance
  # the lake row reports, and an unresolvable geometry warns once, not twice.
  lake <- NULL
  if (is.null(by_vars)) {
    present_rows <- result_df[!is.na(result_df$estimate), ]
    present <- as.character(present_rows$section)
    lake <- combine_section_variances( # nolint: object_usage_linter
      design,
      section_var = present_rows$se^2,
      rate = sec_rate[present],
      expansion_se = expansion_vec[present],
      decomposition = decomposition_list[present]
    )
    result_df$se_prop_of_lake_total <- NA_real_
    result_df$se_prop_of_lake_total[!is.na(result_df$estimate)] <-
      section_prop_of_lake_se( # nolint: object_usage_linter
        section_est = present_rows$estimate,
        section_var = present_rows$se^2,
        lake_var = lake$se^2,
        cross = section_cross_covariance( # nolint: object_usage_linter
          rate = sec_rate[present],
          expansion_se = expansion_vec[present],
          structure = expansion_group_structure(design, design[["section_col"]]), # nolint: object_usage_linter
          decomposition = decomposition_list[present],
          n = nrow(present_rows)
        )
      )
  }

  # Append .lake_total row if requested (ungrouped path only)
  if (aggregate_sections && is.null(by_vars)) {
    present_rows <- result_df[!is.na(result_df$estimate), ]
    lake_est <- sum(present_rows$estimate)

    present <- as.character(present_rows$section)
    lake_se <- lake$se
    if (!is.null(se_expansion)) {
      se_expansion <- c(se_expansion, lake$component %||% NA_real_)
    }
    if (!is.null(expansion_decomposition)) {
      # Keyed by party-size group rather than by section -- the groups summed
      # across the sections -- which is exactly what a wider combination needs.
      expansion_decomposition <- c(
        expansion_decomposition,
        list(combine_section_decompositions( # nolint: object_usage_linter
          sec_rate[present],
          decomposition_list[present]
        ))
      )
    }

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
      se_prop_of_lake_total = 0,
      data_available = TRUE
    )
    result_df <- dplyr::bind_rows(result_df, lake_row)
  }

  new_creel_estimates( # nolint: object_usage_linter
    estimates = result_df,
    method = "product-total-release-sections",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = if (!is.null(by_vars)) c("section", by_vars) else "section",
    effort_target = target,
    unit = product_total_unit(rate_unit(design), design$effort_unit), # nolint: object_usage_linter
    se_expansion = se_expansion,
    expansion_decomposition = expansion_decomposition
  )
}
