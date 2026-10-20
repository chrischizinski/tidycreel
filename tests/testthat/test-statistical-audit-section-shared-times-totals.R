# GH #414, part 2: sections declared with `add_sections(shared_count_times =
# TRUE)` were counted at the same drawn times, so their within-day errors are
# correlated as well as their days (GH #403). `estimate_effort()` carried that
# covariance into its lake row; the catch, harvest and release totals did not
# read the declaration at all, and their lake SE was the same with it as
# without it.
#
# Pinned by hand from the raw occasions. Per stratum h, the within-day term
# added to the lake variance is
#   2 * R_Ah * R_Bh * (S_h / k) * sum_d cp_d / (n_h * (k - 1)),
# where cp_d is the cross-product of the two sections' counts about their day
# means at the shared occasions, k the counts per day, n_h the sampled days and
# S_h = n_h on sampled days or N_h on an expanded target (Rasmussen 1998).

stt_calendar <- function() {
  cal <- data.frame(date = as.Date("2024-06-01") + 0:13)
  cal$day_type <- ifelse(format(cal$date, "%u") %in% c("6", "7"), "weekend", "weekday")
  cal
}

# Two counts a day at the same two times in both sections; B's afternoon slope
# sets the sign of the within-day covariance.
stt_counts <- function(b_slope = c(15, 20, 25, 30)) {
  days <- as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09"))
  day_type <- c("weekday", "weekday", "weekend", "weekend")
  mk <- function(sec, am, pm) {
    data.frame(
      date = rep(days, each = 2), day_type = rep(day_type, each = 2),
      section = sec, count_time = rep(c(9, 15), 4), n = as.vector(rbind(am, pm))
    )
  }
  a_base <- c(10, 12, 20, 22)
  b_base <- c(30, 34, 50, 55)
  rbind(mk("A", a_base, a_base + c(6, 8, 10, 12)), mk("B", b_base, b_base + b_slope))
}

stt_interviews <- function() {
  days <- as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09"))
  day_type <- c("weekday", "weekday", "weekend", "weekend")
  iv <- data.frame(
    date = rep(days, each = 3, times = 2), day_type = rep(day_type, each = 3, times = 2),
    section = rep(c("A", "B"), each = 12),
    hours_fished = rep(c(2, 3.5, 1.5, 4, 2.5, 3, 5, 1, 2, 4.5, 3, 2.5), 2),
    catch_total = c(1, 2, 0, 3, 1, 1, 4, 0, 1, 2, 2, 1, 0, 1, 1, 0, 2, 0, 1, 0, 0, 1, 1, 0),
    trip_status = "complete"
  )
  iv$trip_duration <- iv$hours_fished
  iv$kept <- pmax(0, iv$catch_total - 1)
  iv$iid <- seq_len(nrow(iv))
  iv
}

stt_design <- function(shared, cnt = stt_counts(), with_times = TRUE) {
  d <- creel_design(stt_calendar(), date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_sections(d, data.frame(section = c("A", "B")), # nolint: object_usage_linter
    section_col = section, shared_count_times = shared # nolint: object_usage_linter
  )
  d <- if (with_times) {
    suppressWarnings(suppressMessages(add_counts(d, cnt, count_col = "n", count_time_col = count_time))) # nolint: object_usage_linter
  } else {
    suppressWarnings(suppressMessages(add_counts(d, cnt[cnt$count_time == 9, ], count_col = "n"))) # nolint: object_usage_linter
  }
  iv <- stt_interviews()
  d <- suppressWarnings(suppressMessages(add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = catch_total, harvest = kept, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  )))
  catch_df <- data.frame(
    iid = iv$iid, species = "walleye", count = iv$catch_total - iv$kept, catch_type = "released"
  )
  suppressWarnings(suppressMessages(add_catch( # nolint: object_usage_linter
    d, catch_df,
    catch_uid = iid, interview_uid = iid, species = species, count = count, # nolint: object_usage_linter
    catch_type = catch_type # nolint: object_usage_linter
  )))
}

# Per stratum: the within-day covariance of the two sections' daily effort.
stt_hand_within_cov <- function(cnt, target) {
  n_cal <- table(stt_calendar()$day_type)
  vapply(c("weekday", "weekend"), function(h) {
    s <- cnt[cnt$day_type == h, ]
    cp <- vapply(split(s, s$date), function(day) {
      a <- day$n[day$section == "A"][order(day$count_time[day$section == "A"])]
      b <- day$n[day$section == "B"][order(day$count_time[day$section == "B"])]
      sum((a - mean(a)) * (b - mean(b)))
    }, numeric(1))
    k <- 2
    n_h <- length(cp)
    s_h <- if (identical(target, "sampled_days")) n_h else n_cal[[h]]
    (s_h / k) * sum(cp) / (n_h * (k - 1))
  }, numeric(1))
}

# Ratio-of-means rate per section and stratum for one per-trip quantity.
stt_rates <- function(y) {
  iv <- stt_interviews()
  iv$y <- y
  vapply(c("weekday", "weekend"), function(h) {
    vapply(c("A", "B"), function(s) {
      v <- iv[iv$section == s & iv$day_type == h, ]
      sum(v$y) / sum(v$hours_fished)
    }, numeric(1))
  }, numeric(2))
}

stt_lake_var <- function(fn, d, target) {
  res <- suppressWarnings(suppressMessages(fn(d, target = target)))$estimates
  res$se[res$section == ".lake_total"]^2
}

test_that("#414: the hand covariance reproduces the effort lake row's pooled term", {
  # Guards the hand formula on the quantity #403 already pinned: the effort lake
  # row's within-day variance exceeds the sections' own by twice the covariance.
  cnt <- stt_counts()
  for (tg in c("sampled_days", "period_total")) {
    e <- suppressWarnings(suppressMessages(
      estimate_effort(stt_design(TRUE), target = tg) # nolint: object_usage_linter
    ))$estimates
    lake_w <- e$se_within[e$section == ".lake_total"]^2
    own_w <- sum(e$se_within[e$section %in% c("A", "B")]^2)
    expect_equal(lake_w - own_w, 2 * sum(stt_hand_within_cov(cnt, tg)), tolerance = 1e-8)
  }
})

test_that("#414: declared shared count times add the within-day covariance to the catch lake SE", {
  cnt <- stt_counts()
  r <- stt_rates(stt_interviews()$catch_total)
  for (tg in c("sampled_days", "period_total")) {
    off <- stt_lake_var(estimate_total_catch, stt_design(FALSE), tg) # nolint: object_usage_linter
    on <- stt_lake_var(estimate_total_catch, stt_design(TRUE), tg) # nolint: object_usage_linter
    expected <- 2 * sum(r["A", ] * r["B", ] * stt_hand_within_cov(cnt, tg))
    # The undeclared lake variance is the part-1 value (between-day covariance
    # only); the declaration adds exactly the within-day cross term.
    expect_equal(on - off, expected, tolerance = 1e-8)
    expect_gt(on, off)
  }
})

test_that("#414: harvest and release lake rows carry the same within-day term", {
  # Near-twins: each total weights the covariance by its own rate.
  cnt <- stt_counts()
  iv <- stt_interviews()
  cases <- list(
    list(fn = estimate_total_harvest, y = iv$kept), # nolint: object_usage_linter
    list(fn = estimate_total_release, y = iv$catch_total - iv$kept) # nolint: object_usage_linter
  )
  for (case in cases) {
    r <- stt_rates(case$y)
    off <- stt_lake_var(case$fn, stt_design(FALSE), "period_total")
    on <- stt_lake_var(case$fn, stt_design(TRUE), "period_total")
    expected <- 2 * sum(r["A", ] * r["B", ] * stt_hand_within_cov(cnt, "period_total"))
    expect_equal(on - off, expected, tolerance = 1e-8)
  }
})

test_that("#414: sections moving against each other within the day narrow the lake SE", {
  # One factor varies: the sign of B's afternoon slope. A fix that only inflated
  # the lake SE would pass the test above and fail this one.
  cnt <- stt_counts(b_slope = -c(15, 20, 25, 30))
  r <- stt_rates(stt_interviews()$catch_total)
  off <- stt_lake_var(estimate_total_catch, stt_design(FALSE, cnt), "period_total") # nolint: object_usage_linter
  on <- stt_lake_var(estimate_total_catch, stt_design(TRUE, cnt), "period_total") # nolint: object_usage_linter
  expected <- 2 * sum(r["A", ] * r["B", ] * stt_hand_within_cov(cnt, "period_total"))
  expect_lt(expected, 0)
  expect_equal(on - off, expected, tolerance = 1e-8)
})

test_that("#414: the share SE moves with the declaration", {
  # prop_of_lake_total's SE is built from each section's covariance with the
  # rest, so the within-day term has to reach it too, not only the lake row.
  res <- lapply(c(FALSE, TRUE), function(s) {
    suppressWarnings(suppressMessages(
      estimate_total_catch(stt_design(s), target = "period_total") # nolint: object_usage_linter
    ))$estimates
  })
  a_off <- res[[1]]$se_prop_of_lake_total[res[[1]]$section == "A"]
  a_on <- res[[2]]$se_prop_of_lake_total[res[[2]]$section == "A"]
  expect_false(isTRUE(all.equal(a_off, a_on)))
})

test_that("#414: a declaration the totals cannot honour is refused, as effort refuses it", {
  # One count a day, no occasions kept: the cross-products are unrecoverable.
  # Before the fix the totals accepted this silently and assumed independence.
  d <- stt_design(TRUE, with_times = FALSE)
  expect_error(
    suppressWarnings(estimate_total_catch(d, target = "period_total")), # nolint: object_usage_linter
    class = "creel_error_shared_times_unpooled"
  )
})

# Review findings on the first version (Codex). It took the covariance as half
# the pooled within-day variance less the sections' own, and the two divide by
# different numbers of sampled days when the sections' days differ.

test_that("#414: sections that share no day add no within-day covariance", {
  # B counted on other days of the same strata. The declaration changed the
  # lake variance here (3634.2 -> 3540.0) although no occasion was shared.
  cnt <- stt_counts()
  moved <- c(
    "2024-06-03" = "2024-06-05", "2024-06-04" = "2024-06-06",
    "2024-06-08" = "2024-06-01", "2024-06-09" = "2024-06-02"
  )
  b <- cnt$section == "B"
  cnt$date[b] <- as.Date(moved[as.character(cnt$date[b])])
  off <- stt_lake_var(estimate_total_catch, stt_design(FALSE, cnt), "period_total") # nolint: object_usage_linter
  on <- stt_lake_var(estimate_total_catch, stt_design(TRUE, cnt), "period_total") # nolint: object_usage_linter
  expect_equal(on, off, tolerance = 1e-10)
})

test_that("#414: unpaired occasions add nothing and say so", {
  # B counted an hour after A: same days, different occasions. The declaration
  # cannot be honoured on those days, and the user is told rather than left to
  # assume it was.
  cnt <- stt_counts()
  cnt$count_time[cnt$section == "B"] <- cnt$count_time[cnt$section == "B"] + 1
  d <- stt_design(TRUE, cnt)
  expect_message(
    suppressWarnings(estimate_total_catch(d, target = "period_total")), # nolint: object_usage_linter
    class = "creel_message_within_day_independent"
  )
  off <- stt_lake_var(estimate_total_catch, stt_design(FALSE, cnt), "period_total") # nolint: object_usage_linter
  expect_equal(stt_lake_var(estimate_total_catch, d, "period_total"), off, tolerance = 1e-10) # nolint: object_usage_linter
})

test_that("#414: partially overlapping days cannot push the covariance past the variances", {
  # Two sampled days each, one shared, ten population days. Scaling the shared
  # cross-product by the overlap alone gave a covariance of 1000 against
  # section variances of 500 each, an invalid matrix and an NA lake SE (Codex,
  # second review). The overlapping-samples form gives
  # rho * sqrt(500 * 500) * 1 / sqrt(2 * 2) = 250.
  cal <- data.frame(date = as.Date("2024-06-01") + 0:9, day_type = "all")
  mk <- function(sec, day, am, pm) {
    data.frame(
      date = as.Date("2024-06-01") + day, day_type = "all", section = sec,
      count_time = c(9, 15), n = c(am, pm)
    )
  }
  cnt <- rbind(mk("A", 0, 10, 30), mk("A", 1, 20, 20), mk("B", 0, 10, 30), mk("B", 2, 20, 20))
  d <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_sections(d, data.frame(section = c("A", "B")), # nolint: object_usage_linter
    section_col = section, shared_count_times = TRUE # nolint: object_usage_linter
  )
  d <- suppressWarnings(suppressMessages(add_counts(d, cnt, count_col = "n", count_time_col = count_time))) # nolint: object_usage_linter
  e <- suppressWarnings(suppressMessages(estimate_effort(d, target = "period_total")))$estimates # nolint: object_usage_linter
  own <- e$se_within[e$section %in% c("A", "B")]^2
  expect_equal(own, c(500, 500))
  cells <- lapply(c(A = "A", B = "B"), function(s) {
    list(strata = data.frame(day_type = "all"), effort = e$estimate[e$section == s], rate = 1)
  })
  cross <- section_effort_cross_covariance(d, "period_total", cells) # nolint: object_usage_linter
  expect_equal(cross["A", "B"], 250)
  expect_lte(abs(cross["A", "B"]), sqrt(prod(own)))
})
