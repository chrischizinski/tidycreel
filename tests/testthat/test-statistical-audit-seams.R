# Statistical-audit seed tests. These demonstrate the three test patterns the
# audit framework relies on (metamorphic invariants, independent reference
# calculations, known-vs-unknown distinctions) — they are exemplars for future
# audit tests, not a complete audit. See README-statistical-audit.md.

test_that("metamorphic: estimates are invariant to interview row order", {
  # A design-based estimate is a function of the data, not of row position.
  # Sensitivity to row order would mean some quantity (a weight, a stratum,
  # a first-row unit guess) is being picked up positionally — the bug class
  # behind prior finding #105 (add_counts selected its column positionally).
  design <- build_br_design_for_tests(3L, 6L, 12L, seed = 42L)

  baseline_effort <- suppressWarnings(estimate_effort(design))
  baseline_catch <- suppressWarnings(estimate_total_catch(design))

  shuffled <- design
  shuffled$interviews <- sa_shuffle_rows(shuffled$interviews, seed = 7L)

  sa_expect_same_estimates(baseline_effort, suppressWarnings(estimate_effort(shuffled)))
  sa_expect_same_estimates(baseline_catch, suppressWarnings(estimate_total_catch(shuffled)))
})

test_that("metamorphic: estimates are invariant to an irrelevant column", {
  # Adding a column no estimator consumes must change nothing. A violation
  # means column selection somewhere is positional or greedy rather than
  # by name — the same seam class as finding #105.
  design <- build_br_design_for_tests(3L, 6L, 12L, seed = 42L)

  baseline_effort <- suppressWarnings(estimate_effort(design))
  baseline_catch <- suppressWarnings(estimate_total_catch(design))

  decorated <- design
  decorated$interviews$irrelevant_note <- seq_len(nrow(decorated$interviews))

  sa_expect_same_estimates(baseline_effort, suppressWarnings(estimate_effort(decorated)))
  sa_expect_same_estimates(baseline_catch, suppressWarnings(estimate_total_catch(decorated)))
})

test_that("reference calculation: mean_party_size matches base-R arithmetic", {
  # Method 2 of the audit protocol: the statistical definition computed in
  # plain base R, sharing no tidycreel helper with the implementation. The
  # estimand is the mean party size among boat parties; its SE is sd/sqrt(n)
  # because parties are treated as an iid sample of the party-size
  # distribution.
  interviews <- tibble::tibble(
    n_anglers = c(2, 3, 4, 9, 9),
    angler_type = c("boat", "boat", "boat", "bank", "bank")
  )

  out <- mean_party_size(interviews, n_anglers, angler_type = angler_type)

  boat_sizes <- c(2, 3, 4)
  expect_equal(as.numeric(out), sum(boat_sizes) / 3)
  expect_equal(attr(out, "se"), stats::sd(boat_sizes) / sqrt(3))
})

test_that("distinction: a single-party party size has unknown SE, not zero SE", {
  # 0 and NA are different statements. One interviewed party yields a mean
  # with no measurable spread: the SE is unknown (NA), not zero. A zero here
  # would enter the effort variance as "multiplier known exactly", which is
  # indistinguishable from the uncertainty never having been propagated —
  # the exact defect class fixed in #121.
  interviews <- tibble::tibble(
    n_anglers = c(3, 5),
    angler_type = c("boat", "bank")
  )

  out <- mean_party_size(interviews, n_anglers, angler_type = angler_type)

  expect_equal(as.numeric(out), 3)
  expect_identical(attr(out, "se"), NA_real_)
})

test_that("contract: every design's tidy() carries an `estimate` column (#199)", {
  # tidy() is the documented accessor, and its contract is a uniform shape
  # across designs -- that is what lets a report, a book chapter or a rollup
  # loop over survey types. Ice renamed `estimate` to carry its effort type,
  # so generic code reading tidy(x)$estimate got NULL, and sum(NULL) is 0: a
  # season total came back as zero rather than as an error. The same shape as
  # the v5.0.0 book-render defect.
  #
  # A design-specific name is welcome as an *additional* column. It may not
  # replace the one every other design returns.
  skip_if_not_installed("lme4")
  designs <- list(
    instantaneous = local({
      cal <- build_property_calendar(8L)
      d <- creel_design(cal, date = date, strata = day_type)
      cnt <- data.frame(
        date = sort(unique(cal$date))[1:4],
        day_type = "weekday",
        anglers = c(10, 20, 30, 40),
        stringsAsFactors = FALSE
      )
      suppressWarnings(suppressMessages(
        add_counts(d, cnt, count_col = anglers, psu = "date")
      ))
    }),
    bus_route = build_br_design_for_tests(4L, 8L, 40L, seed = 11L),
    ice = build_ice_design(8L, 40L, seed = 5L),
    br_degenerate = build_br_degenerate_design(8L, 40L, seed = 7L)
  )

  for (nm in names(designs)) {
    out <- tidy(suppressWarnings(estimate_effort(designs[[nm]])))
    expect_true("estimate" %in% names(out), info = nm)
    expect_true(is.numeric(out$estimate), info = nm)
    expect_true(all(c("se", "ci_lower", "ci_upper", "n") %in% names(out)), info = nm)
  }
})

test_that("contract: the ice effort-type column is an alias, not a replacement (#199)", {
  # Both names, agreeing. The descriptive name is worth keeping -- it records
  # which effort type was estimated -- but not at the cost of the shared one.
  ice <- build_ice_design(8L, 40L, seed = 5L)
  out <- tidy(suppressWarnings(estimate_effort(ice)))

  expect_true(all(c("estimate", "total_effort_hr_on_ice") %in% names(out)))
  expect_equal(out$estimate, out$total_effort_hr_on_ice)

  # And the read that used to return NULL now returns the total.
  expect_equal(sum(out$estimate), out$estimate)
  expect_gt(sum(out$estimate), 0)
})

test_that("metamorphic: partitioning interviews within a site visit leaves the SE alone (#198)", {
  # In a bus-route design the selected unit is the site visit -- a site within a
  # circuit, on one date -- and interviews are nested inside it. Several anglers
  # contacted during one visit are not independent draws from the frame, so
  # recording the same anglers as more rows adds bookkeeping, not information.
  #
  # Taking the variance over interview rows made the reported precision a
  # function of interview-recording convention: the split below left the
  # Horvitz-Thompson estimate exactly unchanged and shrank the SE by 1/sqrt(2),
  # so an agency recording one row per angler looked more precise than one
  # recording one row per party for the same survey.
  #
  # The estimate has always been invariant here. It is the SE that is under test.
  split_within_visit <- function(design) {
    iv <- design$interviews
    a <- iv
    b <- iv
    for (col in c("hours_fished", ".angler_effort", "catch_total", "catch_kept")) {
      if (col %in% names(iv)) {
        a[[col]] <- iv[[col]] / 2
        b[[col]] <- iv[[col]] / 2
      }
    }
    if ("interview_id" %in% names(b)) {
      b$interview_id <- paste0(b$interview_id, "b")
    }
    out <- design
    out$interviews <- rbind(a, b)
    out
  }

  designs <- list(
    bus_route = build_br_design_for_tests(4L, 8L, 40L, seed = 11L),
    ice = build_ice_design(8L, 40L, seed = 5L),
    br_degenerate = build_br_degenerate_design(8L, 40L, seed = 7L)
  )

  for (nm in names(designs)) {
    d <- designs[[nm]]
    base <- tidy(suppressWarnings(estimate_effort(d)))
    split <- tidy(suppressWarnings(estimate_effort(split_within_visit(d))))

    expect_equal(base$estimate, split$estimate, info = nm)
    expect_equal(base$se, split$se, info = nm)
    # A zero SE would satisfy the equality above without saying anything.
    expect_gt(base$se, 0)
  }
})

test_that("metamorphic: sub-counts and their per-day means give the same effort (#193)", {
  # Two counts on one day are two looks at that day, not two sampled days. A
  # design built from am/pm sub-counts must therefore agree with one built from
  # the daily means those sub-counts average to — the point estimate is a
  # property of the survey, not of how finely the counts were recorded.
  #
  # It did not agree. Without count_time_col the repeated rows survived into
  # design$counts and were summed by the expansion, returning exactly k times
  # the true total for k counts per day. The sub-count design is now the only
  # accepted form of this input, and the equality below is what says the
  # aggregation it performs is the right one.
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:9,
    day_type = "weekday",
    stringsAsFactors = FALSE
  )
  sampled <- as.Date("2024-06-03") + 0:3
  day_means <- c(10, 20, 30, 40)

  sub_counts <- data.frame(
    date = rep(sampled, each = 2L),
    day_type = "weekday",
    count_time = rep(c("am", "pm"), 4L),
    angler_count = as.vector(rbind(day_means - 3, day_means + 3)),
    stringsAsFactors = FALSE
  )
  mean_counts <- data.frame(
    date = sampled,
    day_type = "weekday",
    angler_count = day_means,
    stringsAsFactors = FALSE
  )

  base_design <- function() {
    creel_design(cal, date = date, strata = day_type)
  }
  from_subs <- add_counts(
    base_design(), sub_counts,
    count_col = "angler_count", count_time_col = count_time
  )
  from_means <- add_counts(base_design(), mean_counts, count_col = "angler_count")

  eff_subs <- suppressWarnings(estimate_effort(from_subs, target = "sampled_days"))
  eff_means <- suppressWarnings(estimate_effort(from_means, target = "sampled_days"))

  # Independent reference: the estimand is the sum of the four daily means,
  # computed here in base R rather than through any tidycreel helper.
  expect_equal(tidy(eff_subs)$estimate, sum(day_means))
  expect_equal(tidy(eff_means)$estimate, sum(day_means))

  # The sub-count design knows something the pre-averaged one cannot: the
  # spread within each day. That must show up as a within-day component, and
  # as a strictly larger total SE — not as a zero that looks propagated.
  expect_gt(tidy(eff_subs)$se_within, 0)
  expect_gt(tidy(eff_subs)$se, tidy(eff_means)$se)

  # The equality has to survive to a management-relevant number, not stop at
  # effort: a doubled effort propagated undiminished into total catch.
  iv <- data.frame(
    interview_uid = as.character(1:8),
    date = rep(sampled, each = 2L),
    day_type = "weekday",
    effort = 2,
    catch_count = 4,
    trip_status = "complete",
    stringsAsFactors = FALSE
  )
  add_iv <- function(d) {
    suppressWarnings(add_interviews(
      d, iv,
      catch = catch_count, effort = effort, trip_status = trip_status
    ))
  }
  catch_subs <- suppressWarnings(estimate_total_catch(add_iv(from_subs)))
  catch_means <- suppressWarnings(estimate_total_catch(add_iv(from_means)))
  expect_equal(tidy(catch_subs)$estimate, tidy(catch_means)$estimate)
})

test_that("distinction: repeat counts with no count time are refused, not guessed (#193)", {
  # The information needed is not in the table. Two rows on one unit are either
  # two looks at it (average) or two undeclared units (sum), and the difference
  # is a factor of k in the reported effort. Guessing either way is a silent
  # error, so the refusal is the correct behaviour and is asserted as such.
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:9,
    day_type = "weekday",
    stringsAsFactors = FALSE
  )
  untimed <- data.frame(
    date = rep(as.Date("2024-06-03") + 0:3, each = 2L),
    day_type = "weekday",
    angler_count = as.vector(rbind(c(7, 17, 27, 37), c(13, 23, 33, 43))),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type)

  # Attaching warns; the refusal is at estimate time, where the summing happens.
  # An estimator that never sums them -- estimate_effort_aerial_glmm() models
  # the counts against their flight time -- keeps its several rows per day.
  attached <- suppressWarnings(suppressMessages(
    add_counts(design, untimed, count_col = "angler_count")
  ))
  expect_error(
    suppressWarnings(estimate_effort(attached, target = "sampled_days")),
    class = "creel_error_repeated_psus"
  )

  # Declaring what separates them is the escape hatch, and it must work: these
  # rows really are two effort types counted once each, not repeats.
  typed <- untimed
  typed$effort_type <- rep(c("bank", "boat"), 4L)
  declared <- add_counts(
    design, typed,
    count_col = "angler_count",
    unit_cols = c("date", "day_type", "effort_type")
  )
  # Has to survive to the estimate, not merely to attach: the design remembers
  # how its unit was declared, so the estimate-time guard rebuilds the same key
  # rather than refusing every unit_cols caller (GH #162).
  expect_no_error(suppressWarnings(estimate_effort(declared, target = "sampled_days")))
})
