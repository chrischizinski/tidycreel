# Calamus 2016 Bus-Route Survey Validation
# Validates the full tidycreel bus-route estimation pipeline against
# pre-computed reference outputs derived from Calamus 2016 fixture data.
#
# Usage: Rscript inst/validation/calamus-2016-validation.R
#   from the package root directory.
#
# **MUST be run from the package root directory (where DESCRIPTION lives).**
# Use Rscript from that directory; do not source() from subdirectories.
#
# Offline: reads only static CSV files in inst/extdata/calamus-2016/
# Fully self-contained — no external service calls are made.

if (!file.exists("DESCRIPTION")) {
  stop("This script must be run from the package root (the directory containing DESCRIPTION). ",
       "Set your working directory there before running.")
}

suppressPackageStartupMessages({
  devtools::load_all(".")
})

# Working directory is package root (verified by DESCRIPTION guard above)
fixture_dir <- file.path("inst", "extdata", "calamus-2016")

# ---- 1. Load fixture data ----
message("Loading Calamus 2016 fixture data...")
ivw <- read.csv(
  file.path(fixture_dir, "interviews.csv"),
  stringsAsFactors = FALSE
)
ivw$date <- as.Date(ivw$date)

cnt <- read.csv(
  file.path(fixture_dir, "counts.csv"),
  stringsAsFactors = FALSE
)
cnt$date <- as.Date(cnt$date)

ref <- read.csv(
  file.path(fixture_dir, "reference-outputs.csv"),
  stringsAsFactors = FALSE
)

# ---- 2. Log data characteristics (proves edge cases loaded) ----
n_uids   <- length(unique(ivw$interview_uid))
n_rows   <- nrow(ivw)
dup_uids <- sum(table(ivw$interview_uid) > 1)
message(sprintf(
  "  interviews: %d rows, %d unique UIDs, %d duplicated UIDs",
  n_rows, n_uids, dup_uids
))

ct_raw <- read.csv(
  file.path(fixture_dir, "catch.csv"),
  colClasses = c(species = "character"),
  stringsAsFactors = FALSE
)
catch_types <- sort(unique(ct_raw$catch_type))
message(sprintf("  catch_type values: %s", paste(catch_types, collapse = ", ")))
message(sprintf(
  "  species codes: %s",
  paste(sort(unique(ct_raw$species)), collapse = ", ")
))
if (!"caught" %in% ct_raw$catch_type) {
  stop("catch.csv missing 'caught' catch_type -- fixture data is corrupted")
}
if (!all(c("86", "862") %in% ct_raw$species)) {
  stop("catch.csv missing species 86 or 862 -- fixture data is corrupted")
}

# ---- 3. Derive harvest_count per interview from catch.csv ----
# Bus-route harvest estimator (estimate_harvest_rate -> estimate_harvest_br)
# implements Jones & Pollock (2012) Eq. 19.5: H_hat = sum(h_i / pi_i).
# The harvest_col must be present in interviews before add_interviews() is called.
# Aggregate: sum(catch_count) per interview_uid WHERE catch_type == "harvested".
harvested_rows <- ct_raw[ct_raw$catch_type == "harvested", ]
harvest_by_uid <- stats::aggregate(
  catch_count ~ interview_uid,
  data = harvested_rows,
  FUN = sum
)
names(harvest_by_uid)[2] <- "harvest_count"

# Left join: all interviews get a harvest_count (0 if no harvested catch rows)
ivw <- merge(ivw, harvest_by_uid, by = "interview_uid", all.x = TRUE)
ivw$harvest_count[is.na(ivw$harvest_count)] <- 0L
message(sprintf(
  "  harvest_count derived: total = %d across %d interview rows",
  sum(ivw$harvest_count), nrow(ivw)
))

# ---- 4. Define sampling frame ----
# Matches the frame used to generate reference-outputs.csv in Plan 01.
sf <- data.frame(
  site     = c("North", "South", "Pier"),
  circuit  = "circuit1",
  p_site   = c(0.40, 0.35, 0.25),
  p_period = 0.50,
  stringsAsFactors = FALSE
)

# ---- 5. Define calendar ----
# Covers all dates in interviews.csv (2016-06-06 to 2016-06-12).
# 2016-06-06 (Mon) through 2016-06-10 (Fri) are weekdays.
# 2016-06-11 (Sat) and 2016-06-12 (Sun) are weekend.
cal <- data.frame(
  date     = as.Date(c(
    "2016-06-06", "2016-06-07", "2016-06-08",
    "2016-06-09", "2016-06-10", "2016-06-11", "2016-06-12"
  )),
  day_type = c(
    "weekday", "weekday", "weekday",
    "weekday", "weekday", "weekend", "weekend"
  ),
  stringsAsFactors = FALSE
)

# ---- 6. Build design and run pipeline ----
message("Building bus-route creel design...")
design <- creel_design(
  calendar       = cal,
  date           = date,
  strata         = day_type,
  survey_type    = "bus_route",
  sampling_frame = sf,
  site           = site,
  circuit        = circuit,
  p_site         = p_site,
  p_period       = p_period
)

message("Adding counts...")
# Merge day_type from calendar into counts — add_counts requires strata columns
cnt <- merge(cnt, cal[c("date", "day_type")], by = "date", all.x = TRUE)
design <- add_counts(design, cnt)

message("Adding interviews (duplicated UIDs preserved -- bus-route design)...")
design <- add_interviews(
  design, ivw,
  catch         = catch_count,
  harvest       = harvest_count,
  effort        = effort_hours,
  trip_status   = trip_status,
  n_counted     = n_counted,
  n_interviewed = n_interviewed
)

# ---- 7. Run estimators ----
# Note on harvest: for bus_route, estimate_harvest_rate() dispatches to
# estimate_harvest_br() (Jones & Pollock 2012, Eq. 19.5), which computes the
# Horvitz-Thompson TOTAL harvest count (not a per-unit rate). The function name
# is a domain-level convention; the returned estimate IS the total harvest.
# estimate_total_harvest() is not used here because it computes
# effort x HPUE via the delta method and produces a different quantity.
message("Running estimators...")
eff     <- suppressWarnings(estimate_effort(design))
cat_est <- suppressWarnings(estimate_total_catch(design))
harv    <- suppressWarnings(estimate_harvest_rate(design))

# ---- 8. Compare against reference outputs ----
computed <- list(
  effort_total  = eff$estimates$estimate,
  catch_total   = cat_est$estimates$estimate,
  harvest_total = harv$estimates$estimate
)

REL_TOL <- 0.001  # 0.1% relative tolerance

results <- data.frame(
  estimand  = ref$estimand,
  reference = ref$estimate,
  computed  = vapply(
    ref$estimand,
    function(nm) computed[[nm]],
    numeric(1L)
  ),
  stringsAsFactors = FALSE
)
results$rel_error <- abs(results$computed - results$reference) / abs(results$reference)
results$pass      <- results$rel_error <= REL_TOL

# ---- 9. Print per-estimand results ----
message("\n--- Calamus 2016 Validation Results ---")
for (i in seq_len(nrow(results))) {
  status <- if (results$pass[i]) "PASS" else "FAIL"
  message(sprintf(
    "  [%s] %s: reference=%.4f  computed=%.4f  rel_error=%.6f",
    status,
    results$estimand[i],
    results$reference[i],
    results$computed[i],
    results$rel_error[i]
  ))
}

# ---- 10. Overall result and exit code ----
all_pass <- all(results$pass)
overall  <- if (all_pass) "PASS" else "FAIL"
message(sprintf(
  "\n=== Overall: %s (%d/%d estimands within %.1f%% tolerance) ===",
  overall, sum(results$pass), nrow(results), REL_TOL * 100
))

if (!all_pass) {
  failed <- results$estimand[!results$pass]
  message(sprintf("Failed estimands: %s", paste(failed, collapse = ", ")))
  quit(status = 1L)
}
invisible(results)
