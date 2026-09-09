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
    class = "creel_error_key_in_by"
  )
})

test_that("BY-02 (#293): everything() is refused rather than run unbounded", {
  design <- suppressMessages(make_screening_design())

  # Before the fix this call selected the key plus every other interview column
  # and did not return within 900s. The requirement is a refusal that NAMES the
  # key -- a generic error would leave the user no way to fix the call.
  expect_error(
    tidycreel:::resolve_species_by(rlang::quo(everything()), design),
    class = "creel_error_key_in_by"
  )
  # The class is what code should catch, but the message has to name the column
  # or the user cannot tell which of their by= terms to drop.
  expect_error(
    tidycreel:::resolve_species_by(rlang::quo(everything()), design),
    "interview_id"
  )
})

test_that("BY-03 (#293): naming a derived column is refused", {
  design <- suppressMessages(make_screening_design())

  # The design must actually claim this column as derived; the refusal reads
  # that field, not the leading dot.
  expect_true(".angler_effort" %in% tidycreel:::derived_interview_cols(design))
  expect_error(
    tidycreel:::resolve_species_by(rlang::quo(.angler_effort), design),
    class = "creel_error_derived_col_in_by"
  )
  expect_error(
    tidycreel:::resolve_species_by(rlang::quo(.angler_effort), design),
    "\\.angler_effort"
  )

  # A pattern matching only derived columns is an explicit request too:
  # silently returning an empty grouping would be worse than the error.
  expect_error(
    tidycreel:::resolve_species_by(rlang::quo(starts_with(".")), design),
    class = "creel_error_derived_col_in_by"
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

test_that("BY-08 (#293): trip duration counts as derived only when built here", {
  # `trip_duration_col` names a column add_interviews() computed only when it
  # computed one, and the caller's own otherwise. The design records WHICH,
  # because the name cannot answer it -- and answering by name would refuse a
  # legitimate grouping variable.
  design <- suppressMessages(make_screening_design())

  computed <- design
  computed$trip_duration_col <- ".trip_duration_hrs"
  computed$trip_duration_derived <- TRUE
  expect_true(".trip_duration_hrs" %in% tidycreel:::derived_interview_cols(computed))

  supplied <- design
  supplied$trip_duration_col <- "trip_duration"
  supplied$trip_duration_derived <- FALSE
  expect_false("trip_duration" %in% tidycreel:::derived_interview_cols(supplied))

  # The case a name test gets wrong: the caller's OWN column happens to be
  # called .trip_duration_hrs. It is theirs, so it stays groupable.
  collides <- design
  collides$trip_duration_col <- ".trip_duration_hrs"
  collides$trip_duration_derived <- FALSE
  expect_false(".trip_duration_hrs" %in% tidycreel:::derived_interview_cols(collides))
})

test_that("BY-09 (#293): a design records whether it derived the duration", {
  # The flag BY-08 relies on has to be set by the constructor, not just be
  # settable. add_interviews() computes a duration only from trip_start plus
  # interview_time; given a duration column it must record that it did not.
  design <- suppressMessages(make_screening_design())
  expect_false(design$trip_duration_derived)
  expect_identical(design$trip_duration_col, "trip_duration")
})

test_that("BY-10 (#293): what a pattern means depends on what else it matches", {
  # Wildcard-vs-explicit is decided by re-resolving with the derived columns
  # removed: if that leaves nothing, the selector was asking for them. So the
  # SAME selector refuses on one design and drops silently on another. That is
  # deliberate, and pinned here so it stays a decision rather than an accident.
  design <- suppressMessages(make_screening_design())

  # Only dot-named column is the derived one -> the pattern can only have meant it.
  expect_error(
    tidycreel:::resolve_species_by(rlang::quo(starts_with(".")), design),
    class = "creel_error_derived_col_in_by"
  )

  # A user column also matches -> the pattern still has something of theirs to
  # return, which is what a pattern asks for.
  with_user_col <- design
  with_user_col$interviews[[".se_expansion"]] <- rep(
    c("bank", "boat"),
    length.out = nrow(with_user_col$interviews)
  )
  expect_identical(
    tidycreel:::resolve_species_by(
      rlang::quo(starts_with(".")),
      with_user_col
    )$interview_vars,
    ".se_expansion"
  )
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
    class = "creel_error_key_in_by"
  )
})

# Guard coverage across every by= entry point (GH #312) -------------------------
#
# #293 built `screen_by_vars()` and wired it into `resolve_species_by()`. It
# reached two of the twelve places a `by=` selection is resolved. The other ten
# called `tidyselect::eval_select()` and used the names directly, so the same
# interview key #293 refuses on `estimate_catch_rate()` was accepted by the
# length, age and summary paths -- returning singleton groups in which
# `estimate` and `se` are equal in every row, a 100% CV, alongside percentages
# computed from one interview.
#
# The tests below deliberately go through the PUBLIC functions rather than
# `screen_by_vars()` itself. A unit test of the screen passes whether or not
# anything calls it, which is precisely the gap that let #312 exist after #293
# shipped green. One case per entry point, because a guard passing one twin's
# test says nothing about its siblings.

make_biological_design <- function() {
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")
  data("example_catch", package = "tidycreel")
  data("example_lengths", package = "tidycreel")
  data("example_ages", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type)
  design <- add_interviews(
    design,
    example_interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept,
    trip_status = trip_status,
    species_sought = species_sought
  )
  design <- add_catch(
    design,
    example_catch,
    catch_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  )
  design <- add_lengths(
    design,
    example_lengths,
    length_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    length = length,
    length_type = length_type,
    count = count,
    release_format = "binned"
  )
  add_ages(
    design,
    example_ages,
    age_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    age = age,
    age_type = age_type
  )
}

test_that("BY-09 (#312): every by= entry point refuses the interview key", {
  design <- suppressWarnings(suppressMessages(make_biological_design()))

  # The premise: one row per id, so any grouping by it gives groups of n = 1.
  ids <- design$interviews[[design$catch_interview_uid_col]]
  expect_identical(length(unique(ids)), nrow(design$interviews))

  # Named individually rather than looped so a failure reports WHICH path
  # regressed. Each of these accepted the key before #312.
  expect_error(
    suppressWarnings(est_length_distribution(design, by = interview_id, bin_width = 25)),
    class = "creel_error_key_in_by"
  )
  expect_error(
    suppressWarnings(est_age_distribution(design, by = interview_id)),
    class = "creel_error_key_in_by"
  )
  expect_error(
    suppressWarnings(summarize_length_freq(design, by = interview_id)),
    class = "creel_error_key_in_by"
  )
  expect_error(
    suppressWarnings(summarize_cws_rates(design, by = interview_id)),
    class = "creel_error_key_in_by"
  )
  expect_error(
    suppressWarnings(summarize_hws_rates(design, by = interview_id)),
    class = "creel_error_key_in_by"
  )

  # The already-guarded path, kept here so the two cannot drift apart again.
  expect_error(
    suppressWarnings(estimate_catch_rate(design, by = interview_id)),
    class = "creel_error_key_in_by"
  )

  # The harvest and release rates also re-resolve `by=` in their standard
  # routing, and #312 screens those sites too. Their KEY refusal, though, comes
  # from `resolve_species_by()` upstream and predates #312 -- these two
  # assertions are coverage of that upstream screen, not of the new call sites,
  # and they pass against the pre-fix code. What the new call sites change on
  # these paths is the derived-column drop, which BY-11 pins on the catch path.
  expect_error(
    suppressWarnings(estimate_harvest_rate(design, by = interview_id)),
    class = "creel_error_key_in_by"
  )
  expect_error(
    suppressWarnings(estimate_release_rate(design, by = interview_id)),
    class = "creel_error_key_in_by"
  )
})

test_that("BY-10 (#312): the refusal names the offending column on each path", {
  design <- suppressWarnings(suppressMessages(make_biological_design()))

  # The class is what code catches; the message is the only thing that tells a
  # user which by= term to drop. A refusal that does not name the column leaves
  # them guessing, which on the length path is the difference between a fixable
  # call and an abandoned one.
  expect_error(
    suppressWarnings(est_length_distribution(design, by = interview_id, bin_width = 25)),
    "interview_id"
  )
  expect_error(
    suppressWarnings(summarize_cws_rates(design, by = interview_id)),
    "interview_id"
  )
})

test_that("BY-11 (#312): a wildcard no longer re-admits a derived column downstream", {
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Interviews only: no add_catch()/add_lengths()/add_ages(), so no interview
  # key is registered and the key guard cannot fire. That isolates the OTHER
  # half of the screen -- the silent drop of package-derived columns.
  design <- suppressMessages(creel_design(
    example_calendar,
    date = date,
    strata = day_type
  ))
  design <- suppressWarnings(suppressMessages(add_interviews(
    design,
    example_interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept,
    trip_status = trip_status
  )))
  expect_true(".angler_effort" %in% names(design$interviews))

  # `resolve_species_by()` screened this selection and dropped `.angler_effort`,
  # and then the standard (non-species) routing re-resolved the same quosure
  # against the raw frame, which put it straight back. The call still refuses --
  # 22 interviews cannot fill groups of 10 -- but WHICH groups it built is the
  # observable, and `.angler_effort` was one of the grouping terms.
  msg <- tryCatch(
    {
      suppressWarnings(suppressMessages(
        estimate_catch_rate(design, by = tidyselect::everything())
      ))
      NULL
    },
    error = function(e) conditionMessage(e)
  )
  expect_false(is.null(msg))
  expect_false(grepl(".angler_effort", msg, fixed = TRUE))
})
