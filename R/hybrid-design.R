# as_hybrid_svydesign() -------------------------------------------------------

#' Construct a hybrid access + roving survey design
#'
#' `r lifecycle::badge("experimental")`
#'
#' Combines count data from access-point and roving survey components into a
#' single `survey::svydesign` object suitable for effort estimation via
#' [estimate_effort()].
#'
#' A hybrid design is appropriate when a survey uses both fixed access-point
#' counts (e.g., boat-launch interviews with angler counts) and roving-route
#' counts (e.g., progressive counts along a shoreline transect) within the same
#' sampling frame.  The two components are stacked, with a `component` column
#' distinguishing them, and inclusion probabilities are derived from the
#' user-supplied sampling fractions per stratum.
#'
#' **PSU alignment requirement:** Both `access_data` and `roving_data` must
#' share the same date and stratum columns.  Mismatched column names, or dates
#' present in one component but absent in the other, trigger an error rather
#' than a silent expansion.  If PSU boundaries differ (e.g., access routes
#' cover different sections than roving routes), the estimates will be biased;
#' a warning is issued when stratum-date combinations are asymmetric.
#'
#' @param access_data Data frame of access-point count observations.  Must
#'   contain the columns named by `date_col`, `strata_col`, and `count_col`.
#' @param roving_data Data frame of roving-route count observations.  Must
#'   contain the same columns as `access_data`.
#' @param date_col Character scalar.  Name of the date column (shared by both
#'   tables). Default `"date"`.
#' @param strata_col Character scalar.  Name of the stratum column (shared by
#'   both tables). Default `"day_type"`.
#' @param count_col Character scalar.  Name of the count column (shared by
#'   both tables). Default `"count"`.
#' @param access_fraction Named numeric vector. Sampling fraction per stratum
#'   for the access-point component (proportion of access points sampled on
#'   each sampled day; must be in (0, 1]). Names must match stratum values in
#'   `access_data`.
#' @param roving_fraction Named numeric vector. Sampling fraction per stratum
#'   for the roving-route component.  Names must match stratum values in
#'   `roving_data`.
#' @param fpc Logical. Apply finite-population correction? Default `TRUE`.
#'
#' @return A `survey::svydesign` object with an additional class attribute
#'   `"creel_hybrid_svydesign"`.  The design data contains a `component`
#'   column (`"access"` or `"roving"`) and a `weight` column derived from
#'   the sampling fractions.
#'
#' @examples
#' \dontrun{
#' access <- data.frame(
#'   date     = as.Date(c("2024-06-01", "2024-06-02")),
#'   day_type = c("weekday", "weekend"),
#'   count    = c(12L, 30L)
#' )
#' roving <- data.frame(
#'   date     = as.Date(c("2024-06-01", "2024-06-02")),
#'   day_type = c("weekday", "weekend"),
#'   count    = c(8L, 22L)
#' )
#' design <- as_hybrid_svydesign(
#'   access_data      = access,
#'   roving_data      = roving,
#'   access_fraction  = c(weekday = 0.5, weekend = 0.5),
#'   roving_fraction  = c(weekday = 0.4, weekend = 0.4)
#' )
#' survey::svytotal(~count, design)
#' }
#'
#' @export
as_hybrid_svydesign <- function(
  access_data,
  roving_data,
  date_col = "date",
  strata_col = "day_type",
  count_col = "count",
  access_fraction = NULL,
  roving_fraction = NULL,
  fpc = TRUE
) {
  # ---- Input validation ----------------------------------------------------
  for (arg_name in c("date_col", "strata_col", "count_col")) {
    val <- get(arg_name)
    if (!is.character(val) || length(val) != 1L) {
      cli::cli_abort("{.arg {arg_name}} must be a single character string.")
    }
  }
  if (!is.data.frame(access_data)) {
    cli::cli_abort("{.arg access_data} must be a data frame.")
  }
  if (!is.data.frame(roving_data)) {
    cli::cli_abort("{.arg roving_data} must be a data frame.")
  }

  required_cols <- c(date_col, strata_col, count_col)
  missing_access <- setdiff(required_cols, names(access_data))
  missing_roving <- setdiff(required_cols, names(roving_data))
  if (length(missing_access) > 0L) {
    cli::cli_abort(
      "Column(s) {.field {missing_access}} missing from {.arg access_data}."
    )
  }
  if (length(missing_roving) > 0L) {
    cli::cli_abort(
      "Column(s) {.field {missing_roving}} missing from {.arg roving_data}."
    )
  }

  # Validate fractions
  .check_fraction <- function(frac, name, data, strata_col) {
    if (is.null(frac)) {
      cli::cli_abort("{.arg {name}} must be provided.")
    }
    strata_vals <- unique(as.character(data[[strata_col]]))
    missing_strata <- setdiff(strata_vals, names(frac))
    if (length(missing_strata) > 0L) {
      cli::cli_abort(
        "{.arg {name}} is missing entries for strata: ",
        "{.val {missing_strata}}."
      )
    }
    bad_vals <- frac[names(frac) %in% strata_vals]
    bad_vals <- bad_vals[bad_vals <= 0 | bad_vals > 1]
    if (length(bad_vals) > 0L) {
      cli::cli_abort(
        "{.arg {name}} values must be in (0, 1]. ",
        "Invalid: {.val {names(bad_vals)}} = {.val {bad_vals}}."
      )
    }
  }
  .check_fraction(access_fraction, "access_fraction", access_data, strata_col)
  .check_fraction(roving_fraction, "roving_fraction", roving_data, strata_col)

  # ---- PSU alignment check -------------------------------------------------
  access_keys <- paste(
    as.character(access_data[[date_col]]),
    as.character(access_data[[strata_col]])
  )
  roving_keys <- paste(
    as.character(roving_data[[date_col]]),
    as.character(roving_data[[strata_col]])
  )
  only_access <- setdiff(unique(access_keys), unique(roving_keys))
  only_roving <- setdiff(unique(roving_keys), unique(access_keys))

  if (length(only_access) > 0L || length(only_roving) > 0L) {
    msgs <- character(0)
    if (length(only_access) > 0L) {
      msgs <- c(msgs, paste0(
        "i" = paste(
          length(only_access),
          "date-stratum combination(s) only in access_data"
        )
      ))
    }
    if (length(only_roving) > 0L) {
      msgs <- c(msgs, paste0(
        "i" = paste(
          length(only_roving),
          "date-stratum combination(s) only in roving_data"
        )
      ))
    }
    cli::cli_warn(c(
      "Asymmetric date-stratum coverage between access and roving data.",
      "!" = "Effort estimates may be biased for unmatched combinations.",
      msgs
    ))
  }

  # ---- Combine and weight --------------------------------------------------
  access_out <- access_data[, required_cols, drop = FALSE]
  access_out$component <- "access"
  access_out$weight <- 1 / access_fraction[
    as.character(access_out[[strata_col]])
  ]

  roving_out <- roving_data[, required_cols, drop = FALSE]
  roving_out$component <- "roving"
  roving_out$weight <- 1 / roving_fraction[
    as.character(roving_out[[strata_col]])
  ]

  combined <- rbind(access_out, roving_out)

  # ---- Build svydesign -----------------------------------------------------
  # fpc_val: sampling fraction per row (n/N = f).
  # svydesign(fpc) accepts: the sampling fraction if <= 1, or population size
  # if > 1. We supply the fraction directly.
  combined$fpc_val <- ifelse(
    combined$component == "access",
    access_fraction[as.character(combined[[strata_col]])],
    roving_fraction[as.character(combined[[strata_col]])]
  )

  ids_formula <- stats::as.formula("~1")
  strata_formula <- stats::as.formula(paste0("~", strata_col))
  weights_formula <- stats::as.formula("~weight")

  if (fpc) {
    design <- survey::svydesign(
      ids     = ids_formula,
      strata  = strata_formula,
      weights = weights_formula,
      fpc     = ~fpc_val, # nolint: object_usage_linter
      data    = combined
    )
  } else {
    design <- survey::svydesign(
      ids     = ids_formula,
      strata  = strata_formula,
      weights = weights_formula,
      data    = combined
    )
  }

  class(design) <- c("creel_hybrid_svydesign", class(design))
  attr(design, "component_col") <- "component"
  attr(design, "count_col") <- count_col
  design
}

# ---- S3 methods -------------------------------------------------------------

#' Print a creel_hybrid_svydesign
#'
#' @param x A `creel_hybrid_svydesign` object.
#' @param ... Ignored.
#'
#' @return `x`, invisibly.
#'
#' @export
print.creel_hybrid_svydesign <- function(x, ...) {
  cli::cli_h1("Hybrid Creel Survey Design")
  n_access <- sum(x$variables$component == "access") # nolint: object_usage_linter
  n_roving <- sum(x$variables$component == "roving") # nolint: object_usage_linter
  cli::cli_text(
    "Components: {.val access} ({n_access} obs) + ",
    "{.val roving} ({n_roving} obs)"
  )
  cli::cli_text("")
  NextMethod()
  invisible(x)
}
