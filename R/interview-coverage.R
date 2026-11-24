#' Check whether the interviews can represent the fishing the counts measured
#'
#' A catch total multiplies counted effort by a catch rate from interviews, and
#' the product is right only if the interviewed trips can represent the fishing
#' the counts measured. The estimators check that across strata: a total
#' refuses a stratum with counted effort and no rate, and a rate pooled across
#' strata refuses a stratum fished with no usable interviews. Nothing in them
#' looks *within* a stratum. A morning-only interview plan on a lake with an
#' evening bite passes every one of those checks, and the rate it produces
#' describes morning trips while the effort it multiplies covers the whole day.
#'
#' `check_interview_coverage()` compares the two by time of day, within each
#' stratum, in blocks of `block` minutes. It changes no estimate and raises no
#' warning in the estimators; it returns a report.
#'
#' @section Two layers, and what each can show:
#'
#' **The plan layer** asks whether a trip in each block of the fishing day had
#' any chance of being interviewed. An access-point clerk interviews trips as
#' they end, so a trip ending while no clerk is scheduled cannot enter the
#' sample at all (Pollock et al. 1994; Robson and Jones 1989); a roving clerk
#' meets anglers only while present. A block of the fishing day that no
#' interview period overlaps has zero probability of selection, and no
#' weighting of the trips that were interviewed can stand in for it (Lohr 2022,
#' sec. 1.3.4). This layer can **establish** a gap. It needs the sampling plan,
#' which the design does not keep: `periods`, the table of interview periods
#' the schedule was drawn from, and `fishing_hours`, the fishing day. Without
#' them it reports `NA`, never "covered".
#'
#' **The data layer** compares, block by block, the effort the counts saw with
#' the fishing the interviewed trips did. A count is the number of anglers
#' present at an instant, so the mean count in a block stands for the block's
#' effort; the interviewed fishing is the hours each interviewed trip spent in
#' the block, from `trip_start` to `interview_time`. Time fished, not the number
#' of interviews, is the quantity compared, because a roving clerk meets an
#' angler with probability proportional to time fished (Hoenig et al. 1997). A
#' block with counted anglers and no interviewed fishing is a `gap`. This layer
#' can only **point to** a gap: in a small sample a block can be missed by
#' chance under a plan that covers it. Hartill et al. (2011) found about 15% of
#' boats returning after interviewers had left, a gap of exactly this kind.
#'
#' @section What is unknown, and why it is not reported as covered:
#'
#' * A block with no count in it has unknown effort: `mean_count` and `gap` are
#'   `NA`, not `0` and `FALSE`.
#' * Interviews need clock times: `add_interviews(trip_start = ,
#'   interview_time = )`. Interviews given only a `trip_duration` carry no time
#'   of day. While any interview in a stratum lacks one, a block with no
#'   interviewed fishing there has `gap = NA`, since the untimed interviews may
#'   have fished it; `n_no_clock_time` in the summary counts them.
#' * Counts need clock times: `add_counts(count_time_col = )`, as `"HH:MM"` or
#'   date-times. Without them the data layer is `NA` throughout.
#' * When counts were attached with `period_length_col`, the stored counts are
#'   already expanded by each day's period length; effort shares across blocks
#'   are then comparable only when that expansion is similar across the days a
#'   block was counted on.
#'
#' Times are read on the survey-day clock, so a night creel's blocks run past
#' midnight from its `day_start`.
#'
#' @param design A `creel_design` with `survey_type = "instantaneous"`, counts
#'   and interviews attached. Bus-route and ice designs are refused: their
#'   interviews are the effort data. Aerial and camera designs are refused: the
#'   counts there have no link to interview times.
#' @param periods `NULL`, or a data frame of the periods clerks interview in,
#'   with `start` and `end` as `"HH:MM"`. It may carry any of the design's
#'   strata columns to give each stratum its own periods; rows without them
#'   apply to every stratum. This is the `periods` table given to
#'   [generate_schedule()]: every period that can be drawn has a positive
#'   probability of being worked.
#' @param fishing_hours `NULL`, a character vector `c(start, end)` as `"HH:MM"`
#'   applying to every stratum, or a data frame with `start`, `end` and
#'   optionally strata columns, as for `periods`.
#' @param block Block length in minutes. Default 60.
#'
#' @return A `creel_coverage_report`, a list with:
#'   \describe{
#'     \item{plan}{One row per stratum and block: `block_start`, `block_end`
#'       (`"HH:MM"` on the survey-day clock), `in_fishing_day`, and
#'       `interviewable` (`TRUE`, `FALSE`, or `NA` without `periods` and
#'       `fishing_hours`).}
#'     \item{data}{One row per stratum and block: `mean_count`, `n_count_obs`,
#'       `interviewed_hours`, `n_interviews`, `effort_share`,
#'       `interviewed_share` and `gap`.}
#'     \item{summary}{One row per stratum: `n_interviews`, `n_no_clock_time`,
#'       `effort_share_in_data_gaps`, `fishing_hours_not_interviewable` and
#'       `effort_share_not_interviewable`.}
#'     \item{block}{The block length in minutes.}
#'   }
#'
#' @references
#' Hartill, B. W., Watson, T. G., and Bian, R. (2011). Refining and applying a
#' maximum-count aerial-access survey design to estimate the harvest taken from
#' New Zealand's largest recreational fishery. *North American Journal of
#' Fisheries Management*, 31, 1197-1210.
#'
#' Hoenig, J. M., Jones, C. M., Pollock, K. H., Robson, D. S., and Wade, D. L.
#' (1997). Calculation of catch rate and total catch in roving surveys of
#' anglers. *Biometrics*, 53, 306-317.
#'
#' Lohr, S. L. (2022). *Sampling: Design and Analysis* (3rd ed.). CRC Press.
#'
#' Pollock, K. H., Jones, C. M., and Brown, T. L. (1994). *Angler Survey
#' Methods and Their Applications in Fisheries Management*. American Fisheries
#' Society Special Publication 25.
#'
#' Robson, D. S., and Jones, C. M. (1989). The theoretical basis of an access
#' site angler survey design. *Biometrics*, 45, 83-98.
#'
#' @examples
#' cal <- data.frame(date = as.Date("2024-06-03") + 0:9, day_type = "weekday")
#' sampled <- cal$date[c(1, 3, 6, 8)]
#' counts <- data.frame(
#'   date = rep(sampled, each = 3), day_type = "weekday",
#'   count_time = rep(c("08:00", "13:00", "19:00"), 4),
#'   anglers = c(10, 8, 20, 12, 9, 25, 9, 7, 18, 11, 10, 22)
#' )
#' # Interviews only in the morning
#' start <- as.POSIXct(paste(rep(sampled, each = 3), "06:30"), tz = "UTC")
#' interviews <- data.frame(
#'   date = rep(sampled, each = 3), day_type = "weekday",
#'   catch = c(2, 1, 3, 0, 2, 1, 4, 1, 2, 3, 1, 0),
#'   hours = 3, status = "complete",
#'   trip_start = start, interview_time = start + 3 * 3600
#' )
#' design <- creel_design(cal, date = date, strata = day_type)
#' design <- add_counts(design, counts, count_col = anglers, count_time_col = count_time)
#' design <- add_interviews(design, interviews,
#'   catch = catch, effort = hours, trip_status = status,
#'   trip_start = trip_start, interview_time = interview_time
#' )
#' check_interview_coverage(
#'   design,
#'   periods = data.frame(start = "06:00", end = "12:00"),
#'   fishing_hours = c("06:00", "21:00")
#' )
#'
#' @family "Reporting & Diagnostics"
#' @export
check_interview_coverage <- function(design, periods = NULL, fishing_hours = NULL, block = 60) {
  if (!inherits(design, "creel_design")) {
    creel_abort(
      c(
        "{.arg design} must be a {.cls creel_design} object.",
        "x" = "{.arg design} is {.cls {class(design)[1]}}."
      ),
      class = "creel_error_invalid_input"
    )
  }
  if (!identical(design$design_type, "instantaneous")) {
    creel_abort(
      c(
        "Interview coverage is checked for instantaneous count designs only.",
        "x" = "This design is {.val {design$design_type}}.",
        "i" = "Bus-route and ice interviews are the effort data; aerial and camera counts \\
               have no link to interview times. See {.code ?check_interview_coverage}."
      ),
      class = c("creel_error_coverage_unsupported", "creel_error_invalid_input")
    )
  }
  if (is.null(design$counts) || is.null(design$interviews)) {
    creel_abort(
      c(
        "Interview coverage needs both counts and interviews.",
        "i" = "Attach them with {.fn add_counts} and {.fn add_interviews}."
      ),
      class = c("creel_error_coverage_needs_data", "creel_error_invalid_input")
    )
  }
  if (!is.numeric(block) || length(block) != 1L || is.na(block) || block <= 0 || block > 1440) {
    creel_abort(
      c(
        "{.arg block} must be one number of minutes in (0, 1440].",
        "x" = "Got {.val {block}}."
      ),
      class = "creel_error_invalid_input"
    )
  }

  ds <- design$night$day_start_min %||% 0L
  strata_cols <- design$strata_cols
  strata <- coverage_strata(design, strata_cols)
  edges <- unique(c(seq(0, 1440, by = block), 1440))
  blocks <- data.frame(
    .b = seq_len(length(edges) - 1L),
    .lo = edges[-length(edges)],
    .hi = edges[-1L]
  )

  plan <- coverage_plan(strata, strata_cols, blocks, periods, fishing_hours, ds)
  data <- coverage_data(design, strata, strata_cols, blocks, ds)
  summary <- coverage_summary(plan, data, strata, strata_cols, design, ds)

  structure(
    list(
      plan = coverage_finish(plan, strata_cols, ds),
      data = coverage_finish(data, strata_cols, ds),
      summary = summary,
      block = block
    ),
    class = "creel_coverage_report"
  )
}

#' The design's strata, one row each, with an internal key
#' @keywords internal
#' @noRd
coverage_strata <- function(design, strata_cols) {
  st <- unique(design$calendar[strata_cols])
  rownames(st) <- NULL
  st$.key <- group_key(st, strata_cols) # nolint: object_usage_linter
  st
}

#' Survey-day minutes for an "HH:MM" start/end pair table, refusing bad times
#' @keywords internal
#' @noRd
coverage_windows <- function(tbl, arg, strata, strata_cols, ds) {
  if (is.character(tbl) && length(tbl) == 2L) {
    tbl <- data.frame(start = tbl[1], end = tbl[2])
  }
  if (!is.data.frame(tbl) || !all(c("start", "end") %in% names(tbl)) || nrow(tbl) == 0L) {
    creel_abort(
      c(
        "{.arg {arg}} must be a data frame with {.field start} and {.field end} columns.",
        "i" = "Times are {.val HH:MM}; strata columns are optional."
      ),
      class = c("creel_error_coverage_input", "creel_error_invalid_input")
    )
  }
  s <- clock_minutes(tbl$start, strict = FALSE) # nolint: object_usage_linter
  e <- clock_minutes(tbl$end, strict = FALSE) # nolint: object_usage_linter
  bad <- is.na(s) | is.na(e)
  if (any(bad)) {
    creel_abort(
      c(
        "{.arg {arg}} has times that are not {.val HH:MM}.",
        "x" = "Rows: {which(bad)}."
      ),
      class = c("creel_error_coverage_input", "creel_error_invalid_input")
    )
  }
  tbl$.s <- survey_min(s, ds) # nolint: object_usage_linter
  tbl$.e <- survey_min(e, ds, end = TRUE) # nolint: object_usage_linter
  if (any(tbl$.e <= tbl$.s)) {
    creel_abort(
      c(
        "Every {.arg {arg}} row must end after it starts on the survey-day clock.",
        "x" = "Rows: {which(tbl$.e <= tbl$.s)}."
      ),
      class = c("creel_error_coverage_input", "creel_error_invalid_input")
    )
  }
  by <- intersect(strata_cols, names(tbl))
  # Rows with no strata columns apply to every stratum; rows with some apply to
  # the strata they match.
  out <- lapply(seq_len(nrow(strata)), function(i) {
    rows <- if (length(by) == 0L) {
      rep(TRUE, nrow(tbl))
    } else {
      Reduce(`&`, lapply(by, function(v) as.character(tbl[[v]]) == as.character(strata[[v]][i])))
    }
    tbl[rows, c(".s", ".e"), drop = FALSE]
  })
  names(out) <- strata$.key
  missing <- strata$.key[vapply(out, nrow, integer(1)) == 0L]
  if (length(missing) > 0L) {
    creel_abort(
      c(
        "{.arg {arg}} has no row for some strata.",
        "x" = "Missing: {.val {gsub('\u001f', ' / ', missing, fixed = TRUE)}}."
      ),
      class = c("creel_error_coverage_input", "creel_error_invalid_input")
    )
  }
  out
}

#' Minutes of [lo, hi) covered by the union of intervals
#' @keywords internal
#' @noRd
coverage_overlap <- function(lo, hi, s, e) {
  sum(pmax(0, pmin(hi, e) - pmax(lo, s)))
}

#' Plan layer: which blocks of the fishing day an interview period overlaps
#' @keywords internal
#' @noRd
coverage_plan <- function(strata, strata_cols, blocks, periods, fishing_hours, ds) {
  known <- !is.null(periods) && !is.null(fishing_hours)
  win_p <- if (known) coverage_windows(periods, "periods", strata, strata_cols, ds) else NULL
  win_f <- if (known) coverage_windows(fishing_hours, "fishing_hours", strata, strata_cols, ds) else NULL
  rows <- lapply(seq_len(nrow(strata)), function(i) {
    out <- cbind(strata[rep(i, nrow(blocks)), , drop = FALSE], blocks)
    if (!known) {
      out$in_fishing_day <- NA
      out$interviewable <- NA
      return(out)
    }
    k <- strata$.key[i]
    f <- win_f[[k]]
    p <- win_p[[k]]
    out$in_fishing_day <- mapply(
      function(lo, hi) any(pmin(hi, f$.e) > pmax(lo, f$.s)), out$.lo, out$.hi
    )
    out$interviewable <- mapply(
      function(lo, hi) any(pmin(hi, p$.e) > pmax(lo, p$.s)), out$.lo, out$.hi
    )
    # Outside the fishing day there is no trip to cover.
    out$interviewable[!out$in_fishing_day] <- NA
    out
  })
  do.call(rbind, rows)
}

#' Data layer: counted effort vs interviewed fishing time, per block
#' @keywords internal
#' @noRd
coverage_data <- function(design, strata, strata_cols, blocks, ds) {
  date_col <- design$date_col
  day_strata <- unique(design$calendar[c(date_col, strata_cols)])
  day_strata$.key <- group_key(day_strata, strata_cols) # nolint: object_usage_linter

  # Counts: instants on the survey-day clock, joined to their day's stratum.
  wdc <- design$within_day_counts
  count_min <- if (is.null(wdc)) NULL else clock_minutes(wdc$.count_time, strict = TRUE) # nolint: object_usage_linter
  if (!is.null(count_min)) {
    wdc$.key <- day_strata$.key[match(as.character(wdc[[date_col]]), as.character(day_strata[[date_col]]))]
    wdc$.m <- survey_min(count_min, ds) # nolint: object_usage_linter
    wdc <- wdc[!is.na(wdc$.m) & !is.na(wdc$.value) & !is.na(wdc$.key), , drop = FALSE]
  }

  # Interviews: the interval each trip fished, on the survey-day clock.
  iv <- design$interviews
  ts_col <- design$trip_start_col
  it_col <- design$interview_time_col
  timed <- !is.null(ts_col) && !is.null(it_col) &&
    inherits(iv[[ts_col]], "POSIXt") && inherits(iv[[it_col]], "POSIXt")
  iv$.key <- group_key(iv, strata_cols) # nolint: object_usage_linter
  if (timed) {
    # Anchored on the interview, which lies in the record's survey day; a trip
    # that began before the day did (before midnight, or before a night
    # creel's day_start) is clipped at the day's start rather than wrapped to
    # its end. An interview exactly at day_start ends the previous survey day.
    dur <- as.numeric(difftime(iv[[it_col]], iv[[ts_col]], units = "mins"))
    iv$.e <- survey_min(clock_minutes(iv[[it_col]]), ds, end = TRUE) # nolint: object_usage_linter
    iv$.s <- pmax(0, iv$.e - dur)
  } else {
    iv$.s <- NA_real_
    iv$.e <- NA_real_
  }

  rows <- lapply(seq_len(nrow(strata)), function(i) {
    k <- strata$.key[i]
    out <- cbind(strata[rep(i, nrow(blocks)), , drop = FALSE], blocks)
    if (is.null(count_min)) {
      out$mean_count <- NA_real_
      out$n_count_obs <- NA_integer_
    } else {
      ck <- wdc[wdc$.key == k, , drop = FALSE]
      cb <- findInterval(ck$.m, blocks$.lo, rightmost.closed = FALSE)
      out$n_count_obs <- as.integer(tabulate(cb, nbins = nrow(blocks)))
      sums <- vapply(blocks$.b, function(b) sum(ck$.value[cb == b]), numeric(1))
      # No count in a block: its effort is unknown, not zero.
      out$mean_count <- ifelse(out$n_count_obs > 0L, sums / pmax(out$n_count_obs, 1L), NA_real_)
    }
    ik <- iv[iv$.key == k & !is.na(iv$.s) & !is.na(iv$.e), , drop = FALSE]
    out$interviewed_hours <- vapply(seq_len(nrow(blocks)), function(b) {
      sum(pmax(0, pmin(blocks$.hi[b], ik$.e) - pmax(blocks$.lo[b], ik$.s))) / 60
    }, numeric(1))
    out$n_interviews <- vapply(seq_len(nrow(blocks)), function(b) {
      sum(pmin(blocks$.hi[b], ik$.e) > pmax(blocks$.lo[b], ik$.s))
    }, integer(1))
    n_untimed <- sum(iv$.key == k & (is.na(iv$.s) | is.na(iv$.e)))

    len <- out$.hi - out$.lo
    eff <- out$mean_count * len
    out$effort_share <- if (all(is.na(eff)) || sum(eff, na.rm = TRUE) == 0) {
      NA_real_
    } else {
      eff / sum(eff, na.rm = TRUE)
    }
    tot_iv <- sum(out$interviewed_hours)
    out$interviewed_share <- if (tot_iv > 0) out$interviewed_hours / tot_iv else NA_real_
    # A gap needs counted anglers and no interviewed fishing. Unknown effort,
    # or untimed interviews that may have fished the block, leave it unknown.
    out$gap <- ifelse(
      is.na(out$mean_count), NA,
      ifelse(out$mean_count > 0 & out$interviewed_hours == 0,
        if (n_untimed > 0L) NA else TRUE,
        FALSE
      )
    )
    attr(out, "n_untimed") <- n_untimed
    out
  })
  n_untimed <- vapply(rows, function(r) attr(r, "n_untimed"), integer(1))
  out <- do.call(rbind, rows)
  attr(out, "n_untimed") <- stats::setNames(n_untimed, strata$.key)
  out
}

#' One row per stratum: the shares of counted effort in each kind of gap
#' @keywords internal
#' @noRd
coverage_summary <- function(plan, data, strata, strata_cols, design, ds) {
  n_untimed <- attr(data, "n_untimed")
  iv_key <- group_key(design$interviews, strata_cols) # nolint: object_usage_linter
  rows <- lapply(seq_len(nrow(strata)), function(i) {
    k <- strata$.key[i]
    d <- data[data$.key == k, , drop = FALSE]
    p <- plan[plan$.key == k, , drop = FALSE]
    eff <- d$mean_count * (d$.hi - d$.lo)
    known_eff <- sum(eff, na.rm = TRUE)
    data_gap_share <- if (known_eff == 0 || any(is.na(d$gap[!is.na(d$mean_count)]))) {
      NA_real_
    } else {
      sum(eff[d$gap %in% TRUE]) / known_eff
    }
    plan_known <- !all(is.na(p$in_fishing_day))
    not_iv <- plan_known & (p$in_fishing_day %in% TRUE) & (p$interviewable %in% FALSE)
    plan_gap_share <- if (!plan_known || known_eff == 0) NA_real_ else sum(eff[not_iv], na.rm = TRUE) / known_eff
    out <- strata[i, strata_cols, drop = FALSE]
    out$n_interviews <- sum(iv_key == k)
    out$n_no_clock_time <- unname(n_untimed[k])
    out$effort_share_in_data_gaps <- data_gap_share
    out$fishing_hours_not_interviewable <- if (plan_known) sum((p$.hi - p$.lo)[not_iv]) / 60 else NA_real_
    out$effort_share_not_interviewable <- plan_gap_share
    out
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  tibble::as_tibble(out)
}

#' Internal columns out, readable block labels in
#' @keywords internal
#' @noRd
coverage_finish <- function(x, strata_cols, ds) {
  hhmm <- function(m) {
    clock <- (m + ds) %% 1440
    sprintf("%02d:%02d", clock %/% 60, clock %% 60)
  }
  x$block_start <- hhmm(x$.lo)
  x$block_end <- hhmm(x$.hi)
  internal <- c(strata_cols, ".key", ".b", ".lo", ".hi", "block_start", "block_end")
  keep <- c(strata_cols, "block_start", "block_end", setdiff(names(x), internal))
  out <- x[keep]
  rownames(out) <- NULL
  tibble::as_tibble(out)
}

#' @export
format.creel_coverage_report <- function(x, ...) {
  s <- x$summary
  strata_cols <- setdiff(names(s), c(
    "n_interviews", "n_no_clock_time", "effort_share_in_data_gaps",
    "fishing_hours_not_interviewable", "effort_share_not_interviewable"
  ))
  label <- do.call(paste, c(lapply(strata_cols, function(v) as.character(s[[v]])), sep = " / "))
  pct <- function(v) ifelse(is.na(v), "unknown", sprintf("%.0f%%", 100 * v))
  lines <- c(
    cli::rule(left = "Interview coverage by time of day", width = 60),
    sprintf("Blocks of %s minutes, per stratum.", format(x$block)),
    ""
  )
  for (i in seq_len(nrow(s))) {
    lines <- c(
      lines,
      sprintf("%s (%d interviews):", label[i], s$n_interviews[i]),
      sprintf(
        "  Plan: %s of the fishing day not interviewable (%s of counted effort)",
        ifelse(is.na(s$fishing_hours_not_interviewable[i]), "unknown hours",
          sprintf("%g h", s$fishing_hours_not_interviewable[i])
        ),
        pct(s$effort_share_not_interviewable[i])
      ),
      sprintf("  Data: %s of counted effort in blocks with no interviewed fishing", pct(s$effort_share_in_data_gaps[i]))
    )
    if (s$n_no_clock_time[i] > 0L) {
      lines <- c(lines, sprintf("  %d interview(s) carry no clock time.", s$n_no_clock_time[i]))
    }
  }
  c(
    lines, "",
    "The plan layer can establish a gap; the data layer can only point to one.",
    "Unknown means the inputs to decide it are missing, never covered."
  )
}

#' @export
print.creel_coverage_report <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}
