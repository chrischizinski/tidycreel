#' Day length for a latitude and date
#'
#' @description
#' Computes the number of hours between sunrise and sunset at a given latitude
#' on a given date, using the CBM model of Forsythe et al. (1995). The
#' calculation is a closed form -- no lookup tables, network access, or
#' location database is involved.
#'
#' Only latitude is needed. Longitude and time zone shift *when* sunrise and
#' sunset occur but not the interval between them, so they are not arguments.
#'
#' @details
#' Day length is astronomical, and the effort estimators want something else.
#' In Hoenig et al. (1993) and Pope et al. (Ch. 17), the daily expansion factor
#' \eqn{T_d} is the length of the period the counts were *randomised within* --
#' a property of the survey design, set by regulation, access hours, or the
#' field protocol. It is often close to daylight and it is not the same
#' quantity. Use `day_length()` to build simulated or planned surveys, and pass
#' the period your protocol actually used to [add_counts()].
#'
#' Above the Arctic and Antarctic circles the sun may not rise or set at all.
#' In those cases the result saturates at `0` or `24` rather than erroring.
#'
#' @param lat Numeric latitude in decimal degrees, positive north, in
#'   \[-90, 90\]. Recycled against `date`.
#' @param date A `Date` vector (or anything [as.Date()] accepts). Recycled
#'   against `lat`.
#' @param horizon How far the sun must be below the horizon for the day to
#'   count as over. Either one of `"sunset"` (the default; 0.833 degrees,
#'   accounting for the solar disc and atmospheric refraction), `"civil"` (6),
#'   `"nautical"` (12), `"astronomical"` (18), or a number giving the
#'   depression angle in degrees directly.
#'
#' @return A numeric vector of day lengths in hours, the length of the longer
#'   of `lat` and `date`.
#'
#' @references
#' Forsythe, W.C., Rykiel, E.J., Stahl, R.S., Wu, H., Schoolfield, R.M. (1995).
#' A model comparison for daylength as a function of latitude and day of year.
#' Ecological Modelling 80:87-95. \doi{10.1016/0304-3800(94)00034-F}
#'
#' Hoenig, J.M., Robson, D.S., Jones, C.M., Pollock, K.H. (1993). Scheduling
#' counts in the instantaneous and progressive count methods for estimating
#' sportfishing effort. North American Journal of Fisheries Management
#' 13:723-736.
#'
#' @examples
#' # A single day at Kearney, Nebraska
#' day_length(40.699, as.Date("2024-06-21"))
#'
#' # A whole season, for use as a simulated expansion factor
#' season <- seq(as.Date("2024-05-01"), as.Date("2024-08-31"), by = "day")
#' summary(day_length(40.699, season))
#'
#' # Anglers fish into twilight; civil twilight adds roughly an hour in June
#' day_length(40.699, as.Date("2024-06-21"), horizon = "civil")
#'
#' # Latitude drives the seasonal swing
#' day_length(c(25, 45, 65), as.Date("2024-12-21"))
#'
#' @seealso [simulate_creel_data()], [add_counts()]
#' @family "Simulation"
#' @export
day_length <- function(lat, date, horizon = "sunset") {
  checkmate::assert_numeric(
    lat,
    lower = -90,
    upper = 90,
    any.missing = FALSE,
    min.len = 1L
  )

  date <- tryCatch(
    as.Date(date),
    error = function(e) {
      cli::cli_abort(c(
        "{.arg date} must be a {.cls Date} or coercible to one.",
        "x" = "Got {.cls {class(date)[1]}}."
      ))
    }
  )
  if (length(date) == 0L || anyNA(date)) {
    cli::cli_abort(c(
      "{.arg date} must be a non-empty vector with no missing values.",
      "x" = "Got {length(date)} value{?s}, {sum(is.na(date))} missing."
    ))
  }

  p <- resolve_horizon(horizon)

  n <- max(length(lat), length(date))
  if (n %% length(lat) != 0L || n %% length(date) != 0L) {
    cli::cli_abort(c(
      "{.arg lat} and {.arg date} must be recyclable to a common length.",
      "x" = "Got lengths {length(lat)} and {length(date)}."
    ))
  }
  lat <- rep_len(lat, n)
  date <- rep_len(date, n)

  doy <- as.integer(format(date, "%j"))

  # Forsythe et al. (1995) CBM model. theta is the revolution angle from the
  # day of year, phi the resulting solar declination.
  theta <- 0.2163108 + 2 * atan(0.9671396 * tan(0.00860 * (doy - 186)))
  phi <- asin(0.39795 * cos(theta))

  lat_rad <- lat * pi / 180
  cos_h <- (sin(p * pi / 180) + sin(lat_rad) * sin(phi)) /
    (cos(lat_rad) * cos(phi))

  # Beyond the polar circles the sun never crosses the horizon and cos_h leaves
  # [-1, 1]. Clamping saturates those days at 24 h of light or 24 h of dark,
  # which is the physical answer, rather than returning NaN.
  cos_h <- pmax(-1, pmin(1, cos_h))

  24 - (24 / pi) * acos(cos_h)
}

#' Resolve the horizon argument to a depression angle in degrees
#'
#' @param horizon A recognised name or a numeric depression angle.
#'
#' @return A single number, degrees below the horizon.
#'
#' @keywords internal
#' @noRd
resolve_horizon <- function(horizon, error_call = rlang::caller_env()) {
  if (is.numeric(horizon)) {
    checkmate::assert_number(horizon, finite = TRUE)
    return(horizon)
  }

  known <- c(
    sunset = 0.8333,
    civil = 6,
    nautical = 12,
    astronomical = 18
  )

  if (!is.character(horizon) || length(horizon) != 1L || !horizon %in% names(known)) {
    cli::cli_abort(
      c(
        "{.arg horizon} must be {.or {.val {names(known)}}}, or a number of degrees.",
        "x" = "Got {.val {horizon}}."
      ),
      call = error_call
    )
  }

  unname(known[[horizon]])
}
