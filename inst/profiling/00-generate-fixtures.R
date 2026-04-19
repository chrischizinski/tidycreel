#!/usr/bin/env Rscript
# 00-generate-fixtures.R
#
# Purpose: Build realistic and stress bus-route creel_design fixtures and save
# them as RDS files for use by the profiling harness scripts.
#
# Run from the package root:
#   Rscript inst/profiling/00-generate-fixtures.R
#
# Output:
#   inst/profiling/fixtures/design-realistic.rds
#   inst/profiling/fixtures/design-stress.rds
#
# IMPORTANT: Do NOT source() or library() this script from package code.
# It is a standalone development tool in inst/profiling/ only.

pkgload::load_all(".")

# ---------------------------------------------------------------------------
# Helper: build bus-route sampling frame with n_sites sites
# ---------------------------------------------------------------------------
make_br_sampling_frame <- function(n_sites) {
  site_ids <- paste0("site_", seq_len(n_sites))
  # Raw weights: uniform, then normalize to sum to 1.0
  raw_weights <- rep(1.0 / n_sites, n_sites)
  # Ensure exact sum of 1 (floating point correction on last element)
  raw_weights[n_sites] <- 1.0 - sum(raw_weights[-n_sites])
  data.frame(
    site = site_ids,
    circuit = "c1",
    p_site = raw_weights,
    p_period = rep(0.5, n_sites),
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# Helper: build calendar with n_days days and n_strata strata
# ---------------------------------------------------------------------------
make_br_calendar <- function(n_days, n_strata = 2) {
  start_date <- as.Date("2024-01-01")
  dates <- seq(start_date, by = "day", length.out = n_days)
  # Alternating weekday / weekend strata (repeating across n_strata labels)
  strata_labels <- c("weekday", "weekend")
  day_type <- strata_labels[((seq_len(n_days) - 1) %% n_strata) + 1]
  data.frame(
    date = dates,
    day_type = day_type,
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# Helper: build a fully-populated bus-route creel_design
# ---------------------------------------------------------------------------
build_br_design <- function(n_sites, n_days, n_species, n_interviews_per_day,
                            seed = 42) {
  set.seed(seed)

  cal <- make_br_calendar(n_days)
  sf <- make_br_sampling_frame(n_sites)

  # --- core design object ---------------------------------------------------
  design <- creel_design(
    cal,
    date = date, strata = day_type,
    survey_type = "bus_route",
    sampling_frame = sf,
    site = site,
    circuit = circuit,
    p_site = p_site,
    p_period = p_period
  )

  # --- synthetic interviews -------------------------------------------------
  n_interviews <- n_days * n_interviews_per_day
  interview_dates <- sample(cal$date, n_interviews, replace = TRUE)
  interview_sites <- sample(sf$site, n_interviews, replace = TRUE)
  trip_status_vec <- sample(
    c("complete", "incomplete"),
    n_interviews,
    replace = TRUE,
    prob = c(0.9, 0.1)
  )
  angler_hours_vec <- runif(n_interviews, min = 0.5, max = 8.0)
  trip_duration_vec <- pmax(angler_hours_vec - runif(n_interviews, 0, 0.5), 0.5)

  # n_counted and n_interviewed per interview row (bus-route requires these)
  n_interviewed_vec <- sample(1L:5L, n_interviews, replace = TRUE)
  n_counted_vec <- n_interviewed_vec + sample(0L:3L, n_interviews, replace = TRUE)

  # total catch per complete interview (0 for incomplete)
  catch_total_vec <- ifelse(
    trip_status_vec == "complete",
    rpois(n_interviews, lambda = 2),
    0L
  )

  interviews_df <- data.frame(
    interview_id = seq_len(n_interviews),
    date = interview_dates,
    site = interview_sites,
    circuit = "c1",
    trip_status = trip_status_vec,
    hours_fished = angler_hours_vec,
    trip_duration = trip_duration_vec,
    n_counted = as.integer(n_counted_vec),
    n_interviewed = as.integer(n_interviewed_vec),
    fish_caught = as.integer(catch_total_vec),
    stringsAsFactors = FALSE
  )

  # Attach interviews to design
  design <- add_interviews(
    design,
    interviews_df,
    effort        = hours_fished,
    catch         = fish_caught,
    trip_status   = trip_status,
    trip_duration = trip_duration,
    n_counted     = n_counted,
    n_interviewed = n_interviewed
  )

  # --- synthetic catch (long-format per-species) ----------------------------
  # Only for complete interviews
  complete_idx <- which(interviews_df$trip_status == "complete")
  n_complete <- length(complete_idx)

  if (n_complete > 0 && n_species > 0) {
    species_names <- paste0("sp_", seq_len(n_species))

    catch_rows <- lapply(seq_len(n_complete), function(i) {
      interview_row_idx <- complete_idx[i]
      data.frame(
        interview_id = interview_row_idx,
        species = species_names,
        catch_type = sample(
          c("harvested", "released"),
          n_species,
          replace = TRUE,
          prob = c(0.7, 0.3)
        ),
        count = as.integer(rpois(n_species, lambda = 2)),
        stringsAsFactors = FALSE
      )
    })

    catch_df <- do.call(rbind, catch_rows)

    design <- add_catch(
      design,
      catch_df,
      catch_uid     = interview_id,
      interview_uid = interview_id,
      species       = species,
      count         = count,
      catch_type    = catch_type
    )
  }

  design
}

# ---------------------------------------------------------------------------
# Build and save fixtures
# ---------------------------------------------------------------------------
cat("Building realistic fixture (n_sites=30, n_days=20, n_species=5)...\n")
design_realistic <- build_br_design(
  n_sites              = 30,
  n_days               = 20,
  n_species            = 5,
  n_interviews_per_day = 25
)

cat("Building stress fixture (n_sites=300, n_days=200, n_species=10)...\n")
design_stress <- build_br_design(
  n_sites              = 300,
  n_days               = 200,
  n_species            = 10,
  n_interviews_per_day = 25
)

dir.create("inst/profiling/fixtures", showWarnings = FALSE, recursive = TRUE)
saveRDS(design_realistic, "inst/profiling/fixtures/design-realistic.rds")
saveRDS(design_stress, "inst/profiling/fixtures/design-stress.rds")

cat(
  "Fixtures built.",
  "Realistic:", format(object.size(design_realistic), units = "MB"),
  "Stress:", format(object.size(design_stress), units = "MB"),
  "\n"
)
