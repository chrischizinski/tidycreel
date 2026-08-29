# as_hybrid_svydesign() -------------------------------------------------------

#' Construct a hybrid access + roving survey design
#'
#' `r lifecycle::badge("experimental")`
#'
#' Combines count data from access-point and roving survey components into a
#' single `survey::svydesign` object.  The two components are treated as
#' **strata**, each carrying its own sampling fraction and its own population
#' size, so the design total is the stratified sum of the component totals.
#'
#' **Disjointness precondition.**  Adding the two component totals is valid if
#' and only if the components sample **disjoint sets of angler trips** -- no
#' angler trip may be observed by both.  What produces that disjointness is a
#' property of the survey protocol (angler type, geography, access mode, or a
#' rule the designer imposes); tidycreel cannot infer it from the counts, the
#' dates, the strata, or the method label, so you must affirm it with
#' `trips_disjoint = TRUE`.  The design cannot be constructed otherwise.  A
#' boat angler intercepted on the water by a roving route and again at the
#' ramp on the same trip belongs to both frames, and the total double counts
#' that trip.
#'
#' `component` names a survey **method**, not an angler population: an access
#' point may intercept bank anglers at a pier or boat anglers at a ramp, and a
#' roving route may be walked or run by boat.  Either method can cover either
#' angler type, so disjointness is a fact about the protocol and never about
#' the labels.
#'
#' **Estimation route.**  The returned object is a `survey.design2`, not a
#' [creel_design()], so [estimate_effort()] does not accept it.  Estimate from
#' it with `survey::svytotal()` and the other `survey` functions directly, as
#' in the examples below.
#'
#' **Design structure.**  Rows are stratified on the interaction of
#' `strata_col` and `component`, so each component carries its own population
#' size at its own sampling fraction, and clustered on `date_col`, so several
#' counts taken on one date form one primary sampling unit rather than several
#' independent ones.  A component that sampled only one date within a stratum
#' leaves that stratum with a single PSU: the design still constructs, but
#' `survey` refuses to compute a variance for it.
#'
#' **PSU alignment requirement:** Both `access_data` and `roving_data` must
#' share the same date and stratum columns.  Mismatched column names, or dates
#' present in one component but absent in the other, trigger an error rather
#' than a silent expansion; a warning is issued when stratum-date combinations
#' are asymmetric, because both components should sample the same days.  That
#' is a requirement about *when* each component samples, not *where* -- two
#' components covering different water is the condition that makes their sum
#' valid, not a source of bias.
#'
#' @param access_data Data frame of access-point count observations.  Must
#'   contain the columns named by `date_col`, `strata_col`, and `count_col`.
#' @param roving_data Data frame of roving-route count observations.  Must
#'   contain the same columns as `access_data`.
#' @param date_col Character scalar.  Name of the date column (shared by both
#'   tables). Default `"date"`.  Used to cluster observations into PSUs.
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
#' @param trips_disjoint Logical scalar.  Required, with no default.  Set to
#'   `TRUE` to affirm that the access and roving components sample disjoint
#'   sets of angler trips, the precondition under which their totals may be
#'   added.  tidycreel cannot verify this from the data; see the
#'   "Disjointness precondition" section above.
#' @param fpc Logical. Apply finite-population correction? Default `TRUE`.
#'
#' @return A `survey::svydesign` object with an additional class attribute
#'   `"creel_hybrid_svydesign"`.  The design data contains a `component`
#'   column (`"access"` or `"roving"`), a `weight` column derived from the
#'   sampling fractions, and a `.hybrid_stratum` column holding the
#'   stratum-by-component interaction the design is stratified on.
#'
#' @examples
#' access <- data.frame(
#'   date     = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend"),
#'   count    = c(12L, 15L, 30L, 28L)
#' )
#' roving <- data.frame(
#'   date     = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend"),
#'   count    = c(8L, 10L, 22L, 25L)
#' )
#' design <- as_hybrid_svydesign(
#'   access_data      = access,
#'   roving_data      = roving,
#'   access_fraction  = c(weekday = 0.5, weekend = 0.5),
#'   roving_fraction  = c(weekday = 0.4, weekend = 0.4),
#'   trips_disjoint   = TRUE
#' )
#'
#' # estimate_effort() does not accept this object; use survey directly
#' survey::svytotal(~count, design)
#'
#' @family "Survey Design"
#' @export
as_hybrid_svydesign <- function(
  access_data,
  roving_data,
  date_col = "date",
  strata_col = "day_type",
  count_col = "count",
  access_fraction = NULL,
  roving_fraction = NULL,
  trips_disjoint = NULL,
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
        c(
          "{.arg {name}} is missing entries for strata.",
          "x" = "Missing: {.val {missing_strata}}."
        )
      )
    }
    bad_vals <- frac[names(frac) %in% strata_vals]
    bad_vals <- bad_vals[bad_vals <= 0 | bad_vals > 1]
    if (length(bad_vals) > 0L) {
      cli::cli_abort(
        c(
          "{.arg {name}} values must be in (0, 1].",
          "x" = "Invalid strata: {.val {names(bad_vals)}} = {.val {bad_vals}}."
        )
      )
    }
  }
  .check_fraction(access_fraction, "access_fraction", access_data, strata_col)
  .check_fraction(roving_fraction, "roving_fraction", roving_data, strata_col)

  # Disjointness precondition. Adding the component totals is valid only if no
  # angler trip can be observed by both components. Nothing in date/strata/count
  # can establish that, so the caller has to affirm it (#229).
  if (is.null(trips_disjoint)) {
    cli::cli_abort(c(
      "{.arg trips_disjoint} must be provided.",
      "x" = paste(
        "Summing the access and roving components assumes each angler trip",
        "can be counted by only one of them, and tidycreel cannot verify",
        "that from the counts, dates, or strata."
      ),
      "i" = "Set {.code trips_disjoint = TRUE} to affirm it holds."
    ))
  }
  if (!is.logical(trips_disjoint) || length(trips_disjoint) != 1L ||
        is.na(trips_disjoint)) {
    cli::cli_abort("{.arg trips_disjoint} must be {.code TRUE} or {.code FALSE}.")
  }
  if (!trips_disjoint) {
    cli::cli_abort(c(
      "{.arg trips_disjoint} is {.code FALSE}, so the components may not be summed.",
      "x" = paste(
        "A trip observed by both components is counted twice, and the",
        "stratified total is biased upward by the overlap."
      ),
      "i" = paste(
        "Estimate the components separately, or reconcile the overlap",
        "before combining them."
      )
    ))
  }

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
      msgs <- c(
        msgs,
        paste0(
          "i" = paste(
            length(only_access),
            "date-stratum combination(s) only in access_data"
          )
        )
      )
    }
    if (length(only_roving) > 0L) {
      msgs <- c(
        msgs,
        paste0(
          "i" = paste(
            length(only_roving),
            "date-stratum combination(s) only in roving_data"
          )
        )
      )
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
  access_out$weight <- 1 /
    access_fraction[
      as.character(access_out[[strata_col]])
    ]

  roving_out <- roving_data[, required_cols, drop = FALSE]
  roving_out$component <- "roving"
  roving_out$weight <- 1 /
    roving_fraction[
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

  # Each component samples its own frame at its own rate, so the stratum is the
  # stratum-by-component interaction: pooling them derives one population size
  # from a row count that mixes both, and `fpc` then varies within stratum.
  combined$.hybrid_stratum <- paste(
    as.character(combined[[strata_col]]),
    combined$component,
    sep = "."
  )

  # Cluster on the date so repeat counts on one day are one PSU, not several
  # independent ones -- the defect class refuse_duplicate_psus() guards against
  # on the creel_design path. `nest` because dates recur across the component
  # strata.
  ids_formula <- stats::as.formula(paste0("~", date_col))
  strata_formula <- stats::as.formula("~.hybrid_stratum")
  weights_formula <- stats::as.formula("~weight")

  if (fpc) {
    design <- survey::svydesign(
      ids = ids_formula,
      strata = strata_formula,
      weights = weights_formula,
      fpc = ~fpc_val, # nolint: object_usage_linter
      data = combined,
      nest = TRUE
    )
  } else {
    design <- survey::svydesign(
      ids = ids_formula,
      strata = strata_formula,
      weights = weights_formula,
      data = combined,
      nest = TRUE
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
