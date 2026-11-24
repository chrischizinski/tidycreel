#' Combine estimates from independent surveys
#'
#' Sums two or more totals estimated from separate, independently sampled
#' surveys (two lakes, two seasons, day and night shifts drawn as separate
#' designs) into one total. The estimate is the sum of the parts, its variance
#' the sum of their variances, and its confidence interval uses the
#' Satterthwaite degrees of freedom (Satterthwaite 1946):
#' \deqn{\nu = (\sum_i v_i)^2 / \sum_i (v_i^2 / \nu_i),}
#' where \eqn{v_i} is a part's squared standard error and \eqn{\nu_i} the
#' degrees of freedom its own interval used (`Inf` for a normal interval).
#' Independent stratum totals add, and so do their variances (Cochran 1977,
#' ch. 5).
#'
#' @details
#' Adding variances is right only when the parts share nothing estimated, and
#' a hand-made sum gives a plausible, too-small standard error whenever they
#' do. `combine_estimates()` therefore refuses, with a classed error, when:
#'
#' * the parts are not the same quantity: different estimate type, effort
#'   target, unit, grouping or confidence level, or an unknown (`NA`) unit;
#' * a part is a rate or a mean. A combined rate is combined catch divided by
#'   combined effort, a ratio, not a sum. Use [compare_estimates()] to compare
#'   two rates;
#' * the parts share one party-size estimate or one aerial calibration
#'   component, read from `x$provenance`, or a part's provenance is unknown;
#' * one part's interviews (for rates and totals) or counts (for effort and
#'   totals) are all contained in another's -- the same data behind both
#'   parts. A partial overlap raises the warning
#'   `creel_warning_combine_partial_overlap` with the number of shared rows;
#' * with `by`, a group is present in one part and absent from another. An
#'   absent group is unknown, not zero: supply a zero row if it is a real zero.
#'
#' Overlapping coverage that the data cannot show -- day and night windows
#' that overlap, two lakes sharing a section -- is the user's responsibility.
#'
#' Supported quantities: effort, total catch, total harvest, total release
#' and angler trips. Mark-recapture harvest, which carries no design to check
#' the parts against, is refused.
#'
#' Rows whose estimate or standard error is unknown (`NA`) in any part are
#' unknown in the result. Named standard-error components are summed as
#' variances: absent where every part lacks them, `NA` where any part's is
#' unknown.
#'
#' @param ... Two or more `creel_estimates` objects, the parts.
#'
#' @return A `creel_estimates` object with method `"combined-<quantity>"`,
#'   variance method `"sum-of-independent"`, and the union of the parts'
#'   `provenance`, so a combined estimate can itself be combined or compared
#'   and still be checked.
#'
#' @references
#' Cochran, W. G. (1977). *Sampling Techniques*, 3rd ed. Wiley.
#'
#' Satterthwaite, F. E. (1946). An approximate distribution of estimates of
#' variance components. *Biometrics Bulletin* 2(6): 110--114.
#'
#' @seealso [compare_estimates()] for the difference of two estimates.
#' @family "Estimation"
#' @export
#'
#' @examples
#' cal <- data.frame(
#'   date = as.Date("2024-06-01") + 0:9,
#'   day_type = rep(c("weekday", "weekday", "weekend", "weekend", "weekday"), 2)
#' )
#' sampled <- cal[c(1, 2, 3, 4, 6, 8), ]
#' # Angler counts on the sampled days of one lake, 8-hour fishing day
#' lake <- function(anglers) {
#'   d <- creel_design(cal, date = date, strata = day_type)
#'   d <- add_counts(
#'     d, data.frame(sampled, anglers = anglers, shift_hours = 8),
#'     period_length_col = shift_hours
#'   )
#'   estimate_effort(d)
#' }
#' north <- lake(c(12, 30, 9, 25, 14, 33))
#' south <- lake(c(4, 11, 6, 15, 5, 12))
#' both <- combine_estimates(north, south)
#' both$estimates
combine_estimates <- function(...) {
  parts <- list(...)
  if (length(parts) < 2L) {
    creel_abort( # nolint: object_usage_linter
      c(
        "{.fn combine_estimates} needs at least two estimates.",
        "x" = "Got {length(parts)}."
      ),
      class = "creel_error_combine_too_few"
    )
  }
  quantity <- check_combinable(parts, op = "sum")
  aligned <- align_combined_parts(parts)

  est <- combine_matrix(aligned, "estimate")
  se <- combine_matrix(aligned, "se")
  df <- combine_matrix(aligned, "ci_df")
  v <- se^2

  estimate <- rowSums(est)
  total_var <- rowSums(v)
  combined_se <- sqrt(total_var)
  ci_df <- satterthwaite_df(v, df)
  conf_level <- parts[[1]]$conf_level
  bounds <- combined_ci(estimate, combined_se, ci_df, conf_level)

  out <- aligned$labels
  out$estimate <- estimate
  out$se <- combined_se
  out$ci_lower <- bounds$lower
  out$ci_upper <- bounds$upper
  out$n <- combined_n(aligned)
  out <- tibble::as_tibble(out)

  comps <- combine_se_components(parts, aligned)
  estimators <- unique(unlist(lapply(parts, `[[`, "estimator")))

  new_creel_estimates( # nolint: object_usage_linter
    estimates = out,
    method = paste0("combined-", quantity),
    variance_method = "sum-of-independent",
    design = NULL,
    conf_level = conf_level,
    by_vars = parts[[1]]$by_vars,
    effort_target = parts[[1]]$effort_target,
    unit = parts[[1]]$unit,
    estimator = if (length(estimators) == 0L) NULL else paste(estimators, collapse = " + "),
    se_expansion = comps$se_expansion,
    se_components = comps$se_components,
    ci_df = ci_df,
    provenance = union_provenance(parts)
  )
}


#' Compare two estimates from independent surveys
#'
#' The difference of two estimates of the same quantity from separate,
#' independently sampled surveys -- effort, catch or a catch rate on day
#' shifts against night shifts, one lake against another. The difference is
#' `estimate_a - estimate_b`, its variance the sum of the two variances
#' (independence makes the covariance zero), and its interval and test use
#' the Satterthwaite degrees of freedom, as [combine_estimates()] does.
#'
#' @details
#' Every check of [combine_estimates()] applies, with one exception: rates are
#' allowed, because comparing two rates is meaningful where adding them is
#' not. The two parts may use different rate estimators (a roving
#' mean-of-ratios against an access ratio-of-means estimate the same
#' quantity); each part's estimator is reported.
#'
#' The independence checks matter more here than for a sum. One pooled rate
#' used for both parts gives a difference of exactly 0 with a positive
#' standard error, which reads as "no difference" when no comparison was made.
#'
#' Exactly two parts. More than two is a multiple-comparison question this
#' function does not answer.
#'
#' @param a,b `creel_estimates` objects of the same quantity.
#'
#' @return A tibble with one row per group: the grouping columns, then
#'   `estimate_a`, `estimate_b`, `difference`, `se`, `df` (Satterthwaite;
#'   `Inf` for a normal reference), `ci_lower`, `ci_upper`, `statistic`
#'   (difference / se, a t statistic on `df`), `p_value` (two-sided),
#'   `estimator_a` and `estimator_b`. The confidence level is the parts' own.
#'
#' @references
#' Satterthwaite, F. E. (1946). An approximate distribution of estimates of
#' variance components. *Biometrics Bulletin* 2(6): 110--114.
#'
#' @seealso [combine_estimates()] for the sum of estimates.
#' @family "Estimation"
#' @export
#'
#' @examples
#' cal <- data.frame(
#'   date = as.Date("2024-06-01") + 0:9,
#'   day_type = rep(c("weekday", "weekday", "weekend", "weekend", "weekday"), 2)
#' )
#' sampled <- cal[c(1, 2, 3, 4, 6, 8), ]
#' # Angler counts on the sampled days of one lake, 8-hour fishing day
#' lake <- function(anglers) {
#'   d <- creel_design(cal, date = date, strata = day_type)
#'   d <- add_counts(
#'     d, data.frame(sampled, anglers = anglers, shift_hours = 8),
#'     period_length_col = shift_hours
#'   )
#'   estimate_effort(d)
#' }
#' compare_estimates(lake(c(12, 30, 9, 25, 14, 33)), lake(c(4, 11, 6, 15, 5, 12)))
compare_estimates <- function(a, b) {
  parts <- list(a, b)
  check_combinable(parts, op = "difference")
  aligned <- align_combined_parts(parts)

  est <- combine_matrix(aligned, "estimate")
  se <- combine_matrix(aligned, "se")
  df <- combine_matrix(aligned, "ci_df")
  v <- se^2

  difference <- est[, 1] - est[, 2]
  diff_se <- sqrt(rowSums(v))
  diff_df <- satterthwaite_df(v, df)
  bounds <- combined_ci(difference, diff_se, diff_df, a$conf_level)
  statistic <- difference / diff_se
  p_value <- ifelse(
    is.na(diff_df),
    NA_real_,
    2 * stats::pt(-abs(statistic), df = diff_df)
  )

  out <- aligned$labels
  out$estimate_a <- est[, 1]
  out$estimate_b <- est[, 2]
  out$difference <- difference
  out$se <- diff_se
  out$df <- diff_df
  out$ci_lower <- bounds$lower
  out$ci_upper <- bounds$upper
  out$statistic <- statistic
  out$p_value <- p_value
  out$estimator_a <- a$estimator %||% NA_character_
  out$estimator_b <- b$estimator %||% NA_character_
  tibble::as_tibble(out)
}


# ---- internals -------------------------------------------------------------

#' The quantity an estimate measures
#'
#' Internal (GH #585). `method` names how an estimate was computed, and one
#' quantity has several: ungrouped aerial effort is `"aerial_total"` and
#' grouped aerial effort `"total"`. A combination needs what was estimated,
#' so methods map to quantities here, in one place. `NA` for a method this
#' table does not cover, which the caller refuses rather than guesses.
#'
#' @param x A `creel_estimates` object
#' @return A single string, or `NA_character_`
#' @keywords internal
#' @noRd
estimate_quantity <- function(x) {
  m <- x$method
  if (startsWith(m, "combined-")) {
    return(sub("^combined-", "", m))
  }
  effort <- c(
    "total", "total-sections", "aerial_total", "aerial_glmm_total",
    "camera_ratio", "camera_raw", "camera_mi"
  )
  if (m %in% effort) return("effort")
  for (q in c("catch", "harvest", "release")) {
    if (m %in% paste0(c("product-total-", "ht-total-"), q)) return(paste0(q, "-total"))
  }
  if (m == "angler-trips") return("angler-trips")
  rate_suffix <- c(cpue = "catch-rate", hpue = "harvest-rate", rpue = "release-rate")
  for (s in names(rate_suffix)) {
    if (grepl(paste0("-", s, "(-per-angler)?$"), m)) {
      per_angler <- if (grepl("-per-angler$", m)) "-per-angler" else ""
      return(paste0(rate_suffix[[s]], per_angler))
    }
  }
  if (m == "regression-cpue") return("catch-rate")
  NA_character_
}

combine_rate_quantities <- function(q) grepl("-rate", q, fixed = TRUE)

#' Which data a quantity is estimated from
#' @keywords internal
#' @noRd
combine_data_used <- function(quantity) {
  if (quantity == "effort") return("counts")
  if (combine_rate_quantities(quantity)) return("interviews")
  c("counts", "interviews")
}

#' Every refusal combine_estimates() and compare_estimates() share
#'
#' Internal (GH #585). Returns the common quantity, or aborts.
#' @keywords internal
#' @noRd
check_combinable <- function(parts, op, call = rlang::caller_env()) {
  fn <- if (op == "sum") "combine_estimates" else "compare_estimates" # nolint: object_usage_linter
  not_est <- which(!vapply(parts, inherits, logical(1), "creel_estimates"))
  if (length(not_est) > 0L) {
    creel_abort( # nolint: object_usage_linter
      c(
        "Every part must be a {.cls creel_estimates} object.",
        "x" = "Part{?s} {not_est} {?is/are} not."
      ),
      class = "creel_error_combine_not_estimate", call = call
    )
  }

  quantity <- vapply(parts, estimate_quantity, character(1))
  unsupported <- which(is.na(quantity))
  if (length(unsupported) > 0L) {
    methods <- vapply(parts[unsupported], `[[`, character(1), "method") # nolint: object_usage_linter
    creel_abort( # nolint: object_usage_linter
      c(
        "{.fn {fn}} does not support {.val {unique(methods)}} estimates.",
        "i" = paste0(
          "Supported: effort, total catch, harvest and release, angler trips",
          if (op == "difference") ", and catch, harvest and release rates" else "",
          "."
        ),
        "i" = "Mark-recapture harvest carries no design to check its independence against. See {.code ?{fn}}."
      ),
      class = "creel_error_combine_unsupported", call = call
    )
  }
  if (length(unique(quantity)) > 1L) {
    creel_abort( # nolint: object_usage_linter
      c(
        "The parts estimate different quantities.",
        "x" = "Got {.val {unique(quantity)}}."
      ),
      class = "creel_error_combine_quantity_mismatch", call = call
    )
  }
  quantity <- quantity[[1]]
  if (op == "sum" && combine_rate_quantities(quantity)) {
    creel_abort( # nolint: object_usage_linter
      c(
        "Rates cannot be summed.",
        "x" = "The parts are {.val {quantity}} estimates.",
        "i" = paste(
          "A combined rate is combined catch / combined effort, a ratio (Pollock et al. 1994).",
          "Combine the totals and the effort instead, or use {.fn compare_estimates} to compare two rates."
        )
      ),
      class = "creel_error_combine_rate", call = call
    )
  }

  check_same_slot(parts, "effort_target", "effort target", "creel_error_combine_target_mismatch", call)
  units <- lapply(parts, `[[`, "unit")
  if (any(vapply(units, function(u) is.null(u) || anyNA(u), logical(1)))) {
    creel_abort( # nolint: object_usage_linter
      c(
        "A part's unit is unknown.",
        "i" = "Units are derived, never assumed: two unknown units cannot be shown to match. See {.code ?{fn}}."
      ),
      class = "creel_error_combine_unit_unknown", call = call
    )
  }
  check_same_slot(parts, "unit", "unit", "creel_error_combine_unit_mismatch", call)
  by_sets <- lapply(parts, function(p) sort(p$by_vars %||% character()))
  if (length(unique(by_sets)) > 1L) {
    creel_abort( # nolint: object_usage_linter
      c(
        "The parts are grouped differently.",
        "x" = "{.arg by} must name the same columns in every part."
      ),
      class = "creel_error_combine_by_mismatch", call = call
    )
  }
  check_same_slot(
    parts, "conf_level", "confidence level", "creel_error_combine_conf_level_mismatch", call,
    hint = "Re-estimate one part at the other's {.arg conf_level}."
  )
  pending <- which(!vapply(parts, function(p) is.null(p$aerial_calibration_rel_var), logical(1)))
  if (length(pending) > 0L) {
    creel_abort( # nolint: object_usage_linter
      c(
        "Part{?s} {pending} still carr{?ies/y} an aerial calibration variance outside {.field se}.",
        "i" = "Pass the estimates the estimate_* functions return."
      ),
      class = "creel_error_combine_calibration_pending", call = call
    )
  }

  check_shared_provenance(parts, call)
  check_shared_rows(parts, combine_data_used(quantity), call)
  quantity
}

check_same_slot <- function(parts, slot, label, class, call, hint = NULL) {
  values <- lapply(parts, `[[`, slot)
  if (length(unique(values)) > 1L) {
    shown <- vapply(values, function(v) if (is.null(v)) "NULL" else paste(v, collapse = ", "), character(1)) # nolint: object_usage_linter
    creel_abort( # nolint: object_usage_linter
      c(
        "The parts have different {label}s.",
        "x" = "Got {.val {shown}}.",
        if (!is.null(hint)) c("i" = hint)
      ),
      class = class, call = call
    )
  }
  invisible(NULL)
}

#' Refuse parts that share an estimated component
#' @keywords internal
#' @noRd
check_shared_provenance <- function(parts, call) {
  for (component in c("party_size", "aerial_calibration")) {
    label <- if (component == "party_size") "party-size estimate" else "aerial calibration"
    stamps <- lapply(parts, function(p) p$provenance[[component]])
    unknown <- which(vapply(stamps, function(s) !is.null(s) && anyNA(s), logical(1)))
    if (length(unknown) > 0L) {
      # The label is pasted in, not interpolated: cli counts every value in a
      # string with `{?}` as a quantity, and two quantities cannot pluralise.
      creel_abort( # nolint: object_usage_linter
        c(
          paste0("Part{?s} {unknown} used a ", label, " whose identity is unknown."),
          "x" = "Without it, a shared {label} cannot be ruled out, and summed variances would understate the SE.",
          "i" = "Re-derive the counts with {.fn derive_angler_count}, which records it in {.field expansion_id}."
        ),
        class = "creel_error_combine_provenance_unknown", call = call
      )
    }
    for (i in seq_along(parts)[-length(parts)]) {
      for (j in (i + 1L):length(parts)) {
        if (length(intersect(stamps[[i]], stamps[[j]])) > 0L) {
          creel_abort( # nolint: object_usage_linter
            c(
              "Parts {i} and {j} share one {label}.",
              "x" = "Its error is common to both, so their variances do not add.",
              "i" = "Estimate the {label} separately for each part, or estimate both parts in one design."
            ),
            class = paste0("creel_error_combine_shared_", component), call = call
          )
        }
      }
    }
  }
  invisible(NULL)
}

#' Row fingerprints of one design table, on the columns two tables share
#' @keywords internal
#' @noRd
combine_row_ids <- function(df, cols) {
  if (is.null(df) || nrow(df) == 0L || length(cols) == 0L) {
    return(character())
  }
  vals <- lapply(df[cols], function(x) {
    x <- as.character(x)
    x[is.na(x)] <- "\u001e"
    x
  })
  do.call(paste, c(vals, sep = "\u001f"))
}

#' Refuse parts estimated from the same interviews or counts
#'
#' Internal (GH #585; maintainer decision 2026-11-24, option b). Rows are
#' compared by content on the columns both tables have, excluding internal
#' (dot-prefixed) columns that pipelines add. One part's rows all contained
#' in another's -- identical tables, or a pooled set behind both parts -- is
#' refused. A partial overlap is warned with its size: coincidental identical
#' records are possible between independent surveys on the same dates, so a
#' partial match is not proof of reuse.
#' @keywords internal
#' @noRd
check_shared_rows <- function(parts, tables, call) {
  designs <- lapply(parts, `[[`, "design")
  no_design <- which(vapply(designs, is.null, logical(1)))
  if (length(no_design) > 0L) {
    creel_abort( # nolint: object_usage_linter
      c(
        "Part{?s} {no_design} carr{?ies/y} no design.",
        "x" = "Shared interviews or counts cannot be ruled out without it."
      ),
      class = "creel_error_combine_provenance_unknown", call = call
    )
  }
  for (tbl in tables) {
    for (i in seq_along(parts)[-length(parts)]) {
      for (j in (i + 1L):length(parts)) {
        a <- designs[[i]][[tbl]]
        b <- designs[[j]][[tbl]]
        if (is.null(a) || is.null(b)) next
        cols <- setdiff(intersect(names(a), names(b)), grep("^[.]", names(a), value = TRUE))
        ra <- unique(combine_row_ids(a, cols))
        rb <- unique(combine_row_ids(b, cols))
        shared <- intersect(ra, rb)
        if (length(shared) == 0L) next
        if (all(ra %in% rb) || all(rb %in% ra)) {
          creel_abort( # nolint: object_usage_linter
            c(
              "Parts {i} and {j} were estimated from the same {tbl}.",
              "x" = paste(
                "Every {sub('s$', '', tbl)} row of one part is in the other, so their errors",
                "are correlated and summed variances would understate the SE."
              ),
              "i" = "Use each part's own {tbl}, or estimate both parts in one design."
            ),
            class = paste0("creel_error_combine_shared_", tbl), call = call
          )
        }
        creel_warn( # nolint: object_usage_linter
          c(
            paste0("Parts {i} and {j} have {length(shared)} identical ", tbl, " row{?s}."),
            "i" = paste(
              "Coincidental matches are possible between independent surveys;",
              "shared data would make the combined SE too small."
            )
          ),
          class = c("creel_warning_combine_partial_overlap", "creel_warning")
        )
      }
    }
  }
  invisible(NULL)
}

#' Align the parts' rows by group
#'
#' Internal. Returns the part rows in the first part's group order, the group
#' labels, and the keys. A group absent from any part is refused: absent is
#' unknown, not zero.
#' @keywords internal
#' @noRd
align_combined_parts <- function(parts, call = rlang::caller_env()) {
  by_vars <- parts[[1]]$by_vars
  keys <- lapply(parts, function(p) {
    if (is.null(by_vars)) rep("all", nrow(p$estimates)) else group_key(p$estimates, by_vars) # nolint: object_usage_linter
  })
  dup <- which(vapply(keys, anyDuplicated, integer(1)) > 0L)
  if (length(dup) > 0L) {
    creel_abort( # nolint: object_usage_linter
      c(
        "Part{?s} {dup} ha{?s/ve} more than one row per group.",
        "i" = "Group by every column that distinguishes the rows."
      ),
      class = "creel_error_combine_by_mismatch", call = call
    )
  }
  ref <- keys[[1]]
  for (i in seq_along(keys)[-1]) {
    missing_here <- setdiff(ref, keys[[i]])
    extra_here <- setdiff(keys[[i]], ref)
    if (length(missing_here) > 0L || length(extra_here) > 0L) {
      shown <- gsub("\u001f", " / ", c(missing_here, extra_here), fixed = TRUE) # nolint: object_usage_linter
      creel_abort( # nolint: object_usage_linter
        c(
          "The parts' groups do not match.",
          "x" = "Group{?s} {.val {shown}} {?is/are} in one part and not the other.",
          "i" = "An absent group is unknown, not zero. Add a zero row to a part if the group truly had none."
        ),
        class = "creel_error_combine_group_missing", call = call
      )
    }
  }
  rows <- lapply(seq_along(parts), function(i) match(ref, keys[[i]]))
  labels <- if (is.null(by_vars)) {
    list()
  } else {
    as.list(parts[[1]]$estimates[by_vars])
  }
  list(parts = parts, rows = rows, keys = ref, labels = labels)
}

combine_matrix <- function(aligned, field) {
  do.call(cbind, lapply(seq_along(aligned$parts), function(i) {
    p <- aligned$parts[[i]]
    vals <- if (field == "ci_df") p$ci_df else p$estimates[[field]]
    as.numeric(vals)[aligned$rows[[i]]]
  }))
}

#' Satterthwaite degrees of freedom for a sum of independent variances
#'
#' Internal. A part with zero variance contributes nothing; an infinite df
#' (a normal interval) contributes a zero term. An unknown df on a part that
#' does carry variance makes the result unknown.
#' @keywords internal
#' @noRd
satterthwaite_df <- function(v, df) {
  terms <- ifelse(!is.na(v) & v == 0, 0, ifelse(is.infinite(df), 0, v^2 / df))
  denom <- rowSums(terms)
  num <- rowSums(v)^2
  out <- num / denom
  out[!is.na(denom) & denom == 0] <- Inf
  out
}

combined_ci <- function(estimate, se, df, conf_level) {
  crit <- ifelse(is.na(df), NA_real_, stats::qt(1 - (1 - conf_level) / 2, df = df))
  list(lower = estimate - crit * se, upper = estimate + crit * se)
}

combined_n <- function(aligned) {
  if (!all(vapply(aligned$parts, function(p) "n" %in% names(p$estimates), logical(1)))) {
    return(rep(NA_integer_, length(aligned$keys)))
  }
  as.integer(rowSums(combine_matrix(aligned, "n")))
}

#' Sum named SE components as variances across parts
#'
#' Internal. A component absent from a part does not apply there and adds
#' nothing; absent from every part, it stays absent. An `NA` in any part makes
#' the result `NA`, never 0. `party_size` is returned separately as
#' `se_expansion`, which the constructor mirrors back.
#' @keywords internal
#' @noRd
combine_se_components <- function(parts, aligned) {
  n_out <- length(aligned$keys)
  per_part <- function(p, i, value) {
    rep_len(as.numeric(value), nrow(p$estimates))[aligned$rows[[i]]]
  }
  sum_component <- function(getter) {
    present <- FALSE
    # Zero is the sum over parts where the component is ABSENT -- it does not
    # apply there, as the constructor documents for se_components. The
    # accumulator is returned only if some part has the component (`present`),
    # and an NA from any part that has it propagates through `+`, so absent
    # never stands in for unknown.
    acc <- rep(0, n_out)
    for (i in seq_along(parts)) {
      value <- getter(parts[[i]])
      if (is.null(value)) next
      present <- TRUE
      acc <- acc + per_part(parts[[i]], i, value)^2
    }
    if (present) sqrt(acc) else NULL
  }
  names_all <- setdiff(unique(unlist(lapply(parts, function(p) names(p$se_components)))), "party_size")
  comps <- lapply(names_all, function(nm) sum_component(function(p) p$se_components[[nm]]))
  names(comps) <- names_all
  comps <- comps[!vapply(comps, is.null, logical(1))]
  list(
    se_expansion = sum_component(function(p) p$se_expansion),
    se_components = if (length(comps) == 0L) NULL else comps
  )
}

#' Union of the parts' provenance
#' @keywords internal
#' @noRd
union_provenance <- function(parts) {
  one <- function(component) {
    stamps <- lapply(parts, function(p) p$provenance[[component]])
    stamps <- stamps[!vapply(stamps, is.null, logical(1))]
    if (length(stamps) == 0L) {
      return(NULL)
    }
    vals <- unlist(stamps)
    if (anyNA(vals)) NA_character_ else sort(unique(vals))
  }
  list(party_size = one("party_size"), aerial_calibration = one("aerial_calibration"))
}
