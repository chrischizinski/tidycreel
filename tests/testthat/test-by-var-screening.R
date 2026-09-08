# Screening of by= selections (GH #293) -----------------------------------------
#
# Two kinds of column could reach a `by=` selection without being a domain the
# user defined: columns the package derived, and the interview key. Both were
# accepted silently. The key is the statistical stake -- one interview per group
# means every group rate has n = 1 and no within-group variance exists -- and it
# manifested as `estimate_total_release(by = everything())` failing to return
# within 900 seconds on a 22-interview fixture.
#
# These tests pin WHY each is refused, not just that an error appears: the key
# refusal must survive a design where the key column's values are the only thing
# distinguishing it, and the derived-column drop must stay silent for a
# wildcard while refusing an explicit mention. A test that only asserted "errors"
# would pass against a version that refused every by= selection.

make_screening_design <- function() {
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")
  data("example_interviews", package = "tidycreel")
  data("example_catch", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type)
  design <- add_counts(design, example_counts)
  design <- add_interviews(
    design,
    example_interviews,
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )
  suppressWarnings(add_catch(
    design,
    example_catch,
    catch_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  ))
}

test_that("BY-01 (#293): the interview key is refused as a grouping variable", {
  design <- suppressMessages(make_screening_design())

  # The premise the refusal rests on: one row per id, so grouping by it gives
  # groups of n = 1. If a future fixture repeats ids, this test is no longer
  # exercising the case it claims to.
  ids <- design$interviews[[design$catch_interview_uid_col]]
  expect_identical(length(unique(ids)), nrow(design$interviews))

  expect_error(
    tidycreel:::resolve_species_by(rlang::quo(interview_id), design),
    "interview key"
  )
})

test_that("BY-02 (#293): everything() is refused rather than run unbounded", {
  design <- suppressMessages(make_screening_design())

  # Before the fix this call selected the key plus every other interview column
  # and did not return within 900s. The requirement is a refusal that NAMES the
  # key -- a generic error would leave the user no way to fix the call.
  expect_error(
    tidycreel:::resolve_species_by(rlang::quo(everything()), design),
    "interview key"
  )
})

test_that("BY-03 (#293): naming a derived column is refused", {
  design <- suppressMessages(make_screening_design())

  # The design must actually claim this column as derived; the refusal reads
  # that field, not the leading dot.
  expect_true(".angler_effort" %in% tidycreel:::derived_interview_cols(design))
  expect_error(
    tidycreel:::resolve_species_by(rlang::quo(.angler_effort), design),
    "the package derived"
  )

  # A pattern matching only derived columns is an explicit request too:
  # silently returning an empty grouping would be worse than the error.
  expect_error(
    tidycreel:::resolve_species_by(rlang::quo(starts_with(".")), design),
    "the package derived"
  )
})

test_that("BY-07 (#293/#259): a user column with a dot name stays groupable", {
  # The first version of this screen matched `^\\.` and swallowed the user
  # column GH #259 exists to protect. The set of derived columns is read from
  # the design, so a user column that merely looks internal is untouched.
  design <- suppressMessages(make_screening_design())
  design$interviews[[".se_expansion"]] <- rep(
    c("bank", "boat"),
    length.out = nrow(design$interviews)
  )

  expect_false(".se_expansion" %in% tidycreel:::derived_interview_cols(design))

  vars <- tidycreel:::resolve_species_by(
    rlang::quo(c(day_type, .se_expansion)),
    design
  )$interview_vars
  expect_identical(vars, c("day_type", ".se_expansion"))
})

test_that("BY-08 (#293): trip duration is derived only when the package built it", {
  # `trip_duration_col` names an internal column when add_interviews() computed
  # the duration, and the user's own column otherwise. Treating the field as
  # always-internal would refuse a legitimate grouping variable.
  design <- suppressMessages(make_screening_design())

  computed <- design
  computed$trip_duration_col <- ".trip_duration_hrs"
  expect_true(".trip_duration_hrs" %in% tidycreel:::derived_interview_cols(computed))

  supplied <- design
  supplied$trip_duration_col <- "trip_duration"
  expect_false("trip_duration" %in% tidycreel:::derived_interview_cols(supplied))
})

test_that("BY-04 (#293): a wildcard drops derived columns without complaint", {
  design <- suppressMessages(make_screening_design())

  # Reach the catch-less branch, where no key is registered, so the derived
  # drop is the only screening that can fire and its silence is observable.
  no_catch <- design
  no_catch$catch <- NULL
  no_catch$catch_interview_uid_col <- NULL

  vars <- expect_silent(
    tidycreel:::resolve_species_by(rlang::quo(everything()), no_catch)$interview_vars
  )

  expect_false(".angler_effort" %in% vars)
  # Dropping derived columns must not thin out the user's own.
  expect_true(all(c("day_type", "trip_status", "hours_fished") %in% vars))
})

test_that("BY-05 (#293): ordinary groupings are unchanged", {
  design <- suppressMessages(make_screening_design())

  expect_identical(
    tidycreel:::resolve_species_by(rlang::quo(day_type), design)$interview_vars,
    "day_type"
  )

  # The species split is what routes a call to the species estimator; screening
  # runs before it and must leave that decision intact.
  both <- tidycreel:::resolve_species_by(rlang::quo(c(day_type, species)), design)
  expect_identical(both$species_var, "species")
  expect_identical(both$interview_vars, "day_type")
})

test_that("BY-06 (#293): the key is refused via any attachment that registered it", {
  design <- suppressMessages(make_screening_design())

  # add_lengths() and add_ages() register the same interviews id column. A
  # design that has one of those but no catch must refuse the key too, or the
  # refusal would depend on which optional table happened to be attached.
  lengths_only <- design
  lengths_only$catch <- NULL
  lengths_only$catch_interview_uid_col <- NULL
  lengths_only$lengths_interview_uid_col <- "interview_id"

  expect_error(
    tidycreel:::resolve_species_by(rlang::quo(interview_id), lengths_only),
    "interview key"
  )
})
