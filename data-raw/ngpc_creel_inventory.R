#!/usr/bin/env Rscript
# data-raw/ngpc_creel_inventory.R
#
# Incrementally updates the NGPC creel inventory and refits the
# ngpc_creel_params summary object used by tidycreel's simulator.
#
# Run:  Rscript data-raw/ngpc_creel_inventory.R
# Or:   source("data-raw/ngpc_creel_inventory.R")  # from repo root
#
# Outputs (local, NOT committed):
#   ~/.cache/tidycreel/ngpc_creel_inventory.rds  -- full per-creel table
#
# Outputs (committed to package):
#   data/ngpc_creel_params.rda  -- fitted distributional parameters

suppressPackageStartupMessages({
  library(httr2)
  library(dplyr)
})

BASE    <- "http://creelsurvey.unl.edu/api/AnalysisData"
CACHE   <- path.expand("~/.cache/tidycreel")
INV_RDS <- file.path(CACHE, "ngpc_creel_inventory.rds")

dir.create(CACHE, recursive = TRUE, showWarnings = FALSE)

# ── Raw fetchers ──────────────────────────────────────────────────────────────
fetch_raw <- function(endpoint, uid) {
  tryCatch({
    resp <- request(paste0(BASE, "/", endpoint)) |>
      req_url_query(Creel_UIDs = uid) |>
      req_timeout(30) |>
      req_perform()
    d <- resp_body_json(resp, simplifyVector = TRUE)
    if (is.data.frame(d) && nrow(d) > 0) d else NULL
  }, error = function(e) NULL)
}

# ── Load existing inventory (incremental update) ──────────────────────────────
existing <- if (file.exists(INV_RDS)) {
  readRDS(INV_RDS)
} else {
  NULL
}
done_uids <- if (!is.null(existing)) existing$creel_uid else character(0)

# ── Discover all complete creels ──────────────────────────────────────────────
cat("Fetching creel list...\n")
creels_raw <- tryCatch({
  resp <- request(paste0(BASE, "/GetAvailableCreels")) |>
    req_timeout(30) |>
    req_perform()
  resp_body_json(resp, simplifyVector = TRUE)
}, error = function(e) stop("Cannot reach NGPC API: ", conditionMessage(e)))

complete <- creels_raw[creels_raw$Creel_DataComplete == TRUE,
                       c("Creel_UID", "Creel_Title", "Creel_Active")]
names(complete) <- c("creel_uid", "title", "active")

new_rows <- complete[!complete$creel_uid %in% done_uids, ]
cat("Total complete:", nrow(complete), " | Already cached:", length(done_uids),
    " | To fetch:", nrow(new_rows), "\n\n")

if (nrow(new_rows) == 0) {
  cat("Inventory up to date.\n")
} else {
  # ── Classify waterbody from title ────────────────────────────────────────────
  urban_kw  <- c("Benson","Zorinsky","Fontenelle","Carter Lake","Walnut Creek",
                 "Standing Bear","Walnut Grove","Haworth","Towl","Wehrspann",
                 "White Hawk","Prairie Queen","Flanagan","Midlands","Shadow",
                 "Hitchcock","Kramar","Kramer","Offutt","Prairie View",
                 "Bennington","Lawerence Youngman","Lawrence Youngman",
                 "Schwer","Halleck","Yanney","Fort Kearney","Gracie Creek")
  large_kw  <- c("McConaughy","Harlan","Merritt","Calamus","Sherman",
                 "Pawnee","Branched Oak","Sutherland","Wanahoo")

  classify_wb <- function(t) {
    if (any(sapply(urban_kw,  function(k) grepl(k, t, ignore.case = TRUE)))) return("urban_small")
    if (any(sapply(large_kw,  function(k) grepl(k, t, ignore.case = TRUE)))) return("large_reservoir")
    "other"
  }

  results <- vector("list", nrow(new_rows))

  for (i in seq_len(nrow(new_rows))) {
    uid   <- new_rows$creel_uid[i]
    title <- new_rows$title[i]
    wtype <- classify_wb(title)

    cat(sprintf("[%d/%d] %s...", i, nrow(new_rows), title))

    catch_df <- fetch_raw("GetCatchData", uid)
    count_df <- fetch_raw("GetCountData", uid)

    # ── Catch / interview stats ───────────────────────────────────────────────
    int <- list(
      n_catch_rows = 0L, n_interviews = 0L,
      n_complete = 0L, n_incomplete = 0L,
      mean_effort_hr = NA_real_, sd_effort_hr = NA_real_, median_effort_hr = NA_real_,
      mean_party = NA_real_, sd_party = NA_real_,
      n_species = 0L, top_species_codes = NA_character_,
      total_catch_H = 0L, total_catch_R = 0L, pct_harvest = NA_real_,
      mean_catch_per_trip = NA_real_, cv_catch_per_trip = NA_real_,
      mean_start_hr = NA_real_, sd_start_hr = NA_real_,
      date_min = NA_character_, date_max = NA_character_, n_days = 0L
    )

    if (!is.null(catch_df)) {
      int$n_catch_rows <- nrow(catch_df)
      uids <- catch_df$ii_UID[!is.na(catch_df$ii_UID)]
      int$n_interviews <- length(unique(uids))

      if ("ii_TripType" %in% names(catch_df)) {
        uniq <- catch_df[!duplicated(catch_df$ii_UID) & !is.na(catch_df$ii_UID), "ii_TripType"]
        int$n_complete   <- sum(uniq == 1, na.rm = TRUE)
        int$n_incomplete <- sum(uniq == 2, na.rm = TRUE)
      }
      if (all(c("ii_TimeFishedHours","ii_TimeFishedMinutes","ii_UID") %in% names(catch_df))) {
        e_df <- catch_df[!duplicated(catch_df$ii_UID) & !is.na(catch_df$ii_UID), ]
        eff  <- as.numeric(e_df$ii_TimeFishedHours) + as.numeric(e_df$ii_TimeFishedMinutes) / 60
        eff  <- eff[!is.na(eff) & eff > 0]
        if (length(eff) > 0) {
          int$mean_effort_hr   <- round(mean(eff), 3)
          int$sd_effort_hr     <- round(sd(eff),   3)
          int$median_effort_hr <- round(median(eff), 3)
        }
      }
      if (all(c("ii_NumberAnglers","ii_UID") %in% names(catch_df))) {
        p_df  <- catch_df[!duplicated(catch_df$ii_UID) & !is.na(catch_df$ii_UID), ]
        party <- as.numeric(p_df$ii_NumberAnglers)
        party <- party[!is.na(party)]
        if (length(party) > 0) {
          int$mean_party <- round(mean(party), 2)
          int$sd_party   <- round(sd(party),   2)
        }
      }
      if ("ir_Species" %in% names(catch_df)) {
        sp_tab <- sort(table(catch_df$ir_Species[!is.na(catch_df$ir_Species)]), decreasing = TRUE)
        int$n_species <- length(sp_tab)
        if (length(sp_tab) > 0) {
          top5 <- head(sp_tab, 5)
          top5_pct <- round(top5 / sum(sp_tab) * 100, 0)
          int$top_species_codes <- paste(sprintf("%s(%d%%)", names(top5), top5_pct), collapse = ", ")
        }
      }
      if (all(c("CatchType","Num") %in% names(catch_df))) {
        h <- sum(as.numeric(catch_df$Num[catch_df$CatchType == "H" & !is.na(catch_df$CatchType)]), na.rm = TRUE)
        r <- sum(as.numeric(catch_df$Num[catch_df$CatchType == "R" & !is.na(catch_df$CatchType)]), na.rm = TRUE)
        int$total_catch_H <- h
        int$total_catch_R <- r
        if ((h + r) > 0) int$pct_harvest <- round(h / (h + r) * 100, 1)
      }
      if (all(c("ii_UID","Num") %in% names(catch_df))) {
        per_int <- tapply(as.numeric(catch_df$Num), catch_df$ii_UID, sum, na.rm = TRUE)
        per_int <- per_int[!is.na(names(per_int))]
        if (length(per_int) > 0) {
          int$mean_catch_per_trip <- round(mean(per_int), 3)
          int$cv_catch_per_trip   <- if (mean(per_int) > 0) round(sd(per_int) / mean(per_int), 3) else NA_real_
        }
      }
      if (all(c("ii_TimeStart","ii_UID") %in% names(catch_df))) {
        ts_df <- catch_df[!duplicated(catch_df$ii_UID) & !is.na(catch_df$ii_UID), ]
        ts    <- ts_df$ii_TimeStart[!is.na(ts_df$ii_TimeStart)]
        if (length(ts) > 0) {
          hr_str <- regmatches(ts, regexpr("T(\\d{2}):(\\d{2})", ts))
          if (length(hr_str) > 0) {
            hr <- as.numeric(substr(hr_str, 2, 3)) + as.numeric(substr(hr_str, 5, 6)) / 60
            int$mean_start_hr <- round(mean(hr, na.rm = TRUE), 2)
            int$sd_start_hr   <- round(sd(hr, na.rm = TRUE),   2)
          }
        }
      }
      if ("cd_Date" %in% names(catch_df)) {
        dates <- unique(as.Date(substr(catch_df$cd_Date, 1, 10)))
        dates <- dates[!is.na(dates)]
        int$n_days   <- length(dates)
        int$date_min <- as.character(min(dates))
        int$date_max <- as.character(max(dates))
      }
    }

    # ── Count stats ───────────────────────────────────────────────────────────
    cnt <- list(
      n_count_recs = 0L,
      mean_bank = NA_real_, sd_bank = NA_real_, max_bank = NA_real_,
      mean_boats = NA_real_, sd_boats = NA_real_, max_boats = NA_real_,
      mean_total_anglers = NA_real_, sd_total_anglers = NA_real_,
      pct_zero_count = NA_real_, has_weather = FALSE
    )

    if (!is.null(count_df)) {
      cnt$n_count_recs <- nrow(count_df)
      if ("c_BankAnglers" %in% names(count_df)) {
        b <- as.numeric(count_df$c_BankAnglers); b <- b[!is.na(b)]
        cnt$mean_bank <- round(mean(b), 2); cnt$sd_bank <- round(sd(b), 2); cnt$max_bank <- max(b)
      }
      if ("c_AnglerBoats" %in% names(count_df)) {
        ab <- as.numeric(count_df$c_AnglerBoats); ab <- ab[!is.na(ab)]
        cnt$mean_boats <- round(mean(ab), 2); cnt$sd_boats <- round(sd(ab), 2); cnt$max_boats <- max(ab)
      }
      if (all(c("c_BankAnglers","c_AnglerBoats") %in% names(count_df))) {
        tot <- as.numeric(count_df$c_BankAnglers) + as.numeric(count_df$c_AnglerBoats)
        tot <- tot[!is.na(tot)]
        cnt$mean_total_anglers <- round(mean(tot), 2)
        cnt$sd_total_anglers   <- round(sd(tot),   2)
        cnt$pct_zero_count     <- round(mean(tot == 0) * 100, 1)
      }
      if ("c_Precipitation" %in% names(count_df)) cnt$has_weather <- TRUE
    }

    results[[i]] <- c(
      list(creel_uid = uid, title = title, waterbody_type = wtype,
           fetched_date = as.character(Sys.Date())),
      int, cnt
    )

    cat(sprintf(" n_int=%d n_cnt=%d n_sp=%d\n",
                int$n_interviews, cnt$n_count_recs, int$n_species))
  }

  new_df <- do.call(rbind, lapply(Filter(Negate(is.null), results), function(x) {
    as.data.frame(lapply(x, function(v) if (length(v) == 0) NA else v[[1]]),
                  stringsAsFactors = FALSE)
  }))

  inv <- if (!is.null(existing)) rbind(existing, new_df) else new_df
  saveRDS(inv, INV_RDS)
  cat("\nInventory saved:", nrow(inv), "records →", INV_RDS, "\n")
}

# ── Re-fit summary parameters from full inventory ─────────────────────────────
cat("\nFitting ngpc_creel_params...\n")
inv <- readRDS(INV_RDS)

fit_params <- function(df) {
  df_int <- df[df$n_interviews > 0, ]
  df_cnt <- df[df$n_count_recs  > 0, ]

  list(
    n_creels      = nrow(df),
    n_with_interviews = nrow(df_int),
    n_counts_only = sum(df$n_interviews == 0),

    effort = list(
      mean   = round(mean(df_int$mean_effort_hr,   na.rm = TRUE), 3),
      sd     = round(mean(df_int$sd_effort_hr,     na.rm = TRUE), 3),
      median = round(mean(df_int$median_effort_hr, na.rm = TRUE), 3),
      # Gamma shape/rate via MOM: shape = mean^2/var, rate = mean/var
      gamma_shape = local({
        m <- mean(df_int$mean_effort_hr, na.rm = TRUE)
        v <- mean(df_int$sd_effort_hr^2, na.rm = TRUE)
        round(m^2 / v, 3)
      }),
      gamma_rate = local({
        m <- mean(df_int$mean_effort_hr, na.rm = TRUE)
        v <- mean(df_int$sd_effort_hr^2, na.rm = TRUE)
        round(m / v, 3)
      })
    ),

    party = list(
      mean = round(mean(df_int$mean_party, na.rm = TRUE), 3),
      sd   = round(mean(df_int$sd_party,   na.rm = TRUE), 3)
    ),

    catch_per_trip = list(
      mean = round(mean(df_int$mean_catch_per_trip, na.rm = TRUE), 3),
      cv   = round(mean(df_int$cv_catch_per_trip,   na.rm = TRUE), 3),
      # NB size = 1/((CV^2) - 1/mu) -- from mean + CV
      nb_size = local({
        mu <- mean(df_int$mean_catch_per_trip, na.rm = TRUE)
        cv <- mean(df_int$cv_catch_per_trip,   na.rm = TRUE)
        size_val <- 1 / (cv^2 - 1/mu)
        round(pmax(0.01, size_val), 3)
      })
    ),

    harvest = list(
      mean_pct = round(mean(df_int$pct_harvest, na.rm = TRUE), 1),
      sd_pct   = round(sd(df_int$pct_harvest,   na.rm = TRUE), 1)
    ),

    counts = list(
      mean_total_anglers = round(mean(df_cnt$mean_total_anglers, na.rm = TRUE), 2),
      sd_total_anglers   = round(mean(df_cnt$sd_total_anglers,   na.rm = TRUE), 2),
      mean_pct_zero      = round(mean(df_cnt$pct_zero_count,     na.rm = TRUE), 1)
    ),

    species = list(
      mean_richness = round(mean(df_int$n_species, na.rm = TRUE), 1)
    ),

    trip_start = list(
      mean_hr = round(mean(df_int$mean_start_hr, na.rm = TRUE), 2),
      sd_hr   = round(mean(df_int$sd_start_hr,   na.rm = TRUE), 2)
    ),

    survey_duration = list(
      mean_days   = round(mean(df_int$n_days, na.rm = TRUE), 0),
      median_days = round(median(df_int$n_days, na.rm = TRUE), 0)
    ),

    # pct_zero_catch is NOT from inventory (GetCatchData artifact -- all 0)
    # Must be derived from GetInterviewData cross-reference
    pct_zero_catch_source = "UNKNOWN: derive from GetInterviewData vs GetCatchData UID diff"
  )
}

ngpc_creel_params <- list(
  large_reservoir = fit_params(inv[inv$waterbody_type == "large_reservoir", ]),
  urban_small     = fit_params(inv[inv$waterbody_type == "urban_small",     ]),
  all             = fit_params(inv),
  metadata = list(
    n_creels_total = nrow(inv),
    inventory_date = as.character(Sys.Date()),
    api_base       = BASE,
    note = paste(
      "Parameters fitted from NGPC complete creels.",
      "pct_zero_catch excluded (GetCatchData artifact).",
      "Effort ~ Gamma(shape, rate); catch ~ NB(mu, size)."
    )
  )
)

usethis::use_data(ngpc_creel_params, overwrite = TRUE)
cat("ngpc_creel_params saved to data/ngpc_creel_params.rda\n")
cat("  large_reservoir: n =", ngpc_creel_params$large_reservoir$n_creels, "\n")
cat("  urban_small:     n =", ngpc_creel_params$urban_small$n_creels, "\n")
