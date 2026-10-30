# Totals with catch rates pooled more coarsely than effort (GH #389).
#
# A rate group pools the interviews of several effort cells -- bank anglers over
# a season block, say, while boat rates stay monthly -- and each cell's effort is
# multiplied by its group's rate. The standard product path
# (compute_stratum_product_sum()) cannot be reused for this by joining the
# pooled rate onto each cell. It treats every cell's rate as independent of
# every other's, so a rate shared by k cells would enter the variance as
# sum(E_c^2) Var(R) instead of (sum E_c)^2 Var(R), its interviews would be
# counted k times, and cells counted on the same drives (bank and boat) would
# be summed with no covariance. All three understate the SE silently.
#
# The estimator here, for a reported row r with rate groups g:
#
#   T_r      = sum_g E_rg R_g
#   Var(T_r) = Var_E(sum_g R_g E_rg)                    effort, at the estimated rates
#            + sum_g E_rg^2 Var(R_g)                    rate, one shared error per group
#            - sum_g Var(E_rg) Var(R_g)                 Goodman (1960) unbiased form, floored at first order
#
# Rates of different groups come from disjoint interviews and are independent
# of each other and of the counts. The effort term is the variance of an effort
# total whose counts were each multiplied by their group's rate, so it is
# computed by the existing effort estimator on a reweighted copy of the design:
# between-day and within-day variance, the bank-boat covariance of units counted
# at the same occasions, and the shared party-size term all come from the code
# that already gets them right for effort.


#' Validate a rate-group mapping table against a design
#'
#' Internal. The keys are the design's strata columns and, optionally,
#' `angler_type`; exactly one other column names the group.
#'
#' @param design A `creel_design`.
#' @param rate_groups The user's mapping table.
#' @param call Calling environment for conditions.
#' @return A list: `map` (the table), `key_cols`, `group_col`.
#' @keywords internal
#' @noRd
resolve_rate_groups <- function(design, rate_groups, call = rlang::caller_env()) {
  if (!is.data.frame(rate_groups)) {
    cli::cli_abort(
      "{.arg rate_groups} must be a data frame, not {.cls {class(rate_groups)[1]}}.",
      call = call, class = "creel_error_rate_groups"
    )
  }
  allowed_keys <- c(design$strata_cols, "angler_type")
  key_cols <- intersect(names(rate_groups), allowed_keys)
  group_col <- setdiff(names(rate_groups), allowed_keys)
  missing_strata <- setdiff(design$strata_cols, key_cols)
  if (length(missing_strata) > 0L) {
    cli::cli_abort(
      c(
        "{.arg rate_groups} must name every stratum column.",
        "x" = "Missing: {.field {missing_strata}}.",
        "i" = "Each row maps one effort cell, so the table lists every cell, \\
               pooled or not. A table keyed by only some strata would map whole \\
               blocks of cells it never lists, and a missing cell could not be \\
               told from a pooled one."
      ),
      call = call, class = "creel_error_rate_groups"
    )
  }
  if (length(key_cols) == 0L || length(group_col) != 1L) {
    cli::cli_abort(
      c(
        "{.arg rate_groups} must have key columns and exactly one group column.",
        "i" = "Key columns are the design's strata ({.field {design$strata_cols}}) \\
               and, optionally, {.field angler_type}.",
        "x" = "Key column{?s} found: {.field {key_cols}}.",
        "x" = "Other column{?s} found: {.field {group_col}}."
      ),
      call = call, class = "creel_error_rate_groups"
    )
  }
  groups <- rate_groups[[group_col]]
  if (anyNA(groups) || any(!nzchar(as.character(groups)))) {
    cli::cli_abort(
      "{.arg rate_groups}${.field {group_col}} has an empty or missing group label.",
      call = call, class = "creel_error_rate_groups"
    )
  }
  # An NA key is allowed: it maps the cell whose value is unknown (an
  # interview whose angler type was not recorded, say), which group_key()
  # keeps distinct from every real label. Refusing it would leave such a cell
  # impossible to place, and so impossible to estimate.
  key <- group_key(rate_groups, key_cols) # nolint: object_usage_linter
  if (anyDuplicated(key)) {
    cli::cli_abort(
      c(
        "{.arg rate_groups} maps the same cell more than once.",
        "x" = "A cell can use only one rate."
      ),
      call = call, class = "creel_error_rate_groups"
    )
  }
  if ("angler_type" %in% key_cols) {
    if (!"angler_type" %in% names(design$counts)) {
      cli::cli_abort(
        c(
          "{.arg rate_groups} is keyed by {.field angler_type}, but the counts have no \\
           {.field angler_type} column.",
          "i" = "Build one row per count and angler type with \\
                 {.code derive_angler_count(by_type = TRUE)} and pass \\
                 {.field angler_type} in {.code add_counts(unit_cols = )}."
        ),
        call = call, class = "creel_error_rate_groups"
      )
    }
    if (is.null(design$angler_type_col)) {
      cli::cli_abort(
        c(
          "{.arg rate_groups} is keyed by {.field angler_type}, but the interviews \\
           have no angler type.",
          "i" = "Pass {.arg angler_type} to {.fn add_interviews}."
        ),
        call = call, class = "creel_error_rate_groups"
      )
    }
  }
  rate_groups[[group_col]] <- as.character(groups)
  list(map = rate_groups, key_cols = key_cols, group_col = group_col)
}


#' Each row's rate group, by key
#'
#' @param df Counts, interviews or occasion rows.
#' @param spec From `resolve_rate_groups()`.
#' @param type_col The column holding angler type in `df`.
#' @return Character vector, `NA` where the row's cell is not in the map.
#' @keywords internal
#' @noRd
rate_group_of <- function(df, spec, type_col = "angler_type") {
  src <- df
  if ("angler_type" %in% spec$key_cols) {
    src[["angler_type"]] <- df[[type_col]]
  }
  spec$map[[spec$group_col]][
    match(group_key(src, spec$key_cols), group_key(spec$map, spec$key_cols)) # nolint: object_usage_linter
  ]
}


#' Put each count and interview in its rate group, refusing anything unmapped
#'
#' @return The design with `.rate_group` on its counts, occasion table,
#'   within-day variance table and interviews, and both surveys rebuilt.
#' @keywords internal
#' @noRd
attach_rate_groups <- function(design, spec, call = rlang::caller_env()) {
  count_group <- rate_group_of(design$counts, spec)
  if (anyNA(count_group)) {
    cells <- unique(group_key(design$counts[is.na(count_group), , drop = FALSE], spec$key_cols)) # nolint: object_usage_linter
    cli::cli_abort(
      c(
        "{length(cells)} effort cell{?s} {?has/have} no rate group.",
        "x" = "Unmapped: {.val {gsub('\u001f', ' / ', cells, fixed = TRUE)}}.",
        "i" = "{cli::qty(length(cells))}Every effort cell needs a rate; add {?it/them} to {.arg rate_groups}. \\
               A cell without a rate has an unknown catch, not a zero one."
      ),
      call = call, class = "creel_error_rate_groups"
    )
  }
  # A row is in use if it places counts or interviews: an unknown-type row
  # may map interviews only, since counts are written with known types.
  used <- unique(c(
    group_key(design$counts, spec$key_cols), # nolint: object_usage_linter
    group_key(rate_group_key_frame(design$interviews, spec, design), spec$key_cols) # nolint: object_usage_linter
  ))
  unused <- setdiff(group_key(spec$map, spec$key_cols), used) # nolint: object_usage_linter
  if (length(unused) > 0L) {
    cli::cli_abort(
      c(
        "{length(unused)} row{?s} of {.arg rate_groups} match{?es/} no effort cell.",
        "x" = "Unmatched: {.val {gsub('\u001f', ' / ', unused, fixed = TRUE)}}.",
        "i" = "Check the key values for typos: a row that places no count or \\
               interview usually means the row meant for that cell is missing."
      ),
      call = call, class = "creel_error_rate_groups"
    )
  }

  interview_group <- rate_group_of(design$interviews, spec, design$angler_type_col %||% "angler_type")
  if (anyNA(interview_group)) {
    cells <- unique(group_key( # nolint: object_usage_linter
      rate_group_key_frame(design$interviews[is.na(interview_group), , drop = FALSE], spec, design),
      spec$key_cols
    ))
    cli::cli_abort(
      c(
        "{sum(is.na(interview_group))} interview{?s} fall{?s/} in no rate group.",
        "x" = "Cells: {.val {gsub('\u001f', ' / ', cells, fixed = TRUE)}}.",
        "i" = "{cli::qty(length(cells))}Their trips would be left out of every rate. Map the cell{?s} in \\
               {.arg rate_groups}, or correct the interviews' strata or angler type."
      ),
      call = call, class = "creel_error_rate_groups"
    )
  }

  design$counts$.rate_group <- count_group
  if (!is.null(design$within_day_counts)) {
    design$within_day_counts$.rate_group <- rate_group_of(design$within_day_counts, spec)
  }
  if (!is.null(design$within_day_var)) {
    design$within_day_var$.rate_group <- rate_group_of(design$within_day_var, spec)
  }
  design$survey <- construct_survey_design(design) # nolint: object_usage_linter
  interviews <- design$interviews
  interviews$.rate_group <- interview_group
  rebuild_interview_survey(design, interviews) # nolint: object_usage_linter
}


#' The interview columns a rate-group key reads, under the key's names
#' @keywords internal
#' @noRd
rate_group_key_frame <- function(df, spec, design) {
  out <- df
  if ("angler_type" %in% spec$key_cols) {
    out[["angler_type"]] <- df[[design$angler_type_col]]
  }
  out
}


#' One rate per group, from every trip in the group
#'
#' With `species_col`, one rate per species and group: each species' counts
#' zero-filled over every interview, so a species nobody in the group caught
#' has a known rate of zero, not a missing one.
#'
#' @return A data frame with `.rate_group`, `estimate`, `se`, `n`, and the
#'   species column first when `species_col` is given.
#' @keywords internal
#' @noRd
rate_group_rates <- function(design, metric, variance_method, conf_level, species_col = NULL) {
  by <- ".rate_group"
  estimator <- design$total_estimator %||% "ratio-of-means"
  out <- if (is.null(species_col)) {
    res <- switch(metric,
      catch = cpue_for_stratum_product(design, by, variance_method, conf_level), # nolint: object_usage_linter
      harvest = estimate_harvest_grouped(design, by, variance_method, conf_level, estimator), # nolint: object_usage_linter
      release = rpue_for_stratum_product(design, by, variance_method, conf_level) # nolint: object_usage_linter
    )
    as.data.frame(res$estimates)
  } else {
    species_fn <- switch(metric,
      catch = estimate_cpue_species, # nolint: object_usage_linter
      harvest = estimate_hpue_species, # nolint: object_usage_linter
      release = estimate_release_rate_species # nolint: object_usage_linter
    )
    # validate = FALSE: the group floor was applied by the caller, once, to the
    # groups -- the same trips for every species.
    as.data.frame(species_fn(
      design,
      species_col = species_col, interview_by_vars = by,
      variance_method = variance_method, conf_level = conf_level,
      estimator = estimator, validate = FALSE
    ))
  }
  rates <- data.frame(
    .rate_group = as.character(out[[by]]),
    estimate = out$estimate,
    se = out$se,
    n = out$n,
    stringsAsFactors = FALSE
  )
  if (!is.null(species_col)) {
    rates <- cbind(stats::setNames(out[species_col], species_col), rates)
  }
  rates
}


#' A copy of the design whose counts are each multiplied by their group's rate
#'
#' Every stored form of the count is scaled, because each one feeds a different
#' part of the effort variance: the per-unit counts (between-day), the raw
#' occasions (within-day, paired across units counted at the same times), the
#' per-unit within-day sums of squares (within-day, unpaired), and the party-size
#' basis (its derivative). All are linear in the count except the sums of
#' squares, which scale by the rate squared.
#'
#' @keywords internal
#' @noRd
reweight_counts_by_rate <- function(design, rates) {
  rate_of <- function(g) rates$estimate[match(g, rates$.rate_group)]
  counts <- design$counts
  count_var <- resolve_count_col( # nolint: object_usage_linter
    counts = counts,
    excluded = c(design$date_col, design$strata_cols, design$psu_col),
    count_col = design$count_col
  )
  r <- rate_of(counts$.rate_group)
  counts[[count_var]] <- counts[[count_var]] * r
  if ("expansion_basis" %in% names(counts)) {
    counts$expansion_basis <- counts$expansion_basis * r
  }
  design$counts <- counts
  if (!is.null(design$within_day_counts)) {
    design$within_day_counts$.value <- design$within_day_counts$.value *
      rate_of(design$within_day_counts$.rate_group)
  }
  if (!is.null(design$within_day_var)) {
    design$within_day_var$ss_d <- design$within_day_var$ss_d *
      rate_of(design$within_day_var$.rate_group)^2
  }
  design$survey <- construct_survey_design(design) # nolint: object_usage_linter
  design
}


#' Refuse rate groups on designs this version does not cover
#' @keywords internal
#' @noRd
refuse_rate_groups_design <- function(design, missing_rate, call = rlang::caller_env()) {
  type <- design$design_type %||% "instantaneous"
  if (type %in% c("bus_route", "ice")) {
    cli::cli_abort(
      c(
        "{.arg rate_groups} does not apply to {.val {type}} designs.",
        "x" = "Their totals are Horvitz-Thompson sums, not effort x rate products, \\
               so there is no cell to give a pooled rate."
      ),
      call = call, class = "creel_error_rate_groups"
    )
  }
  if (type %in% c("aerial", "camera") || !is.null(design[["sections"]])) {
    what <- if (!is.null(design[["sections"]])) "sectioned" else type # nolint: object_usage_linter
    cli::cli_abort(
      c(
        "{.arg rate_groups} is not yet available for {what} designs.",
        "i" = "It covers standard count designs with access or roving interviews (GH #389)."
      ),
      call = call, class = "creel_error_rate_groups"
    )
  }
  if (identical(missing_rate, "exclude")) {
    cli::cli_abort(
      c(
        "{.code missing_rate = \"exclude\"} does not combine with {.arg rate_groups}.",
        "x" = "With rate groups every effort cell must have a rate, so there is no \\
               cell to exclude."
      ),
      call = call, class = "creel_error_rate_groups"
    )
  }
  invisible(NULL)
}


#' Effort with its conditions held back
#'
#' The reweighted design's counts are not the user's counts -- a rate of zero
#' makes every one of them zero -- so the checks they trigger would describe
#' data the user never supplied. The same checks run, and speak, on the
#' unweighted effort call beside it.
#' @keywords internal
#' @noRd
quietly_effort <- function(expr) {
  withCallingHandlers(
    expr,
    warning = function(w) invokeRestart("muffleWarning"),
    message = function(m) invokeRestart("muffleMessage")
  )
}


#' Entry point from the three total estimators
#'
#' Resolves `by` the way the standard product path does, splitting off a
#' species grouping, and hands over.
#' @keywords internal
#' @noRd
total_with_rate_groups <- function(
  design,
  by_quo,
  rate_groups,
  metric,
  variance_method,
  conf_level,
  target,
  product_variance,
  ci_type,
  call = rlang::caller_env()
) {
  validate_design_compatibility(design) # nolint: object_usage_linter
  by_vars <- character(0)
  species_col <- NULL
  if (!rlang::quo_is_null(by_quo)) {
    by_info <- resolve_species_by(by_quo, design) # nolint: object_usage_linter
    species_col <- by_info$species_var
    if (!is.null(species_col)) {
      # The remaining grouping columns are resolved as count-side columns, as
      # for a total without species: effort is what they split.
      rest <- by_info$interview_vars
      by_quo <- if (length(rest) == 0L) rlang::quo(NULL) else rlang::quo(c(!!!rlang::syms(rest)))
    }
    if (!rlang::quo_is_null(by_quo)) {
      by_vars <- eval_select_count_by( # nolint: object_usage_linter
        by_quo, design,
        species_route = TRUE,
        error_call = call
      )
    }
  }
  estimate_total_rate_groups(
    design, metric, by_vars, rate_groups, variance_method, conf_level,
    target, product_variance, ci_type,
    species_col = species_col,
    call = call
  )
}


#' Total catch, harvest or release with rates pooled by rate group
#'
#' @param design A design already filtered to the requested trips, with
#'   `total_estimator` set.
#' @param metric `"catch"`, `"harvest"` or `"release"`.
#' @param by_vars Resolved grouping columns (may be empty), species excluded.
#' @param rate_groups The user's mapping table.
#' @param species_col The species column when `by` includes species, else
#'   `NULL`. Each species gets its own rate per group and its own total; the
#'   species rows are reported side by side, never summed, so no covariance
#'   between species is needed.
#' @return A `creel_estimates` object.
#' @keywords internal
#' @noRd
estimate_total_rate_groups <- function(
  design,
  metric,
  by_vars,
  rate_groups,
  variance_method,
  conf_level,
  target,
  product_variance,
  ci_type,
  species_col = NULL,
  call = rlang::caller_env()
) {
  spec <- resolve_rate_groups(design, rate_groups, call)
  design <- attach_rate_groups(design, spec, call)
  # The rate floor applies to the rate actually used: the group's, not the
  # cell's. A cell with three bank trips is fine inside a group with forty.
  validate_total_rate_floor( # nolint: object_usage_linter
    design, ".rate_group",
    type = if (identical(metric, "harvest")) "harvest" else "cpue"
  )
  rates <- rate_group_rates(design, metric, variance_method, conf_level, species_col)

  # Effort per (row, group): the E_rg the rate terms need. The same for every
  # species.
  cell_effort <- as.data.frame(estimate_effort_grouped( # nolint: object_usage_linter
    design, c(by_vars, ".rate_group"), variance_method, conf_level,
    target = target
  )$estimates)

  if (is.null(species_col)) {
    res <- rate_group_product(
      design, rates, cell_effort, by_vars, variance_method, conf_level,
      target, product_variance, ci_type
    )
    out <- res$estimates
    se_expansion <- res$se_expansion
  } else {
    all_species <- sort(unique(rates[[species_col]]))
    pieces <- lapply(all_species, function(sp) {
      sp_rates <- rates[rates[[species_col]] == sp, setdiff(names(rates), species_col), drop = FALSE]
      res <- rate_group_product(
        design, sp_rates, cell_effort, by_vars, variance_method, conf_level,
        target, product_variance, ci_type
      )
      est <- res$estimates
      est[[species_col]] <- rep(sp, nrow(est))
      list(estimates = est[c(species_col, setdiff(names(est), species_col))], se_expansion = res$se_expansion)
    })
    out <- dplyr::bind_rows(lapply(pieces, `[[`, "estimates"))
    se_exp <- lapply(pieces, `[[`, "se_expansion")
    se_expansion <- if (all(vapply(se_exp, is.null, logical(1L)))) NULL else unlist(se_exp, use.names = FALSE)
    by_vars <- c(species_col, by_vars)
  }

  result <- new_creel_estimates( # nolint: object_usage_linter
    estimates = out,
    method = paste0("product-total-", metric),
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = if (length(by_vars) == 0L) NULL else by_vars,
    effort_target = target,
    estimator = reported_estimator(design), # nolint: object_usage_linter
    unit = product_total_unit(rate_unit(design), design$effort_unit), # nolint: object_usage_linter
    se_expansion = se_expansion
  )
  # The pooling, visible: which cells used which group's rate.
  names(rates)[names(rates) == ".rate_group"] <- spec$group_col
  result$rate_groups <- list(map = spec$map, rates = tibble::as_tibble(rates))
  result
}


#' The rate-group product for one set of group rates
#'
#' @param rates One rate per group: `.rate_group`, `estimate`, `se`, `n`.
#' @param cell_effort Effort per `by_vars` x `.rate_group` cell.
#' @return A list: `estimates` (tibble) and `se_expansion`.
#' @keywords internal
#' @noRd
rate_group_product <- function(
  design,
  rates,
  cell_effort,
  by_vars,
  variance_method,
  conf_level,
  target,
  product_variance,
  ci_type
) {
  idx <- match(as.character(cell_effort$.rate_group), rates$.rate_group)
  r_est <- rates$estimate[idx]
  r_var <- rates$se[idx]^2
  rate_term <- cell_effort$estimate^2 * r_var
  if (identical(product_variance, "goodman")) {
    # Goodman's (1960) unbiased estimator subtracts the cross-term, with the
    # first-order value as a floor, cell by cell -- exactly as
    # product_total_variance() does for a stratum, so one group per stratum
    # reproduces the standard total.
    first_order <- r_est^2 * cell_effort$se^2 + rate_term
    cross <- cell_effort$se^2 * r_var
    rate_term <- rate_term - ifelse(first_order - cross > 0, cross, 0)
  }

  # Var_E(sum_g R_g E_rg), from the effort estimator on reweighted counts.
  weighted <- reweight_counts_by_rate(design, rates)
  if (length(by_vars) == 0L) {
    w_result <- quietly_effort(estimate_effort_total( # nolint: object_usage_linter
      weighted, variance_method, conf_level,
      target = target
    ))
    row_key_w <- "all"
    row_key_c <- rep("all", nrow(cell_effort))
  } else {
    w_result <- quietly_effort(estimate_effort_grouped( # nolint: object_usage_linter
      weighted, by_vars, variance_method, conf_level,
      target = target
    ))
    row_key_w <- group_key(as.data.frame(w_result$estimates), by_vars) # nolint: object_usage_linter
    row_key_c <- group_key(cell_effort, by_vars) # nolint: object_usage_linter
  }
  w_df <- as.data.frame(w_result$estimates)

  sum_by_row <- function(x) unname(vapply(row_key_w, function(k) sum(x[row_key_c == k]), numeric(1)))
  product <- sum_by_row(cell_effort$estimate * r_est)
  # The reweighted effort total is the same sum computed the other way; a
  # disagreement means the two calls saw different cells.
  if (!isTRUE(all.equal(unname(product), w_df$estimate, tolerance = 1e-8))) {
    cli::cli_abort(
      "Internal error: rate-group product and reweighted effort disagree.",
      .internal = TRUE
    )
  }
  variance <- w_df$se^2 + sum_by_row(rate_term)

  # Interviews counted once per group present in the row.
  groups_in_row <- lapply(row_key_w, function(k) unique(as.character(cell_effort$.rate_group[row_key_c == k])))
  n_row <- vapply(groups_in_row, function(g) sum(rates$n[match(g, rates$.rate_group)]), numeric(1))
  k_row <- lengths(groups_in_row)
  df_row <- pmax(1L, as.integer(n_row) - k_row)
  z <- stats::qt(1 - (1 - conf_level) / 2, df = df_row)

  se <- sqrt(variance)
  if (identical(ci_type, "log")) {
    use_log <- !is.na(w_df$estimate) & w_df$estimate > 0
    lower <- ifelse(use_log, w_df$estimate * exp(-z * se / w_df$estimate), pmax(0, w_df$estimate - z * se))
    upper <- ifelse(use_log, w_df$estimate * exp(z * se / w_df$estimate), w_df$estimate + z * se)
  } else {
    lower <- pmax(0, w_df$estimate - z * se)
    upper <- w_df$estimate + z * se
  }

  out <- if (length(by_vars) == 0L) tibble::tibble() else tibble::as_tibble(w_df[by_vars])
  out <- if (nrow(out) == 0L) {
    tibble::tibble(estimate = w_df$estimate)
  } else {
    dplyr::mutate(out, estimate = w_df$estimate)
  }
  out$se <- se
  out$ci_lower <- lower
  out$ci_upper <- upper
  out$n <- as.integer(n_row)
  list(estimates = out, se_expansion = w_result$se_expansion)
}
