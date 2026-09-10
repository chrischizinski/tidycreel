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
# the catch table by the same rule add_catch() documents: a "caught" row is that
# SPECIES-INTERVIEW PAIR's total and is optional, and when the pair has none its
# catch is harvested + released.
#
# Written per pair, in a loop over interviews, deliberately: the rule the
# package got wrong twice (#318, #317) was applying that decision once per
# species across the whole table, and a helper that repeated the shortcut could
# not have failed against it. This stays a restatement of the DATA DEFINITION,
# not of R/two-phase-rescale.R.
species_reported_vector <- function(design, species, type) {
  ct <- design[["catch"]]
  wanted <- c(catch = "caught", harvest = "harvested", release = "released")[[type]]
  uid <- design$catch_interview_uid_col
  rows <- ct[as.character(ct[[design$catch_species_col]]) == as.character(species), ,
             drop = FALSE]

  vapply(design$interviews[[uid]], function(id) {
    pair <- rows[as.character(rows[[uid]]) == as.character(id), , drop = FALSE]
    if (nrow(pair) == 0L) {
      # An interview absent from the catch table caught none of this species.
      return(0)
    }
    typed <- pair[pair[[design$catch_type_col]] == wanted, , drop = FALSE]
    if (identical(type, "catch") && nrow(typed) == 0L) {
      typed <- pair[
        pair[[design$catch_type_col]] %in% c("harvested", "released"), ,
        drop = FALSE
      ]
    }
    sum(as.numeric(typed[[design$catch_count_col]]))
  }, numeric(1))
}
