# impute_camera_counts() -------------------------------------------------------

#' Impute missing camera counts using GLM or GLMM
#'
#' `r lifecycle::badge("experimental")`
#'
#' @description
#' Fills outage rows in a camera count data frame using a per-stratum model.
#' The GLM method (default, Hartill 2016) fits a Poisson GLM with `strata_col`
#' (typically `day_type`) as the sole predictor. The GLMM method
#' (Afrifa-Yamoah 2020) fits a negative binomial GLMM and
#' requires the `glmmTMB` package (in `Suggests`).
#'
#' Outage rows are identified as any row where `status_col != "operational"`
#' AND `count_col` is `NA`. All rows are returned; imputed rows have
#' `.imputed = TRUE`. The original `status_col` values (e.g.,
#' `"battery_failure"`) are preserved in imputed rows for traceability.
#'
#' @param data A data frame of camera count records. Must have at least one row
#'   and must contain the columns named by `count_col`, `strata_col`, and
#'   `status_col`.
#' @param count_col Character scalar. Name of the integer count column (e.g.,
#'   `"ingress_count"`). Outage rows have `NA` in this column.
#' @param strata_col Character scalar. Name of the day-type stratum column
#'   (e.g., `"day_type"`). Used as the predictor in the per-stratum GLM/GLMM.
#' @param status_col Character scalar. Name of the camera status column.
#'   Default `"camera_status"`. Rows where this column is not
#'   `"operational"` and `count_col` is `NA` are treated as outages.
#' @param method Character scalar. Imputation model: `"glm"` (default,
#'   Poisson GLM, no extra dependencies) or `"glmm"` (negative binomial GLMM
#'   via `glmmTMB`, requires `glmmTMB` in `Suggests`).
#' @param m Integer scalar. Number of completed data sets to generate.
#'   `1L` (default) fills each outage row with the fitted mean, reproducing the
#'   single-imputation behaviour of earlier versions and returning a plain data
#'   frame.
#'
#'   `m > 1` performs **multiple imputation** and returns a `camera_imputations`
#'   object for [est_effort_camera_mi()] to pool. Afrifa-Yamoah et al. (2020)
#'   use `m = 5` as "an appropriate balance of the bias-variance trade-off".
#'
#'   The distinction matters because a single completed data set structurally
#'   cannot carry the between-imputation variance. Inside `svytotal()` a
#'   prediction is indistinguishable from an observation, so the imputation
#'   model's uncertainty is dropped, and fitted means are smoother than real
#'   counts, shrinking the between-day variance a second time (GH #137).
#' @param site_col Character scalar or `NULL`. When `method = "glmm"` and
#'   `site_col` is not `NULL`, a random intercept `(1 | site_col)` is included
#'   in the GLMM formula. Default `NULL`.
#'
#' @return A data frame with the same rows and columns as `data`, plus a new
#'   logical column `.imputed` appended as the last column. Outage rows are
#'   filled in `count_col` with model-predicted counts (rounded to integer).
#'   The `count_col` storage mode is set to `"integer"` for schema
#'   compatibility with [add_counts()]. Row count equals `nrow(data)`.
#'
#' @references
#'   Hartill, B.W., Taylor, S.M., Keller, K., and Weltersbach, M.S. 2020.
#'   Digital camera monitoring of recreational fishing effort: applications
#'   and challenges. Fish and Fisheries 21:204-215.
#'   \doi{10.1111/faf.12413}
#'
#'   Afrifa-Yamoah, E., Mueller, U.A., Taylor, S.M., and Fisher, A. 2020.
#'   Missing data imputation of high-resolution temporal climate data series
#'   using an integrated framework of expectation maximisation and long
#'   short-term memory neural networks.
#'
#' @examples
#' \dontrun{
#' library(tidycreel)
#' data(example_camera_counts)
#'
#' # Impute missing counts using the default Poisson GLM
#' imputed <- impute_camera_counts(
#'   example_camera_counts,
#'   count_col  = "ingress_count",
#'   strata_col = "day_type"
#' )
#'
#' # Inspect imputed rows
#' imputed[imputed$.imputed, ]
#'
#' # Pass imputed data directly into a camera design
#' cal <- data.frame(
#'   date     = unique(example_camera_counts$date),
#'   day_type = unique(example_camera_counts[, c("date", "day_type")])[["day_type"]]
#' )
#' design <- creel_design(cal,
#'   date = date, strata = day_type,
#'   survey_type = "camera", camera_mode = "counter"
#' )
#' design <- add_counts(design, imputed)
#' }
#'
#' @family "Survey Design"
#' @seealso [est_effort_camera()], [add_counts()]
#' @importFrom stats predict
#' @export
impute_camera_counts <- function(
  data,
  count_col,
  strata_col,
  status_col = "camera_status",
  method = "glm",
  m = 1L,
  site_col = NULL
) {
  # 1. Input validation --------------------------------------------------------
  checkmate::assert_data_frame(data, min.rows = 1L)
  checkmate::assert_string(count_col)
  checkmate::assert_string(strata_col)
  checkmate::assert_string(status_col)
  checkmate::assert_choice(method, c("glm", "glmm"))
  checkmate::assert_int(m, lower = 1L)
  checkmate::assert_string(site_col, null.ok = TRUE)
  m <- as.integer(m)

  # Check columns exist
  for (col in c(count_col, strata_col, status_col)) {
    if (!col %in% names(data)) {
      cli::cli_abort(c(
        "Column {.field {col}} not found in {.arg data}.",
        "i" = "Available columns: {.field {names(data)}}"
      ))
    }
  }
  if (!is.null(site_col) && !site_col %in% names(data)) {
    cli::cli_abort(c(
      "Column {.field {site_col}} not found in {.arg data}.",
      "i" = "Available columns: {.field {names(data)}}"
    ))
  }

  # 2. Guard: glmmTMB required for GLMM method --------------------------------
  if (method == "glmm") {
    rlang::check_installed(
      "glmmTMB",
      reason = "to fit a negative binomial GLMM for camera count imputation"
    ) # nolint: line_length_linter
  }

  # 3. Identify outage rows ----------------------------------------------------
  is_outage <- data[[status_col]] != "operational" & is.na(data[[count_col]])
  # Store pre-imputation NA baseline so .imputed is set correctly for rows that
  # were non-operational but already had a non-NA count (e.g., manually keyed).
  data[[".was_outage"]] <- is_outage

  # 4. High-missingness warning (CAMP-04) -------------------------------------
  strata_vals <- unique(data[[strata_col]])
  miss_fractions <- vapply(
    strata_vals,
    function(s) {
      stratum_mask <- data[[strata_col]] == s
      sum(is_outage[stratum_mask]) / sum(stratum_mask)
    },
    numeric(1L)
  )
  names(miss_fractions) <- strata_vals

  high_miss_strata <- names(miss_fractions[miss_fractions > 0.5])
  if (length(high_miss_strata) > 0L) {
    cli::cli_warn(c(
      "High missingness detected in {length(high_miss_strata)} stratum{?/a}.",
      "!" = "{.val {high_miss_strata}} {?has/have} > 50% missing camera counts.",
      "i" = "Imputation results may be unreliable (Afrifa-Yamoah 2020)."
    ))
  }

  # 5. Per-stratum imputation loop --------------------------------------------
  imputed_list <- lapply(strata_vals, function(s) {
    stratum_data <- data[data[[strata_col]] == s, , drop = FALSE]

    # Observed rows: operational AND non-NA count
    obs_mask <- stratum_data[[status_col]] == "operational" &
      !is.na(stratum_data[[count_col]])

    # All-missing abort (CAMP-05 / D-16)
    if (!any(obs_mask)) {
      cli::cli_abort(c(
        "Stratum {.val {s}} has no observed counts.",
        "x" = "All {nrow(stratum_data)} rows in stratum {.val {s}} are outages or NA.",
        "i" = "Imputation requires at least one operational observation per stratum."
      ))
    }

    # Outage mask within this stratum
    outage_mask <- stratum_data[[status_col]] != "operational" &
      is.na(stratum_data[[count_col]])

    # No outages in this stratum — return as-is, in whichever shape m implies
    # so the bind step below sees one consistent structure.
    if (!any(outage_mask)) {
      return(if (m == 1L) stratum_data else rep(list(stratum_data), m))
    }

    # Build GLM formula. Within a stratum, strata_col has exactly one unique
    # value so fitting count ~ strata_col would fail ("only 1 level"). Per
    # D-09/D-10 the model is intercept-only within each stratum, equivalent
    # to the per-stratum Poisson mean (Hartill 2016).
    glm_formula <- stats::as.formula(paste0(count_col, " ~ 1"))

    if (method == "glm") {
      fit <- stats::glm(
        glm_formula,
        data = stratum_data[obs_mask, , drop = FALSE],
        family = stats::poisson()
      )
    } else {
      # GLMM path (D-13). Within a stratum, strata_col has one level so we
      # use an intercept-only fixed effect; random slope on site_col when
      # provided.
      if (!is.null(site_col)) {
        glmm_formula <- stats::as.formula(
          paste0(count_col, " ~ 1 + (1 | ", site_col, ")")
        )
      } else {
        glmm_formula <- glm_formula
      }

      fit <- tryCatch(
        glmmTMB::glmmTMB(
          glmm_formula,
          data = stratum_data[obs_mask, , drop = FALSE],
          family = glmmTMB::nbinom2(link = "log")
        ),
        error = function(e) {
          cli::cli_warn(c(
            "GLMM convergence failed for stratum {.val {s}}.",
            "i" = "Falling back to Poisson GLM for this stratum.",
            "!" = "Error: {e$message}"
          ))
          NULL
        }
      )

      # Fallback to GLM on convergence failure (D-14)
      if (is.null(fit)) {
        fit <- stats::glm(
          glm_formula,
          data = stratum_data[obs_mask, , drop = FALSE],
          family = stats::poisson()
        )
      }
    }

    # Predict for outage rows (D-11)
    predicted <- predict(
      fit,
      newdata = stratum_data[outage_mask, , drop = FALSE],
      type = "response"
    )

    if (m == 1L) {
      stratum_data[[count_col]][outage_mask] <- as.integer(round(predicted))
      return(stratum_data)
    }

    # Multiple imputation: return m completed copies of this stratum, each
    # drawn from the model's PREDICTIVE distribution rather than filled with
    # its mean (GH #137).
    #
    # Two sources of variation are drawn, and both are needed. Drawing only
    # the count would treat the fitted coefficients as known; drawing only the
    # coefficients would still return a smooth mean where a real count has
    # sampling noise. Filling with the mean, as m = 1 does, has neither, which
    # is why its completed data set is smoother than observed data and shrinks
    # the between-day variance.
    lapply(seq_len(m), function(.i) {
      draw <- .draw_imputed_counts(fit, stratum_data, outage_mask, predicted)
      out <- stratum_data
      out[[count_col]][outage_mask] <- draw
      out
    })
  })

  # 6. Bind results ------------------------------------------------------------
  finalise <- function(res) {
    row.names(res) <- NULL
    # 7. Add .imputed flag (D-06). Use the pre-imputation NA baseline to
    # identify rows that were genuinely imputed (was NA before, non-NA after).
    # Avoids false positives for non-operational rows that already had a
    # manually keyed count.
    res$.imputed <- res[[".was_outage"]] & !is.na(res[[count_col]])
    res[[".was_outage"]] <- NULL
    # 8. Integer coercion (D-08)
    storage.mode(res[[count_col]]) <- "integer"
    res
  }

  if (m == 1L) {
    return(finalise(do.call(rbind, imputed_list)))
  }

  # Each stratum contributed a list of m completed copies; bind the i-th copy
  # of every stratum together to form the i-th completed data set.
  completed <- lapply(seq_len(m), function(i) {
    finalise(do.call(rbind, lapply(imputed_list, function(st) st[[i]])))
  })

  structure(
    completed,
    class = "camera_imputations",
    m = m,
    count_col = count_col,
    strata_col = strata_col,
    method = method
  )
}

#' Draw imputed counts from a fitted model's predictive distribution
#'
#' Draws the regression coefficients from their sampling distribution and then
#' the counts from the resulting conditional distribution, so a completed data
#' set carries both the model's estimation uncertainty and the count's own
#' sampling variation. Filling with `predict(type = "response")` has neither.
#'
#' @param fit A fitted `glm` or `glmmTMB` model.
#' @param stratum_data The stratum's rows.
#' @param outage_mask Logical vector selecting the rows to impute.
#' @param predicted Fitted means for those rows, used as the fallback scale.
#' @return An integer vector of drawn counts, parallel to `sum(outage_mask)`.
#' @keywords internal
#' @noRd
.draw_imputed_counts <- function(fit, stratum_data, outage_mask, predicted) {
  n_out <- sum(outage_mask)

  # Coefficient draw. The models here are intercept-only within a stratum
  # (D-09/D-10), so this is a draw of the log-mean and mu_draw is a scalar
  # recycled across the outage rows.
  mu_draw <- tryCatch(
    {
      beta_hat <- if (inherits(fit, "glmmTMB")) {
        glmmTMB::fixef(fit)$cond
      } else {
        stats::coef(fit)
      }
      v <- as.matrix(stats::vcov(fit))
      if (inherits(fit, "glmmTMB")) {
        v <- as.matrix(stats::vcov(fit)$cond)
      }
      beta_draw <- beta_hat + sqrt(pmax(diag(v), 0)) * stats::rnorm(length(beta_hat))
      rep(exp(unname(beta_draw[[1L]])), n_out)
    },
    error = function(e) as.numeric(predicted)
  )

  # Count draw, from the family the model was fitted with. A negative-binomial
  # fit that were drawn as Poisson would discard exactly the overdispersion it
  # was chosen to capture.
  drawn <- if (inherits(fit, "glmmTMB")) {
    theta <- tryCatch(stats::sigma(fit), error = function(e) NA_real_)
    if (is.finite(theta) && theta > 0) {
      stats::rnbinom(n_out, size = theta, mu = mu_draw)
    } else {
      stats::rpois(n_out, lambda = mu_draw)
    }
  } else {
    stats::rpois(n_out, lambda = mu_draw)
  }

  as.integer(drawn)
}
