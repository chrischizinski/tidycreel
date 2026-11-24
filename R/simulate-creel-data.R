# Creel Data Simulator ----

# Borrowing the RNG for the duration of a call -------------------------------
#
# `seed` is a convenience for reproducing one simulation, not a licence to
# reset the caller's random stream. Calling set.seed() and leaving it set means
# a script that seeds its own analysis, then calls a simulate function in the
# middle, silently continues from OUR seed -- every draw after that point is
# determined by an argument the user passed for one function's benefit, and
# nothing says so.
#
# `.Random.seed` genuinely lives in the global environment: that is where R
# keeps it and where set.seed() writes it, so restoring it there is putting
# back what was taken rather than reaching into user space. When no stream had
# been initialised at all, set.seed() creates `.Random.seed`, and the faithful
# restoration is to remove it again.
#
# Paired: capture with .rng_state(), hand the result to .restore_rng() from an
# on.exit() registered before set.seed() runs.
#' @noRd
.rng_state <- function() {
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    get(".Random.seed", envir = globalenv(), inherits = FALSE)
  } else {
    NULL
  }
}

#' @noRd
.restore_rng <- function(state) {
  if (is.null(state)) {
    suppressWarnings(rm(".Random.seed", envir = globalenv()))
  } else {
    # nolint next: object_name_linter. `.Random.seed` is base R's name, not ours.
    assign(".Random.seed", state, envir = globalenv())
  }
  invisible(NULL)
}

#' Simulate a complete creel survey dataset
#'
#' @description
#' Generates realistic synthetic creel data using a five-level hierarchical
#' generative model (day → trip → count → interview → catch). Caller supplies distributional
#' parameters via \code{params}; no default data are bundled with the package.
#'
#' The generative model follows Su & Clapp (2013) for the day and trip levels;
#' the roving-clerk step follows Greene et al. (1995). Only the sampling step is
#' taken from the latter: its own simulated anglers are deterministic -- evenly
#' spaced around the shoreline, all starting one hour into an eight-hour day,
#' with trip lengths alternating between 3 and 6 hours -- whereas the levels
#' below draw from distributions.
#'
#' \enumerate{
#'   \item \strong{Day level}: Every day of the season draws the number of
#'     angler trips from a Negative Binomial distribution; \code{n_sampled_days}
#'     of them are sampled. Unsampled days are simulated too, so the season's
#'     true totals are known.
#'   \item \strong{Trip level}: Each trip draws its length (hr) from a Gamma
#'     distribution, capped at the fishing day's length \eqn{T}, a start time
#'     uniform in \eqn{[0, T - L]}, and its party size from a Poisson (at
#'     least 1).
#'   \item \strong{Count level}: On a sampled day, each count is taken at a
#'     uniformly random moment of the fishing day and is the number of anglers
#'     fishing then. Count times \eqn{T} is unbiased for the day's angler-hours
#'     (Hoenig et al. 1993).
#'   \item \strong{Interview level}, set by \code{interview_type}:
#'     \code{"access"} -- the clerk meets parties as they leave, every party
#'     with the same chance (70\% of the day's parties), and records the whole
#'     trip; \code{"roving"} -- the clerk meets parties while they fish, each
#'     with a chance proportional to its trip length (0.25 times its length over
#'     the day's mean length, capped at 1, so slightly under a quarter of the
#'     day's parties), at a uniformly random point in the trip, and
#'     records the time fished so far (at least 0.1 h). This is the sampling
#'     difference Pollock et al. (1997) base the choice of catch-rate
#'     estimator on.
#'   \item \strong{Catch level}: Catch accrues over the time fished. A party
#'     catches nothing with probability \code{p_zero_catch}; otherwise its
#'     whole-trip catch is Negative Binomial with mean
#'     \code{catch_rate$mean * n_anglers * trip_length / (1 - p_zero_catch)},
#'     so the population catch rate (total catch over total angler-hours) is
#'     exactly \code{catch_rate$mean}. Harvest is Binomial given catch. A
#'     roving interview's catch so far is the part of that trip's catch caught
#'     in the time fished so far (each fish with probability
#'     \code{hours_fished / trip_length}).
#' }
#'
#' Because catch accrues, the ratio of means on access interviews and the
#' (truncated) mean of ratios on roving interviews both target
#' \code{truth$catch_rate}. Before tidycreel 9.0.0 each party drew one
#' whole-trip catch regardless of time fished, so an incomplete trip carried
#' the whole trip's catch over the hours fished so far and inflated any
#' roving catch rate (GH #494).
#'
#' Counts and interviews come from the same simulated trips, so the true
#' effort, catch and harvest are known (GH #646): \code{truth} reports them
#' over the sampled days and over the season. Before tidycreel 9.0.0 the counts
#' were drawn independently of the trips and only the rates were known.
#'
#' @param params Named list of distributional parameters. Required. Must
#'   include named sub-lists: `effort` (with `gamma_shape`, `gamma_rate` for
#'   [rgamma()]); `party` (with `mean` party size for [rpois()]); `catch_rate`
#'   (with `mean`, the catch per angler-hour, and `nb_size` for [rnbinom()],
#'   default `0.5` when `NULL` or `NA`); `harvest` (with `mean_pct` as a
#'   percentage, e.g. `35` for 35%, default `35` when `NULL` or `NA`); `counts` (with `mean_total_anglers`,
#'   used when `n_anglers_per_day = NULL`).
#' @param season_days Integer. Total days in the season. Default 100.
#' @param n_sampled_days Integer. Number of days actually surveyed. Must be
#'   \code{<= season_days}. Default 30.
#' @param day_types Named \strong{numeric} vector of stratum proportions, e.g.
#'   \code{c(weekday = 5/7, weekend = 2/7)}. Names become the \code{day_type}
#'   values in the output. When the names are exactly \code{weekday} and
#'   \code{weekend}, each day's label comes from its date (Saturday and Sunday
#'   are weekends) and the proportions are ignored; any other names are
#'   assigned to days at random in the stated proportions. When \code{NULL}
#'   (default), uses a single stratum
#'   \code{"all"}. \strong{Note:} passing a character vector (e.g.
#'   \code{c("weekday", "weekend")}) will error — the vector must be numeric
#'   with named elements.
#' @param species Character vector. Species names for the catch table. Default
#'   \code{"walleye"}. Catch is split proportionally across species using
#'   \code{species_weights}.
#' @param species_weights Numeric vector. Relative catch weight per species.
#'   Must be same length as \code{species}. Default equal weights.
#' @param interview_type \code{"access"} (default) or \code{"roving"}: how the
#'   clerk meets parties, and so whether trips are complete or incomplete. See
#'   Details. Simulate twice for a survey that collects both.
#' @param p_complete Removed in tidycreel 9.0.0; supplying it is an error.
#'   \code{interview_type} now decides trip status. The old argument mixed
#'   complete and incomplete trips in one length-biased draw (GH #494).
#' @param p_zero_catch Numeric in \[0, 1). Probability a trip has zero total
#'   catch (zero-inflation). Default \code{0.40}. \strong{Note:} this cannot
#'   be derived from a survey inventory (API artifact); the default is an
#'   empirical estimate from the creel literature.
#' @param n_anglers_per_day Numeric. Mean number of angler parties fishing on
#'   each day of the season (sampled or not). Overrides \code{params$counts$mean_total_anglers} when
#'   specified. Default \code{NULL} (use params).
#' @param start_date Date. First day of the simulated season. Default
#'   \code{Sys.Date()}.
#' @param n_counts_per_day Integer. Number of instantaneous count observations
#'   per sampled day. Default \code{3}.
#' @param lat Numeric latitude in decimal degrees, positive north. The daily
#'   fishing period \eqn{T} is computed per date with \code{\link{day_length}}.
#'   Supply \code{lat} or \code{daylight_hours}, not both.
#' @param daylight_hours Numeric. Length of the daily fishing period \eqn{T}, in
#'   hours, used to convert instantaneous counts to angler-hours. Accepts a
#'   single value applied to every day, or a named length-12 vector of monthly
#'   values (names \code{"1"}…\code{"12"}, or \code{month.abb}) which is matched
#'   on the month of each count date. Use this when \eqn{T} is set by regulation
#'   or field protocol rather than by daylight. Supply \code{daylight_hours}
#'   or \code{lat}, not both.
#'
#'   One of them is required: trips start within the fishing day and counts are
#'   taken at moments in it, so the day needs a length, and there is no honest
#'   default (GH #646).
#' @param seed Integer or \code{NULL}. Random seed for reproducibility.
#'   Default \code{NULL}.
#'
#' @return A named list with four data frames and the true values:
#' \describe{
#'   \item{\code{schedule}}{Full-season calendar, one row per day. Columns:
#'     \code{date}, \code{day_type}, \code{sampled} (logical). Pass directly
#'     to \code{\link{creel_design}} as the \code{calendar} argument.
#'     Day types follow \code{day_types} as described there.}
#'   \item{\code{interviews}}{One row per intercepted angler party. Columns:
#'     \code{date}, \code{day_type}, \code{interview_id}, \code{trip_status}
#'     (\code{"complete"} for access, \code{"incomplete"} for roving),
#'     \code{hours_fished} and \code{trip_duration} (both the time fished at
#'     the interview, as a clerk records it), \code{true_trip_length} (the
#'     whole simulated trip; simulation truth no clerk observes on a roving
#'     interview -- do not pass it to \code{\link{add_interviews}}),
#'     \code{n_anglers}, \code{catch_total} and \code{catch_kept} (both so
#'     far), \code{species_sought}.}
#'   \item{\code{counts}}{One row per instantaneous count. Columns:
#'     \code{date}, \code{day_type}, \code{count_time} (integer index
#'     1…\code{n_counts_per_day}, in time order), \code{total_anglers} (anglers
#'     fishing at the moment of the count), \code{daylight_hours} (\eqn{T} for
#'     that day) and \code{angler_hours} (\code{total_anglers *
#'     daylight_hours}). Pass
#'     \code{count_time_col = count_time} to \code{\link{add_counts}} when
#'     \code{n_counts_per_day > 1}.}
#'   \item{\code{catch}}{Long-format catch table. Columns: \code{interview_id},
#'     \code{species}, \code{count}, \code{catch_type} (\code{"caught"},
#'     \code{"harvested"}, \code{"released"}). For each interview the
#'     rows of each type sum to its \code{catch_total}, \code{catch_kept}
#'     and \code{catch_total - catch_kept}.}
#'   \item{\code{truth}}{A list of the population values estimators should
#'     recover: \code{catch_rate} and \code{harvest_rate} (per angler-hour),
#'     and the realised \code{effort_*} (angler-hours), \code{catch_*} and
#'     \code{harvest_*} (fish) of every simulated trip, each over the
#'     \code{_sampled_days} and over the \code{_season}; and \code{days}, one
#'     row per season day with its \code{parties}, \code{anglers},
#'     \code{effort}, \code{catch} and \code{harvest}.}
#' }
#'
#' The population of trips is simulated before anything about the survey, so a
#' seed fixes the population: runs that differ only in \code{interview_type},
#' \code{n_sampled_days} or \code{n_counts_per_day} sample the same trips and
#' report the same season truth.
#'
#' \strong{Pass \code{angler_hours}, not \code{total_anglers}, to
#' \code{\link{add_counts}}.} An instantaneous count estimates the mean number of
#' anglers present, not effort; effort is that count multiplied by the length of
#' the period the count was randomised within (Hoenig et al. 1993).
#' \code{estimate_effort()} expands whatever numeric column it is given and
#' cannot tell the two apart, so handing it \code{total_anglers} yields
#' a sum of head counts silently mislabelled as angler-hours. The counts table
#' carries three numeric columns and \code{\link{add_counts}} will not guess
#' between them: name the one you mean with
#' \code{add_counts(design, sim$counts, count_col = angler_hours)}, or pass
#' \code{count_col = total_anglers, period_length_col = daylight_hours}.
#'
#' When \code{n_counts_per_day > 1} you must also \strong{drop the measures you
#' are not using} before attaching. \code{total_anglers} differs between the
#' counts taken within one day, so aggregation has no single value to carry
#' forward and would otherwise keep whichever came first. \code{add_counts()}
#' aborts rather than do that (GH #162); select the columns you need, as the
#' second example below does. \code{daylight_hours} is constant within a day and
#' can stay.
#'
#' Note that \code{\link{day_length}} gives astronomical daylight. Where the
#' fishing day is fixed by regulation or access hours instead, pass that period
#' as \code{daylight_hours}.
#'
#' The \code{schedule} output can be passed directly to \code{\link{creel_design}}
#' as the \code{calendar} argument. The \code{interviews} and \code{counts}
#' outputs are then passed to \code{\link{add_interviews}} and
#' \code{\link{add_counts}}.
#'
#' @references
#' Su, Z. & Clapp, D.F. (2013). Evaluation of sample design and estimation
#' methods for Great Lakes angler surveys. Trans. Am. Fish. Soc. 142: 234–246.
#' \doi{10.1080/00028487.2012.728167}
#'
#' Greene, C.J., Hoenig, J.M., Barrowman, N.J. & Pollock, K.H. (1995). Programs
#' to simulate catch rate estimation in a roving creel survey of anglers. DFO
#' Atlantic Fisheries Research Document 95/99. Department of Fisheries and
#' Oceans, St. John's, NL.
#'
#' Pollock, K.H., Hoenig, J.M., Jones, C.M., Robson, D.S. & Greene, C.J.
#' (1997). Catch rate estimation for roving and access point surveys. N. Am. J.
#' Fish. Manage. 17: 11–19.
#' \doi{10.1577/1548-8675(1997)017<0011:CREFRA>2.3.CO;2}
#'
#' Petrere, M. Jr., Giacomini, H.C. & De Marco, P. Jr. (2010).
#' Catch-per-unit-effort: which estimator is best? Braz. J. Biol. 70: 483–491.
#' \doi{10.1590/S1519-69842010005000010}
#'
#' @examples
#' my_params <- list(
#'   effort         = list(gamma_shape = 2.0, gamma_rate = 0.8),
#'   party          = list(mean = 1.5),
#'   catch_rate     = list(mean = 0.25, nb_size = 0.5), # fish per angler-hour
#'   harvest        = list(mean_pct = 35),
#'   counts         = list(mean_total_anglers = 10)
#' )
#'
#' # Basic simulation (single stratum)
#' set.seed(42)
#' sim <- simulate_creel_data(
#'   params         = my_params,
#'   season_days    = 90,
#'   n_sampled_days = 20,
#'   species        = c("walleye", "northern_pike"),
#'   species_weights = c(0.6, 0.4),
#'   daylight_hours = 12
#' )
#' head(sim$schedule)
#' head(sim$interviews)
#' head(sim$counts)
#' head(sim$catch)
#' sim$truth$catch_rate
#' sim$truth$effort_season
#'
#' # Multi-stratum simulation with day_types (named numeric vector).
#' # `lat` derives the daily fishing period from day_length(), so T, and with
#' # it sim2$counts$daylight_hours, follows the season.
#' set.seed(1)
#' sim2 <- simulate_creel_data(
#'   params         = my_params,
#'   season_days    = 90,
#'   n_sampled_days = 20,
#'   day_types      = c(weekday = 5/7, weekend = 2/7),
#'   interview_type = "roving",
#'   lat            = 40.699
#' )
#'
#' # Round-trip: simulate → creel_design → add_counts → add_interviews
#' # total_anglers is dropped: it varies between the counts taken within a day,
#' # so aggregation cannot carry it forward (see the note above).
#' counts2 <- sim2$counts[, c("date", "day_type", "count_time", "angler_hours")]
#'
#' design <- creel_design(sim2$schedule, date = date, strata = day_type) |>
#'   add_counts(
#'     counts2,
#'     count_col = angler_hours, # a head count alone is not effort
#'     count_time_col = count_time
#'   ) |>
#'   add_interviews(
#'     sim2$interviews,
#'     catch          = "catch_total",
#'     effort         = "hours_fished",
#'     harvest        = "catch_kept",
#'     trip_status    = "trip_status",
#'     trip_duration  = "trip_duration",
#'     n_anglers      = "n_anglers",
#'     interview_type = "roving"
#'   )
#'
#' @seealso \code{\link{simulate_creel_catch}}
#' @family "Simulation"
#' @importFrom stats rbinom rgamma rnbinom rpois runif
#' @export
simulate_creel_data <- function(
  params,
  season_days = 100L,
  n_sampled_days = 30L,
  day_types = NULL,
  species = "walleye",
  species_weights = NULL,
  interview_type = c("access", "roving"),
  p_complete = NULL,
  p_zero_catch = 0.40,
  n_anglers_per_day = NULL,
  start_date = Sys.Date(),
  n_counts_per_day = 3L,
  lat = NULL,
  daylight_hours = NULL,
  seed = NULL
) {
  checkmate::assert_list(params, names = "named")
  checkmate::assert_int(season_days, lower = 1L)
  checkmate::assert_int(n_sampled_days, lower = 1L, upper = season_days)
  checkmate::assert_character(species, min.len = 1L, any.missing = FALSE)
  interview_type <- match.arg(interview_type)
  refuse_removed_simulation_inputs(params, p_complete)
  checkmate::assert_number(p_zero_catch, lower = 0.0, upper = 1.0 - 1e-9)
  checkmate::assert_int(n_counts_per_day, lower = 1L)
  if (!is.null(seed)) {
    checkmate::assert_int(seed)
  }

  daylight_fun <- resolve_daylight_hours(daylight_hours, lat)
  if (is.null(daylight_fun)) {
    # The counts are now the anglers present at a moment of the fishing day,
    # so the day needs a length (GH #646). There is no honest default.
    creel_abort(
      c(
        "Supply {.arg lat} or {.arg daylight_hours}: the fishing day needs a length.",
        "i" = "Trips start within the day and counts are taken at times in it (GH #646).",
        "i" = "Use {.arg daylight_hours} when the period is set by regulation or field protocol."
      ),
      class = "creel_error_invalid_input"
    )
  }

  if (!is.null(seed)) {
    # Restore whatever the caller had, once this function returns.
    .rng_old <- .rng_state()
    on.exit(.restore_rng(.rng_old), add = TRUE)
    set.seed(seed)
  }

  sp_wt <- if (is.null(species_weights)) {
    rep(1.0 / length(species), length(species))
  } else {
    checkmate::assert_numeric(species_weights, len = length(species), lower = 0)
    species_weights / sum(species_weights)
  }

  # ── Day-type setup ───────────────────────────────────────────────────────────
  if (is.null(day_types)) {
    day_types <- c("all" = 1.0)
  } else {
    checkmate::assert_numeric(day_types, lower = 0, any.missing = FALSE, names = "named")
    day_types <- day_types / sum(day_types)
  }

  all_dates <- seq.Date(as.Date(start_date), by = "day", length.out = season_days)

  # ── Effort + trip params ─────────────────────────────────────────────────────
  eff_p <- params$effort
  party_p <- params$party
  harv_p <- params$harvest
  catch_p <- params$catch_rate
  checkmate::assert_list(catch_p, names = "named", .var.name = "params$catch_rate")
  checkmate::assert_number(catch_p$mean, lower = 0, .var.name = "params$catch_rate$mean")
  # NULL or NA means "not supplied" (documented default); a supplied value must
  # be a usable dispersion, not silently replaced.
  nb_sz <- if (is.null(catch_p$nb_size) || is.na(catch_p$nb_size)) {
    0.5
  } else {
    checkmate::assert_number(catch_p$nb_size, lower = 1e-9, .var.name = "params$catch_rate$nb_size")
    catch_p$nb_size
  }
  p_h <- if (!is.null(harv_p$mean_pct) && !is.na(harv_p$mean_pct)) harv_p$mean_pct / 100 else 0.35
  p_h <- pmin(pmax(p_h, 0.0), 1.0)
  cnt_p <- params$counts

  mu_anglers <- if (!is.null(n_anglers_per_day)) {
    checkmate::assert_number(n_anglers_per_day, lower = 0.1)
    n_anglers_per_day
  } else {
    cnt_p$mean_total_anglers
  }
  if (is.na(mu_anglers) || mu_anglers <= 0) {
    mu_anglers <- 10.0
  }

  # ── The population: every trip of the season ─────────────────────────────────
  # Simulated first, before anything about the survey is drawn, so one seed
  # gives one population whatever the sampling: an access run and a roving
  # run with the same seed meet the same trips, and changing n_sampled_days
  # or n_counts_per_day leaves the truth unchanged (GH #646). Trips are
  # simulated on every day, sampled or not, so the season's true effort and
  # catch are known.
  pop <- vector("list", season_days)
  for (d in seq_len(season_days)) {
    t_day <- daylight_fun(all_dates[d])
    # Number of parties fishing this day -- NB around mu_anglers. No one
    # fishes a day with no fishing period (a polar night under `lat`).
    n_trips_d <- if (t_day > 0) max(0L, rnbinom(1, mu = mu_anglers, size = 1.5)) else 0L
    if (n_trips_d > 0L) {
      # A trip cannot outlast the fishing day, and starts at a uniformly
      # random time that lets it fit: [0, T - L].
      eff_total <- rgamma(n_trips_d, shape = eff_p$gamma_shape, rate = eff_p$gamma_rate)
      eff_total <- pmin(pmax(eff_total, 0.1), t_day)
      start <- stats::runif(n_trips_d, 0, t_day - eff_total)
      n_ang <- pmax(1L, rpois(n_trips_d, lambda = party_p$mean))
      # Whole-trip catch, drawn once per trip. Catch accrues over the time
      # fished (GH #494) -- mean rate x anglers x hours -- with zero inflation
      # for parties that catch nothing all trip; the non-zero component's mean
      # is scaled by 1 / (1 - p_zero) so total catch over total angler-hours
      # is exactly catch_rate$mean.
      is_zero <- stats::rbinom(n_trips_d, 1L, p_zero_catch) == 1L
      c_trip <- integer(n_trips_d)
      mu_c <- catch_p$mean * n_ang * eff_total / (1 - p_zero_catch)
      c_trip[!is_zero] <- stats::rnbinom(sum(!is_zero), mu = mu_c[!is_zero], size = nb_sz)
      k_trip <- stats::rbinom(n_trips_d, c_trip, p_h)
    } else {
      eff_total <- start <- numeric(0)
      n_ang <- c_trip <- k_trip <- integer(0)
    }
    pop[[d]] <- list(
      t_day = t_day, eff_total = eff_total, start = start,
      n_ang = n_ang, c_trip = c_trip, k_trip = k_trip
    )
  }

  # ── Season calendar ───────────────────────────────────────────────────────────
  # Day types first, then the sample of days: random stratum labels belong to
  # the season, so they must not move when n_sampled_days does.
  dt_names <- names(day_types)
  n_dt <- length(day_types)
  if (setequal(dt_names, c("weekday", "weekend"))) {
    # Weekday and weekend are facts about the date, not labels to draw: a
    # simulated Tuesday labelled "weekend" contradicts any calendar (GH #488).
    # The proportions are then set by the calendar, not by `day_types`.
    all_day_types <- ifelse(format(all_dates, "%u") %in% c("6", "7"), "weekend", "weekday")
  } else {
    # Any other names are arbitrary strata: assign them at random in the
    # stated proportions.
    all_day_types <- dt_names[sample.int(n_dt, season_days, replace = TRUE, prob = day_types)]
  }

  samp_idx <- sort(sample.int(season_days, n_sampled_days, replace = FALSE))

  # ── The survey: interviews and counts on the sampled days ──────────────────────
  interview_rows <- vector("list", season_days)
  count_rows <- vector("list", season_days)
  is_sampled <- seq_len(season_days) %in% samp_idx
  int_id <- 0L

  for (d in samp_idx) {
    d_date <- all_dates[d]
    d_dtype <- all_day_types[d]
    t_day <- pop[[d]]$t_day
    eff_total <- pop[[d]]$eff_total
    start <- pop[[d]]$start
    n_ang <- pop[[d]]$n_ang
    c_trip <- pop[[d]]$c_trip
    k_trip <- pop[[d]]$k_trip
    n_trips_d <- length(eff_total)
    if (n_trips_d > 0L) {
      n_enc <- min(n_trips_d, max(1L, round(n_trips_d * 0.70)))
      if (identical(interview_type, "access")) {
        # Access: the clerk meets parties as they leave, so every finishing
        # party has the same chance whatever its trip length (Pollock et al.
        # 1997). The whole trip is observed.
        enc_idx <- sample.int(n_trips_d, size = n_enc, replace = FALSE)
      } else {
        # Roving: the clerk meets parties while they fish, so each party's
        # chance is proportional to its trip length (length-biased sampling),
        # and it is met at a uniformly random point in its trip. Each party is
        # included independently with probability 0.25 * L / mean(L), capped
        # at 1 for trips over four times the day's mean length -- rare for
        # Gamma trip lengths, and it lowers the average just under a quarter.
        # The cap breaks strict proportionality only for those trips. Not a
        # weighted draw of a fixed 70% without replacement: taking most of a
        # small population that way is barely length-biased at all (mean
        # interviewed length 3.0 h against the 3.75 h a length-biased sample
        # of Gamma(2, 0.8) trips has).
        p_meet <- pmin(1, 0.25 * eff_total / mean(eff_total))
        enc_idx <- which(stats::runif(n_trips_d) < p_meet)
      }

      for (ti in enc_idx) {
        int_id <- int_id + 1L

        if (identical(interview_type, "access")) {
          eff_obs <- eff_total[ti]
          ctotal <- c_trip[ti]
          ckept <- k_trip[ti]
        } else {
          # The time so far; the 0.1 h floor stands for a clerk who does not
          # interview a party that has only just started. The catch so far is
          # the part of the trip's own catch caught by then: each fish falls
          # in the elapsed fraction of the trip with probability h / L, so its
          # mean is rate x anglers x h, and the kept fish so far are drawn
          # from the trip's kept fish.
          eff_obs <- min(eff_total[ti], stats::runif(1, min = 0.1, max = max(0.1, eff_total[ti])))
          ctotal <- stats::rbinom(1L, c_trip[ti], eff_obs / eff_total[ti])
          ckept <- if (ctotal > 0L) stats::rhyper(1L, k_trip[ti], c_trip[ti] - k_trip[ti], ctotal) else 0L
        }

        interview_rows[[d]][[ti]] <- list(
          date = d_date,
          day_type = d_dtype,
          interview_id = int_id,
          trip_status = if (identical(interview_type, "access")) "complete" else "incomplete",
          hours_fished = round(eff_obs, 3),
          # The time so far, as a clerk records it and add_interviews() reads
          # it (GH #488); the full length is simulation truth, kept apart.
          trip_duration = round(eff_obs, 3),
          true_trip_length = round(eff_total[ti], 3),
          n_anglers = n_ang[ti],
          catch_total = as.integer(ctotal),
          catch_kept = as.integer(ckept),
          species_sought = species[which.max(stats::rmultinom(1L, 1L, sp_wt))]
        )
      }
    }

    # Instantaneous counts: anglers present at uniformly random moments of the
    # fishing day (GH #646). count x T is then unbiased for the day's
    # angler-hours (Hoenig et al. 1993). count_time indexes the counts in time
    # order.
    t_cnt <- sort(stats::runif(n_counts_per_day, 0, t_day))
    tot_cnt <- vapply(t_cnt, function(tk) {
      sum(n_ang[start <= tk & tk < start + eff_total])
    }, numeric(1))
    count_rows[[d]] <- data.frame(
      date = rep(d_date, n_counts_per_day),
      day_type = rep(d_dtype, n_counts_per_day),
      count_time = seq_len(n_counts_per_day),
      total_anglers = as.integer(tot_cnt),
      daylight_hours = rep(t_day, n_counts_per_day),
      angler_hours = as.integer(tot_cnt) * t_day
    )
  }


  # ── Assemble interviews ──────────────────────────────────────────────────────
  int_flat <- do.call(c, lapply(interview_rows, function(dl) Filter(Negate(is.null), dl)))
  if (length(int_flat) == 0L) {
    interviews <- data.frame(
      date = as.Date(character(0)),
      day_type = character(0),
      interview_id = integer(0),
      trip_status = character(0),
      hours_fished = numeric(0),
      trip_duration = numeric(0),
      true_trip_length = numeric(0),
      n_anglers = integer(0),
      catch_total = integer(0),
      catch_kept = integer(0),
      species_sought = character(0)
    )
  } else {
    interviews <- do.call(rbind, lapply(int_flat, as.data.frame, stringsAsFactors = FALSE))
    interviews$date <- as.Date(interviews$date, origin = "1970-01-01")
    rownames(interviews) <- NULL
  }

  # ── Assemble counts ──────────────────────────────────────────────────────────
  counts <- do.call(rbind, Filter(Negate(is.null), count_rows))
  rownames(counts) <- NULL

  # ── Build catch (long format, multi-species) ─────────────────────────────────
  if (nrow(interviews) == 0L || length(species) == 0L) {
    catch <- data.frame(
      interview_id = integer(0),
      species = character(0),
      count = integer(0),
      catch_type = character(0)
    )
  } else {
    catch_rows <- vector("list", nrow(interviews))
    for (i in seq_len(nrow(interviews))) {
      iid <- interviews$interview_id[i]
      ctotal <- interviews$catch_total[i]
      ckept <- interviews$catch_kept[i]

      if (ctotal == 0L) {
        next
      }

      # Distribute total catch across species, then split the interview's own
      # kept fish across them: a multivariate hypergeometric draw of ckept
      # fish from sp_counts, made one species at a time. The harvested rows
      # then sum to catch_kept exactly (GH #651); an independent binomial per
      # species summed to a fresh total, describing different fish.
      sp_counts <- as.integer(stats::rmultinom(1L, ctotal, sp_wt))
      sp_kept <- integer(length(species))
      fish_left <- ctotal
      kept_left <- ckept
      for (s in seq_along(species)) {
        if (kept_left == 0L) break
        sp_kept[s] <- stats::rhyper(1L, sp_counts[s], fish_left - sp_counts[s], kept_left)
        fish_left <- fish_left - sp_counts[s]
        kept_left <- kept_left - sp_kept[s]
      }

      sp_rows <- vector("list", length(species))
      for (s in seq_along(species)) {
        c_s <- sp_counts[s]
        k_s <- sp_kept[s]
        r_s <- c_s - k_s
        if (c_s == 0L) {
          next
        }
        sp_rows[[s]] <- data.frame(
          interview_id = rep(iid, 3L),
          species = rep(species[s], 3L),
          count = c(c_s, k_s, r_s),
          catch_type = c("caught", "harvested", "released"),
          stringsAsFactors = FALSE
        )
      }
      catch_rows[[i]] <- do.call(rbind, Filter(Negate(is.null), sp_rows))
    }
    catch <- do.call(rbind, Filter(Negate(is.null), catch_rows))
    if (is.null(catch)) {
      catch <- data.frame(
        interview_id = integer(0),
        species = character(0),
        count = integer(0),
        catch_type = character(0)
      )
    }
    rownames(catch) <- NULL
  }

  # ── Build full-season schedule (calendar for creel_design) ──────────────────
  schedule <- data.frame(
    date = all_dates,
    day_type = all_day_types,
    sampled = seq_len(season_days) %in% samp_idx,
    stringsAsFactors = FALSE
  )

  # The population values an estimator should recover, for simulation studies:
  # the rates, and the realised angler-hours, catch and harvest of every trip,
  # over the sampled days and over the season (GH #646).
  truth_days <- data.frame(
    date = all_dates,
    day_type = all_day_types,
    sampled = is_sampled,
    parties = vapply(pop, function(x) length(x$n_ang), integer(1)),
    anglers = vapply(pop, function(x) sum(x$n_ang), numeric(1)),
    effort = vapply(pop, function(x) sum(x$n_ang * x$eff_total), numeric(1)),
    catch = vapply(pop, function(x) sum(x$c_trip), numeric(1)),
    harvest = vapply(pop, function(x) sum(x$k_trip), numeric(1)),
    stringsAsFactors = FALSE
  )
  truth <- list(
    catch_rate = catch_p$mean,
    harvest_rate = catch_p$mean * p_h,
    effort_sampled_days = sum(truth_days$effort[is_sampled]),
    effort_season = sum(truth_days$effort),
    catch_sampled_days = sum(truth_days$catch[is_sampled]),
    catch_season = sum(truth_days$catch),
    harvest_sampled_days = sum(truth_days$harvest[is_sampled]),
    harvest_season = sum(truth_days$harvest),
    days = truth_days
  )

  list(schedule = schedule, interviews = interviews, counts = counts, catch = catch, truth = truth)
}


#' Simulate catch counts from a distributional family
#'
#' @description
#' Generates catch observations from one of three distributional families:
#' Negative Binomial (\code{"negbin"}), zero-inflated lognormal / Delta
#' (\code{"delta"}), or Poisson. Intended for distributional sensitivity
#' analysis, power checks, and Petrere-style estimator comparisons.
#'
#' @param n Integer. Number of catch observations to generate.
#' @param effort Numeric vector of length \code{n} or scalar. Effort values
#'   (e.g. angler-hours) for each observation. Used to scale catch under
#'   \code{var_structure = "proportional"} or \code{"squared"}.
#' @param family Character. Distribution family:
#'   \code{"negbin"} (default), \code{"delta"}, or \code{"poisson"}.
#' @param mu Numeric. Mean catch rate (catch per unit effort). Default 5.
#' @param size Numeric. Negative Binomial dispersion parameter (NB size).
#'   Ignored when \code{family = "poisson"}. Default 0.5.
#' @param p_zero Numeric in \[0, 1). Zero-inflation probability for
#'   \code{family = "delta"}. Default 0.40.
#' @param sigma Numeric. Log-scale standard deviation for \code{family = "delta"}
#'   (positive values only). Default 1.0.
#' @param var_structure Character. Error variance structure. \code{"constant"}
#'   (default): variance independent of effort; \code{"proportional"}:
#'   \eqn{Var \propto f}; \code{"squared"}: \eqn{Var \propto f^2}.
#' @param seed Integer or \code{NULL}. Random seed. Default \code{NULL}.
#'
#' @return Integer vector of length \code{n} containing simulated catch counts.
#'
#' @details
#' \strong{Delta distribution} (Petrere et al. 2010, Table 1): A mixture of
#' a point mass at zero (probability \code{p_zero}) and a lognormal
#' distribution for positive values (parameters \code{mu} and \code{sigma}
#' on the log scale). Closely matches empirical creel catch distributions.
#'
#' \strong{Variance structures} (Petrere et al. 2010):
#' \itemize{
#'   \item \code{constant}: \eqn{\varepsilon_i \sim N(0, \sigma^2)}
#'   \item \code{proportional}: \eqn{\varepsilon_i \sim N(0, \sigma^2 f_i)}
#'   \item \code{squared}: \eqn{\varepsilon_i \sim N(0, \sigma^2 f_i^2)}
#' }
#'
#' @references
#' Petrere, M. Jr., Giacomini, H.C. & De Marco, P. Jr. (2010).
#' Catch-per-unit-effort: which estimator is best? Braz. J. Biol. 70: 483–491.
#' \doi{10.1590/S1519-69842010005000010}
#'
#' @examples
#' set.seed(1)
#' # NB catch (default)
#' catch_nb <- simulate_creel_catch(n = 200, effort = 3.0, mu = 5, size = 0.5)
#' mean(catch_nb); var(catch_nb)
#'
#' # Delta distribution (zero-inflated lognormal)
#' catch_d <- simulate_creel_catch(
#'   n = 500, effort = 3.0, family = "delta",
#'   p_zero = 0.45, mu = 1.6, sigma = 0.8
#' )
#' mean(catch_d == 0)  # ~0.45
#'
#' # Proportional variance structure
#' effort <- rgamma(100, shape = 2.5, rate = 0.57)
#' catch_prop <- simulate_creel_catch(
#'   n = 100, effort = effort, mu = 4,
#'   var_structure = "proportional"
#' )
#'
#' @seealso \code{\link{simulate_creel_data}}
#' @family "Simulation"
#' @importFrom stats rlnorm rnbinom rpois
#' @export
simulate_creel_catch <- function(
  n,
  effort = 1.0,
  family = c("negbin", "delta", "poisson"),
  mu = 5.0,
  size = 0.5,
  p_zero = 0.40,
  sigma = 1.0,
  var_structure = c("constant", "proportional", "squared"),
  seed = NULL
) {
  family <- match.arg(family)
  var_structure <- match.arg(var_structure)

  checkmate::assert_int(n, lower = 1L)
  checkmate::assert_numeric(effort, lower = 0, any.missing = FALSE)
  checkmate::assert_number(mu, lower = 1e-9)
  checkmate::assert_number(size, lower = 1e-9)
  checkmate::assert_number(p_zero, lower = 0.0, upper = 1.0 - 1e-9)
  checkmate::assert_number(sigma, lower = 1e-9)
  if (!is.null(seed)) {
    checkmate::assert_int(seed)
  }

  if (!is.null(seed)) {
    # Restore whatever the caller had, once this function returns.
    .rng_old <- .rng_state()
    on.exit(.restore_rng(.rng_old), add = TRUE)
    set.seed(seed)
  }

  # Recycle effort to length n
  effort <- rep_len(effort, n)

  # Scale mu by effort based on variance structure
  mu_i <- switch(
    var_structure,
    "constant" = rep(mu, n),
    "proportional" = mu * effort,
    "squared" = mu * effort^2
  )

  switch(
    family,
    "negbin" = {
      as.integer(rnbinom(n, mu = pmax(mu_i, 1e-9), size = size))
    },
    "delta" = {
      is_zero <- rbinom(n, 1L, p_zero) == 1L
      log_mean <- log(pmax(mu_i, 1e-9)) - sigma^2 / 2
      pos_vals <- as.integer(round(rlnorm(n, meanlog = log_mean, sdlog = sigma)))
      pos_vals[pos_vals < 0L] <- 0L
      ifelse(is_zero, 0L, pos_vals)
    },
    "poisson" = {
      as.integer(rpois(n, lambda = pmax(mu_i, 1e-9)))
    }
  )
}

# ---- daylight hours ---------------------------------------------------------

# Refuse inputs removed by GH #494, with a message saying what replaced them,
# rather than silently ignoring them or reinterpreting them.
refuse_removed_simulation_inputs <- function(params, p_complete, call = rlang::caller_env()) {
  if (!is.null(params$catch_per_trip)) {
    creel_abort(
      c(
        "{.code params$catch_per_trip} is no longer used.",
        "x" = paste0(
          "It drew one catch per trip regardless of time fished or party size, ",
          "so an incomplete trip carried the whole trip's catch (GH #494)."
        ),
        "i" = paste0(
          "Supply {.code params$catch_rate = list(mean = , nb_size = )}, the ",
          "catch per angler-hour. A per-trip mean has no conversion to a rate."
        )
      ),
      class = c("creel_error_simulate_removed_input", "creel_error_invalid_input"),
      call = call
    )
  }
  if (!is.null(p_complete)) {
    creel_abort(
      c(
        "{.arg p_complete} is no longer used.",
        "x" = paste0(
          "Mixing complete and incomplete trips from one length-biased draw ",
          "sampled access interviews the way a roving clerk would (GH #494)."
        ),
        "i" = paste0(
          "Use {.code interview_type = \"access\"} (complete trips) or ",
          "{.code interview_type = \"roving\"} (incomplete trips); simulate ",
          "twice for both."
        )
      ),
      class = c("creel_error_simulate_removed_input", "creel_error_invalid_input"),
      call = call
    )
  }
  invisible(NULL)
}

#' Resolve lat / daylight_hours to a function of date
#'
#' Returns `NULL` when the caller supplied neither; simulate_creel_data() then
#' refuses (GH #646), because inventing a latitude would put a plausible number
#' where the caller gave none.
#'
#' @param daylight_hours NULL, a single number, or a named length-12 vector.
#' @param lat NULL or a single latitude in decimal degrees.
#'
#' @return NULL, or a function taking a Date vector and returning hours.
#'
#' @keywords internal
#' @noRd
resolve_daylight_hours <- function(daylight_hours, lat) {
  if (is.null(daylight_hours) && is.null(lat)) {
    return(NULL)
  }

  if (!is.null(daylight_hours) && !is.null(lat)) {
    creel_abort(c(
      "Supply {.arg lat} or {.arg daylight_hours}, not both.",
      "i" = "{.arg lat} derives the daily period with {.fn day_length}.",
      "i" = "{.arg daylight_hours} sets it directly."
    ))
  }

  if (!is.null(lat)) {
    checkmate::assert_number(lat, lower = -90, upper = 90)
    return(function(dates) day_length(lat, dates)) # nolint: object_usage_linter
  }

  checkmate::assert_numeric(daylight_hours, any.missing = FALSE, lower = 1e-9)

  if (length(daylight_hours) == 1L) {
    value <- as.numeric(daylight_hours)
    return(function(dates) rep(value, length(dates)))
  }

  if (length(daylight_hours) != 12L) {
    creel_abort(c(
      "{.arg daylight_hours} must be a single value or a length-12 monthly vector.",
      "x" = "Got length {length(daylight_hours)}."
    ))
  }

  nms <- names(daylight_hours)
  if (is.null(nms)) {
    creel_abort(c(
      "A length-12 {.arg daylight_hours} must be named by month.",
      "i" = "Use names {.val {as.character(1:12)}} or {.val {month.abb}}."
    ))
  }

  idx <- match(nms, month.abb)
  if (anyNA(idx)) {
    idx <- suppressWarnings(as.integer(nms))
  }
  if (anyNA(idx) || !setequal(idx, 1:12)) {
    creel_abort(c(
      "Could not match {.arg daylight_hours} names to months.",
      "i" = "Use names {.val {as.character(1:12)}} or {.val {month.abb}}."
    ))
  }

  lookup <- stats::setNames(
    as.numeric(daylight_hours)[order(idx)],
    sprintf("%02d", 1:12)
  )
  function(dates) unname(lookup[format(dates, "%m")])
}
