# Generate example species catch data linked to example_interviews
# Long format: one row per species per interview per catch_type
#
# Design constraints:
#   - interview_id FK references example_interviews$interview_id (1..22)
#   - For interviews with a "caught" row:
#       sum(count[catch_type == "caught"]) == catch_total for that interview
#   - For interviews with only "harvested" / "released" rows:
#       sum(count) == catch_total for that interview
#   - sum(count[catch_type == "harvested"]) per interview == catch_kept
#   - Species: "walleye", "bass", "panfish"
#   - At least 10 of 22 interviews have catch rows
#   - At least one interview has all three catch_types for the same species
#   - At least several with only "harvested", one or two with only "released"
#   - At least one with "caught" + "harvested" + "released"

example_catch <- data.frame(
  interview_id = c(
    # Interview 1: catch_total=5, catch_kept=2
    # Full detail: caught=5, harvested=2, released=3 (all three types, same species)
    1L, 1L, 1L,
    # Interview 2: catch_total=8, catch_kept=5
    # caught=8, harvested=5, released=3
    2L, 2L, 2L,
    # Interview 5: catch_total=6, catch_kept=3
    # Only harvested + released (no "caught" row)
    # harvested=3, released=3 => total=6, kept=3
    5L, 5L,
    # Interview 6: catch_total=12, catch_kept=8
    # Multi-species: walleye caught+harv+rel, bass caught+harv+rel
    # walleye: caught=7, harv=5, rel=2; bass: caught=5, harv=3, rel=2
    6L, 6L, 6L, 6L, 6L, 6L,
    # Interview 8: catch_total=7, catch_kept=4
    # caught=7, harvested=4, released=3
    8L, 8L, 8L,
    # Interview 9: catch_total=4, catch_kept=2
    # Only harvested + released
    # harvested=2, released=2 => total=4, kept=2
    9L, 9L,
    # Interview 11: catch_total=10, catch_kept=7
    # Multi-species: walleye caught+harv+rel, panfish harvested only
    # walleye: caught=7, harv=5, rel=2; panfish: harvested=2 (no caught row for panfish)
    # Total caught rows: walleye caught=7 => sum caught=7 but catch_total=10
    # Use only harv+rel approach: walleye harv=5+rel=2=7, panfish harv=2+rel=1=3 => total=10, kept=7
    11L, 11L, 11L, 11L,
    # Interview 12: catch_total=8, catch_kept=5
    # Multi-species: walleye and bass, only harvested + released
    # walleye: harv=3, rel=2=5; bass: harv=2, rel=1=3 => total=8, kept=5
    12L, 12L, 12L, 12L,
    # Interview 13: catch_total=6, catch_kept=4
    # Only "released" rows (no harvested, no caught)
    # Wait - catch_kept=4, so must have harvested=4
    # Use harvested only: walleye harv=4, bass rel=2 => total=6, kept=4
    13L, 13L,
    # Interview 14: catch_total=9, catch_kept=6
    # caught+harv+rel on walleye + panfish harvested
    # walleye: caught=6, harv=4, rel=2; panfish: harvested=2, released=1
    # sum caught = 6 != catch_total=9 => use no "caught" rows
    # walleye: harv=4, rel=2=6; panfish: harv=2, rel=1=3 => total=9, kept=6
    14L, 14L, 14L, 14L,
    # Interview 20: catch_total=7, catch_kept=5
    # caught=7, harvested=5, released=2
    20L, 20L, 20L,
    # Interview 22: catch_total=11, catch_kept=8
    # Multi-species: walleye+bass caught+harv+rel
    # walleye: caught=6, harv=5, rel=1; bass: caught=5, harv=3, rel=2
    22L, 22L, 22L, 22L, 22L, 22L
  ),
  species = c(
    # Interview 1
    "walleye", "walleye", "walleye",
    # Interview 2
    "walleye", "walleye", "walleye",
    # Interview 5
    "bass", "bass",
    # Interview 6: walleye caught+harv+rel, bass caught+harv+rel
    "walleye", "walleye", "walleye", "bass", "bass", "bass",
    # Interview 8
    "panfish", "panfish", "panfish",
    # Interview 9
    "bass", "bass",
    # Interview 11: walleye harv+rel, panfish harv+rel
    "walleye", "walleye", "panfish", "panfish",
    # Interview 12: walleye harv+rel, bass harv+rel
    "walleye", "walleye", "bass", "bass",
    # Interview 13: walleye harv, bass rel
    "walleye", "bass",
    # Interview 14: walleye harv+rel, panfish harv+rel
    "walleye", "walleye", "panfish", "panfish",
    # Interview 20
    "walleye", "walleye", "walleye",
    # Interview 22: walleye caught+harv+rel, bass caught+harv+rel
    "walleye", "walleye", "walleye", "bass", "bass", "bass"
  ),
  count = c(
    # Interview 1: caught=5, harv=2, rel=3
    5L, 2L, 3L,
    # Interview 2: caught=8, harv=5, rel=3
    8L, 5L, 3L,
    # Interview 5: harv=3, rel=3
    3L, 3L,
    # Interview 6: walleye caught=7, harv=5, rel=2; bass caught=5, harv=3, rel=2
    7L, 5L, 2L, 5L, 3L, 2L,
    # Interview 8: caught=7, harv=4, rel=3
    7L, 4L, 3L,
    # Interview 9: harv=2, rel=2
    2L, 2L,
    # Interview 11: walleye harv=5, rel=2; panfish harv=2, rel=1
    5L, 2L, 2L, 1L,
    # Interview 12: walleye harv=3, rel=2; bass harv=2, rel=1
    3L, 2L, 2L, 1L,
    # Interview 13: walleye harv=4; bass rel=2
    4L, 2L,
    # Interview 14: walleye harv=4, rel=2; panfish harv=2, rel=1
    4L, 2L, 2L, 1L,
    # Interview 20: caught=7, harv=5, rel=2
    7L, 5L, 2L,
    # Interview 22: walleye caught=6, harv=5, rel=1; bass caught=5, harv=3, rel=2
    6L, 5L, 1L, 5L, 3L, 2L
  ),
  catch_type = c(
    # Interview 1
    "caught", "harvested", "released",
    # Interview 2
    "caught", "harvested", "released",
    # Interview 5
    "harvested", "released",
    # Interview 6
    "caught", "harvested", "released", "caught", "harvested", "released",
    # Interview 8
    "caught", "harvested", "released",
    # Interview 9
    "harvested", "released",
    # Interview 11
    "harvested", "released", "harvested", "released",
    # Interview 12
    "harvested", "released", "harvested", "released",
    # Interview 13
    "harvested", "released",
    # Interview 14
    "harvested", "released", "harvested", "released",
    # Interview 20
    "caught", "harvested", "released",
    # Interview 22
    "caught", "harvested", "released", "caught", "harvested", "released"
  ),
  stringsAsFactors = FALSE
)

# Quality checks
stopifnot(all(example_catch$catch_type %in% c("caught", "harvested", "released")))
stopifnot(all(example_catch$interview_id %in% 1L:22L))
stopifnot(all(example_catch$count >= 0L))
stopifnot(all(example_catch$species %in% c("walleye", "bass", "panfish")))

# Verify caught totals match catch_total in example_interviews
load("data/example_interviews.rda")
interviews_with_caught <- unique(
  example_catch$interview_id[example_catch$catch_type == "caught"]
)
for (iid in interviews_with_caught) {
  caught_sum <- sum(
    example_catch$count[
      example_catch$interview_id == iid & example_catch$catch_type == "caught"
    ]
  )
  expected <- example_interviews$catch_total[example_interviews$interview_id == iid]
  if (caught_sum != expected) {
    stop(sprintf(
      "Interview %d: caught sum = %d, catch_total = %d",
      iid, caught_sum, expected
    ))
  }
}

# Verify harvested totals match catch_kept in example_interviews
interviews_with_data <- unique(example_catch$interview_id)
for (iid in interviews_with_data) {
  harv_sum <- sum(
    example_catch$count[
      example_catch$interview_id == iid & example_catch$catch_type == "harvested"
    ]
  )
  expected_kept <- example_interviews$catch_kept[example_interviews$interview_id == iid]
  if (harv_sum != expected_kept) {
    stop(sprintf(
      "Interview %d: harvested sum = %d, catch_kept = %d",
      iid, harv_sum, expected_kept
    ))
  }
}

# Verify no-caught interviews: sum of all count == catch_total
interviews_no_caught <- setdiff(interviews_with_data, interviews_with_caught)
for (iid in interviews_no_caught) {
  total_sum <- sum(example_catch$count[example_catch$interview_id == iid])
  expected <- example_interviews$catch_total[example_interviews$interview_id == iid]
  if (total_sum != expected) {
    stop(sprintf(
      "Interview %d (no caught): total count = %d, catch_total = %d",
      iid, total_sum, expected
    ))
  }
}

# Save the dataset
usethis::use_data(example_catch, overwrite = TRUE)
