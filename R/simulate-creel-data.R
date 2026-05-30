# Creel Data Simulator ----

#' Simulate a complete creel survey dataset
#'
#' @description
#' Generates realistic synthetic creel data using a three-level hierarchical
#' generative model (day → trip → catch). Caller supplies distributional
#' parameters via \code{params}; no default data are bundled with the package.
#'
#' The generative model follows Su & Clapp (2013) and Greene (1995):
#' \enumerate{
#'   \item \strong{Day level}: Sample \code{n_sampled_days} days from the
#'     season. Each sampled day draws the number of angler trips arriving from
#'     a Negative Binomial distribution.
#'   \item \strong{Trip level}: Each trip draws effort (hr) from a Gamma
#'     distribution, party size from a zero-truncated Poisson, and trip
#'     completion from a Bernoulli draw.
#'   \item \strong{Catch level}: Each complete or incomplete trip draws total
#'     catch from a Negative Binomial; harvest is Binomial given total catch.
#'   \item \strong{Roving clerk}: Interview probability is proportional to
#'     trip length (length-biased sampling). Incomplete trips contribute
#'     elapsed effort, not total effort.
#' }
#'
#' @param params Named list of distributional parameters. Required. Must
#'   include sub-lists:
#'   \describe{
#'     \item{\code{effort}}{List with \code{gamma_shape} and \code{gamma_rate}
#'       (passed to \code{rgamma()}).}
#'     \item{\code{party}}{List with \code{mean} (mean party size, used as
#'       \code{lambda} for \code{rpois()}).}
#'     \item{\code{catch_per_trip}}{List with \code{mean} and \code{nb_size}
#'       (used for \code{rnbinom()}).}
#'     \item{\code{harvest}}{List with \code{mean_pct} (harvest as a
#'       percentage, e.g. \code{35} for 35\%).}
#'     \item{\code{counts}}{List with \code{mean_total_anglers} (mean
#'       instantaneous count; used when \code{n_anglers_per_day = NULL}).}
#'   }
#' @param season_days Integer. Total days in the season. Default 100.
#' @param n_sampled_days Integer. Number of days actually surveyed. Must be
#'   \code{<= season_days}. Default 30.
#' @param day_types Named numeric vector. Proportion of days per stratum, e.g.
#'   \code{c(weekday = 5/7, weekend = 2/7)}. When \code{NULL} (default),
#'   uses a single stratum \code{"all"}.
#' @param species Character vector. Species names for the catch table. Default
#'   \code{"walleye"}. Catch is split proportionally across species using
#'   \code{species_weights}.
#' @param species_weights Numeric vector. Relative catch weight per species.
#'   Must be same length as \code{species}. Default equal weights.
#' @param p_complete Numeric in (0, 1]. Probability a trip is complete
#'   (intercepted at trip end). Default \code{0.75}.
#' @param p_zero_catch Numeric in \[0, 1). Probability a trip has zero total
#'   catch (zero-inflation). Default \code{0.40}. \strong{Note:} this cannot
#'   be derived from the NGPC inventory (API artifact); the default is an
#'   empirical estimate from the creel literature.
#' @param n_anglers_per_day Numeric. Mean number of angler parties arriving
#'   per sampled day. Overrides \code{params$counts$mean_total_anglers} when
#'   specified. Default \code{NULL} (use params).
#' @param start_date Date. First day of the simulated season. Default
#'   \code{Sys.Date()}.
#' @param n_counts_per_day Integer. Number of instantaneous count observations
#'   per sampled day. Default \code{3}.
#' @param seed Integer or \code{NULL}. Random seed for reproducibility.
#'   Default \code{NULL}.
#'
#' @return A named list with three data frames:
#' \describe{
#'   \item{\code{interviews}}{One row per intercepted angler party. Columns:
#'     \code{date}, \code{day_type}, \code{interview_id}, \code{trip_status}
#'     (\code{"complete"} or \code{"incomplete"}), \code{hours_fished},
#'     \code{trip_duration} (total trip length; equals \code{hours_fished} for
#'     complete trips), \code{n_anglers}, \code{catch_total}, \code{catch_kept},
#'     \code{species_sought}.}
#'   \item{\code{counts}}{One row per instantaneous count. Columns:
#'     \code{date}, \code{day_type}, \code{total_anglers}.}
#'   \item{\code{catch}}{Long-format catch table. Columns: \code{interview_id},
#'     \code{species}, \code{count}, \code{catch_type} (\code{"caught"},
#'     \code{"harvested"}, \code{"released"}).}
#' }
#'
#' The \code{interviews} and \code{counts} outputs can be passed directly to
#' \code{\link{add_interviews}} and \code{\link{add_counts}} after constructing
#' a calendar with \code{\link{creel_design}}.
#'
#' @references
#' Su, B.C. & Clapp, D.F. (2013). Simulation-based evaluation of creel survey
#' designs. N. Am. J. Fish. Manage. 33: 895–909.
#'
#' Greene, B.T. (1995). The ANGLER simulation model. N. Am. J. Fish. Manage.
#' 15: 743–750.
#'
#' Petrere, M. et al. (2010). Catch-per-unit-effort: which estimator is best?
#' Fish. Res. 106: 325–333.
#'
#' @examples
#' my_params <- list(
#'   effort         = list(gamma_shape = 2.0, gamma_rate = 0.8),
#'   party          = list(mean = 1.5),
#'   catch_per_trip = list(mean = 1.8, nb_size = 0.5),
#'   harvest        = list(mean_pct = 35),
#'   counts         = list(mean_total_anglers = 10)
#' )
#' set.seed(42)
#' sim <- simulate_creel_data(
#'   params         = my_params,
#'   season_days    = 90,
#'   n_sampled_days = 20,
#'   species        = c("walleye", "northern_pike"),
#'   species_weights = c(0.6, 0.4)
#' )
#' head(sim$interviews)
#' head(sim$counts)
#' head(sim$catch)
#'
#' @seealso \code{\link{simulate_creel_catch}}
#' @family "Simulation"
#' @importFrom stats rbinom rgamma rnbinom rpois runif
#' @export
simulate_creel_data <- function(
  params,
  season_days     = 100L,
  n_sampled_days  = 30L,
  day_types       = NULL,
  species         = "walleye",
  species_weights = NULL,
  p_complete      = 0.75,
  p_zero_catch    = 0.40,
  n_anglers_per_day = NULL,
  start_date      = Sys.Date(),
  n_counts_per_day = 3L,
  seed            = NULL
) {
  checkmate::assert_list(params, names = "named")
  checkmate::assert_int(season_days,    lower = 1L)
  checkmate::assert_int(n_sampled_days, lower = 1L, upper = season_days)
  checkmate::assert_character(species, min.len = 1L, any.missing = FALSE)
  checkmate::assert_number(p_complete,   lower = 1e-6, upper = 1.0)
  checkmate::assert_number(p_zero_catch, lower = 0.0,  upper = 1.0 - 1e-9)
  checkmate::assert_int(n_counts_per_day, lower = 1L)
  if (!is.null(seed)) checkmate::assert_int(seed)

  if (!is.null(seed)) set.seed(seed)

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

  # ── Season calendar: sample n_sampled_days from season_days ─────────────────
  all_dates  <- seq.Date(as.Date(start_date), by = "day", length.out = season_days)
  samp_idx   <- sort(sample.int(season_days, n_sampled_days, replace = FALSE))
  samp_dates <- all_dates[samp_idx]

  dt_names   <- names(day_types)
  n_dt       <- length(day_types)
  day_type_vec <- dt_names[sample.int(n_dt, n_sampled_days, replace = TRUE,
                                      prob = day_types)]

  # ── Effort + trip params ─────────────────────────────────────────────────────
  eff_p   <- params$effort
  party_p <- params$party
  catch_p <- params$catch_per_trip
  harv_p  <- params$harvest
  cnt_p   <- params$counts

  mu_anglers <- if (!is.null(n_anglers_per_day)) {
    checkmate::assert_number(n_anglers_per_day, lower = 0.1)
    n_anglers_per_day
  } else {
    cnt_p$mean_total_anglers
  }
  if (is.na(mu_anglers) || mu_anglers <= 0) mu_anglers <- 10.0

  # ── Simulate ─────────────────────────────────────────────────────────────────
  interview_rows <- vector("list", n_sampled_days)
  count_rows     <- vector("list", n_sampled_days)
  int_id         <- 0L

  for (d in seq_len(n_sampled_days)) {
    d_date    <- samp_dates[d]
    d_dtype   <- day_type_vec[d]

    # Number of parties arriving this day — NB around mu_anglers
    n_trips_d <- max(0L, rnbinom(1, mu = mu_anglers, size = 1.5))

    if (n_trips_d > 0L) {
      # Trip-level draws
      eff_total <- rgamma(n_trips_d,
                          shape = eff_p$gamma_shape,
                          rate  = eff_p$gamma_rate)
      eff_total <- pmax(eff_total, 0.05)

      n_ang <- pmax(1L, rpois(n_trips_d, lambda = party_p$mean))

      is_complete <- rbinom(n_trips_d, 1L, p_complete) == 1L

      # Length-biased encounter probability ∝ trip length (roving clerk)
      enc_prob <- eff_total / sum(eff_total)
      n_enc    <- min(n_trips_d, max(1L, round(n_trips_d * 0.70)))
      enc_idx  <- sample.int(n_trips_d, size = n_enc, replace = FALSE,
                             prob = enc_prob)

      for (ti in enc_idx) {
        int_id <- int_id + 1L

        # Incomplete trips: only elapsed portion observed
        eff_obs <- if (is_complete[ti]) {
          eff_total[ti]
        } else {
          runif(1, min = 0.1, max = eff_total[ti])
        }

        # Catch — zero-inflated NB
        is_zero <- rbinom(1L, 1L, p_zero_catch) == 1L
        if (is_zero) {
          ctotal <- 0L
          ckept  <- 0L
        } else {
          nb_sz  <- if (!is.na(catch_p$nb_size) && catch_p$nb_size > 0) catch_p$nb_size else 0.5
          ctotal <- rnbinom(1L, mu = catch_p$mean, size = nb_sz)
          p_h    <- if (!is.na(harv_p$mean_pct)) harv_p$mean_pct / 100 else 0.35
          p_h    <- pmin(pmax(p_h, 0.0), 1.0)
          ckept  <- rbinom(1L, ctotal, p_h)
        }

        interview_rows[[d]][[ti]] <- list(
          date         = d_date,
          day_type     = d_dtype,
          interview_id = int_id,
          trip_status  = if (is_complete[ti]) "complete" else "incomplete",
          hours_fished = round(eff_obs, 3),
          trip_duration = round(eff_total[ti], 3),
          n_anglers    = n_ang[ti],
          catch_total  = ctotal,
          catch_kept   = ckept,
          species_sought = species[which.max(stats::rmultinom(1L, 1L, sp_wt))]
        )
      }
    }

    # Instantaneous counts for this day
    mu_cnt   <- max(0.1, mu_anglers * 0.6)  # count ~ 60% of daily arrivals
    tot_cnt  <- rnbinom(n_counts_per_day, mu = mu_cnt, size = 1.5)
    count_rows[[d]] <- data.frame(
      date          = rep(d_date, n_counts_per_day),
      day_type      = rep(d_dtype, n_counts_per_day),
      total_anglers = as.integer(tot_cnt)
    )
  }

  # ── Assemble interviews ──────────────────────────────────────────────────────
  int_flat <- do.call(c, lapply(interview_rows, function(dl) Filter(Negate(is.null), dl)))
  if (length(int_flat) == 0L) {
    interviews <- data.frame(
      date = as.Date(character(0)), day_type = character(0),
      interview_id = integer(0), trip_status = character(0),
      hours_fished = numeric(0), trip_duration = numeric(0),
      n_anglers = integer(0), catch_total = integer(0),
      catch_kept = integer(0), species_sought = character(0)
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
      interview_id = integer(0), species = character(0),
      count = integer(0), catch_type = character(0)
    )
  } else {
    catch_rows <- vector("list", nrow(interviews))
    for (i in seq_len(nrow(interviews))) {
      iid    <- interviews$interview_id[i]
      ctotal <- interviews$catch_total[i]
      ckept  <- interviews$catch_kept[i]

      if (ctotal == 0L) next

      # Distribute total catch across species
      sp_counts <- as.integer(stats::rmultinom(1L, ctotal, sp_wt))
      sp_kept   <- as.integer(stats::rmultinom(1L, ckept,  sp_wt))

      sp_rows <- vector("list", length(species))
      for (s in seq_along(species)) {
        c_s <- sp_counts[s]
        k_s <- sp_kept[s]
        r_s <- c_s - k_s
        if (c_s == 0L) next
        sp_rows[[s]] <- data.frame(
          interview_id = rep(iid, 3L),
          species      = rep(species[s], 3L),
          count        = c(c_s, k_s, r_s),
          catch_type   = c("caught", "harvested", "released"),
          stringsAsFactors = FALSE
        )
      }
      catch_rows[[i]] <- do.call(rbind, Filter(Negate(is.null), sp_rows))
    }
    catch <- do.call(rbind, Filter(Negate(is.null), catch_rows))
    if (is.null(catch)) {
      catch <- data.frame(
        interview_id = integer(0), species = character(0),
        count = integer(0), catch_type = character(0)
      )
    }
    rownames(catch) <- NULL
  }

  list(interviews = interviews, counts = counts, catch = catch)
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
#' Petrere, M. et al. (2010). Catch-per-unit-effort: which estimator is best?
#' Fish. Res. 106: 325–333.
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
  effort        = 1.0,
  family        = c("negbin", "delta", "poisson"),
  mu            = 5.0,
  size          = 0.5,
  p_zero        = 0.40,
  sigma         = 1.0,
  var_structure = c("constant", "proportional", "squared"),
  seed          = NULL
) {
  family        <- match.arg(family)
  var_structure <- match.arg(var_structure)

  checkmate::assert_int(n,      lower = 1L)
  checkmate::assert_numeric(effort, lower = 0, any.missing = FALSE)
  checkmate::assert_number(mu,    lower = 1e-9)
  checkmate::assert_number(size,  lower = 1e-9)
  checkmate::assert_number(p_zero, lower = 0.0, upper = 1.0 - 1e-9)
  checkmate::assert_number(sigma,  lower = 1e-9)
  if (!is.null(seed)) checkmate::assert_int(seed)

  if (!is.null(seed)) set.seed(seed)

  # Recycle effort to length n
  effort <- rep_len(effort, n)

  # Scale mu by effort based on variance structure
  mu_i <- switch(var_structure,
    "constant"     = rep(mu, n),
    "proportional" = mu * effort,
    "squared"      = mu * effort^2
  )

  switch(family,
    "negbin" = {
      as.integer(rnbinom(n, mu = pmax(mu_i, 1e-9), size = size))
    },
    "delta" = {
      is_zero  <- rbinom(n, 1L, p_zero) == 1L
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
