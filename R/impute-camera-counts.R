# impute_camera_counts() -------------------------------------------------------

#' Impute missing camera counts using GLM or GLMM
#'
#' `r lifecycle::badge("experimental")`
#'
#' @description
#' Fills outage rows in a camera count data frame using a per-stratum model.
#' The GLM method (default, Hartill 2016) fits a Poisson GLM with `strata_col`
#' (typically `day_type`) as the sole predictor. The GLMM method
#' (Afrifa-Yamoah 2020) fits a zero-inflated negative binomial GLMM and
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
#'   Poisson GLM, no extra dependencies) or `"glmm"` (zero-inflated negative
#'   binomial GLMM via `glmmTMB`, requires `glmmTMB` in `Suggests`).
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
#'   Hartill, B.W., Cryer, M., and Morrison, M.A. 2020. Camera-based creel
#'   surveys: estimating fishing effort and catch rates from ingress-egress
#'   camera counts. Fisheries Research 231:105706.
#'   \doi{10.1016/j.fishres.2020.105706}
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
  method     = "glm",
  site_col   = NULL
) {
  # 1. Input validation --------------------------------------------------------
  checkmate::assert_data_frame(data, min.rows = 1L)
  checkmate::assert_string(count_col)
  checkmate::assert_string(strata_col)
  checkmate::assert_string(status_col)
  checkmate::assert_choice(method, c("glm", "glmm"))
  checkmate::assert_string(site_col, null.ok = TRUE)

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
    rlang::check_installed("glmmTMB", reason = "to fit zero-inflated negative binomial GLMM for camera count imputation") # nolint: line_length_linter
  }

  # 3. Identify outage rows ----------------------------------------------------
  is_outage <- data[[status_col]] != "operational" & is.na(data[[count_col]])

  # 4. High-missingness warning (CAMP-04) -------------------------------------
  strata_vals <- unique(data[[strata_col]])
  miss_fractions <- vapply(strata_vals, function(s) {
    stratum_mask <- data[[strata_col]] == s
    sum(is_outage[stratum_mask]) / sum(stratum_mask)
  }, numeric(1L))
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

    # No outages in this stratum — return as-is
    if (!any(outage_mask)) {
      return(stratum_data)
    }

    # Build GLM formula. Within a stratum, strata_col has exactly one unique
    # value so fitting count ~ strata_col would fail ("only 1 level"). Per
    # D-09/D-10 the model is intercept-only within each stratum, equivalent
    # to the per-stratum Poisson mean (Hartill 2016).
    glm_formula <- stats::as.formula(paste0(count_col, " ~ 1"))

    if (method == "glm") {
      fit <- stats::glm(
        glm_formula,
        data   = stratum_data[obs_mask, , drop = FALSE],
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
          data   = stratum_data[obs_mask, , drop = FALSE],
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
          data   = stratum_data[obs_mask, , drop = FALSE],
          family = stats::poisson()
        )
      }
    }

    # Predict for outage rows (D-11)
    predicted <- predict(
      fit,
      newdata = stratum_data[outage_mask, , drop = FALSE],
      type    = "response"
    )
    stratum_data[[count_col]][outage_mask] <- as.integer(round(predicted))

    stratum_data
  })

  # 6. Bind results ------------------------------------------------------------
  result <- do.call(rbind, imputed_list)
  row.names(result) <- NULL

  # 7. Add .imputed flag (D-06) -----------------------------------------------
  # Any non-operational row that now has a non-NA count was imputed
  # (operational rows always had counts; outage rows had NA before imputation)
  result$.imputed <- result[[status_col]] != "operational" &
    !is.na(result[[count_col]])

  # 8. Integer coercion (D-08) ------------------------------------------------
  storage.mode(result[[count_col]]) <- "integer"

  result
}
