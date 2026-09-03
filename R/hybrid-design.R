# as_hybrid_svydesign() -------------------------------------------------------

#' Combine disjoint count frames into one stratified survey design
#'
#' `r lifecycle::badge("experimental")`
#'
#' Combines two or more count series covering disjoint parts of one fishery into
#' a single `survey::svydesign` object.  The frames are treated as **strata**,
#' each carrying its own within-day sampling fraction, and all expanded to the
#' same population of days, so the design total is the stratified sum of the
#' frame totals over the season.
#'
#' **Estimand.**  The design estimates a **period total** -- the total over
#' every day in `calendar`, not over the days that happened to be sampled.
#' Two expansions get it there, and both live in the row weight: the
#' within-day fraction expands the part of the frame that the count enumerated
#' to the whole of it, and `N_h / n_h` expands the sampled days to the days the
#' stratum holds.  Only the second is a stage-1 sampling fraction, so only the
#' second drives the finite-population correction.
#'
#' **Disjointness precondition.**  Adding the frame totals is valid if and only
#' if the frames sample **disjoint sets of angler trips** -- no angler trip may
#' be observed by more than one.  What produces that disjointness is a property
#' of the survey protocol (angler type, geography, access mode, or a rule the
#' designer imposes); tidycreel cannot infer it from the counts, the dates, the
#' strata, or the frame labels, so you must affirm it with
#' `trips_disjoint = TRUE`.  The design cannot be constructed otherwise.  A boat
#' angler intercepted on the water by a roving route and again at the ramp on
#' the same trip belongs to two frames, and the total double counts that trip.
#'
#' **What a frame is.**  A frame is a disjoint part of the fishery, enumerated
#' by its own count.  In the protocol this design was built for the frames are
#' angler-type domains -- boat anglers, and bank anglers dispersed along a
#' shoreline with no well-defined access site (Malvestuto 1996).  Pope et al.
#' (Chapter 17) carry exactly this as an `anglerType` column alongside the
#' stratum, and estimate effort by stratum and angler type; `frame_col` is that
#' column.
#'
#' The frame is **not** an interview mode.  In the creel literature access and
#' roving describe how anglers are *interviewed*: access interviews intercept
#' completed trips as anglers leave, roving interviews intercept incomplete
#' trips while anglers are still fishing, and the two require different
#' catch-rate estimators (Pollock et al. 1994).  A survey mixing the two is a
#' **hybrid interview** design.  Counts are not described that way at all --
#' they are instantaneous, progressive, bus-route, camera or aerial, the values
#' [creel_schema()] accepts for `survey_type`.  tidycreel carries the interview
#' axis on [add_interviews()]'s `interview_type` argument, which is where it
#' belongs.  Earlier versions of this function named its arguments
#' `access_data` and `roving_data`, which borrowed the interview vocabulary for
#' something that is not an interview mode (GH #248).
#'
#' **Estimation route.**  The returned object is a `survey.design2`, not a
#' [creel_design()], so [estimate_effort()] does not accept it.  Estimate from
#' it with `survey::svytotal()` and the other `survey` functions directly, as
#' in the examples below.
#'
#' **Design structure.**  Rows are stratified on the interaction of
#' `strata_col` and `frame_col`, so each count frame carries its own
#' sampled-day count at its own within-day fraction, and clustered on
#' `date_col`, so the date is the primary sampling unit.  The population size is
#' taken from `calendar` and is shared by every frame: one stratum is one span
#' of the season, whichever frame observed it.  A frame that sampled only one
#' date within a stratum leaves that stratum with a single PSU: the design still
#' constructs, but `survey` refuses to compute a variance for it.
#'
#' **One count row per frame-day.**  A day-level expansion is only defined when
#' a sampled day is one row per frame, so repeated counts on one date within a
#' frame are refused.  Two counts on a date are two looks at that date, not two
#' sampled days; summed, they multiply the total by the number of counts, and
#' the day expansion then multiplies that again.  Average them to one row per
#' date before constructing the design, or model them on a path that keeps the
#' count time.
#'
#' **PSU alignment requirement:** every frame should sample the same
#' date-stratum combinations.  A warning is issued when coverage is asymmetric,
#' because the frames should sample the same days.  That is a requirement about
#' *when* each frame samples, not *where* -- frames covering different water is
#' the condition that makes their sum valid, not a source of bias.
#'
#' @param counts Data frame of count observations for every frame, in long form:
#'   one row per frame per sampled date.  Must contain the columns named by
#'   `date_col`, `strata_col`, `count_col` and `frame_col`, with at most one row
#'   per frame per date within a stratum.
#' @param frame_col Character scalar.  Name of the column in `counts` that
#'   partitions it into disjoint count frames -- an angler-type column, for
#'   instance.  Required, with no default: the column carries the partition the
#'   whole design rests on, and a default would let a missed argument pick one
#'   silently.  Must have at least two distinct non-missing values; its values
#'   become the frame labels in the returned design.
#' @param calendar Data frame giving the population of days the totals expand
#'   to, carrying the columns named by `date_col` and `strata_col`.  Required:
#'   the `NULL` default is rejected, and exists only so the error can say what
#'   is missing.
#'
#'   The stratum population size \eqn{N_h} is the number of **distinct** dates
#'   the stratum holds, counted the way [creel_design()] counts it.  One row
#'   per day is the natural form, but a duplicated row is tolerated rather than
#'   refused, precisely because the count is over distinct dates and a repeat
#'   changes nothing.
#'
#'   Two things are required.  Every sampled date must appear in `calendar`
#'   under the same stratum, or the population is smaller than the sample.  And
#'   each date must belong to **exactly one** stratum -- a day listed under two
#'   lengthens the season by a day in each, and the period total then expands
#'   to a calendar larger than the one that exists.
#' @param date_col Character scalar.  Name of the date column (shared by
#'   `counts` and `calendar`). Default `"date"`.  Used to cluster observations
#'   into PSUs.  Must be of class `Date`, with no missing values in either
#'   table.
#' @param strata_col Character scalar.  Name of the stratum column (shared by
#'   `counts` and `calendar`). Default `"day_type"`.  Must have no missing
#'   values in either table: dates and strata are the join keys, and a missing
#'   key matches every other missing key rather than being refused.
#' @param count_col Character scalar.  Name of the count column in `counts`.
#'   Default `"count"`.
#' @param fraction Named list of named numeric vectors, one element per frame,
#'   named by the frame labels in `frame_col`.  Each element gives the
#'   **within-day** sampling fraction per stratum for that frame: the proportion
#'   of the frame the count enumerated on each sampled day, in (0, 1].  Expands
#'   a sampled day to a whole day; it is not a fraction of the season and does
#'   not drive the finite-population correction.  Names of each element must
#'   match the stratum values that frame carries.
#' @param trips_disjoint Logical scalar.  Required: the `NULL` default is
#'   rejected, and exists only so the error can say what is missing.  Set to
#'   `TRUE` to affirm that the frames sample disjoint sets of angler trips, the
#'   precondition under which their totals may be added.  tidycreel cannot
#'   verify this from the data; see the "Disjointness precondition" section
#'   above.
#' @param fpc Logical scalar.  Apply the day-level finite-population correction
#'   \eqn{n_h / N_h}?  Default `TRUE`.  Set to `FALSE` for the conservative
#'   with-replacement variance.  `NA` and vectors of length other than one are
#'   refused.
#'
#' @return A `survey::svydesign` object with an additional class attribute
#'   `"creel_hybrid_svydesign"`.  The design data carries the `frame_col`
#'   column unchanged, a `weight` column holding both the within-day and the
#'   day-to-season expansion, a `.hybrid_stratum` column holding the
#'   stratum-by-frame interaction the design is stratified on, and a `.pop_days`
#'   column holding the stratum population \eqn{N_h} the finite-population
#'   correction is taken against.  `attr(design, "component_col")` names the
#'   frame column.
#'
#' @examples
#' calendar <- data.frame(
#'   date = seq(as.Date("2024-06-01"), as.Date("2024-06-30"), by = "day")
#' )
#' calendar$day_type <- ifelse(
#'   format(calendar$date, "%u") %in% c("6", "7"), "weekend", "weekday"
#' )
#'
#' counts <- data.frame(
#'   date = rep(
#'     as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09")),
#'     times = 2
#'   ),
#'   day_type = rep(c("weekday", "weekday", "weekend", "weekend"), times = 2),
#'   angler_type = rep(c("boat", "bank"), each = 4),
#'   count = c(12L, 15L, 30L, 28L, 8L, 10L, 22L, 25L)
#' )
#' design <- as_hybrid_svydesign(
#'   counts,
#'   frame_col      = "angler_type",
#'   calendar       = calendar,
#'   fraction       = list(
#'     boat = c(weekday = 0.5, weekend = 0.5),
#'     bank = c(weekday = 0.4, weekend = 0.4)
#'   ),
#'   trips_disjoint = TRUE
#' )
#'
#' # estimate_effort() does not accept this object; use survey directly
#' survey::svytotal(~count, design)
#'
#' @family "Survey Design"
#' @export
as_hybrid_svydesign <- function(
  counts,
  frame_col,
  calendar = NULL,
  date_col = "date",
  strata_col = "day_type",
  count_col = "count",
  fraction = NULL,
  trips_disjoint = NULL,
  fpc = TRUE
) {
  # ---- Input validation ----------------------------------------------------
  if (missing(frame_col)) {
    cli::cli_abort(c(
      "{.arg frame_col} must be provided.",
      "x" = paste(
        "It names the column that partitions {.arg counts} into disjoint count",
        "frames, which is the partition the stratified total rests on."
      ),
      "i" = "For example {.code frame_col = \"angler_type\"}."
    ))
  }
  for (arg_name in c("date_col", "strata_col", "count_col", "frame_col")) {
    val <- get(arg_name)
    if (!is.character(val) || length(val) != 1L) {
      cli::cli_abort("{.arg {arg_name}} must be a single character string.")
    }
  }
  if (!is.data.frame(counts)) {
    cli::cli_abort("{.arg counts} must be a data frame.")
  }

  required_cols <- c(date_col, strata_col, count_col)
  missing_counts <- setdiff(c(required_cols, frame_col), names(counts))
  if (length(missing_counts) > 0L) {
    cli::cli_abort(
      "Column(s) {.field {missing_counts}} missing from {.arg counts}."
    )
  }

  # A missing frame label would form its own frame through as.character(), which
  # silently adds an "NA" stratum carrying whatever rows lost their label.
  n_na_frame <- sum(is.na(counts[[frame_col]]))
  if (n_na_frame > 0L) {
    cli::cli_abort(c(
      "{.field {frame_col}} in {.arg counts} has {n_na_frame} missing \\
       {cli::qty(n_na_frame)}value{?s}.",
      "x" = paste(
        "A missing frame label would form a frame of its own, carrying the",
        "rows that lost their label into a stratum nobody asked for."
      ),
      "i" = "Drop or fill the affected {cli::qty(n_na_frame)}row{?s} first."
    ))
  }

  frames <- unique(as.character(counts[[frame_col]]))
  if (length(frames) < 2L) {
    cli::cli_abort(c(
      "{.field {frame_col}} must hold at least two distinct frames.",
      "x" = "Found {length(frames)}: {.val {frames}}.",
      "i" = paste(
        "This design combines disjoint count frames. With one frame there is",
        "nothing to combine -- build it with {.fn creel_design} instead."
      )
    ))
  }

  # The calendar is the population of days the total expands to. Deriving N_h
  # from it rather than from a caller-supplied day fraction is how
  # creel_design() expresses the same quantity, and it gives one stratum one
  # population however many frames observed it -- a fraction per frame made the
  # frames imply different calendars for the same stratum (#246).
  if (is.null(calendar)) {
    cli::cli_abort(c(
      "{.arg calendar} must be provided.",
      "x" = paste(
        "The design expands the frame totals to a population of days,",
        "and the sampled dates alone cannot say how many days a stratum",
        "holds."
      ),
      "i" = paste(
        "Supply the season calendar with one row per day, carrying",
        "{.field {date_col}} and {.field {strata_col}}."
      )
    ))
  }
  if (!is.data.frame(calendar)) {
    cli::cli_abort("{.arg calendar} must be a data frame.")
  }
  missing_calendar <- setdiff(c(date_col, strata_col), names(calendar))
  if (length(missing_calendar) > 0L) {
    cli::cli_abort(
      "Column(s) {.field {missing_calendar}} missing from {.arg calendar}."
    )
  }

  # ---- Date class and missing keys -----------------------------------------
  # Every key below is compared through as.character(), which turns NA into the
  # string "NA" and makes it match another NA. A missing calendar date then
  # counts as a distinct day in N_h and inflates the period total with no error
  # and no warning; a missing calendar stratum quietly withholds that day from
  # the stratum it belongs to; and a missing sampled date reaches
  # survey::svydesign(), which aborts with "missing values in `id'" -- an error
  # about an internal column the caller never supplied. Refuse all three here,
  # naming the column. Date class is required for the same reason the rest of
  # the package requires it (prep_counts(), creel_design()'s calendar): the
  # keys must mean the same day on both sides of the join.
  .check_keys <- function(data, name) {
    date_vals <- data[[date_col]]
    if (!inherits(date_vals, "Date")) {
      cli::cli_abort(c(
        "{.field {date_col}} in {.arg {name}} must be a {.cls Date} column.",
        "x" = "Got class {.cls {class(date_vals)[1]}}."
      ))
    }
    for (col in c(date_col, strata_col)) {
      n_na <- sum(is.na(data[[col]]))
      if (n_na > 0L) {
        cli::cli_abort(c(
          "{.field {col}} in {.arg {name}} has {n_na} missing \\
           {cli::qty(n_na)}value{?s}.",
          "x" = paste(
            "Dates and strata are the keys the frames, the calendar and",
            "the day expansion are all joined on, and a missing key is",
            "matched to every other missing key rather than refused."
          ),
          "i" = "Drop or fill the affected {cli::qty(n_na)}row{?s} first."
        ))
      }
    }
  }
  .check_keys(counts, "counts")
  .check_keys(calendar, "calendar")

  # ---- Within-day fractions ------------------------------------------------
  # One entry per frame, each a named vector over that frame's strata. Keyed on
  # the frame rather than positional, so an extra frame cannot silently inherit
  # a neighbour's fraction.
  if (is.null(fraction)) {
    cli::cli_abort(c(
      "{.arg fraction} must be provided.",
      "i" = paste(
        "A named list with one entry per frame, each a named numeric vector",
        "over that frame's {.field {strata_col}} values."
      )
    ))
  }
  if (!is.list(fraction) || is.null(names(fraction)) || anyNA(names(fraction))) {
    cli::cli_abort(c(
      "{.arg fraction} must be a named list, one entry per frame.",
      "i" = "Names must be the {.field {frame_col}} values: {.val {frames}}."
    ))
  }
  missing_frames <- setdiff(frames, names(fraction))
  if (length(missing_frames) > 0L) {
    cli::cli_abort(c(
      "{.arg fraction} is missing entries for {cli::qty(length(missing_frames))}frame{?s}.",
      "x" = "Missing: {.val {missing_frames}}.",
      "i" = "Every frame needs its own within-day fraction; they are not shared."
    ))
  }
  # An entry for a frame that is not in the data is almost always a typo or a
  # frame that has since been filtered out. Ignoring it silently is how a
  # caller ends up believing a fraction was applied that never was.
  extra_frames <- setdiff(names(fraction), frames)
  if (length(extra_frames) > 0L) {
    cli::cli_abort(c(
      "{.arg fraction} has {cli::qty(length(extra_frames))}entr{?y/ies} for \\
       {cli::qty(length(extra_frames))}frame{?s} not in {.field {frame_col}}.",
      "x" = "Unused: {.val {extra_frames}}.",
      "i" = "Frames present: {.val {frames}}."
    ))
  }
  dup_frames <- unique(names(fraction)[duplicated(names(fraction))])
  if (length(dup_frames) > 0L) {
    cli::cli_abort(c(
      "{.arg fraction} names {cli::qty(length(dup_frames))}frame{?s} more than once.",
      "x" = "Duplicated: {.val {dup_frames}}.",
      "i" = "Only the first entry would be used, so the others are silently lost."
    ))
  }
  for (fr in frames) {
    frac <- fraction[[fr]]
    if (!is.numeric(frac) || is.null(names(frac))) {
      cli::cli_abort(
        "{.arg fraction[[\"{fr}\"]]} must be a named numeric vector."
      )
    }
    strata_vals <- unique(as.character(
      counts[[strata_col]][as.character(counts[[frame_col]]) == fr]
    ))
    missing_strata <- setdiff(strata_vals, names(frac))
    if (length(missing_strata) > 0L) {
      cli::cli_abort(c(
        "{.arg fraction[[\"{fr}\"]]} is missing entries for strata.",
        "x" = "Missing: {.val {missing_strata}}."
      ))
    }
    bad_vals <- frac[names(frac) %in% strata_vals]
    bad_vals <- bad_vals[bad_vals <= 0 | bad_vals > 1]
    if (length(bad_vals) > 0L) {
      cli::cli_abort(c(
        "{.arg fraction[[\"{fr}\"]]} values must be in (0, 1].",
        "x" = "Invalid strata: {.val {names(bad_vals)}} = {.val {bad_vals}}."
      ))
    }
  }

  # Disjointness precondition. Adding the frame totals is valid only if no
  # angler trip can be observed by more than one frame. Nothing in
  # date/strata/count can establish that, so the caller has to affirm it (#229).
  if (is.null(trips_disjoint)) {
    cli::cli_abort(c(
      "{.arg trips_disjoint} must be provided.",
      "x" = paste(
        "Summing the frames assumes each angler trip can be counted by only",
        "one of them, and tidycreel cannot verify that from the counts,",
        "dates, or strata."
      ),
      "i" = "Set {.code trips_disjoint = TRUE} to affirm it holds."
    ))
  }
  if (!is.logical(trips_disjoint) || length(trips_disjoint) != 1L ||
        is.na(trips_disjoint)) {
    cli::cli_abort("{.arg trips_disjoint} must be {.code TRUE} or {.code FALSE}.")
  }
  # `fpc` is branched on directly further down. Unvalidated, `NA` reaches
  # `if (fpc)` as base R's "missing value where TRUE/FALSE needed" and a
  # length-2 vector silently uses its first element, so the design is built with
  # a correction the caller did not ask for.
  if (!is.logical(fpc) || length(fpc) != 1L || is.na(fpc)) {
    cli::cli_abort("{.arg fpc} must be {.code TRUE} or {.code FALSE}.")
  }
  if (!trips_disjoint) {
    cli::cli_abort(c(
      "{.arg trips_disjoint} is {.code FALSE}, so the frames may not be summed.",
      "x" = paste(
        "A trip observed by two frames is counted twice, and the",
        "stratified total is biased upward by the overlap."
      ),
      "i" = paste(
        "Estimate the frames separately, or reconcile the overlap",
        "before combining them."
      )
    ))
  }

  # ---- One count row per frame-day -----------------------------------------
  # The day expansion below is a per-day factor, so it is only defined when a
  # sampled day is one row within a frame. Two counts on one date are two looks
  # at that date, not two sampled days: summed they multiply the total by the
  # number of counts per day, and N_h / n_h then multiplies that again. Same
  # defect class as refuse_duplicate_psus() on the creel_design bridge (#193,
  # #197). Keyed on the frame as well, or the frames' own rows on a shared date
  # would read as repeats of each other.
  n_dup <- n_duplicate_psus(counts, c(frame_col, date_col, strata_col)) # nolint: object_usage_linter
  if (n_dup > 0L) {
    cli::cli_abort(
      c(
        "{.arg counts} has {n_dup} repeated sampling \\
         {cli::qty(n_dup)}day{?s}.",
        "x" = paste(
          "{cli::qty(n_dup)}The repeated {?row is/rows are} keyed on",
          "{.field {c(frame_col, date_col, strata_col)}}."
        ),
        "x" = paste(
          "Two counts on one date are two looks at that date, not two",
          "sampled days. Summed, they multiply the total by the number of",
          "counts per day, and the expansion to the calendar multiplies",
          "that again."
        ),
        "i" = paste(
          "Average the repeats to one row per date before constructing the",
          "design."
        )
      ),
      class = "creel_error_repeated_psus"
    )
  }

  # ---- PSU alignment check -------------------------------------------------
  # Every frame should sample the same date-stratum combinations. Report each
  # frame that departs from the union rather than a single pairwise difference,
  # so the message stays meaningful past two frames.
  row_frame <- as.character(counts[[frame_col]])
  keys_by_frame <- lapply(frames, function(fr) {
    unique(paste(
      as.character(counts[[date_col]][row_frame == fr]),
      as.character(counts[[strata_col]][row_frame == fr])
    ))
  })
  names(keys_by_frame) <- frames
  all_keys <- unique(unlist(keys_by_frame, use.names = FALSE))
  asymmetric <- vapply(
    keys_by_frame,
    function(k) length(setdiff(all_keys, k)),
    integer(1)
  )
  if (any(asymmetric > 0L)) {
    msgs <- vapply(
      names(asymmetric)[asymmetric > 0L],
      function(fr) {
        paste(
          asymmetric[[fr]],
          "date-stratum combination(s) missing from frame", fr
        )
      },
      character(1)
    )
    cli::cli_warn(c(
      "Asymmetric date-stratum coverage between count frames.",
      "!" = "Effort estimates may be biased for unmatched combinations.",
      stats::setNames(msgs, rep("i", length(msgs)))
    ))
  }

  # ---- Calendar coverage ---------------------------------------------------
  # A sampled date absent from the calendar would leave N_h short of n_h, and
  # the sampling fraction n_h / N_h would exceed 1. Refuse rather than let the
  # fpc go out of range.
  cal_strata <- as.character(calendar[[strata_col]])
  cal_dates <- as.character(calendar[[date_col]])
  cal_keys <- paste(cal_strata, cal_dates)

  # A calendar day belongs to exactly one stratum. Listing one under two makes it
  # count toward both stratum populations, so the season is longer than it is and
  # the period total inflates -- with no error and no warning. Repeating a date
  # WITHIN one stratum is harmless: N_h counts distinct dates either way.
  cal_pairs <- unique(data.frame(d = cal_dates, s = cal_strata, stringsAsFactors = FALSE))
  straddling <- unique(cal_pairs$d[duplicated(cal_pairs$d)])
  if (length(straddling) > 0L) {
    cli::cli_abort(c(
      "{.arg calendar} assigns {length(straddling)} \\
       {cli::qty(length(straddling))}date{?s} to more than one stratum.",
      "x" = "{cli::qty(length(straddling))}Affected: {.val {straddling}}.",
      "x" = paste(
        "A day counted in two strata lengthens the season by one day in each,",
        "and the period total expands to a calendar larger than the one that",
        "exists."
      ),
      "i" = "Each date must appear under exactly one {.field {strata_col}} value."
    ))
  }
  counts_keys <- paste(
    as.character(counts[[strata_col]]),
    as.character(counts[[date_col]])
  )
  unmatched <- setdiff(unique(counts_keys), unique(cal_keys))
  if (length(unmatched) > 0L) {
    cli::cli_abort(c(
      "{.arg counts} sampled {length(unmatched)} date-stratum \\
       {cli::qty(length(unmatched))}combination{?s} absent from \\
       {.arg calendar}.",
      "x" = "{cli::qty(length(unmatched))}Unmatched: {.val {unmatched}}.",
      "i" = paste(
        "Every sampled date must appear in {.arg calendar} under the same",
        "stratum, or the population it expands to is smaller than the",
        "sample."
      )
    ))
  }

  # ---- Combine -------------------------------------------------------------
  combined <- counts[, unique(c(required_cols, frame_col)), drop = FALSE]

  # Each frame samples its own part of the fishery at its own rate, so the
  # stratum is the stratum-by-frame interaction: pooling them derives one
  # population size from a row count that mixes every frame, and `fpc` then
  # varies within stratum.
  combined$.hybrid_stratum <- paste(
    as.character(combined[[strata_col]]),
    as.character(combined[[frame_col]]),
    sep = "."
  )

  # The separator is a readable "." rather than a control character, so two
  # distinct pairs can land on one key when a value contains a dot itself:
  # stratum "a" with frame "b.c" and stratum "a.b" with frame "c" both give
  # "a.b.c". `survey` would then treat them as one stratum, n_h would be counted
  # over the union of their dates, and the day expansion and the fpc would be
  # wrong for both -- with no error and no warning. Refuse instead of narrowing
  # what a label may contain.
  pair_keys <- paste(
    as.character(combined[[strata_col]]),
    as.character(combined[[frame_col]]),
    sep = "\r"
  )
  collisions <- unique(combined$.hybrid_stratum[
    duplicated(unique(data.frame(k = combined$.hybrid_stratum, p = pair_keys))$k)
  ])
  if (length(collisions) > 0L) {
    cli::cli_abort(c(
      "{length(collisions)} stratum-by-frame \\
       {cli::qty(length(collisions))}key{?s} {?is/are} ambiguous.",
      "x" = "{cli::qty(length(collisions))}Ambiguous: {.val {collisions}}.",
      "x" = paste(
        "Two different {.field {strata_col}} and {.field {frame_col}}",
        "combinations produce the same key, so they would be pooled into one",
        "stratum and expanded over each other's sampled days."
      ),
      "i" = paste(
        "A {.val .} in a stratum or frame label causes this. Rename the",
        "affected values so each combination is distinct."
      )
    ))
  }

  # ---- Day expansion and fpc -----------------------------------------------
  # n_h: distinct dates the frame sampled in this stratum. N_h: distinct days
  # the stratum holds, from the calendar, shared by every frame. Count distinct
  # dates on both sides so the ratio stays in days (GH #183).
  row_stratum <- as.character(combined[[strata_col]])
  n_days <- tapply(
    as.character(combined[[date_col]]),
    combined$.hybrid_stratum,
    function(x) length(unique(x))
  )
  pop_days <- tapply(
    as.character(calendar[[date_col]]),
    cal_strata,
    function(x) length(unique(x))
  )
  n_sampled_days <- as.numeric(n_days[combined$.hybrid_stratum])
  n_pop_days <- as.numeric(pop_days[row_stratum])

  # The within-day fraction expands the access points covered, or the route
  # coverage achieved, to the whole of a sampled day. N_h / n_h expands the
  # sampled days to the season. Both belong in the weight; only the second is a
  # stage-1 sampling fraction over the date PSUs, so only the second may drive
  # the fpc. Supplying the within-day fraction there made `survey` read it as a
  # fraction of the calendar and shrink the variance as though half the season
  # had been enumerated (#246).
  #
  # Looked up on the frame-stratum pair. A separator that cannot occur in either
  # value keeps "a.b" + "c" from colliding with "a" + "b.c".
  frac_lookup <- unlist(lapply(frames, function(fr) {
    v <- fraction[[fr]]
    stats::setNames(as.numeric(v), paste(fr, names(v), sep = "\r"))
  }))
  within_day <- unname(frac_lookup[paste(
    as.character(combined[[frame_col]]),
    row_stratum,
    sep = "\r"
  )])
  combined$weight <- unname(
    (1 / within_day) * (n_pop_days / n_sampled_days)
  )

  # Hand `survey` the population size rather than the fraction n_h / N_h. It
  # reads a value <= 1 as a fraction and derives the population by division,
  # which breaks outright when a stratum was fully sampled -- the fraction is
  # then exactly 1 and `as.fpc()` aborts inside `survey`. The population size
  # is a number we already know; there is nothing to derive.
  combined$.pop_days <- n_pop_days

  # ---- Build svydesign -----------------------------------------------------
  # Cluster on the date so a sampled day is one PSU. `nest` because dates
  # recur across the frame strata.
  ids_formula <- stats::as.formula(paste0("~", date_col))
  strata_formula <- stats::as.formula("~.hybrid_stratum")
  weights_formula <- stats::as.formula("~weight")

  if (fpc) {
    design <- survey::svydesign(
      ids = ids_formula,
      strata = strata_formula,
      weights = weights_formula,
      fpc = ~.pop_days, # nolint: object_usage_linter
      data = combined,
      nest = TRUE
    )
  } else {
    design <- survey::svydesign(
      ids = ids_formula,
      strata = strata_formula,
      weights = weights_formula,
      data = combined,
      nest = TRUE
    )
  }

  class(design) <- c("creel_hybrid_svydesign", class(design))
  attr(design, "component_col") <- frame_col
  attr(design, "count_col") <- count_col
  design
}

# ---- S3 methods -------------------------------------------------------------

#' Print a creel_hybrid_svydesign
#'
#' @param x A `creel_hybrid_svydesign` object.
#' @param ... Ignored.
#'
#' @return `x`, invisibly.
#'
#' @export
print.creel_hybrid_svydesign <- function(x, ...) {
  cli::cli_h1("Hybrid Creel Survey Design")
  frame_col <- attr(x, "component_col")
  n_by_frame <- table(as.character(x$variables[[frame_col]]))
  parts <- paste0(names(n_by_frame), " (", as.integer(n_by_frame), " obs)") # nolint: object_usage_linter
  cli::cli_text("Frames: {parts}")
  cli::cli_text("")
  NextMethod()
  invisible(x)
}
