# The season calendar creel_design() takes: every day of the season with its
# stratum (GH #559).

#' Build a season calendar
#'
#' @description
#' `creel_calendar()` returns every day of the season, one row per date, with
#' its day type and stratum: the calendar [creel_design()] takes. Unsampled
#' days must be in the calendar, because they are the population days the
#' totals expand to, and each date must appear once.
#'
#' # Strata
#'
#' `strata` names the parts the stratum label is built from, in order:
#' - `"season_block"`: the block's label from `season_blocks`;
#' - `"month"`: the month, as `"06"`;
#' - `"week"`: the week of the season, as `"wk01"`. Week 1 starts on the
#'   season's first day, and each later week starts on the day after the last
#'   weekend day (Monday when the weekend is Saturday and Sunday), so a
#'   weekend is never split between two weeks. The first and last weeks can
#'   be partial;
#' - `"day_type"`: `"weekday"` or `"weekend"`.
#'
#' The default, `c("month", "day_type")`, gives labels such as
#' `"06_weekend"`.
#'
#' # Holidays and special periods
#'
#' A date in `holidays` is a weekend day of its stratum: its `day_type` is
#' `"weekend"`, and a holiday Monday in June falls in `"06_weekend"`. It
#' does not move week boundaries: a holiday Monday is in the week it starts.
#'
#' A date in `special_periods` is a stratum of its own: its `day_type` is
#' `"special"` and its `stratum` is the period's `label`, whatever `strata`
#' says. A period is not split by month, week or block, so a holiday weekend
#' running from 30 June to 2 July is one stratum. (Apportioning such a
#' stratum's total back to months is #429.) A date that is both a holiday and
#' in a special period is in the special period.
#'
#' Holidays and special periods are dates, not rules: the package does not
#' know which holidays an agency observes or how it blocks them.
#'
#' A holiday or special period outside the season is refused, not dropped:
#' it usually means the wrong year.
#'
#' @param start,end First and last day of the season, as a `Date` or
#'   `"YYYY-MM-DD"`.
#' @param strata Character vector: the parts of the stratum label, any of
#'   `"season_block"`, `"month"`, `"week"` and `"day_type"`, in the order
#'   they appear in the label.
#' @param weekend_days Day names (full or three-letter English, any case)
#'   that form the weekend. `NULL` (default) means Saturday and Sunday. The
#'   weekend days must be consecutive, because the week starts after them.
#' @param holidays Optional `Date` vector (or `"YYYY-MM-DD"` strings) of days
#'   treated as weekend days.
#' @param special_periods Optional data frame of periods that are strata of
#'   their own: `start_date`, `end_date` and `label`, with an optional
#'   `reason`, as [generate_schedule()] takes. Periods with different labels
#'   cannot overlap.
#' @param season_blocks Optional data frame with `start_date` and `label`.
#'   Each row starts a block that runs until the next row's `start_date`; the
#'   first must be the season's first day. Required when `strata` includes
#'   `"season_block"`, and refused otherwise.
#'
#' @return A data frame with one row per day of the season: `date`, `month`
#'   (integer), `week` (integer, week of the season), `day_type`
#'   (`"weekday"`, `"weekend"` or `"special"`), `season_block` (when
#'   `season_blocks` is supplied) and `stratum`.
#'
#' @examples
#' cal <- creel_calendar(
#'   "2024-05-01", "2024-09-02",
#'   holidays = as.Date(c("2024-05-27", "2024-09-02")),
#'   special_periods = data.frame(
#'     start_date = "2024-07-04", end_date = "2024-07-07",
#'     label = "july4"
#'   )
#' )
#' table(cal$stratum)
#'
#' creel_design(cal, date = date, strata = stratum)
#'
#' # Early and late season blocks, by day type
#' creel_calendar(
#'   "2024-05-01", "2024-08-31",
#'   strata = c("season_block", "day_type"),
#'   season_blocks = data.frame(
#'     start_date = c("2024-05-01", "2024-07-01"),
#'     label = c("early", "late")
#'   )
#' ) |> head()
#'
#' @family "Scheduling"
#' @export
creel_calendar <- function(
  start,
  end,
  strata = c("month", "day_type"),
  weekend_days = NULL,
  holidays = NULL,
  special_periods = NULL,
  season_blocks = NULL
) {
  call <- rlang::current_env()
  start <- calendar_date(start, "start", call)
  end <- calendar_date(end, "end", call)
  if (length(start) != 1L || length(end) != 1L) {
    cli::cli_abort("{.arg start} and {.arg end} must each be one date.", call = call)
  }
  if (end < start) {
    cli::cli_abort(
      "{.arg end} ({.val {format(end)}}) is before {.arg start} ({.val {format(start)}}).",
      call = call
    )
  }

  parts <- c("season_block", "month", "week", "day_type")
  if (!is.character(strata) || length(strata) == 0L || anyNA(strata) ||
        !all(strata %in% parts) || anyDuplicated(strata)) {
    cli::cli_abort(
      c(
        "{.arg strata} must name each part of the stratum label at most once.",
        "i" = "Parts: {.val {parts}}."
      ),
      call = call
    )
  }
  if ("season_block" %in% strata && is.null(season_blocks)) {
    cli::cli_abort(
      "{.arg strata} includes {.val season_block}, but {.arg season_blocks} is {.code NULL}.",
      call = call
    )
  }
  if (!is.null(season_blocks) && !"season_block" %in% strata) {
    cli::cli_abort(
      c(
        "{.arg season_blocks} is supplied, but {.arg strata} does not use it.",
        "i" = "Add {.val season_block} to {.arg strata}, or leave {.arg season_blocks} out."
      ),
      call = call
    )
  }

  weekend_wday <- resolve_weekend_days(weekend_days, 0L, call = call)
  date <- seq(start, end, by = "day")
  wday <- lubridate::wday(date, week_start = 1)
  cal <- data.frame(
    date = date,
    month = as.integer(format(date, "%m")),
    week = calendar_week(date, wday, weekend_wday, call),
    day_type = ifelse(wday %in% weekend_wday, "weekend", "weekday"),
    stringsAsFactors = FALSE
  )

  if (!is.null(holidays)) {
    holidays <- unique(calendar_date(holidays, "holidays", call))
    calendar_refuse_outside(holidays, start, end, "holidays", call)
    cal$day_type[cal$date %in% holidays] <- "weekend"
  }

  if (!is.null(season_blocks)) {
    cal$season_block <- calendar_blocks(season_blocks, date, call)
  }

  label <- list(
    season_block = cal$season_block,
    month = sprintf("%02d", cal$month),
    week = sprintf("wk%02d", cal$week),
    day_type = cal$day_type
  )
  cal$stratum <- do.call(paste, c(unname(label[strata]), sep = "_"))

  if (!is.null(special_periods)) {
    special <- resolve_special_periods(date, cal$stratum, special_periods)
    calendar_refuse_outside(
      c(as.Date(special_periods$start_date), as.Date(special_periods$end_date)),
      start, end, "special_periods", call
    )
    labels <- as.character(special_periods$label)
    if (anyNA(labels) || any(!nzchar(labels))) {
      cli::cli_abort("{.arg special_periods} has a missing or empty {.field label}.", call = call)
    }
    in_special <- seq_along(date) %in% match(special$audit$date, date)
    clash <- intersect(unique(labels), cal$stratum[!in_special])
    if (length(clash) > 0L) {
      cli::cli_abort(
        c(
          "{.arg special_periods} label{?s} {.val {clash}} {?is/are} also the label of an ordinary stratum.",
          "i" = "A special period is a stratum of its own; give it a label no other stratum has."
        ),
        call = call
      )
    }
    cal$day_type[in_special] <- "special"
    cal$stratum <- special$final_stratum
  }

  keep <- c("date", "month", "week", "day_type", if (!is.null(season_blocks)) "season_block", "stratum")
  cal <- cal[keep]
  rownames(cal) <- NULL
  cal
}

# Internal: a Date vector from Dates or "YYYY-MM-DD" strings, refusing
# anything that does not parse rather than turning it into NA.
calendar_date <- function(x, arg, call) {
  if (inherits(x, "Date")) {
    out <- x
  } else if (is.character(x)) {
    out <- as.Date(x, format = "%Y-%m-%d", optional = TRUE)
  } else {
    out <- as.Date(rep(NA_character_, length(x)))
  }
  if (length(out) == 0L || anyNA(out)) {
    cli::cli_abort(
      "{.arg {arg}} must be dates ({.cls Date} or {.val YYYY-MM-DD}) with no missing values.",
      call = call
    )
  }
  out
}

# Internal: refuse dates outside the season. Dropping them would hide a
# wrong year.
calendar_refuse_outside <- function(x, start, end, arg, call) {
  outside <- sort(unique(x[x < start | x > end]))
  if (length(outside) > 0L) {
    cli::cli_abort(
      c(
        "{.arg {arg}} has {length(outside)} date{?s} outside the season \\
         ({.val {format(start)}} to {.val {format(end)}}): {.val {format(outside)}}.",
        "i" = "Check the year, or trim the dates to the season."
      ),
      call = call
    )
  }
  invisible(NULL)
}

# Internal: week of the season. Week 1 starts on the first day; a new week
# starts on the day after the last weekend day, so a weekend stays in one
# week. That needs the weekend days to be one consecutive run (wrapping from
# Sunday to Monday counts as consecutive).
calendar_week <- function(date, wday, weekend_wday, call) {
  last <- weekend_wday[!((weekend_wday %% 7L) + 1L) %in% weekend_wday]
  if (length(last) != 1L) {
    cli::cli_abort(
      c(
        "{.arg weekend_days} must be consecutive days, and not the whole week.",
        "i" = "The week of the season starts on the day after the weekend."
      ),
      call = call
    )
  }
  week_start <- (last %% 7L) + 1L
  starts <- wday == week_start
  starts[1L] <- FALSE
  as.integer(cumsum(starts) + 1L)
}

# Internal: the season block of each date.
calendar_blocks <- function(season_blocks, date, call) {
  if (!is.data.frame(season_blocks) || !all(c("start_date", "label") %in% names(season_blocks))) {
    cli::cli_abort(
      "{.arg season_blocks} must be a data frame with {.field start_date} and {.field label}.",
      call = call
    )
  }
  starts <- calendar_date(season_blocks$start_date, "season_blocks$start_date", call)
  labels <- as.character(season_blocks$label)
  if (anyNA(labels) || any(!nzchar(labels)) || anyDuplicated(labels)) {
    cli::cli_abort("{.arg season_blocks} labels must be present and unique.", call = call)
  }
  if (is.unsorted(starts, strictly = TRUE)) {
    cli::cli_abort("{.arg season_blocks} start dates must be in increasing order.", call = call)
  }
  if (starts[1L] != date[1L]) {
    cli::cli_abort(
      c(
        "The first season block must start on the season's first day.",
        "x" = "It starts {.val {format(starts[1L])}}; the season starts {.val {format(date[1L])}}."
      ),
      call = call
    )
  }
  calendar_refuse_outside(starts, date[1L], date[length(date)], "season_blocks", call)
  labels[findInterval(as.numeric(date), as.numeric(starts))]
}
