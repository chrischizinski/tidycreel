#' Standardize sampled-day effort rows for count-based workflows
#'
#' @description
#' Converts a data frame that already contains sampled-day effort estimates into
#' a canonical tibble for downstream use with `add_counts()`. This helper is the
#' preferred seam for count-based workflows where raw within-day count schedules,
#' section probabilities, boat-party-size adjustments, camera multipliers, or
#' similar count-side corrections have already been resolved outside the core
#' estimator.
#'
#' The returned table always contains canonical columns:
#' `date`, any selected strata columns, `effort_type`, `daily_effort`, `psu`,
#' and `correction_factor`. Optional columns `n_counts`, `within_day_var`, and
#' `source_method` are included when supplied.
#'
#' @param data A data frame containing sampled-day effort rows.
#' @param date Tidy selector for the Date column.
#' @param strata Optional tidy selector for one or more strata columns.
#' @param effort_type Tidy selector for the effort-type column. Common values
#'   are `"bank"` and `"boat"`.
#' @param daily_effort Tidy selector for the numeric sampled-day effort column.
#' @param correction_factor Optional multiplicative correction applied to
#'   `daily_effort`. May be a scalar (defaults to `1`) or an expression that
#'   evaluates to a numeric vector with one value per row, including a bare
#'   column name. Values must be finite and strictly positive.
#' @param psu Optional tidy selector for the PSU column. Defaults to the selected
#'   date column when omitted.
#' @param n_counts Optional tidy selector for the number of within-day counts
#'   each sampled-day estimate is built from (k_d). Required whenever
#'   `within_day_var` is supplied.
#' @param within_day_var Optional tidy selector for the within-day
#'   **sum of squares** of the counts behind each sampled-day estimate, that is
#'   `sum((x - mean(x))^2)` per PSU. This is not a variance: the divisor is
#'   applied downstream by the estimator, which forms
#'   `sum(ss_d) / (n_sampled * (k_bar - 1))`. Supplying a variance here
#'   understates the within-day component by a factor of `k_d - 1`. Must be `0`
#'   wherever `n_counts` is 1, and requires `n_counts`.
#'
#'   Supply it on the raw `daily_effort` values you pass in; it is rescaled into `daily_effort`
#'   squared units on output, multiplied by `correction_factor^2`. `add_counts()` reads the emitted
#'   `within_day_var` and `n_counts` columns into the design, so the reported SE
#'   carries a within-day component. Before tidycreel 2.6.0 both columns were
#'   written here and never read, and the SE omitted that component entirely.
#'   Do not combine with `add_counts(count_time_col = )`, which derives the same
#'   quantity from raw counts; supplying both is an error.
#' @param source_method Optional tidy selector for a column describing how the
#'   sampled-day effort estimate was derived (e.g. `"direct_count"`,
#'   `"boat_count_x_mean_party_size"`, `"camera_count_x_detection_correction"`).
#'
#' @return A tibble with canonical sampled-day effort columns. Required columns
#'   are `date`, selected strata columns (if any), `effort_type`, `daily_effort`,
#'   `psu`, and `correction_factor`. Optional columns are appended when supplied.
#'
#' @seealso [add_counts()]
#' @family "Survey Design"
#' @export
prep_counts_daily_effort <- function(
  data,
  date,
  strata = NULL,
  effort_type,
  daily_effort,
  correction_factor = 1,
  psu = NULL,
  n_counts = NULL,
  within_day_var = NULL,
  source_method = NULL
) {
  date_quo <- rlang::enquo(date)
  strata_quo <- rlang::enquo(strata)
  effort_type_quo <- rlang::enquo(effort_type)
  daily_effort_quo <- rlang::enquo(daily_effort)
  correction_factor_quo <- rlang::enquo(correction_factor)
  psu_quo <- rlang::enquo(psu)
  n_counts_quo <- rlang::enquo(n_counts)
  within_day_var_quo <- rlang::enquo(within_day_var)
  source_method_quo <- rlang::enquo(source_method)

  date_col <- names(tidyselect::eval_select(date_quo, data))
  if (length(date_col) != 1L) {
    cli::cli_abort(c(
      "{.arg date} must select exactly one column.",
      "x" = "Selected {length(date_col)} columns."
    ))
  }

  strata_cols <- if (rlang::quo_is_null(strata_quo)) {
    character(0)
  } else {
    names(tidyselect::eval_select(strata_quo, data))
  }

  effort_type_col <- names(tidyselect::eval_select(effort_type_quo, data))
  if (length(effort_type_col) != 1L) {
    cli::cli_abort(c(
      "{.arg effort_type} must select exactly one column.",
      "x" = "Selected {length(effort_type_col)} columns."
    ))
  }

  daily_effort_col <- names(tidyselect::eval_select(daily_effort_quo, data))
  if (length(daily_effort_col) != 1L) {
    cli::cli_abort(c(
      "{.arg daily_effort} must select exactly one column.",
      "x" = "Selected {length(daily_effort_col)} columns."
    ))
  }

  psu_col <- if (rlang::quo_is_null(psu_quo)) {
    date_col
  } else {
    names(tidyselect::eval_select(psu_quo, data))
  }
  if (length(psu_col) != 1L) {
    cli::cli_abort(c(
      "{.arg psu} must select exactly one column when supplied.",
      "x" = "Selected {length(psu_col)} columns."
    ))
  }

  n_counts_col <- if (rlang::quo_is_null(n_counts_quo)) {
    NULL
  } else {
    names(tidyselect::eval_select(n_counts_quo, data))
  }

  within_day_var_col <- if (rlang::quo_is_null(within_day_var_quo)) {
    NULL
  } else {
    names(tidyselect::eval_select(within_day_var_quo, data))
  }

  validate_within_day_inputs(n_counts_col, within_day_var_col, data)

  source_method_col <- if (rlang::quo_is_null(source_method_quo)) {
    NULL
  } else {
    names(tidyselect::eval_select(source_method_quo, data))
  }

  date_vals <- data[[date_col]]
  if (!inherits(date_vals, "Date")) {
    cli::cli_abort(c(
      "{.field {date_col}} must be a {.cls Date} column.",
      "x" = "Got class {.cls {class(date_vals)[1]}}."
    ))
  }

  base_daily_effort_vals <- data[[daily_effort_col]]
  if (!is.numeric(base_daily_effort_vals)) {
    cli::cli_abort(c(
      "{.field {daily_effort_col}} must be numeric.",
      "x" = "Got class {.cls {class(base_daily_effort_vals)[1]}}."
    ))
  }

  if (any(!is.finite(base_daily_effort_vals))) {
    cli::cli_abort(c(
      "{.field {daily_effort_col}} must contain finite values.",
      "x" = "Found {sum(!is.finite(base_daily_effort_vals))} non-finite value(s)."
    ))
  }

  effort_type_vals <- data[[effort_type_col]]
  if (!(is.character(effort_type_vals) || is.factor(effort_type_vals))) {
    cli::cli_abort(c(
      "{.field {effort_type_col}} must be character or factor.",
      "x" = "Got class {.cls {class(effort_type_vals)[1]}}."
    ))
  }

  correction_factor_vals <- rlang::eval_tidy(correction_factor_quo, data = data)
  if (length(correction_factor_vals) == 1L) {
    correction_factor_vals <- rep(correction_factor_vals, nrow(data))
  }

  if (!is.numeric(correction_factor_vals)) {
    cli::cli_abort(c(
      "{.arg correction_factor} must be numeric.",
      "x" = "Got class {.cls {class(correction_factor_vals)[1]}}."
    ))
  }

  if (length(correction_factor_vals) != nrow(data)) {
    cli::cli_abort(c(
      "{.arg correction_factor} must be length 1 or match the number of rows in {.arg data}.",
      "x" = "Got length {length(correction_factor_vals)} for {nrow(data)} row(s)."
    ))
  }

  if (any(!is.finite(correction_factor_vals))) {
    cli::cli_abort(c(
      "{.arg correction_factor} must contain finite values.",
      "x" = "Found {sum(!is.finite(correction_factor_vals))} non-finite value(s)."
    ))
  }

  if (any(correction_factor_vals <= 0)) {
    cli::cli_abort(c(
      "{.arg correction_factor} must be strictly positive.",
      "x" = "Found {sum(correction_factor_vals <= 0)} non-positive value(s)."
    ))
  }

  adjusted_daily_effort_vals <- base_daily_effort_vals * correction_factor_vals

  out <- tibble::tibble(
    date = date_vals
  )

  for (col in strata_cols) {
    out[[col]] <- data[[col]]
  }

  out[["effort_type"]] <- as.character(effort_type_vals)
  out[["daily_effort"]] <- adjusted_daily_effort_vals
  out[["psu"]] <- data[[psu_col]]
  out[["correction_factor"]] <- correction_factor_vals

  if (!is.null(n_counts_col)) {
    out[["n_counts"]] <- data[[n_counts_col]]
  }
  if (!is.null(within_day_var_col)) {
    # daily_effort is scaled by correction_factor above, so the sum of squares
    # has to be scaled by its square to stay in (daily_effort)^2 units. Passing
    # it through unscaled would leave the within-day component a factor of cf^2
    # away from the between-day term it is added to (GH #109).
    out[["within_day_var"]] <- data[[within_day_var_col]] *
      correction_factor_vals^2
  }
  if (!is.null(source_method_col)) {
    out[["source_method"]] <- data[[source_method_col]]
  }

  mark_counts_as_effort(out) # nolint: object_usage_linter
}

#' Standardize boat-party sampled-day effort rows
#'
#' @description
#' Converts boat-count rows plus mean anglers-per-boat inputs into canonical
#' sampled-day effort rows for downstream use with `add_counts()`. This helper
#' is intentionally narrow: it handles the common boat-party expansion
#' (`boat_count * mean_party_size`) and leaves broader source-specific
#' reconstruction outside estimator internals.
#'
#' The returned table always contains canonical columns:
#' `date`, any selected strata columns, `effort_type`, `daily_effort`, `psu`,
#' and `correction_factor`. Optional columns `n_counts`, `within_day_var`, and
#' `source_method` are included when supplied.
#'
#' @param data A data frame containing sampled-day boat-count rows.
#' @param date Tidy selector for the Date column.
#' @param strata Optional tidy selector for one or more strata columns.
#' @param boat_count Tidy selector for the numeric boat count column.
#' @param mean_party_size Tidy selector for the numeric mean anglers-per-boat
#'   column.
#' @param mean_party_size_se Optional standard error of `mean_party_size`. May
#'   be a scalar or an expression evaluating to one value per row. Supplying it
#'   emits the `expansion_*` carrier columns, which [add_counts()] reads so the
#'   reported standard error includes the party-size sampling error.
#'
#'   `NULL` (the default) leaves the component absent rather than zero. A zero
#'   would enter the variance as "the multiplier is known exactly" and be
#'   indistinguishable from never having propagated, so the two states are kept
#'   apart. `NA` is accepted and propagates as unknown.
#'
#'   Before tidycreel 3.4.0 this argument did not exist, and the component was
#'   unreachable on this path: the same expansion through
#'   [derive_angler_count()] reported a larger, correct standard error while
#'   this one silently omitted the term (GH #143).
#' @param effort_type Effort-type values for output. Defaults to "boat". May be
#'   a scalar string/factor or an expression that evaluates to one value per row.
#' @param correction_factor Optional multiplicative correction applied after the
#'   boat-party expansion. May be a scalar (defaults to `1`) or an expression
#'   that evaluates to a numeric vector with one value per row. Values must be
#'   finite and strictly positive.
#' @param psu Optional tidy selector for the PSU column. Defaults to the selected
#'   date column when omitted.
#' @param n_counts Optional tidy selector for the number of within-day counts
#'   each sampled-day estimate is built from (k_d). Required whenever
#'   `within_day_var` is supplied.
#' @param within_day_var Optional tidy selector for the within-day
#'   **sum of squares** of the counts behind each sampled-day estimate, that is
#'   `sum((x - mean(x))^2)` per PSU. This is not a variance: the divisor is
#'   applied downstream by the estimator, which forms
#'   `sum(ss_d) / (n_sampled * (k_bar - 1))`. Supplying a variance here
#'   understates the within-day component by a factor of `k_d - 1`. Must be `0`
#'   wherever `n_counts` is 1, and requires `n_counts`.
#'
#'   Supply it on the raw `boat_count` values you pass in; it is rescaled into `daily_effort`
#'   squared units on output, multiplied by `(mean_party_size * correction_factor)^2`. `add_counts()` reads the emitted
#'   `within_day_var` and `n_counts` columns into the design, so the reported SE
#'   carries a within-day component. Before tidycreel 2.6.0 both columns were
#'   written here and never read, and the SE omitted that component entirely.
#'   Do not combine with `add_counts(count_time_col = )`, which derives the same
#'   quantity from raw counts; supplying both is an error.
#' @param source_method Optional source-method values. Defaults to
#'   `"boat_count_x_mean_party_size"`. May be a scalar string/factor or an
#'   expression that evaluates to one value per row.
#'
#' @return A tibble with canonical sampled-day effort columns. Required columns
#'   are `date`, selected strata columns (if any), `effort_type`, `daily_effort`,
#'   `psu`, and `correction_factor`. Optional columns are appended when supplied.
#'
#' @seealso [prep_counts_daily_effort()], [add_counts()]
#' @family "Survey Design"
#' @export
prep_counts_boat_party <- function(
  data,
  date,
  strata = NULL,
  boat_count,
  mean_party_size,
  mean_party_size_se = NULL,
  effort_type = "boat",
  correction_factor = 1,
  psu = NULL,
  n_counts = NULL,
  within_day_var = NULL,
  source_method = "boat_count_x_mean_party_size"
) {
  date_quo <- rlang::enquo(date)
  strata_quo <- rlang::enquo(strata)
  boat_count_quo <- rlang::enquo(boat_count)
  mean_party_size_quo <- rlang::enquo(mean_party_size)
  mean_party_size_se_quo <- rlang::enquo(mean_party_size_se)
  effort_type_quo <- rlang::enquo(effort_type)
  correction_factor_quo <- rlang::enquo(correction_factor)
  psu_quo <- rlang::enquo(psu)
  n_counts_quo <- rlang::enquo(n_counts)
  within_day_var_quo <- rlang::enquo(within_day_var)
  source_method_quo <- rlang::enquo(source_method)

  date_col <- names(tidyselect::eval_select(date_quo, data))
  if (length(date_col) != 1L) {
    cli::cli_abort(c(
      "{.arg date} must select exactly one column.",
      "x" = "Selected {length(date_col)} columns."
    ))
  }

  strata_cols <- if (rlang::quo_is_null(strata_quo)) {
    character(0)
  } else {
    names(tidyselect::eval_select(strata_quo, data))
  }

  boat_count_col <- names(tidyselect::eval_select(boat_count_quo, data))
  if (length(boat_count_col) != 1L) {
    cli::cli_abort(c(
      "{.arg boat_count} must select exactly one column.",
      "x" = "Selected {length(boat_count_col)} columns."
    ))
  }

  mean_party_size_col <- names(tidyselect::eval_select(mean_party_size_quo, data))
  if (length(mean_party_size_col) != 1L) {
    cli::cli_abort(c(
      "{.arg mean_party_size} must select exactly one column.",
      "x" = "Selected {length(mean_party_size_col)} columns."
    ))
  }

  psu_col <- if (rlang::quo_is_null(psu_quo)) {
    date_col
  } else {
    names(tidyselect::eval_select(psu_quo, data))
  }
  if (length(psu_col) != 1L) {
    cli::cli_abort(c(
      "{.arg psu} must select exactly one column when supplied.",
      "x" = "Selected {length(psu_col)} columns."
    ))
  }

  n_counts_col <- if (rlang::quo_is_null(n_counts_quo)) {
    NULL
  } else {
    names(tidyselect::eval_select(n_counts_quo, data))
  }

  within_day_var_col <- if (rlang::quo_is_null(within_day_var_quo)) {
    NULL
  } else {
    names(tidyselect::eval_select(within_day_var_quo, data))
  }

  validate_within_day_inputs(n_counts_col, within_day_var_col, data)

  date_vals <- data[[date_col]]
  if (!inherits(date_vals, "Date")) {
    cli::cli_abort(c(
      "{.field {date_col}} must be a {.cls Date} column.",
      "x" = "Got class {.cls {class(date_vals)[1]}}."
    ))
  }

  boat_count_vals <- data[[boat_count_col]]
  if (!is.numeric(boat_count_vals)) {
    cli::cli_abort(c(
      "{.field {boat_count_col}} must be numeric.",
      "x" = "Got class {.cls {class(boat_count_vals)[1]}}."
    ))
  }
  if (any(!is.finite(boat_count_vals))) {
    cli::cli_abort(c(
      "{.field {boat_count_col}} must contain finite values.",
      "x" = "Found {sum(!is.finite(boat_count_vals))} non-finite value(s)."
    ))
  }
  if (any(boat_count_vals < 0)) {
    cli::cli_abort(c(
      "{.field {boat_count_col}} must be non-negative.",
      "x" = "Found {sum(boat_count_vals < 0)} negative value(s)."
    ))
  }

  mean_party_size_vals <- data[[mean_party_size_col]]
  if (!is.numeric(mean_party_size_vals)) {
    cli::cli_abort(c(
      "{.field {mean_party_size_col}} must be numeric.",
      "x" = "Got class {.cls {class(mean_party_size_vals)[1]}}."
    ))
  }
  if (any(!is.finite(mean_party_size_vals))) {
    cli::cli_abort(c(
      "{.field {mean_party_size_col}} must contain finite values.",
      "x" = "Found {sum(!is.finite(mean_party_size_vals))} non-finite value(s)."
    ))
  }
  if (any(mean_party_size_vals <= 0)) {
    cli::cli_abort(c(
      "{.field {mean_party_size_col}} must be strictly positive.",
      "x" = "Found {sum(mean_party_size_vals <= 0)} non-positive value(s)."
    ))
  }

  correction_factor_vals <- rlang::eval_tidy(correction_factor_quo, data = data)
  if (length(correction_factor_vals) == 1L) {
    correction_factor_vals <- rep(correction_factor_vals, nrow(data))
  }
  if (!is.numeric(correction_factor_vals)) {
    cli::cli_abort(c(
      "{.arg correction_factor} must be numeric.",
      "x" = "Got class {.cls {class(correction_factor_vals)[1]}}."
    ))
  }
  if (length(correction_factor_vals) != nrow(data)) {
    cli::cli_abort(c(
      "{.arg correction_factor} must be length 1 or match the number of rows in {.arg data}.",
      "x" = "Got length {length(correction_factor_vals)} for {nrow(data)} row(s)."
    ))
  }
  if (any(!is.finite(correction_factor_vals))) {
    cli::cli_abort(c(
      "{.arg correction_factor} must contain finite values.",
      "x" = "Found {sum(!is.finite(correction_factor_vals))} non-finite value(s)."
    ))
  }
  if (any(correction_factor_vals <= 0)) {
    cli::cli_abort(c(
      "{.arg correction_factor} must be strictly positive.",
      "x" = "Found {sum(correction_factor_vals <= 0)} non-positive value(s)."
    ))
  }

  # NULL rather than zero when absent, the same contract `derive_angler_count()`
  # keeps: a zero would enter the variance as "the multiplier is known exactly"
  # and be indistinguishable from never having propagated (GH #143).
  mean_party_size_se_vals <- if (rlang::quo_is_null(mean_party_size_se_quo)) {
    NULL
  } else {
    se_vals <- rlang::eval_tidy(mean_party_size_se_quo, data = data)
    if (length(se_vals) == 1L) {
      se_vals <- rep(se_vals, nrow(data))
    }
    if (!is.numeric(se_vals)) {
      cli::cli_abort(c(
        "{.arg mean_party_size_se} must be numeric.",
        "x" = "Got class {.cls {class(se_vals)[1]}}."
      ))
    }
    if (length(se_vals) != nrow(data)) {
      cli::cli_abort(c(
        "{.arg mean_party_size_se} must be length 1 or match the number of rows in {.arg data}.",
        "x" = "Got length {length(se_vals)} for {nrow(data)} row(s)."
      ))
    }
    # NA is allowed through and propagates: a multiplier whose uncertainty could
    # not be estimated gives an unknown component, not a smaller one. Negative
    # is not a standard error.
    if (any(se_vals < 0, na.rm = TRUE)) {
      cli::cli_abort(c(
        "{.arg mean_party_size_se} must not be negative.",
        "x" = "Found {sum(se_vals < 0, na.rm = TRUE)} negative value(s)."
      ))
    }
    as.numeric(se_vals)
  }

  effort_type_vals <- rlang::eval_tidy(effort_type_quo, data = data)
  if (length(effort_type_vals) == 1L) {
    effort_type_vals <- rep(effort_type_vals, nrow(data))
  }
  if (length(effort_type_vals) != nrow(data)) {
    cli::cli_abort(c(
      "{.arg effort_type} must be length 1 or match the number of rows in {.arg data}.",
      "x" = "Got length {length(effort_type_vals)} for {nrow(data)} row(s)."
    ))
  }
  if (!(is.character(effort_type_vals) || is.factor(effort_type_vals))) {
    cli::cli_abort(c(
      "{.arg effort_type} must evaluate to character or factor values.",
      "x" = "Got class {.cls {class(effort_type_vals)[1]}}."
    ))
  }

  source_method_vals <- rlang::eval_tidy(source_method_quo, data = data)
  if (length(source_method_vals) == 1L) {
    source_method_vals <- rep(source_method_vals, nrow(data))
  }
  if (length(source_method_vals) != nrow(data)) {
    cli::cli_abort(c(
      "{.arg source_method} must be length 1 or match the number of rows in {.arg data}.",
      "x" = "Got length {length(source_method_vals)} for {nrow(data)} row(s)."
    ))
  }
  if (!(is.character(source_method_vals) || is.factor(source_method_vals))) {
    cli::cli_abort(c(
      "{.arg source_method} must evaluate to character or factor values.",
      "x" = "Got class {.cls {class(source_method_vals)[1]}}."
    ))
  }

  out <- tibble::tibble(
    date = date_vals
  )

  for (col in strata_cols) {
    out[[col]] <- data[[col]]
  }

  out[["effort_type"]] <- as.character(effort_type_vals)
  out[["daily_effort"]] <- boat_count_vals * mean_party_size_vals * correction_factor_vals
  out[["psu"]] <- data[[psu_col]]
  out[["correction_factor"]] <- correction_factor_vals

  if (!is.null(n_counts_col)) {
    out[["n_counts"]] <- data[[n_counts_col]]
  }
  if (!is.null(within_day_var_col)) {
    # daily_effort is boat_count x mean_party_size x correction_factor here, so
    # a sum of squares computed on boat counts needs both factors squared to
    # reach (daily_effort)^2 units (GH #109).
    out[["within_day_var"]] <- data[[within_day_var_col]] *
      (mean_party_size_vals * correction_factor_vals)^2
  }
  out[["source_method"]] <- as.character(source_method_vals)

  # Carrier columns for the party-size variance component (GH #143). This
  # function performs the same boat -> angler expansion as
  # `derive_angler_count()` but wrote none of them, so the component was not
  # merely omitted by default -- it was unreachable, on the pipeline the
  # documentation calls preferred.
  if (!is.null(mean_party_size_se_vals)) {
    # d(daily_effort)/d(mean_party_size). The correction factor multiplies the
    # product here, so it belongs in the basis: a basis of the bare boat count
    # would be the derivative of a quantity this function does not produce, and
    # `add_counts()` would be right to call it desynchronised (GH #131).
    out[["expansion_basis"]] <- boat_count_vals * correction_factor_vals
    out[["expansion_se"]] <- mean_party_size_se_vals
    # No join key is available here -- `mean_party_size` selects a column of
    # `data` rather than arriving from `mean_party_size()` with its grouping
    # attached -- so the group falls back to the multiplier's own value, the
    # same fallback `with_expansion_group()` documents. Two separate estimates
    # that happen to be numerically equal then merge into one group, which
    # treats them as correlated and overstates rather than understates.
    out[["expansion_group"]] <- as.character(mean_party_size_vals)
    # This function does its own multiplication, so the basis is the derivative
    # of the column it writes, not of a count handed to it later.
    out[["expansion_of"]] <- "daily_effort"
  }

  mark_counts_as_effort(out) # nolint: object_usage_linter
}

# Within-day variance inputs ----

#' Validate the within-day variance inputs to the prep_counts_* functions
#'
#' `within_day_var` is consumed as a per-PSU **sum of squares**, not a variance:
#' `compute_within_day_var_contribution()` forms
#' `sum(ss_d) / (n_sampled * (k_bar - 1))`, supplying the divisor itself. It also
#' needs `k_d`, which is what `n_counts` carries, so the two columns are only
#' usable together. Before GH #109 both were written to the output tibble and
#' never read by `add_counts()`, so a within-day component supplied here was
#' silently dropped and the reported SE omitted it entirely.
#'
#' @param n_counts_col Resolved column name or NULL
#' @param within_day_var_col Resolved column name or NULL
#' @param data The caller's data frame
#' @param call Calling environment for the condition
#'
#' @keywords internal
#' @noRd
validate_within_day_inputs <- function(
  n_counts_col,
  within_day_var_col,
  data,
  call = rlang::caller_env()
) {
  if (is.null(within_day_var_col)) {
    return(invisible(NULL))
  }

  if (is.null(n_counts_col)) {
    cli::cli_abort(
      c(
        "{.arg within_day_var} requires {.arg n_counts}.",
        "x" = "The within-day variance component needs the number of counts per \\
               PSU as well as the sum of squares.",
        "i" = "{.arg within_day_var} is a {.strong sum of squares}, not a variance: \\
               pass {.code sum((x - mean(x))^2)} per PSU.",
        "i" = "Supply {.arg n_counts} with the number of counts each PSU is built from."
      ),
      call = call
    )
  }

  ss_vals <- data[[within_day_var_col]]
  k_vals <- data[[n_counts_col]]

  if (!is.numeric(ss_vals)) {
    cli::cli_abort(
      c(
        "{.arg within_day_var} must be numeric.",
        "x" = "Column {.val {within_day_var_col}} is {.cls {class(ss_vals)[1]}}."
      ),
      call = call
    )
  }
  if (!is.numeric(k_vals)) {
    cli::cli_abort(
      c(
        "{.arg n_counts} must be numeric.",
        "x" = "Column {.val {n_counts_col}} is {.cls {class(k_vals)[1]}}."
      ),
      call = call
    )
  }

  bad_ss <- !is.na(ss_vals) & ss_vals < 0
  if (any(bad_ss)) {
    cli::cli_abort(
      c(
        "{.arg within_day_var} must not be negative.",
        "x" = "Found {sum(bad_ss)} negative value{?s} in {.val {within_day_var_col}}.",
        "i" = "A sum of squares cannot be negative."
      ),
      call = call
    )
  }

  bad_k <- !is.na(k_vals) & k_vals < 1
  if (any(bad_k)) {
    cli::cli_abort(
      c(
        "{.arg n_counts} must be at least 1.",
        "x" = "Found {sum(bad_k)} value{?s} below 1 in {.val {n_counts_col}}."
      ),
      call = call
    )
  }

  # A single count carries no within-day information, so its sum of squares must
  # be zero. A non-zero value means the two columns describe different things.
  single <- !is.na(k_vals) & k_vals == 1 & !is.na(ss_vals) & ss_vals != 0
  if (any(single)) {
    cli::cli_abort(
      c(
        "{.arg within_day_var} is non-zero where {.arg n_counts} is 1.",
        "x" = "Found {sum(single)} such row{?s}.",
        "i" = "A PSU built from one count has no within-day variation, so its \\
               sum of squares must be 0.",
        "i" = "Check that {.arg within_day_var} is a sum of squares and not a variance."
      ),
      call = call
    )
  }

  invisible(NULL)
}
