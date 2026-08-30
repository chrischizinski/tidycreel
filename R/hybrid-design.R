# as_hybrid_svydesign() -------------------------------------------------------

#' Construct a hybrid access + roving survey design
#'
#' `r lifecycle::badge("experimental")`
#'
#' Combines two count series covering disjoint parts of one fishery into a
#' single `survey::svydesign` object.  The two components are treated as
#' **strata**, each carrying its own within-day sampling fraction, and both
#' expanded to the same population of days, so the design total is the
#' stratified sum of the component totals over the season.
#'
#' **Estimand.**  The design estimates a **period total** -- the total over
#' every day in `calendar`, not over the days that happened to be sampled.
#' Two expansions get it there, and both live in the row weight: the
#' within-day fraction expands the part of the component's frame that the
#' count enumerated to the whole of it, and `N_h / n_h` expands the sampled
#' days to the days the stratum holds.  Only the second is a
#' stage-1 sampling fraction, so only the second drives the finite-population
#' correction.
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
#' **What `component` names, and what it does not.**  The two components are
#' two **count frames**: two disjoint parts of the fishery, each enumerated by
#' its own count.  In the protocol this design was built for they are
#' angler-type domains -- boat anglers, and bank anglers dispersed along a
#' shoreline with no well-defined access site (Malvestuto 1996).
#'
#' The labels `"access"` and `"roving"` are borrowed from the **interview**
#' vocabulary and describe these frames only obliquely, by which interview
#' mode happens to cover each.  In the creel literature access and roving
#' describe how anglers are *interviewed*: access interviews intercept
#' completed trips as anglers leave, roving interviews intercept incomplete
#' trips while anglers are still fishing, and the two require different
#' catch-rate estimators (Pollock et al. 1994).  A survey mixing the two is a
#' **hybrid interview** design.  Counts are not described that way at all --
#' they are instantaneous, progressive, bus-route, camera or aerial, the
#' values [creel_schema()] accepts for `survey_type`, none of which is
#' "access" or "roving".  tidycreel carries the interview axis on
#' [add_interviews()]'s `interview_type` argument, which is where it belongs.
#' These argument names are inherited and are under review; what the design
#' requires of the two components is disjointness, not a method label.
#'
#' **Estimation route.**  The returned object is a `survey.design2`, not a
#' [creel_design()], so [estimate_effort()] does not accept it.  Estimate from
#' it with `survey::svytotal()` and the other `survey` functions directly, as
#' in the examples below.
#'
#' **Design structure.**  Rows are stratified on the interaction of
#' `strata_col` and `component`, so each count frame carries its own
#' sampled-day count at its own within-day fraction, and clustered on `date_col`, so the
#' date is the primary sampling unit.  The population size is taken from
#' `calendar` and is shared by both components: one stratum is one span of the
#' season, whichever method observed it.  A component that sampled only one
#' date within a stratum leaves that stratum with a single PSU: the design
#' still constructs, but `survey` refuses to compute a variance for it.
#'
#' **One count row per component-day.**  A day-level expansion is only defined
#' when a sampled day is one row per component, so repeated counts on one date
#' are refused.  Two counts on a date are two looks at that date, not two
#' sampled days; summed, they multiply the total by the number of counts, and
#' the day expansion then multiplies that again.  Average them to one row per
#' date before constructing the design, or model them on a path that keeps the
#' count time.
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
#' @param access_data Data frame of count observations for the frame labelled
#'   `"access"` in the returned design.  Must contain the columns named by
#'   `date_col`, `strata_col`, and `count_col`, with at most one row per date
#'   within a stratum.  See "What `component` names" above: the label is
#'   inherited from the interview vocabulary and does not describe a count
#'   method.
#' @param roving_data Data frame of count observations for the frame labelled
#'   `"roving"`.  Must contain the same columns as `access_data`.
#' @param calendar Data frame giving the population of days the totals expand
#'   to, with one row per day carrying the columns named by `date_col` and
#'   `strata_col`.  Required: the `NULL` default is rejected, and exists only
#'   so the error can say what is missing.  The number of **distinct**
#'   dates per stratum is the stratum population size \eqn{N_h}, counted the
#'   way [creel_design()] counts it.  Every sampled date must appear in
#'   `calendar` under the same stratum.
#' @param date_col Character scalar.  Name of the date column (shared by both
#'   tables and by `calendar`). Default `"date"`.  Used to cluster
#'   observations into PSUs.
#' @param strata_col Character scalar.  Name of the stratum column (shared by
#'   both tables and by `calendar`). Default `"day_type"`.
#' @param count_col Character scalar.  Name of the count column (shared by
#'   both tables). Default `"count"`.
#' @param access_fraction Named numeric vector.  **Within-day** sampling
#'   fraction per stratum for the `"access"` component: the proportion of that
#'   component's frame the count enumerated on each sampled day, in (0, 1].
#'   Expands a sampled day to a whole day; it is not a fraction of the season
#'   and does not drive the finite-population correction.  Names must match
#'   stratum values in `access_data`.
#' @param roving_fraction Named numeric vector.  Within-day sampling fraction
#'   per stratum for the `"roving"` component, with the same meaning as
#'   `access_fraction`.  Names must match stratum values in `roving_data`.
#' @param trips_disjoint Logical scalar.  Required: the `NULL` default is
#'   rejected, and exists only so the error can say what is missing.  Set to
#'   `TRUE` to affirm that the access and roving components sample disjoint
#'   sets of angler trips, the precondition under which their totals may be
#'   added.  tidycreel cannot verify this from the data; see the
#'   "Disjointness precondition" section above.
#' @param fpc Logical.  Apply the day-level finite-population correction
#'   \eqn{n_h / N_h}?  Default `TRUE`.  Set to `FALSE` for the conservative
#'   with-replacement variance.
#'
#' @return A `survey::svydesign` object with an additional class attribute
#'   `"creel_hybrid_svydesign"`.  The design data contains a `component`
#'   column (`"access"` or `"roving"`), a `weight` column carrying both the
#'   within-day and the day-to-season expansion, a `.hybrid_stratum` column
#'   holding the stratum-by-component interaction the design is stratified on,
#'   and a `.pop_days` column holding the stratum population \eqn{N_h} the
#'   finite-population correction is taken against.
#'
#' @examples
#' calendar <- data.frame(
#'   date = seq(as.Date("2024-06-01"), as.Date("2024-06-30"), by = "day")
#' )
#' calendar$day_type <- ifelse(
#'   format(calendar$date, "%u") %in% c("6", "7"), "weekend", "weekday"
#' )
#'
#' access <- data.frame(
#'   date     = as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend"),
#'   count    = c(12L, 15L, 30L, 28L)
#' )
#' roving <- data.frame(
#'   date     = as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend"),
#'   count    = c(8L, 10L, 22L, 25L)
#' )
#' design <- as_hybrid_svydesign(
#'   access_data      = access,
#'   roving_data      = roving,
#'   calendar         = calendar,
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
  calendar = NULL,
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

  # The calendar is the population of days the total expands to. Deriving N_h
  # from it rather than from a caller-supplied day fraction is how
  # creel_design() expresses the same quantity, and it gives one stratum one
  # population however many methods observed it -- a fraction per component
  # made access and roving imply different calendars for the same stratum
  # (#246).
  if (is.null(calendar)) {
    cli::cli_abort(c(
      "{.arg calendar} must be provided.",
      "x" = paste(
        "The design expands the component totals to a population of days,",
        "and the sampled dates alone cannot say how many days a stratum",
        "holds."
      ),
      "i" = paste(
        "Supply the season calendar with one row per day, carrying",
        "{.field {date_col}} and {.field {strata_col}}."
      )
    ))
  }
  if (!is.data.frame(calendar)) {
    cli::cli_abort("{.arg calendar} must be a data frame.")
  }
  missing_calendar <- setdiff(c(date_col, strata_col), names(calendar))
  if (length(missing_calendar) > 0L) {
    cli::cli_abort(
      "Column(s) {.field {missing_calendar}} missing from {.arg calendar}."
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

  # ---- One count row per component-day -------------------------------------
  # The day expansion below is a per-day factor, so it is only defined when a
  # sampled day is one row. Two counts on one date are two looks at that date,
  # not two sampled days: summed they multiply the total by the number of
  # counts per day, and N_h / n_h then multiplies that again. Same defect class
  # as refuse_duplicate_psus() on the creel_design bridge (#193, #197).
  .refuse_repeat_days <- function(data, name) {
    n_dup <- n_duplicate_psus(data, c(date_col, strata_col)) # nolint: object_usage_linter
    if (n_dup == 0L) {
      return(invisible(NULL))
    }
    cli::cli_abort(
      c(
        "{.arg {name}} has {n_dup} repeated sampling \\
         {cli::qty(n_dup)}day{?s}.",
        "x" = paste(
          "{cli::qty(n_dup)}The repeated {?row is/rows are} keyed on",
          "{.field {c(date_col, strata_col)}}."
        ),
        "x" = paste(
          "Two counts on one date are two looks at that date, not two",
          "sampled days. Summed, they multiply the total by the number of",
          "counts per day, and the expansion to the calendar multiplies",
          "that again."
        ),
        "i" = paste(
          "Average the repeats to one row per date before constructing the",
          "design."
        )
      ),
      class = "creel_error_repeated_psus"
    )
  }
  .refuse_repeat_days(access_data, "access_data")
  .refuse_repeat_days(roving_data, "roving_data")

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

  # ---- Calendar coverage ---------------------------------------------------
  # A sampled date absent from the calendar would leave N_h short of n_h, and
  # the sampling fraction n_h / N_h would exceed 1. Refuse rather than let the
  # fpc go out of range.
  cal_strata <- as.character(calendar[[strata_col]])
  cal_keys <- paste(cal_strata, as.character(calendar[[date_col]]))
  .check_calendar_coverage <- function(data, name) {
    keys <- paste(
      as.character(data[[strata_col]]),
      as.character(data[[date_col]])
    )
    unmatched <- setdiff(unique(keys), unique(cal_keys))
    if (length(unmatched) == 0L) {
      return(invisible(NULL))
    }
    cli::cli_abort(c(
      "{.arg {name}} sampled {length(unmatched)} date-stratum \\
       {cli::qty(length(unmatched))}combination{?s} absent from \\
       {.arg calendar}.",
      "x" = "{cli::qty(length(unmatched))}Unmatched: {.val {unmatched}}.",
      "i" = paste(
        "Every sampled date must appear in {.arg calendar} under the same",
        "stratum, or the population it expands to is smaller than the",
        "sample."
      )
    ))
  }
  .check_calendar_coverage(access_data, "access_data")
  .check_calendar_coverage(roving_data, "roving_data")

  # ---- Combine -------------------------------------------------------------
  access_out <- access_data[, required_cols, drop = FALSE]
  access_out$component <- "access"

  roving_out <- roving_data[, required_cols, drop = FALSE]
  roving_out$component <- "roving"

  combined <- rbind(access_out, roving_out)

  # Each component samples its own frame at its own rate, so the stratum is the
  # stratum-by-component interaction: pooling them derives one population size
  # from a row count that mixes both, and `fpc` then varies within stratum.
  combined$.hybrid_stratum <- paste(
    as.character(combined[[strata_col]]),
    combined$component,
    sep = "."
  )

  # ---- Day expansion and fpc -----------------------------------------------
  # n_h: distinct dates the component sampled in this stratum. N_h: distinct
  # days the stratum holds, from the calendar, shared by both components.
  # Count distinct dates on both sides so the ratio stays in days (GH #183).
  row_stratum <- as.character(combined[[strata_col]])
  n_days <- tapply(
    as.character(combined[[date_col]]),
    combined$.hybrid_stratum,
    function(x) length(unique(x))
  )
  pop_days <- tapply(
    as.character(calendar[[date_col]]),
    cal_strata,
    function(x) length(unique(x))
  )
  n_sampled_days <- as.numeric(n_days[combined$.hybrid_stratum])
  n_pop_days <- as.numeric(pop_days[row_stratum])

  # The within-day fraction expands the access points covered, or the route
  # coverage achieved, to the whole of a sampled day. N_h / n_h expands the
  # sampled days to the season. Both belong in the weight; only the second is a
  # stage-1 sampling fraction over the date PSUs, so only the second may drive
  # the fpc. Supplying the within-day fraction there made `survey` read it as a
  # fraction of the calendar and shrink the variance as though half the season
  # had been enumerated (#246).
  within_day <- ifelse(
    combined$component == "access",
    access_fraction[row_stratum],
    roving_fraction[row_stratum]
  )
  combined$weight <- unname(
    (1 / within_day) * (n_pop_days / n_sampled_days)
  )

  # Hand `survey` the population size rather than the fraction n_h / N_h. It
  # reads a value <= 1 as a fraction and derives the population by division,
  # which breaks outright when a stratum was fully sampled -- the fraction is
  # then exactly 1 and `as.fpc()` aborts inside `survey`. The population size
  # is a number we already know; there is nothing to derive.
  combined$.pop_days <- n_pop_days

  # ---- Build svydesign -----------------------------------------------------
  # Cluster on the date so a sampled day is one PSU. `nest` because dates
  # recur across the component strata.
  ids_formula <- stats::as.formula(paste0("~", date_col))
  strata_formula <- stats::as.formula("~.hybrid_stratum")
  weights_formula <- stats::as.formula("~weight")

  if (fpc) {
    design <- survey::svydesign(
      ids = ids_formula,
      strata = strata_formula,
      weights = weights_formula,
      fpc = ~.pop_days, # nolint: object_usage_linter
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
