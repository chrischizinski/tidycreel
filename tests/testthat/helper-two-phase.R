# Design-estimated total of a per-interview vector (GH #310 tests).
#
# The estimator scales onto `svytotal()` of the reported count over the
# interview survey, NOT the raw column sum. Those two coincide only while every
# interview weight is 1, which is true of the shipped fixtures -- so a test
# pinned to `sum()` passes just as happily for an estimator that dropped the
# survey weighting entirely. Asserting through the design closes that gap.
#
# The expectation VECTORS are written from the data definition in each test
# rather than reused from R/two-phase-rescale.R, so this stays a check on the
# estimator rather than a restatement of it.
weighted_interview_total <- function(design, vec) {
  svy <- design$interview_survey
  svy$variables$.expected_reported <- as.numeric(vec)
  as.numeric(stats::coef(survey::svytotal(~.expected_reported, svy)))
}

# The per-interview reported count for one species and catch type, built from
# the catch table by the same rule add_catch() documents: a "caught" row is
# optional, and absent it means harvested + released.
species_reported_vector <- function(design, species, type) {
  ct <- design[["catch"]]
  wanted <- c(catch = "caught", harvest = "harvested", release = "released")[[type]]
  rows <- ct[ct[[design$catch_species_col]] == species, , drop = FALSE]
  typed <- rows[rows[[design$catch_type_col]] == wanted, , drop = FALSE]
  if (identical(type, "catch") && nrow(typed) == 0L) {
    typed <- rows[rows[[design$catch_type_col]] %in% c("harvested", "released"), , drop = FALSE]
  }
  uid <- design$catch_interview_uid_col
  out <- rep(0, nrow(design$interviews))
  if (nrow(typed) > 0L) {
    agg <- stats::aggregate(typed[[design$catch_count_col]], by = list(uid = typed[[uid]]), FUN = sum)
    names(agg) <- c("uid", "total")
    matched <- agg$total[match(design$interviews[[uid]], agg$uid)]
    matched[is.na(matched)] <- 0
    out <- as.numeric(matched)
  }
  out
}
