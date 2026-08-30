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
#' @param use_trips Character. Which interviews contribute to CPUE. `"complete"`
#'   (default) uses only completed trips; `"all"` includes incomplete trips.
#'   Incomplete trips have lower observed CPUE (angler may catch more after
#'   interview), so `"all"` introduces a downward bias.
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
#' @param ci_method character. \code{"delta"} (default) returns only
#'   delta-method CIs. \code{"bootstrap"} additionally returns
#'   \code{ci_lo_boot}/\code{ci_hi_boot} using survey bootstrap resampling.
#'   Only applies to bus-route/ice designs.
#' @param product_variance character. Variance formula for the product
#'   \eqn{E \times C}. \code{"goodman"} (default) uses Goodman's (1960)
#'   unbiased estimator \eqn{E^2 Var(C) + C^2 Var(E) - Var(E)Var(C)}; the
#'   cross-term is subtracted because substituting estimates for the unknown
#'   means leaves the two-term plug-in biased upward. \code{"first_order"}
#'   omits it (classical two-term delta method), which is conservative.
#'   Both assume \eqn{E} and \eqn{C} are independently estimated. When both
#'   components are so imprecise that the subtraction would give a
#'   non-positive variance, the first-order value is used as a floor.
#' @param ci_type character. Shape of the confidence interval.
#'   \code{"symmetric"} (default) gives the standard \eqn{\hat\theta \pm z
#'   \cdot SE} interval clamped at zero. \code{"log"} applies a
#'   log-transform so the CI stays positive:
#'   \eqn{[\hat\theta e^{-z SE/\hat\theta},\; \hat\theta e^{z SE/\hat\theta}]}.
#'
#' @return A creel_estimates S3 object with method = "product-total-catch".
#'   For bus-route and ice designs, returns a bus-route HT estimate with
#'   method = "ht-total-catch" and a "site_contributions" attribute.
#'   For sectioned designs, returns per-section rows plus (by default) a
#'   \code{.lake_total} row. The lake-wide total is computed as
#'   \code{sum(TC_i)} over sections, never as \code{E_total * CPUE_pooled}.
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
#' Total catch is computed as Effort × CPUE. Variance is propagated using the
#' delta method, which accounts for uncertainty in both estimates. The formula
#' for independent estimates is approximately:
#'
#' \deqn{Var(E \times C) \approx E^2 \cdot Var(C) + C^2 \cdot Var(E)}
#'
#' Variance is computed via a stratified delta-method sum in
#' \code{compute_stratum_product_sum()}, not via \code{survey::svycontrast()}.
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
#' @section What the pooled total assumes:
#' Effort comes from the counts, so a total can only be broken down by an
#' attribute the counts classify. When a domain appears in the interviews but not
#' in the counts, the only available total is \code{E_total * rate_pooled},
#' where the pooled rate is a ratio of means weighted by the \emph{interview
#' sample's} composition over that domain. Had the domain been classified in the
#' counts it would be a stratum and the total would be
#' \code{sum(E_h * rate_h)}, which is unbiased whatever the interview
#' composition happens to be.
#'
#' The two agree only when the interview sample's effort composition matches the
#' true effort composition, and interview selection is not proportional to
#' effort by construction of the standard designs. Access interviews intercept
#' completed trips, over-representing anglers who must return to a fixed point:
#' Malvestuto (1996) notes that it is \dQuote{usually impossible to sample all
#' angler types proportional to their level of effort}, a particular problem for
#' bank anglers who may be \dQuote{widely dispersed along the shoreline and not
#' associated with well-defined access sites}. Roving interviews are
#' length-biased toward longer trips. So the mix differs by design rather than by
#' accident, and where levels differ in rate the pooled total inherits that
#' difference.
#'
#' None of this is verifiable from within the data, because the counts carry no
#' composition to compare against. Where it is detectable -- the interviews hold
#' an unclassified categorical domain and the crude rate differs materially
#' across its levels -- a warning of class
#' \code{creel_warning_pooled_domain_mix} is raised. It flags a risk, not a
#' defect. Classifying the domain in the count data is what removes the
#' assumption.
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
#'   catch = catch_total, effort = hours_fished, n_anglers = n_anglers,
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
estimate_total_catch <- function(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  target = c("sampled_days", "stratum_total", "period_total"),
  use_trips = c("complete", "all"),
  aggregate_sections = TRUE,
  missing_sections = "warn",
  verbose = FALSE,
  ci_method = c("delta", "bootstrap"),
  product_variance = c("goodman", "first_order"),
  ci_type = c("symmetric", "log")
) {
  # Capture by parameter BEFORE validation
  by_quo <- rlang::enquo(by)
  target <- match.arg(target)
  use_trips <- match.arg(use_trips)
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
    # These designs estimate a completed-trip total; "all" has no estimator here.
    # See br_complete_trips_only() for why an uncompleted trip breaks the HT sum
    # in two directions at once.
    if (identical(use_trips, "all")) {
      cli::cli_abort(c(
        "{.code use_trips = \"all\"} is not available for {.val {design$design_type}} designs.",
        "x" = paste(
          "The bus-route total is a completed-trip Horvitz-Thompson sum;",
          "an uncompleted trip contributes catch-so-far under the inclusion",
          "probability of a completed one."
        ),
        "i" = paste(
          "Incomplete trips support a rate, not a total; see",
          "{.code estimate_catch_rate(use_trips = \"incomplete\")}."
        )
      ))
    }
    if (verbose) {
      cli::cli_inform(c(
        "i" = "Using bus-route estimator (Jones & Pollock 2012, Eq. 19.5)"
      ))
    }
    # Resolved against interviews *plus* the species column: eval_select() on the
    # interviews alone aborts on `by = species`, which is a grouping this
    # estimator supports on every other design type (finding 19).
    by_info_br <- resolve_species_by(by_quo, design) # nolint: object_usage_linter
    by_vars_br <- by_info_br$interview_vars

    if (!is.null(by_info_br$species_var)) {
      if (is.null(design[["catch"]])) {
        cli::cli_abort(c(
          "Species-level total catch requires catch data.",
          "x" = "Call {.fn add_catch} before using species grouping in {.fn estimate_total_catch}."
        ))
      }

      return(estimate_total_species_br( # nolint: object_usage_linter
        design,
        species_col = by_info_br$species_var,
        interview_by_vars = by_vars_br,
        variance_method = variance,
        conf_level = conf_level,
        quantity = "catch",
        ci_method = ci_method
      ))
    }

    return(estimate_total_catch_br(
      # nolint: object_usage_linter
      design,
      by_vars_br,
      variance,
      conf_level,
      verbose = FALSE,
      ci_method = ci_method
    ))
  }

  # Camera designs reach here with a count of arrivals where effort belongs, and
  # this function multiplies it by a rate per angler-hour (GH #214). Raised here
  # as well as in estimate_effort() because the totals call
  # estimate_effort_total() directly and never hear that refusal. First in the
  # block, so the camera case aborts instead of warning on its way out.
  refuse_camera_design(design, "estimate_total_catch") # nolint: object_usage_linter

  # Effort x rate from here on: flag a party-hour rate meeting angler-hour effort
  warn_party_hours_product(design) # nolint: object_usage_linter
  check_product_units(design) # nolint: object_usage_linter
  # Totals call estimate_effort_total() directly, bypassing estimate_effort(),
  # so the finding-13 warning has to be raised here too or this path never
  # hears that the count column had no T_d applied.
  warn_missing_period_length(design) # nolint: object_usage_linter

  # A domain the counts never classified forces the pooled product form,
  # whose weighting comes from the interview mix rather than the effort mix
  # (GH #242). Raised before the section dispatch so both paths hear it.
  warn_pooled_domain_mix(design, "estimate_total_catch") # nolint: object_usage_linter

  # Section dispatch guard (v0.7.0+ — only fires when add_sections() was called)
  if (!is.null(design[["sections"]])) {
    return(estimate_total_catch_sections(
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
    estimates_df <- estimate_total_catch_species(
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
      method = "product-total-catch",
      variance_method = variance,
      design = design,
      conf_level = conf_level,
      by_vars = by_info$all_vars,
      effort_target = target,
      unit = product_total_unit(rate_unit(design), design$effort_unit), # nolint: object_usage_linter
      se_expansion = attr(estimates_df, "se_expansion")
    ))
  }

  # Standard (non-species) routing
  if (rlang::quo_is_null(by_quo)) {
    # Ungrouped estimation
    return(estimate_total_catch_ungrouped(
      design,
      variance,
      conf_level,
      target = target,
      use_trips = use_trips,
      product_variance = product_variance,
      ci_type = ci_type
    )) # nolint: object_usage_linter
  } else {
    # Grouped estimation
    # Resolve by parameter to column names
    by_vars <- eval_select_count_by( # nolint: object_usage_linter
      by_quo,
      design,
      species_route = TRUE,
      error_call = rlang::caller_env()
    )

    # Validate grouping compatibility
    validate_grouping_compatibility(design, by_vars) # nolint: object_usage_linter

    return(estimate_total_catch_grouped(
      design,
      by_vars,
      variance,
      conf_level,
      target = target,
      use_trips = use_trips,
      product_variance = product_variance,
      ci_type = ci_type
    )) # nolint: object_usage_linter
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
cpue_for_stratum_product <- function(
  design,
  by_vars,
  variance_method,
  conf_level,
  use_trips = "complete"
) {
  use_trips <- match.arg(use_trips, c("complete", "all"))

  # Apply trip filter before computing CPUE so that total-catch and
  # total-harvest/release can use the same use_trips value for consistency.
  trip_status_col <- design$trip_status_col
  if (!is.null(trip_status_col) && use_trips != "all") {
    filtered_interviews <- design$interviews[
      tolower(design$interviews[[trip_status_col]]) == use_trips,
      ,
      drop = FALSE
    ]
    design <- rebuild_interview_survey(design, filtered_interviews) # nolint: object_usage_linter
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
estimate_total_catch_ungrouped <- function(
  design,
  variance_method,
  conf_level,
  target = "sampled_days",
  use_trips = "complete",
  product_variance = "goodman",
  ci_type = "symmetric"
) {
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

  cpue_result <- cpue_for_stratum_product(
    # nolint: object_usage_linter
    design,
    strata_cols,
    variance_method,
    conf_level,
    use_trips = use_trips
  )
  cpue_df <- cpue_result$estimates

  warn_missing_rate_strata(effort_df, cpue_df, strata_cols, "estimate_total_catch") # nolint: object_usage_linter

  # Stratified-sum product estimator: sum(E_h * CPUE_h) across strata h
  estimates_df <- compute_stratum_product_sum( # nolint: object_usage_linter
    # nolint: object_usage_linter
    effort_df = effort_df,
    rate_df = cpue_df,
    stratum_by_vars = strata_cols,
    interview_by_vars = NULL,
    conf_level = conf_level,
    rate_suffix = "cpue",
    product_variance = product_variance,
    ci_type = ci_type,
    expansion_se = named_expansion_se(effort_result, strata_cols), # nolint: object_usage_linter
    expansion_structure = expansion_group_structure(design), # nolint: object_usage_linter
    expansion_decomposition = named_expansion_decomposition(effort_result, strata_cols) # nolint: object_usage_linter
  )

  new_creel_estimates( # nolint: object_usage_linter
    estimates = tibble::as_tibble(estimates_df),
    method = "product-total-catch",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL,
    effort_target = target,
    unit = product_total_unit(rate_unit(design), design$effort_unit), # nolint: object_usage_linter
    se_expansion = attr(estimates_df, "se_expansion")
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
estimate_total_catch_grouped <- function(
  design,
  by_vars,
  variance_method,
  conf_level,
  target = "sampled_days",
  use_trips = "complete",
  product_variance = "goodman",
  ci_type = "symmetric"
) {
  strata_cols <- design$strata_cols %||% character(0)
  # Union of calendar strata and user grouping: ensures per-stratum products
  stratum_by_vars <- unique(c(strata_cols, by_vars))

  # Per-stratum effort grouped by union of strata and user vars
  effort_result <- estimate_effort_grouped(
    design,
    stratum_by_vars,
    variance_method,
    conf_level,
    target = target
  ) # nolint: object_usage_linter
  effort_df <- effort_result$estimates

  cpue_result <- cpue_for_stratum_product(
    # nolint: object_usage_linter
    design,
    stratum_by_vars,
    variance_method,
    conf_level,
    use_trips = use_trips
  )
  cpue_df <- cpue_result$estimates

  warn_missing_rate_strata(effort_df, cpue_df, stratum_by_vars, "estimate_total_catch(by=)") # nolint: object_usage_linter

  # Stratified-sum within each by_vars group
  estimates_df <- compute_stratum_product_sum( # nolint: object_usage_linter
    # nolint: object_usage_linter
    effort_df = effort_df,
    rate_df = cpue_df,
    stratum_by_vars = stratum_by_vars,
    interview_by_vars = if (length(by_vars) > 0L) by_vars else NULL,
    conf_level = conf_level,
    rate_suffix = "cpue",
    product_variance = product_variance,
    ci_type = ci_type,
    expansion_se = named_expansion_se(effort_result, stratum_by_vars), # nolint: object_usage_linter
    expansion_structure = expansion_group_structure(design), # nolint: object_usage_linter
    expansion_decomposition = named_expansion_decomposition(effort_result, stratum_by_vars) # nolint: object_usage_linter
  )

  new_creel_estimates( # nolint: object_usage_linter
    estimates = tibble::as_tibble(estimates_df),
    method = "product-total-catch",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars,
    effort_target = target,
    unit = product_total_unit(rate_unit(design), design$effort_unit), # nolint: object_usage_linter
    se_expansion = attr(estimates_df, "se_expansion")
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
estimate_total_catch_species <- function(
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

  # Per-stratum species CPUE (grouped by strata + interview grouping vars)
  rate_by <- if (length(stratum_by_vars) > 0L) stratum_by_vars else NULL
  all_rate_df <- estimate_cpue_species(
    # nolint: object_usage_linter
    design,
    species_col = species_col,
    interview_by_vars = rate_by,
    variance_method = variance_method,
    conf_level = conf_level,
    validate = FALSE
  )

  # Per-stratum effort (grouped by same vars)
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
    context = "species total catch"
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
      rate_suffix = "cpue",
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

#' Per-section total catch estimation (product estimator)
#'
#' @keywords internal
#' @noRd
estimate_total_catch_sections <- function(
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

  # Resolve by= ONCE before the section loop (no species dispatch in v0.7.0 section path)
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
        result <- estimate_total_catch_grouped(
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
        cpue_res <- estimate_cpue_total(sec_design, variance_method, conf_level, "ratio") # nolint: object_usage_linter
        effort_est <- effort_res$estimates$estimate
        cpue_est <- cpue_res$estimates$estimate
        effort_se <- effort_res$estimates$se
        cpue_se <- cpue_res$estimates$se
        sec_rate[[sec]] <- cpue_est
        sec_expansion_se[[sec]] <- effort_res$se_expansion
        sec_decomposition[[sec]] <- effort_res$expansion_decomposition
        sec_estimate <- effort_est * cpue_est
        sec_var <- product_total_variance(
          effort_est,
          effort_se,
          cpue_est,
          cpue_se,
          product_variance
        )
        sec_se <- sqrt(sec_var)
        sec_n <- cpue_res$estimates$n
        z_val <- stats::qt(1 - (1 - conf_level) / 2, df = max(1L, sec_n - 1L))
        sec_ci_lower <- if (ci_type == "log" && sec_estimate > 0) {
          sec_estimate * exp(-z_val * sec_se / sec_estimate)
        } else {
          pmax(0, sec_estimate - z_val * sec_se)
        }
        sec_ci_upper <- if (ci_type == "log" && sec_estimate > 0) {
          sec_estimate * exp(z_val * sec_se / sec_estimate)
        } else {
          sec_estimate + z_val * sec_se
        }
        section_rows[[sec]] <- tibble::tibble(
          section = sec,
          estimate = sec_estimate,
          se = sec_se,
          ci_lower = sec_ci_lower,
          ci_upper = sec_ci_upper,
          n = sec_n,
          prop_of_lake_total = NA_real_,
          se_prop_of_lake_total = NA_real_,
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
    lake_ci_lower <- if (ci_type == "log" && lake_est > 0) {
      lake_est * exp(-t_crit * lake_se / lake_est)
    } else {
      pmax(0, lake_est - t_crit * lake_se)
    }
    lake_ci_upper <- if (ci_type == "log" && lake_est > 0) {
      lake_est * exp(t_crit * lake_se / lake_est)
    } else {
      lake_est + t_crit * lake_se
    }

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
    method = "product-total-catch-sections",
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
