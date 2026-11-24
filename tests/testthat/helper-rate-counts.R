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
