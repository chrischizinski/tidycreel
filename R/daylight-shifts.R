#' Shift times bounded by sunrise and sunset
#'
#' @description
#' Returns each date's shifts for a survey whose shifts run from sunrise to a
#' clock cutoff and from the cutoff to sunset (or between several cutoffs),
#' in local clock time. The result can be passed straight to
#' [generate_schedule()]`(periods = )`, so each sampled day's drawn shift
#' carries that day's daylight window: [attach_count_times()] then draws count
#' times inside it, and [add_counts()] checks the period length against it.
#'
#' Sunrise and sunset come from NOAA's solar-position equations (the sun's
#' centre at 0.833 degrees below the horizon by default, allowing for
#' refraction and the solar disc), which agree with the US Naval Observatory
#' to about a minute at mid-latitudes. Times are rounded to the minute, and
#' `hours` is computed from the rounded times so it matches the shift window
#' exactly.
#'
#' Day length alone needs only latitude ([day_length()]), but *where* a clock
#' cutoff falls within the day also depends on longitude and the time zone,
#' including daylight saving time, so all three are required here.
#' [day_length()] uses a different model (Forsythe et al. 1995) and is meant
#' for simulation; the two can differ by a minute or two.
#'
#' @param date Dates (a `Date` vector or anything [as.Date()] accepts).
#' @param lat Latitude in decimal degrees, positive north.
#' @param lon Longitude in decimal degrees, positive east (so negative in the
#'   Americas).
#' @param tz Time zone name, e.g. `"America/Chicago"` (see [OlsonNames()]).
#' @param cutoffs Clock times (`"HH:MM"`, local) that divide the day into
#'   shifts. One cutoff gives two shifts (AM: sunrise to cutoff; PM: cutoff to
#'   sunset); `k` cutoffs give `k + 1`.
#' @param horizon Sun depression angle that defines sunrise and sunset: as in
#'   [day_length()], `"sunset"` (default), `"civil"`, `"nautical"`,
#'   `"astronomical"`, or a number of degrees. `"civil"` adds roughly half an
#'   hour at each end, for anglers who fish into twilight.
#'
#' @return A data frame with one row per date and shift: `date`,
#'   `period_id` (1 = first shift of the day), `start_time` and `end_time`
#'   (`"HH:MM"`, local), and `hours` (decimal hours).
#'
#' @details A cutoff that falls before sunrise or after sunset on some date
#'   would give a shift of zero or negative length; that is an error naming
#'   the dates. So is a date on which the sun does not rise or set.
#'
#' @references
#' NOAA Global Monitoring Laboratory. General solar position calculations.
#' <https://gml.noaa.gov/grad/solcalc/solareqns.PDF>
#'
#' @examples
#' # Kearney, Nebraska: AM / PM shifts split at 13:30 local time
#' daylight_shifts(
#'   as.Date(c("2024-05-01", "2024-06-21", "2024-08-31")),
#'   lat = 40.699, lon = -99.083, tz = "America/Chicago"
#' )
#'
#' # Into a schedule: each sampled day's drawn shift carries its own window
#' days <- seq(as.Date("2024-06-01"), as.Date("2024-06-30"), by = "day")
#' shifts <- daylight_shifts(days, 40.699, -99.083, "America/Chicago")
#' sched <- generate_schedule(
#'   start_date = "2024-06-01", end_date = "2024-06-30", n_periods = 2,
#'   sampling_rate = 0.3, periods_per_day = 1, periods = shifts, seed = 1
#' )
#' head(sched)
#'
#' @seealso [generate_schedule()], [attach_count_times()], [add_counts()],
#'   [day_length()]
#' @family "Scheduling"
#' @export
daylight_shifts <- function(date, lat, lon, tz, cutoffs = "13:30", horizon = "sunset") {
  date <- tryCatch(as.Date(date), error = function(e) {
    cli::cli_abort("{.arg date} must be dates.")
  })
  if (length(date) == 0L || anyNA(date)) {
    cli::cli_abort("{.arg date} must be a non-empty vector with no missing values.")
  }
  checkmate::assert_number(lat, lower = -90, upper = 90)
  checkmate::assert_number(lon, lower = -180, upper = 180)
  if (!is.character(tz) || length(tz) != 1L || !tz %in% OlsonNames()) {
    cli::cli_abort(c(
      "{.arg tz} must be one time zone name from {.fn OlsonNames}.",
      "x" = "Got {.val {tz}}."
    ))
  }
  hhmm <- "^([01][0-9]|2[0-3]):[0-5][0-9]$"
  if (!is.character(cutoffs) || length(cutoffs) == 0L || !all(grepl(hhmm, cutoffs))) {
    cli::cli_abort("{.arg cutoffs} must be clock times as {.val HH:MM}.")
  }
  cut_min <- vapply(cutoffs, parse_hhmm_to_min, integer(1), USE.NAMES = FALSE) # nolint: object_usage_linter
  if (is.unsorted(cut_min, strictly = TRUE)) {
    cli::cli_abort("{.arg cutoffs} must be in increasing order with no repeats.")
  }
  depression <- resolve_horizon(horizon) # nolint: object_usage_linter

  st <- noaa_sun_times(date, lat, lon, tz, depression)
  if (anyNA(st$sunrise) || anyNA(st$sunset)) {
    bad <- as.character(date[is.na(st$sunrise) | is.na(st$sunset)]) # nolint: object_usage_linter
    cli::cli_abort(c(
      "The sun does not rise or set on {length(bad)} date{?s} at this latitude: {.val {bad}}.",
      "i" = "Daylight shifts need a sunrise and a sunset."
    ))
  }

  bounds <- cbind(st$sunrise, matrix(cut_min, nrow = length(date), ncol = length(cut_min), byrow = TRUE),
                  st$sunset)
  len <- bounds[, -1, drop = FALSE] - bounds[, -ncol(bounds), drop = FALSE]
  if (any(len <= 0)) {
    bad <- as.character(date[apply(len <= 0, 1, any)]) # nolint: object_usage_linter
    cli::cli_abort(c(
      "A cutoff falls outside daylight on {length(bad)} date{?s}: {.val {bad}}.",
      "x" = "A shift from sunrise to a cutoff before sunrise (or from a cutoff after sunset) \\
             has no length.",
      "i" = "Check {.arg cutoffs}, {.arg lon} and {.arg tz}."
    ))
  }

  n_shift <- ncol(len)
  data.frame(
    date = rep(date, each = n_shift),
    period_id = rep(seq_len(n_shift), times = length(date)),
    start_time = format_min_to_hhmm(as.integer(t(bounds[, -ncol(bounds), drop = FALSE]))), # nolint: object_usage_linter
    end_time = format_min_to_hhmm(as.integer(t(bounds[, -1, drop = FALSE]))), # nolint: object_usage_linter
    hours = as.numeric(t(len)) / 60,
    stringsAsFactors = FALSE
  )
}

#' Sunrise and sunset in local clock minutes (NOAA)
#'
#' NOAA's simplified solar equations (as in the NGPC prototype validated
#' against the US Naval Observatory). Returns minutes after local midnight,
#' rounded to the minute, honouring daylight saving time through `tz`; `NA`
#' where the sun does not cross the horizon that day.
#'
#' @noRd
noaa_sun_times <- function(date, lat, lon, tz, depression = 0.8333) {
  jd <- as.numeric(date) + 2440587.5
  n <- ceiling(jd - 2451545.0 + 0.0008)
  j_star <- n - lon / 360
  m <- (357.5291 + 0.98560028 * j_star) %% 360
  mr <- m * pi / 180
  c_eq <- 1.9148 * sin(mr) + 0.0200 * sin(2 * mr) + 0.0003 * sin(3 * mr)
  lambda <- ((m + c_eq + 180 + 102.9372) %% 360) * pi / 180
  j_transit <- 2451545.0 + j_star + 0.0053 * sin(mr) - 0.0069 * sin(2 * lambda)
  decl <- asin(sin(lambda) * sin(23.4397 * pi / 180))
  phi <- lat * pi / 180
  cos_w <- (sin(-depression * pi / 180) - sin(phi) * sin(decl)) / (cos(phi) * cos(decl))
  never <- cos_w > 1 | cos_w < -1
  w <- acos(pmin(pmax(cos_w, -1), 1)) * 180 / pi
  local_min <- function(j) {
    t <- as.POSIXct((j - 2440587.5) * 86400, origin = "1970-01-01", tz = "UTC")
    lt <- as.POSIXlt(t, tz = tz)
    out <- as.integer(round(lt$hour * 60 + lt$min + lt$sec / 60))
    # A time that rounds onto another local date (far-west longitudes in the
    # wrong zone) is not a daylight bound for this date.
    out[as.Date(format(lt, "%Y-%m-%d")) != date] <- NA_integer_
    out
  }
  rise <- local_min(j_transit - w / 360)
  set <- local_min(j_transit + w / 360)
  rise[never] <- NA_integer_
  set[never] <- NA_integer_
  list(sunrise = rise, sunset = set)
}
