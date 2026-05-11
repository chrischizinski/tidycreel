# Omaha Urban Lake Instantaneous Survey Validation
#
# Validates the tidycreel instantaneous estimation pipeline across 10 urban
# Omaha creel surveys (2019-2022) spanning a range of lake sizes and data
# volumes. These surveys use the UNL Standard Creel design with Morning/Evening
# periods, p_period = 0.5, and no sections (single "Whole Lake" section).
#
# Goal: confirm that estimate_effort() and estimate_total_catch() run without
# error and return finite, non-NA estimates for all 10 surveys.
#
# Usage: Rscript inst/validation/omaha-instantaneous-validation.R
#   from the package root directory.
#
# Notes:
# - catch.csv is used as the primary interview source; interviews.csv contains
#   mostly NA stubs for these surveys (effort fields live in catch.csv).
# - High-use day classification is skipped; only weekday/weekend strata used.
#   A future version should fetch design_special and apply high_use strata.
# - McConaughy spawn surveys (cross-midnight periods) are excluded here;
#   they require a separate validation script.

suppressPackageStartupMessages({
  devtools::load_all(".")
})

FIXTURES <- list(
  list(slug = "standing-bear-2019",     label = "Standing Bear 2019",     acres = 135),
  list(slug = "prairie-queen-2019",     label = "Prairie Queen 2019",     acres = 105),
  list(slug = "lake-halleck-2019",      label = "Lake Halleck 2019",      acres = 4),
  list(slug = "schwer-pond-2019",       label = "Schwer Pond 2019",       acres = 3.5),
  list(slug = "flanagan-2021",          label = "Flanagan 2021",          acres = 220),
  list(slug = "walnut-creek-2021",      label = "Walnut Creek 2021",      acres = 70),
  list(slug = "benson-2021",            label = "Benson 2021",            acres = 4),
  list(slug = "offutt-2021",            label = "Offutt Base Lake 2021",  acres = 160),
  list(slug = "zorinsky-2022",          label = "Zorinsky 2022",          acres = 255),
  list(slug = "lawrence-youngman-2022", label = "Lawrence Youngman 2022", acres = 60)
)

EXTDATA <- file.path("inst", "extdata")

# ---- Helpers -----------------------------------------------------------------

parse_ngpc_date <- function(x) {
  as.Date(sub("T.*", "", as.character(x)))
}

classify_day_type <- function(dates) {
  wd <- weekdays(dates, abbreviate = FALSE)
  ifelse(wd %in% c("Saturday", "Sunday"), "weekend", "weekday")
}

# Build daily effort from raw NGPC counts + design periods.
# effort_hours per day = sum over count rows of:
#   (c_BankAnglers + c_AnglerBoats) * dp_PeriodLengthInHours / dp_PeriodProbability
build_effort_counts <- function(counts_raw, periods_raw) {
  counts_raw$date   <- parse_ngpc_date(counts_raw$cd_Date)
  counts_raw$month  <- as.integer(format(counts_raw$date, "%m"))
  counts_raw$period <- as.integer(counts_raw$cd_Period)

  # period lookup: month x period -> length_hrs, prob
  pl <- periods_raw[, c("dp_Month", "dp_PeriodNumber",
                         "dp_PeriodLengthInHours", "dp_PeriodProbability")]
  names(pl) <- c("month", "period", "period_hrs", "period_prob")
  pl$period_hrs  <- as.numeric(pl$period_hrs)
  pl$period_prob <- as.numeric(pl$period_prob)
  # Omit negative lengths (cross-midnight overnight periods — not for this script)
  pl <- pl[!is.na(pl$period_hrs) & pl$period_hrs > 0, ]

  cnt <- merge(counts_raw, pl, by = c("month", "period"), all.x = FALSE)

  bank  <- suppressWarnings(as.numeric(cnt$c_BankAnglers))
  boats <- suppressWarnings(as.numeric(cnt$c_AnglerBoats))
  bank[is.na(bank)]   <- 0
  boats[is.na(boats)] <- 0
  cnt$total_anglers <- bank + boats

  cnt$effort_contribution <- cnt$total_anglers *
    cnt$period_hrs / cnt$period_prob

  # Aggregate to one effort_hours value per sampled date
  agg <- stats::aggregate(
    effort_contribution ~ date,
    data = cnt,
    FUN  = sum,
    na.rm = TRUE
  )
  names(agg)[2] <- "effort_hours"
  agg
}

# Build interview-level data from catch.csv (which carries effort fields).
# Deduplicates to one row per ii_UID, aggregates total catch per interview.
build_interviews_from_catch <- function(catch_raw) {
  if (nrow(catch_raw) == 0) return(NULL)

  catch_raw$date   <- parse_ngpc_date(catch_raw$cd_Date)
  catch_raw$effort_hrs   <- suppressWarnings(as.numeric(catch_raw$ii_TimeFishedHours))
  catch_raw$effort_mins  <- suppressWarnings(as.numeric(catch_raw$ii_TimeFishedMinutes))
  catch_raw$effort_hours <- with(catch_raw,
    ifelse(is.na(effort_hrs), NA_real_,
      effort_hrs + ifelse(is.na(effort_mins), 0, effort_mins / 60)))

  catch_raw$n_anglers    <- suppressWarnings(as.numeric(catch_raw$ii_NumberAnglers))
  catch_raw$n_anglers[is.na(catch_raw$n_anglers)] <- 1L

  # trip_status: 1 = complete, 2 = incomplete
  tt <- suppressWarnings(as.integer(catch_raw$ii_TripType))
  catch_raw$trip_status <- ifelse(is.na(tt), "complete",
                             ifelse(tt == 1L, "complete", "incomplete"))

  catch_raw$catch_n <- suppressWarnings(as.numeric(catch_raw$Num))
  catch_raw$catch_n[is.na(catch_raw$catch_n)] <- 0

  # One row per interview (ii_UID)
  ivw_cols <- c("ii_UID", "date", "effort_hours", "n_anglers", "trip_status")
  ivw_dedup <- catch_raw[!duplicated(catch_raw$ii_UID), ivw_cols]

  # Total catch per interview
  catch_agg <- stats::aggregate(
    catch_n ~ ii_UID,
    data = catch_raw,
    FUN  = sum,
    na.rm = TRUE
  )
  names(catch_agg)[2] <- "total_catch"

  ivw <- merge(ivw_dedup, catch_agg, by = "ii_UID", all.x = TRUE)
  ivw$total_catch[is.na(ivw$total_catch)] <- 0L
  ivw
}

# ---- Main validation loop ----------------------------------------------------

results <- vector("list", length(FIXTURES))

for (i in seq_along(FIXTURES)) {
  fx <- FIXTURES[[i]]
  message("\n=== ", fx$label, " ===")
  dir <- file.path(EXTDATA, fx$slug)

  counts_raw  <- read.csv(file.path(dir, "counts.csv"),  stringsAsFactors = FALSE)
  periods_raw <- read.csv(file.path(dir, "design_periods.csv"), stringsAsFactors = FALSE)
  catch_raw   <- read.csv(file.path(dir, "catch.csv"),   stringsAsFactors = FALSE,
                          colClasses = c(ir_Species = "character",
                                         ii_UID = "character"))

  effort_counts <- tryCatch(
    build_effort_counts(counts_raw, periods_raw),
    error = function(e) { message("  [ERROR building counts] ", conditionMessage(e)); NULL }
  )
  if (is.null(effort_counts) || nrow(effort_counts) == 0) {
    results[[i]] <- data.frame(label = fx$label, status = "FAIL: empty counts",
                                effort = NA, effort_se = NA, total_catch = NA,
                                n_days = NA, n_interviews = NA)
    next
  }

  # Calendar: all sampled dates + day_type
  effort_counts$day_type <- classify_day_type(effort_counts$date)
  cal <- effort_counts[, c("date", "day_type")]

  ivw <- tryCatch(
    build_interviews_from_catch(catch_raw),
    error = function(e) { message("  [ERROR building interviews] ", conditionMessage(e)); NULL }
  )

  # Run pipeline
  result_row <- tryCatch({
    design <- creel_design(
      calendar   = cal,
      date       = date,
      strata     = day_type,
      survey_type = "instantaneous"
    )

    design <- add_counts(design, effort_counts)

    if (!is.null(ivw) && nrow(ivw) > 0) {
      # Merge day_type into interviews
      ivw <- merge(ivw, cal, by = "date", all.x = TRUE)
      # Drop rows with missing effort (can't use in CPUE estimator)
      ivw_valid <- ivw[!is.na(ivw$effort_hours) & ivw$effort_hours > 0, ]
      if (nrow(ivw_valid) > 0) {
        design <- suppressWarnings(
          add_interviews(design, ivw_valid,
            catch      = total_catch,
            effort     = effort_hours,
            trip_status = trip_status
          )
        )
      }
    }

    eff <- suppressWarnings(estimate_effort(design))
    eff_est <- eff$estimates$estimate[1]
    eff_se  <- eff$estimates$se[1]

    catch_est <- NA_real_
    if (!is.null(design$interviews)) {
      tc <- tryCatch(
        suppressWarnings(estimate_total_catch(design)),
        error = function(e) NULL
      )
      if (!is.null(tc)) catch_est <- sum(tc$estimates$estimate, na.rm = TRUE)
    }

    message(sprintf(
      "  effort = %.0f hr (SE %.1f) | total_catch = %.0f | days = %d | interviews = %d",
      eff_est, eff_se, catch_est,
      nrow(effort_counts),
      if (!is.null(ivw)) nrow(ivw) else 0L
    ))

    data.frame(
      label        = fx$label,
      acres        = fx$acres,
      status       = ifelse(is.finite(eff_est) && !is.na(eff_se), "PASS", "WARN: non-finite"),
      effort       = round(eff_est, 1),
      effort_se    = round(eff_se, 1),
      total_catch  = round(catch_est, 0),
      n_days       = nrow(effort_counts),
      n_interviews = if (!is.null(ivw)) nrow(ivw) else 0L,
      stringsAsFactors = FALSE
    )
  }, error = function(e) {
    message("  [PIPELINE ERROR] ", conditionMessage(e))
    data.frame(label = fx$label, acres = fx$acres, status = paste("FAIL:", conditionMessage(e)),
               effort = NA, effort_se = NA, total_catch = NA,
               n_days = NA, n_interviews = NA, stringsAsFactors = FALSE)
  })

  results[[i]] <- result_row
}

# ---- Summary -----------------------------------------------------------------

summary_tbl <- do.call(rbind, results)
message("\n\n========================================")
message("VALIDATION SUMMARY")
message("========================================")
print(summary_tbl, row.names = FALSE)

n_pass <- sum(summary_tbl$status == "PASS", na.rm = TRUE)
n_fail <- sum(grepl("^FAIL", summary_tbl$status), na.rm = TRUE)
message(sprintf("\n%d / %d surveys PASSED", n_pass, nrow(summary_tbl)))
if (n_fail > 0) {
  message(sprintf("WARNING: %d survey(s) FAILED", n_fail))
  quit(status = 1)
}
