#' Instantaneous Effort Estimator (survey-first)
#'
#' Estimate angler-hours from instantaneous (snapshot) counts using mean-count
#' expansion per day × group, then compute design-based totals and variance via
#' the `survey` package when a day-level design is supplied.
#'
#' Effort per day×group = mean(count) × total_minutes ÷ 60.
#'
#' @param counts Tibble/data.frame of instantaneous counts with columns:
#'   `count`, a minutes column (one of `interval_minutes`, `count_duration`,
#'   or `flight_minutes`), grouping variables (e.g., `date`, `location`), and
#'   optionally `total_day_minutes` or `total_minutes` for day-level expansion.
#' @param by Character vector of grouping variables (e.g., `date`, `location`).
#'   Missing columns are ignored with a warning.
#' @param minutes_col Candidate name(s) for per-count minutes. The first present
#'   is used.
#' @param total_minutes_col Candidate name(s) for day×group total minutes.
#'   If absent, falls back to the sum of per-count minutes within the day×group
#'   (warns).
#' @param day_id Day identifier (PSU), typically `date`, used to join with the
#'   survey design.
#' @param covariates Optional character vector of additional grouping variables
#'   (e.g., `shift_block`, `day_type`).
#' @param svy Optional `svydesign`/`svrepdesign` for day-level sampling design.
#' @param conf_level Confidence level for Wald CIs (default 0.95).
#'
#' @details
#' Aggregates per-count observations to day × group totals and uses a
#' day-PSU survey design to compute totals/variance via the `survey` package.
#' When `svy` is not provided, a non-design fallback uses within-group
#' variability to approximate SE/CI; prefer a valid survey design for
#' defensible inference.
#'
#' @seealso [as_day_svydesign()], [survey::svytotal()], [survey::svyby()].
#'
#' @return Tibble with grouping columns, `estimate`, `se`, `ci_low`, `ci_high`,
#'   `n`, `method`, and a `diagnostics` list-column.
#' @export
est_effort.instantaneous <- function(
  counts,
  by = c("date", "location"),
  minutes_col = c(
    "interval_minutes",
    "count_duration",
    "flight_minutes"
  ),
  total_minutes_col = c(
    "total_minutes",
    "total_day_minutes",
    "block_total_minutes"
  ),
  day_id = "date",
  covariates = NULL,
  svy = NULL,
  conf_level = 0.95
) {
  tc_require_cols(counts, c("count"), context = "instantaneous effort")
  min_col <- intersect(minutes_col, names(counts))
  if (length(min_col) == 0) cli::cli_abort(c(
    "x" = "Missing per-count minutes column for instantaneous effort.",
    "i" = paste0("Provide one of: ", paste(minutes_col, collapse = ", "))
  ))
  min_col <- min_col[1]

  # Grouping
  by <- tc_group_warn(by, names(counts))
  if (is.null(covariates)) covariates <- character()
  covariates <- tc_group_warn(covariates, names(counts))
  by_all <- unique(c(by, covariates))

  # Determine total minutes column
  tot_min_col <- intersect(total_minutes_col, names(counts))
  warn_used_sum <- FALSE
  if (length(tot_min_col) == 0) {
    tot_min_col <- min_col
    warn_used_sum <- TRUE
  } else {
    tot_min_col <- tot_min_col[1]
  }

  # Compute day-level totals per group
  day_group <- counts |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(day_id, by_all)))) |>
    dplyr::summarise(
      mean_count = mean(.data$count, na.rm = TRUE),
      total_minutes = if (warn_used_sum) {
        sum(.data[[min_col]], na.rm = TRUE)
      } else {
        dplyr::first(.data[[tot_min_col]])
      },
      n_counts = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(effort_day = mean_count * total_minutes / 60)

  if (warn_used_sum) {
    cli::cli_warn(c(
      "!" = paste0(
        "Instantaneous: using sum of ", min_col,
        " per day×group as total minutes."
      ),
      "i" = "Provide `total_minutes_col` for proper expansion."
    ))
  }

  # Design-based path
  if (!is.null(svy)) {
    svy_vars <- svy$variables
    if (!(day_id %in% names(svy_vars))) {
      cli::cli_abort(paste0("`svy` must include day_id variable: ", day_id))
    }
    # Join weights and replicate weights if present
    day_group$.w <- as.numeric(stats::weights(svy))[match(
      day_group[[day_id]], svy_vars[[day_id]]
    )]
    if (any(is.na(day_group$.w))) {
      cli::cli_abort(paste0("Failed to align survey weights on ", day_id))
    }

    ids_formula <- stats::as.formula(paste("~", day_id))
    if (inherits(svy, "svyrep.design")) {
      repmat <- survey::repweights(svy)
      rep_df <- tibble::as_tibble(repmat)
      rep_df[[day_id]] <- svy_vars[[day_id]]
      day_group <- dplyr::left_join(day_group, rep_df, by = day_id)
      repcols <- colnames(repmat)
      design_eff <- survey::svrepdesign(
        data = day_group,
        repweights = as.matrix(day_group[, repcols]),
        weights = ~.w,
        type = attr(repmat, "type") %||% "bootstrap",
        scale = attr(repmat, "scale") %||% 1,
        rscales = attr(repmat, "rscales") %||% 1,
        combined.weights = attr(repmat, "combined.weights") %||% TRUE
      )
    } else {
      design_eff <- survey::svydesign(ids = ids_formula, weights = ~.w, data = day_group)
    }

    if (length(by_all) > 0) {
      by_formula <- stats::as.formula(paste("~", paste(by_all, collapse = "+")))
      est <- survey::svyby(
        ~effort_day,
        by = by_formula,
        design_eff,
        survey::svytotal,
        na.rm = TRUE
      )
      out <- tibble::as_tibble(est)
      names(out)[names(out) == "effort_day"] <- "estimate"
      V <- attr(est, "var")
      # Robust SE extraction: handle NULL, NA, or lonely PSU cases
      if (!is.null(V) && length(V) > 0 && is.matrix(V)) {
        se_raw <- sqrt(diag(V))
        out$se <- ifelse(is.na(se_raw) | !is.finite(se_raw), NA_real_, se_raw)
      } else {
        out$se <- rep(NA_real_, nrow(out))
      }
      z <- stats::qnorm(1 - (1 - conf_level)/2)
      out$ci_low <- ifelse(!is.na(out$se), out$estimate - z * out$se, NA_real_)
      out$ci_high <- ifelse(!is.na(out$se), out$estimate + z * out$se, NA_real_)
      out$n <- NA_integer_
      out$method <- "instantaneous"
      out$diagnostics <- replicate(nrow(out), list(NULL))
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
        method = "instantaneous",
        diagnostics = list(NULL)
      ))
    }
  }

  # Fallback: per-group estimates using within-group variability only
  out <- counts |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by_all))) |>
    dplyr::summarise(
      mean_count = mean(.data$count, na.rm = TRUE),
      sd_count = stats::sd(.data$count, na.rm = TRUE),
      total_minutes = if (warn_used_sum) {
        sum(.data[[min_col]], na.rm = TRUE)
      } else {
        dplyr::first(.data[[tot_min_col]])
      },
      n = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      estimate = mean_count * total_minutes / 60,
      se = dplyr::if_else(n > 1, (sd_count / sqrt(n)) * (total_minutes / 60), NA_real_)
    )
  out$ci_low <- NA_real_
  out$ci_high <- NA_real_
  idx <- which(out$n > 1 & !is.na(out$estimate) & !is.na(out$se))
  if (length(idx) > 0) {
    cis <- tc_confint(out$estimate[idx], out$se[idx], level = conf_level)
    out$ci_low[idx] <- cis[seq_along(idx)]
    out$ci_high[idx] <- cis[length(idx) + seq_along(idx)]
  }
  out$method <- "instantaneous"
  out$diagnostics <- replicate(nrow(out), list(NULL))
  dplyr::select(out, dplyr::all_of(by_all), estimate, se, ci_low, ci_high, n, method, diagnostics)
}
