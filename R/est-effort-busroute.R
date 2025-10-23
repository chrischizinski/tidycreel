#' Bus-Route Effort Estimation (survey-first HT)
#'
#' Estimate fishing effort for bus-route designs using a Horvitz–Thompson-style
#' day×group total and compute design-based totals and variance via the `survey`
#' package. Supports replicate-weight designs.
#'
#' @param x A `busroute_design` object.
#' @param counts Optional tibble/data.frame of observation data. If `x` contains
#'   `$counts`, that will be used by default.
#' @param by Character vector of grouping variables to retain in output (e.g.,
#'   `date`, `location`). Missing columns are ignored with a warning.
#' @param day_id Day identifier (PSU), typically `date`.
#' @param inclusion_prob_col Column name with inclusion probability `pi` for each
#'   observed party/vehicle or count segment (default `inclusion_prob`).
#' @param route_minutes_col Per-visit route minutes column to translate counts
#'   to time (default `route_minutes`). Used if `contrib_hours_col` is not given.
#' @param contrib_hours_col Optional precomputed contribution in hours for each
#'   observed unit (e.g., observed overlap hours). If present, the HT
#'   contribution is `contrib_hours / pi`. Otherwise uses `count / pi *
#'   route_minutes/60`.
#' @param covariates Optional character vector of additional grouping variables.
#' @param svy Optional `svydesign`/`svrepdesign` encoding day-level sampling. If
#'   absent, a day-PSU design is constructed from `x$calendar` via
#'   `as_day_svydesign()`.
#' @param conf_level Confidence level for CI (default 0.95).
#' @param ... Reserved for future arguments.
#'
#' @return A tibble with group columns, `estimate`, `se`, `ci_low`, `ci_high`,
#'   `n`, `method`, and a `diagnostics` list-column.
#' @details
#' Computes day × group totals using Horvitz–Thompson contributions and uses
#' a day-PSU survey design to compute totals/variance via the `survey` package.
#' Replicate-weight designs are supported by passing a `svrepdesign`.
#'
#' @examples
#' \dontrun{
#' # Example: Create bus-route design and estimate effort
#' # design <- design_busroute(counts, schedule, calendar)
#' # est_effort(design, by = c("date", "location"))
#' }
#'
#' @references
#' Malvestuto, S.P. (1996). Sampling for creel survey data.
#' In: Murphy, B.R. & Willis, D.W. (eds) Fisheries Techniques,
#' 2nd Edition. American Fisheries Society.
#'
#' @export
est_effort.busroute_design <- function(
  x,
  counts = NULL,
  by = c("date", "location"),
  day_id = "date",
  inclusion_prob_col = "inclusion_prob",
  route_minutes_col = "route_minutes",
  contrib_hours_col = NULL,
  covariates = NULL,
  svy = NULL,
  conf_level = 0.95,
  ...
) {
  # Resolve counts
  if (is.null(counts) && !is.null(x$counts)) counts <- x$counts
  if (is.null(counts)) {
    cli::cli_abort(
      "Counts/observations must be supplied via `counts` or present in the design object as `$counts`."
    )
  }

  # Grouping
  by <- tc_group_warn(by, names(counts))
  if (is.null(covariates)) covariates <- character()
  covariates <- tc_group_warn(covariates, names(counts))
  by_all <- unique(c(by, covariates))

  # Required columns
  if (!is.null(contrib_hours_col) && contrib_hours_col %in% names(counts)) {
    contrib_hours <- counts[[contrib_hours_col]]
  } else {
    tc_require_cols(counts, c("count", inclusion_prob_col, route_minutes_col), context = "bus-route effort")
    contrib_hours <- counts$count * counts[[route_minutes_col]] / 60
  }
  tc_require_cols(counts, c(day_id, inclusion_prob_col), context = "bus-route effort")

  # Clamp inclusion probabilities to (0,1] with a warning if outside
  pi_raw <- counts[[inclusion_prob_col]]
  out_of_bounds <- which(!is.na(pi_raw) & (pi_raw <= 0 | pi_raw > 1))
  if (length(out_of_bounds) > 0) {
    cli::cli_warn(
      "{length(out_of_bounds)} rows had inclusion probabilities outside (0,1]; values were clamped."
    )
  }
  pi_vec <- pmax(pmin(pi_raw, 1), .Machine$double.eps)

  # Drop rows with missing critical fields; report diagnostics
  before <- counts
  keep <- !is.na(contrib_hours) & !is.na(pi_vec) & !is.na(counts[[day_id]])
  counts <- counts[keep, , drop = FALSE]
  contrib_hours <- contrib_hours[keep]
  pi_vec <- pi_vec[keep]
  dropped <- tc_diag_drop(before, counts, reason = "missing contrib/pi/day_id")
  counts$ht_contrib <- contrib_hours / pi_vec

  # Day×group totals
  day_group <- counts |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(day_id, by_all)))) |>
    dplyr::summarise(
      effort_day = sum(.data$ht_contrib, na.rm = TRUE),
      n_obs = dplyr::n(),
      .groups = "drop"
    )

  # Build day-PSU svy if not provided
  if (is.null(svy)) {
    if (is.null(x$calendar)) {
      cli::cli_abort(
        "busroute_design lacks $calendar to build day-level design; provide `svy`. "
      )
    }
    cal <- x$calendar
    strata_vars <- intersect(c("day_type", "month", "season", "weekend"), names(cal))
    svy <- as_day_svydesign(cal, day_id = day_id, strata_vars = strata_vars)
  }

  # Join weights and replicate weights if present
  svy_vars <- svy$variables
  if (!(day_id %in% names(svy_vars))) {
    cli::cli_abort(paste0("`svy` must include `", day_id, "` in its variables"))
  }
  # Use sampling weights for replicate designs; ensure vector length matches rows
  base_w <- if (inherits(svy, "svyrep.design")) {
    as.numeric(stats::weights(svy, type = "sampling"))
  } else {
    as.numeric(stats::weights(svy))
  }
  idx <- match(day_group[[day_id]], svy_vars[[day_id]])
  day_group$.w <- base_w[idx]
  if (any(is.na(day_group$.w))) cli::cli_abort(paste0("Failed to align survey weights on ", day_id))

  ids_formula <- stats::as.formula(paste("~", day_id))
  if (inherits(svy, "svyrep.design")) {
    repmat <- svy$repweights
    if (is.null(repmat)) cli::cli_abort("Replicate weights not found on svyrep.design object.")
    # Align replicate weights by index, duplicating rows for repeated days
    repmat_mat <- as.matrix(repmat)
    repweights_aligned <- repmat_mat[idx, , drop = FALSE]
    design_eff <- survey::svrepdesign(
      data = day_group,
      repweights = repweights_aligned,
      weights = ~.w,
      type = attr(repmat, "type") %||% "bootstrap",
      scale = attr(repmat, "scale") %||% 1,
      rscales = attr(repmat, "rscales") %||% 1,
      combined.weights = attr(repmat, "combined.weights") %||% TRUE
    )
  } else {
    design_eff <- survey::svydesign(
      ids = ids_formula,
      weights = ~.w,
      data = day_group,
      nest = TRUE,
      lonely.psu = "adjust"
    )
  }

  # Totals by groups
  if (length(by_all) > 0) {
    by_formula <- stats::as.formula(paste("~", paste(by_all, collapse = "+")))
    est <- survey::svyby(~effort_day, by = by_formula, design_eff, survey::svytotal, na.rm = TRUE)
    out <- tibble::as_tibble(est)
    names(out)[names(out) == "effort_day"] <- "estimate"
    se_try <- try(suppressWarnings(as.numeric(survey::SE(est))), silent = TRUE)
    if (!inherits(se_try, "try-error") && length(se_try) == nrow(out)) {
      out$se <- se_try
    } else {
      V <- attr(est, "var")
      out$se <- if (!is.null(V) && length(V) > 0) sqrt(diag(V)) else rep(NA_real_, nrow(out))
    }
    z <- stats::qnorm(1 - (1 - conf_level)/2)
    out$ci_low <- out$estimate - z * out$se
    out$ci_high <- out$estimate + z * out$se
    out$n <- NA_integer_
    out$method <- "busroute_ht"
    out$diagnostics <- replicate(nrow(out), list(dropped), simplify = FALSE)
    return(dplyr::select(out, dplyr::all_of(by_all), estimate, se, ci_low, ci_high, n, method, diagnostics))
  } else {
    total_est <- survey::svytotal(~effort_day, design_eff, na.rm = TRUE)
    estimate <- as.numeric(total_est[1])
    se <- sqrt(as.numeric(survey::vcov(total_est)))
    ci <- tc_confint(estimate, se, level = conf_level)
    return(tibble::tibble(
      estimate = estimate,
      se = se,
      ci_low = ci[1],
      ci_high = ci[2],
      n = NA_integer_,
      method = "busroute_ht",
      diagnostics = list(dropped)
    ))
  }
}
