# Phase 79 helpers: property-test generators for valid creel designs

build_property_calendar <- function(n_days, start_date = as.Date("2024-06-01")) {
  calendar <- data.frame(
    date = seq.Date(start_date, by = "day", length.out = n_days),
    day_type = rep(c("weekday", "weekend"), length.out = n_days),
    stringsAsFactors = FALSE
  )
  calendar
}

build_trip_interviews_for_tests <- function(calendar,
                                            n_interviews,
                                            site_ids = NULL,
                                            circuit_id = NULL,
                                            catch_total = NULL,
                                            catch_kept = NULL) {
  interview_dates <- sample(rep(calendar$date, length.out = n_interviews))
  interview_day_type <- calendar$day_type[match(interview_dates, calendar$date)]
  n_anglers <- sample(1:3, n_interviews, replace = TRUE)
  n_interviewed <- sample(1:4, n_interviews, replace = TRUE)
  n_counted <- n_interviewed + sample(0:4, n_interviews, replace = TRUE)
  hours_fished <- round(runif(n_interviews, min = 1, max = 6), 2)

  if (is.null(catch_total)) {
    catch_total <- sample(0:8, n_interviews, replace = TRUE)
    if (all(catch_total == 0L)) {
      catch_total[[1]] <- 1L
    }
  }
  catch_total <- as.integer(catch_total)

  if (is.null(catch_kept)) {
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
  }
  catch_kept <- as.integer(catch_kept)

  if (all(catch_kept == 0L) && any(catch_total > 0L)) {
    catch_kept[[which(catch_total > 0L)[[1]]]] <- 1L
  }

  interviews <- data.frame(
    interview_id = seq_len(n_interviews),
    date = interview_dates,
    day_type = interview_day_type,
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

  if (!is.null(site_ids)) {
    interviews$site <- sample(rep(site_ids, length.out = n_interviews))
  }

  if (!is.null(circuit_id)) {
    interviews$circuit <- circuit_id
  }

  interviews
}

species_pool_for_tests <- function(n_species) {
  base_species <- c(
    "bass", "panfish", "walleye", "perch", "crappie",
    "trout", "catfish", "bluegill"
  )

  if (n_species <= length(base_species)) {
    return(base_species[seq_len(n_species)])
  }

  c(base_species, paste0("species_", seq.int(length(base_species) + 1L, n_species)))
}

build_species_catch_for_tests <- function(interview_ids, n_species, include_harvest = TRUE) {
  n_interviews <- length(interview_ids)
  species_names <- species_pool_for_tests(n_species)

  caught_counts <- matrix(
    sample(0:4, n_interviews * n_species, replace = TRUE),
    nrow = n_interviews,
    ncol = n_species
  )

  zero_species <- which(colSums(caught_counts) == 0L)
  if (length(zero_species) > 0L) {
    replacement_rows <- ((seq_along(zero_species) - 1L) %% n_interviews) + 1L
    caught_counts[cbind(replacement_rows, zero_species)] <- 1L
  }

  zero_interviews <- which(rowSums(caught_counts) == 0L)
  if (length(zero_interviews) > 0L) {
    replacement_species <- ((seq_along(zero_interviews) - 1L) %% n_species) + 1L
    caught_counts[cbind(zero_interviews, replacement_species)] <- 1L
  }

  harvested_counts <- matrix(
    vapply(
      caught_counts,
      function(x) {
        if (x == 0L) {
          return(0L)
        }

        sample.int(x + 1L, 1L) - 1L
      },
      integer(1)
    ),
    nrow = n_interviews,
    ncol = n_species
  )

  caught_df <- expand.grid(
    interview_id = interview_ids,
    species = species_names,
    stringsAsFactors = FALSE
  )
  caught_df$count <- as.integer(caught_counts)
  caught_df$catch_type <- "caught"
  caught_df <- caught_df[caught_df$count > 0L, , drop = FALSE]

  catch_df <- caught_df

  if (include_harvest) {
    harvest_df <- expand.grid(
      interview_id = interview_ids,
      species = species_names,
      stringsAsFactors = FALSE
    )
    harvest_df$count <- as.integer(harvested_counts)
    harvest_df$catch_type <- "harvested"
    harvest_df <- harvest_df[harvest_df$count > 0L, , drop = FALSE]
    catch_df <- rbind(catch_df, harvest_df)
  }

  catch_df <- catch_df[, c("interview_id", "species", "count", "catch_type")]

  list(
    interview_catch_total = rowSums(caught_counts),
    interview_catch_kept = rowSums(harvested_counts),
    catch_df = catch_df
  )
}

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

  calendar <- build_property_calendar(n_days)
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

  interviews <- build_trip_interviews_for_tests(
    calendar = calendar,
    n_interviews = n_interviews,
    site_ids = site_ids,
    circuit_id = "C1"
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

build_multispecies_design_for_tests <- function(n_days,
                                                n_interviews,
                                                n_species = 3L,
                                                seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  stopifnot(
    is.numeric(n_days), n_days >= 4,
    is.numeric(n_interviews), n_interviews >= 10,
    is.numeric(n_species), n_species >= 2
  )

  n_days <- as.integer(n_days)
  n_interviews <- as.integer(n_interviews)
  n_species <- as.integer(n_species)

  # Single stratum (all weekday) intentional: this fixture keeps the original
  # combined-ratio regression baseline. Use build_multistrata_multispecies_design_for_tests()
  # for the two-stratum INV-06 multi-strata fixture.
  calendar <- data.frame(
    date = seq.Date(as.Date("2024-06-01"), by = "day", length.out = n_days),
    day_type = rep("weekday", n_days),
    stringsAsFactors = FALSE
  )
  design <- creel_design(
    calendar,
    date = date,
    strata = day_type
  )

  counts <- data.frame(
    date = calendar$date,
    day_type = calendar$day_type,
    effort_hours = round(runif(n_days, min = 12, max = 30), 2),
    stringsAsFactors = FALSE
  )
  design <- suppressMessages(suppressWarnings(add_counts(design, counts)))

  catch_data <- build_species_catch_for_tests(
    interview_ids = seq_len(n_interviews),
    n_species = n_species,
    include_harvest = TRUE
  )

  interviews <- build_trip_interviews_for_tests(
    calendar = calendar,
    n_interviews = n_interviews,
    catch_total = catch_data$interview_catch_total,
    catch_kept = catch_data$interview_catch_kept
  )

  design <- suppressMessages(
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

  suppressMessages(
    suppressWarnings(
      add_catch(
        design,
        catch_data$catch_df,
        catch_uid = interview_id,
        interview_uid = interview_id,
        species = species,
        count = count,
        catch_type = catch_type
      )
    )
  )
}

build_multistrata_multispecies_design_for_tests <- function(n_days,
                                                           n_interviews,
                                                           n_species = 3L,
                                                           seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  stopifnot(
    is.numeric(n_days), n_days >= 4,
    is.numeric(n_interviews), n_interviews >= 10,
    is.numeric(n_species), n_species >= 2
  )

  n_days <- as.integer(n_days)
  n_interviews <- as.integer(n_interviews)
  n_species <- as.integer(n_species)

  # Two strata (weekday + weekend) so INV-06 exercises the multi-strata path.
  # Requires n_days >= 4 so each stratum has at least 2 count days for variance.
  calendar <- data.frame(
    date = seq.Date(as.Date("2024-06-01"), by = "day", length.out = n_days),
    day_type = rep(c("weekday", "weekend"), length.out = n_days),
    stringsAsFactors = FALSE
  )
  design <- creel_design(
    calendar,
    date = date,
    strata = day_type
  )

  counts <- data.frame(
    date = calendar$date,
    day_type = calendar$day_type,
    effort_hours = round(runif(n_days, min = 12, max = 30), 2),
    stringsAsFactors = FALSE
  )
  design <- suppressMessages(suppressWarnings(add_counts(design, counts)))

  catch_data <- build_species_catch_for_tests(
    interview_ids = seq_len(n_interviews),
    n_species = n_species,
    include_harvest = TRUE
  )

  interviews <- build_trip_interviews_for_tests(
    calendar = calendar,
    n_interviews = n_interviews,
    catch_total = catch_data$interview_catch_total,
    catch_kept = catch_data$interview_catch_kept
  )

  design <- suppressMessages(
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

  suppressMessages(
    suppressWarnings(
      add_catch(
        design,
        catch_data$catch_df,
        catch_uid = interview_id,
        interview_uid = interview_id,
        species = species,
        count = count,
        catch_type = catch_type
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

gen_valid_creel_design_multi_species <- function(n_species_min = 2L) {
  stopifnot(is.numeric(n_species_min), n_species_min >= 2)

  candidate_params <- expand.grid(
    n_days = 4:8,
    n_interviews = 10:14,
    n_species = seq.int(as.integer(n_species_min), max(4L, as.integer(n_species_min) + 1L)),
    stringsAsFactors = FALSE
  )

  generator <- hedgehog::gen.with(
    hedgehog::gen.element(seq_len(nrow(candidate_params))),
    function(idx) {
      params <- candidate_params[idx, , drop = FALSE]
      build_multispecies_design_for_tests(
        n_days = params$n_days,
        n_interviews = params$n_interviews,
        n_species = params$n_species,
        seed = idx
      )
    }
  )

  quickcheck::from_hedgehog(generator)
}

gen_valid_creel_design_multistrata_multispecies <- function(n_species_min = 2L) {
  stopifnot(is.numeric(n_species_min), n_species_min >= 2)

  candidate_params <- expand.grid(
    n_days = 4:8,
    n_interviews = 10:14,
    n_species = seq.int(as.integer(n_species_min), max(4L, as.integer(n_species_min) + 1L)),
    stringsAsFactors = FALSE
  )

  generator <- hedgehog::gen.with(
    hedgehog::gen.element(seq_len(nrow(candidate_params))),
    function(idx) {
      params <- candidate_params[idx, , drop = FALSE]
      build_multistrata_multispecies_design_for_tests(
        n_days = params$n_days,
        n_interviews = params$n_interviews,
        n_species = params$n_species,
        seed = idx
      )
    }
  )

  quickcheck::from_hedgehog(generator)
}

build_ice_design <- function(n_days, n_interviews, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  stopifnot(
    is.numeric(n_days), n_days >= 4,
    is.numeric(n_interviews), n_interviews >= 10
  )

  n_days <- as.integer(n_days)
  n_interviews <- as.integer(n_interviews)

  calendar <- build_property_calendar(n_days, start_date = as.Date("2024-01-10"))
  design <- creel_design(
    calendar,
    date = date,
    strata = day_type,
    survey_type = "ice",
    effort_type = "time_on_ice",
    p_period = 0.5
  )

  interviews <- build_trip_interviews_for_tests(
    calendar = calendar,
    n_interviews = n_interviews
  )

  suppressMessages(
    suppressWarnings(
      add_interviews(
        design,
        interviews,
        catch = catch_total,
        effort = hours_fished,
        harvest = catch_kept,
        trip_status = trip_status,
        trip_duration = trip_duration,
        n_counted = n_counted,
        n_interviewed = n_interviewed
      )
    )
  )
}

build_br_degenerate_design <- function(n_days, n_interviews, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  stopifnot(
    is.numeric(n_days), n_days >= 4,
    is.numeric(n_interviews), n_interviews >= 10
  )

  n_days <- as.integer(n_days)
  n_interviews <- as.integer(n_interviews)

  calendar <- build_property_calendar(n_days, start_date = as.Date("2024-01-10"))
  sampling_frame <- data.frame(
    site = "S1",
    circuit = "C1",
    p_site = 1,
    p_period = 0.5,
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

  interviews <- build_trip_interviews_for_tests(
    calendar = calendar,
    n_interviews = n_interviews,
    site_ids = "S1",
    circuit_id = "C1"
  )

  suppressMessages(
    suppressWarnings(
      add_interviews(
        design,
        interviews,
        catch = catch_total,
        effort = hours_fished,
        harvest = catch_kept,
        trip_status = trip_status,
        trip_duration = trip_duration,
        n_counted = n_counted,
        n_interviewed = n_interviewed
      )
    )
  )
}

gen_ice_equivalent_design_params <- function() {
  candidate_params <- expand.grid(
    n_days = 4:8,
    n_interviews = 10:14,
    stringsAsFactors = FALSE
  )

  generator <- hedgehog::gen.with(
    hedgehog::gen.element(seq_len(nrow(candidate_params))),
    function(idx) {
      params <- candidate_params[idx, , drop = FALSE]
      list(
        n_days = params$n_days[[1]],
        n_interviews = params$n_interviews[[1]],
        seed = idx
      )
    }
  )

  quickcheck::from_hedgehog(generator)
}
