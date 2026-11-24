# GH #691: a rate pooled across strata (ungrouped, or grouped by a column that
# is not a stratum) is weighted by each stratum's effort, so a rate fixture
# with more than one stratum needs counts. This gives every calendar day one
# count; days whose stratum label contains "weekend" get more effort, so the
# effort weights differ from the strata's shares of the interviews and the
# weighting is never a silent no-op.
add_rate_counts <- function(design) {
  cal <- design$calendar
  dcol <- design$date_col
  strata <- design$strata_cols
  counts <- cal[c(dcol, strata)]
  label <- do.call(paste, unname(as.list(cal[strata])))
  counts$effort_hours <- ifelse(grepl("weekend", label), 50, 15) + (seq_len(nrow(cal)) %% 5)
  suppressWarnings(suppressMessages(add_counts(design, counts))) # nolint: object_usage_linter
}

# GH #691: a bus-route or ice rate pooled across strata weights each stratum's
# days by N_h / n_h, which needs the register of sampled days
# (creel_design(sampled = )). This marks as worked exactly the calendar days
# that hold an interview or a count, so no empty worked day is invented and
# n_h is the days the fixture's records already cover.
add_br_register <- function(design) {
  cal <- design$calendar
  dcol <- design$date_col
  iv_col <- tidycreel:::interview_psu_col(design, design$interviews) %||% dcol
  days <- unique(c(
    as.character(design$interviews[[iv_col]]),
    if (!is.null(design$counts)) as.character(design$counts[[dcol]])
  ))
  cal$.sampled <- as.character(cal[[dcol]]) %in% days
  design$calendar <- cal
  design$sampled_col <- ".sampled"
  design
}
