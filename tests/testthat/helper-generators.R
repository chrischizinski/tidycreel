# Phase 79 helpers: property-test generators for valid creel designs

build_br_design_for_tests <- function(n_sites, n_days, n_interviews, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  stopifnot(
    is.numeric(n_sites), n_sites >= 2,
    is.numeric(n_days), n_days >= 4,
    is.numeric(n_interviews), n_interviews >= 2
  )

  n_sites <- as.integer(n_sites)
  n_days <- as.integer(n_days)
  n_interviews <- as.integer(n_interviews)

  calendar <- data.frame(
    date = seq.Date(as.Date("2024-06-01"), by = "day", length.out = n_days),
    day_type = rep("weekday", n_days),
    stringsAsFactors = FALSE
  )

  site_ids <- paste0("S", seq_len(n_sites))
  site_weights <- sample(seq.int(1L, 5L), n_sites, replace = TRUE)
  sampling_frame <- data.frame(
    site = site_ids,
    circuit = rep("C1", n_sites),
    p_site = site_weights / sum(site_weights),
    p_period = rep(0.8, n_sites),
    stringsAsFactors = FALSE
  )

  design <- creel_design(
    calendar,
    date = date,
    strata = day_type,
    survey_type = "bus_route",
    sampling_frame = sampling_frame,
    site = site,
    circuit = circuit,
    p_site = p_site,
    p_period = p_period
  )

  interview_dates <- sample(rep(calendar$date, length.out = n_interviews))
  interview_sites <- sample(rep(site_ids, length.out = n_interviews))
  n_anglers <- sample(1:3, n_interviews, replace = TRUE)
  n_interviewed <- sample(1:4, n_interviews, replace = TRUE)
  n_counted <- n_interviewed + sample(0:4, n_interviews, replace = TRUE)
  catch_total <- sample(0:8, n_interviews, replace = TRUE)
  catch_kept <- vapply(
    catch_total,
    function(x) {
      if (x == 0L) {
        return(0L)
      }

      sample.int(x + 1L, 1L) - 1L
    },
    integer(1)
  )
  hours_fished <- round(runif(n_interviews, min = 1, max = 6), 2)

  interviews <- data.frame(
    date = interview_dates,
    day_type = rep("weekday", n_interviews),
    site = interview_sites,
    circuit = rep("C1", n_interviews),
    catch_total = catch_total,
    catch_kept = catch_kept,
    hours_fished = hours_fished,
    n_anglers = n_anglers,
    trip_status = rep("complete", n_interviews),
    trip_duration = hours_fished,
    n_counted = n_counted,
    n_interviewed = n_interviewed,
    stringsAsFactors = FALSE
  )

  suppressMessages(
    suppressWarnings(
      add_interviews(
        design,
        interviews,
        catch = catch_total,
        effort = hours_fished,
        harvest = catch_kept,
        n_anglers = n_anglers,
        trip_status = trip_status,
        trip_duration = trip_duration,
        n_counted = n_counted,
        n_interviewed = n_interviewed
      )
    )
  )
}

gen_valid_creel_design <- function(n_min = 2L) {
  stopifnot(is.numeric(n_min), n_min >= 2)

  candidate_params <- expand.grid(
    n_sites = 2:5,
    n_days = seq.int(max(4L, as.integer(n_min)), max(8L, as.integer(n_min) + 3L)),
    n_interviews = seq.int(max(4L, as.integer(n_min)), max(12L, as.integer(n_min) + 6L)),
    stringsAsFactors = FALSE
  )

  generator <- hedgehog::gen.with(
    hedgehog::gen.element(seq_len(nrow(candidate_params))),
    function(idx) {
      params <- candidate_params[idx, , drop = FALSE]
      build_br_design_for_tests(
        n_sites = params$n_sites,
        n_days = params$n_days,
        n_interviews = params$n_interviews,
        seed = idx
      )
    }
  )

  quickcheck::from_hedgehog(generator)
}
