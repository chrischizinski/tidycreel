# Design bundles: write_design() / read_design() (GH #438, part 1)
#
# A bundle is a recipe, not a snapshot: the manifest lists the steps that
# built the design (see R/design-steps.R) and each step's table is a CSV.
# read_design() runs the steps again with the installed tidycreel, so a fix
# made after the bundle was written applies to it. The calendar is the record
# of the days surveyed; a schedule is never drawn again from its seed.

design_bundle_format <- "tidycreel-design"
design_bundle_version <- 1L

#' Save a creel design as a bundle that rebuilds it
#'
#' Writes the steps that built `design` -- [creel_design()],
#' [add_sections()], [add_counts()], [add_interviews()] with the arguments
#' they were given -- and the table each step was given, to a folder (or a
#' `.zip` file). [read_design()] runs the steps again with the installed
#' version of tidycreel, so the rebuilt design gets every fix made since the
#' bundle was written. Unlike `saveRDS()`, the bundle can be read outside R:
#' a YAML manifest and one CSV per table.
#'
#' @param design A [creel_design()] object.
#' @param path A folder to create, or a file name ending in `.zip` (needs the
#'   zip package).
#' @param include_data `TRUE` (default) writes every table. `FALSE` writes the
#'   design only (the calendar, any sampling frame, and sections) and the arguments of the other
#'   steps, e.g. to share a survey plan or when interviews hold personal data;
#'   supply those tables to [read_design()].
#' @param notes Optional named list written to the manifest as notes, e.g.
#'   how the schedule was drawn. Notes are never used to rebuild the design.
#' @param overwrite Replace an existing bundle at `path`.
#'
#' @details
#' The bundle must rebuild the design exactly, so `write_design()` first
#' rebuilds it from its steps and compares the result with `design`:
#'
#' - A design changed by hand after it was built (for example
#'   `design$calendar$day_type[3] <- "weekend"`) is refused, because the edit
#'   is in no step and would be lost. Make the change in the input table and
#'   build the design again.
#' - A design built by a version of tidycreel without steps is refused; build
#'   it again with this version.
#'
#' Each table is written with a checksum and its column types (dates,
#' date-times with their time zone, factor levels), and is read back and
#' compared before `write_design()` returns.
#'
#' @return `path`, invisibly.
#' @seealso [read_design()]
#' @examples
#' data(example_calendar)
#' data(example_counts)
#' d <- creel_design(example_calendar, date = date, strata = day_type)
#' d <- add_counts(d, example_counts, count_col = effort_hours)
#' path <- file.path(tempdir(), "example-design")
#' write_design(d, path, overwrite = TRUE)
#' d2 <- read_design(path)
#' unlink(path, recursive = TRUE)
#' @export
write_design <- function(design, path, include_data = TRUE, notes = NULL, overwrite = FALSE) {
  if (!inherits(design, "creel_design")) {
    cli::cli_abort("{.arg design} must be a {.cls creel_design} object.")
  }
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    cli::cli_abort("{.arg path} must be one folder or {.file .zip} file name.")
  }
  if (!is.logical(include_data) || length(include_data) != 1L || is.na(include_data)) {
    cli::cli_abort("{.arg include_data} must be {.code TRUE} or {.code FALSE}.")
  }
  if (!is.null(notes) && (!is.list(notes) || is.null(names(notes)) || any(!nzchar(names(notes))))) {
    cli::cli_abort("{.arg notes} must be a named list.")
  }
  check_design_bundleable(design)
  check_design_rebuilds(design)

  as_zip <- grepl("\\.zip$", path, ignore.case = TRUE)
  if (as_zip) rlang::check_installed("zip", reason = "to write a .zip bundle.")
  if (file.exists(path) && !isTRUE(overwrite)) {
    cli::cli_abort(c("{.path {path}} already exists.", "i" = "Use {.code overwrite = TRUE} to replace it."))
  }
  # Everything is written and checked in a staging folder; an existing bundle
  # is replaced only once the new one is complete, so a failed write never
  # destroys it.
  parent <- dirname(path)
  if (!dir.exists(parent)) dir.create(parent, recursive = TRUE)
  # Absolute, because zip::zip() changes into the staging folder before it
  # writes: a relative zip name landed inside the folder it zipped (#459).
  parent <- normalizePath(parent)
  dir <- tempfile(".tidycreel-bundle-", tmpdir = parent)
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  steps <- list()
  tables <- list()
  for (i in seq_along(design$steps)) {
    st <- design$steps[[i]]
    entry <- list(fn = st$fn, args = st$args)
    # The prep_counts_*() mark is an attribute, which a CSV cannot hold. It is
    # recorded with or without the table: a table supplied to read_design()
    # from a CSV has lost it too.
    if (counts_are_effort(st$table)) entry$counts_are_effort <- TRUE # nolint: object_usage_linter
    data_table <- st$fn %in% bundle_data_steps
    if (include_data || !data_table) {
      file <- sprintf("%02d-%s.csv", i, st$table_arg)
      w <- write_step_table(st$table, dir, file, st$table_arg, isTRUE(entry$counts_are_effort))
      entry <- c(entry, w$fields)
      tables[[file]] <- w$md5
    } else {
      entry$table <- NULL
    }
    entry$table_arg <- st$table_arg
    # Further tables a step takes (a bus-route or ice sampling frame). They
    # describe the design, not the survey data, so include_data never drops them.
    for (nm in names(st$extra)) {
      file <- sprintf("%02d-%s.csv", i, nm)
      w <- write_step_table(st$extra[[nm]], dir, file, nm)
      entry$extra[[nm]] <- w$fields
      tables[[file]] <- w$md5
    }
    steps[[i]] <- entry
  }

  manifest <- list(
    format = design_bundle_format,
    format_version = design_bundle_version,
    tidycreel_version = as.character(utils::packageVersion("tidycreel")),
    written = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    include_data = include_data,
    steps = steps,
    tables = tables,
    notes = notes
  )
  manifest <- manifest[!vapply(manifest, is.null, logical(1))]
  # Numbers in the manifest (circuit_time, p_period) must read back exactly:
  # yaml's default of 7 significant digits turned 2/3 into 0.6666667, which
  # rebuilt a different design or refused one.
  yaml::write_yaml(manifest, file.path(dir, "manifest.yml"), handlers = list(numeric = yaml_exact_number))
  back <- yaml::read_yaml(file.path(dir, "manifest.yml"))
  same_args <- vapply(seq_along(steps), function(i) {
    isTRUE(identical(lapply(back$steps[[i]]$args, unlist_scalar), lapply(steps[[i]]$args, unlist_scalar)))
  }, logical(1))
  if (!all(same_args)) {
    cli::cli_abort("The arguments of step{?s} {which(!same_args)} do not survive being written to the manifest.",
                   class = "creel_error_bundle_table_roundtrip")
  }

  # The staging folder is removed on exit through its own name; `ready` is what
  # moves into place (the folder itself, or the zip made from it).
  ready <- dir
  if (as_zip) {
    ready <- paste0(dir, ".zip")
    zip::zip(ready, files = list.files(dir), root = dir)
    on.exit(unlink(ready), add = TRUE)
  }
  unlink(path, recursive = TRUE)
  if (!file.rename(ready, path)) {
    cli::cli_abort("Could not move the new bundle into place at {.path {path}}.")
  }
  invisible(path)
}

#' Rebuild a creel design from a bundle
#'
#' Reads a bundle written by [write_design()] (a folder or `.zip` file),
#' checks each table against its checksum and restores its column types, then
#' runs the recorded steps with the installed version of tidycreel.
#'
#' A manifest written by hand works too: list the steps and their tables, as
#' [write_design()] does. Without recorded column types, the date column of
#' the calendar is read as a date and other columns take the types
#' [utils::read.csv()] guesses; tables without a checksum are reported as not
#' verified.
#'
#' @param path A bundle folder or `.zip` file.
#' @param ... Tables for steps the bundle does not carry (written with
#'   `include_data = FALSE`), named by their argument: `counts = `,
#'   `interviews = `, and `catch = `, `lengths = `, `ages = ` for the tables
#'   given to [add_catch()], [add_lengths()] and [add_ages()].
#'
#' @return A [creel_design()] object.
#' @seealso [write_design()]
#' @inherit write_design examples
#' @export
read_design <- function(path, ...) {
  supplied <- list(...)
  if (length(supplied) && (is.null(names(supplied)) || any(!nzchar(names(supplied))))) {
    cli::cli_abort("Tables in {.arg ...} must be named by their argument, e.g. {.code counts = }.")
  }
  if (!file.exists(path)) cli::cli_abort("No bundle at {.path {path}}.")
  dir <- path
  if (!dir.exists(path)) {
    dir <- tempfile("tidycreel-bundle-")
    utils::unzip(path, exdir = dir)
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  }
  mpath <- file.path(dir, "manifest.yml")
  if (!file.exists(mpath)) cli::cli_abort("{.path {path}} has no {.file manifest.yml}.")
  manifest <- check_manifest(yaml::read_yaml(mpath))

  design <- NULL
  used <- character(0)
  for (i in seq_along(manifest$steps)) {
    st <- manifest$steps[[i]]
    tbl <- if (!is.null(supplied[[st$table_arg]])) {
      used <- c(used, st$table_arg)
      supplied[[st$table_arg]]
    } else if (!is.null(st[["table"]])) { # `$` would partial-match table_arg
      bundle_table(dir, st, manifest, i)
    } else {
      cli::cli_abort(c(
        "Step {i} ({.fn {st$fn}}) has no table in this bundle.",
        "i" = "It was written with {.code include_data = FALSE}; supply it as \\
               {.code read_design(path, {st$table_arg} = <data frame>)}."
      ), class = "creel_error_bundle_table_missing")
    }
    if (isTRUE(st$counts_are_effort)) tbl <- mark_counts_as_effort(tbl) # nolint: object_usage_linter
    args <- c(lapply(st$args, unlist_scalar), bundle_extra_tables(dir, st, manifest, i))
    design <- if (identical(st$fn, "creel_design")) {
      do.call(creel_design, c(list(calendar = tbl), args))
    } else {
      fn <- bundle_step_fn(st$fn)
      do.call(fn, c(list(design = design), stats::setNames(list(tbl), step_table_formal(st$fn, st$table_arg)), args))
    }
  }
  unused <- setdiff(names(supplied), used)
  if (length(unused)) {
    cli::cli_abort("{.arg ...} names {.val {unused}}, which no step of this bundle takes.")
  }
  design
}

# --- internals ---------------------------------------------------------------

# Write one table of a step, with its column types, and read it back at once:
# a table that does not survive the CSV round trip would rebuild a different
# design, so it is refused here, not discovered later. Class included -- a
# schedule read back as a plain data frame rebuilds a different calendar.
write_step_table <- function(df, dir, file, label, effort_mark = FALSE) {
  na <- na_marker(df)
  write_bundle_table(df, file.path(dir, file), na)
  fields <- list(table = file, columns = column_types(df), class = table_class(df))
  if (!identical(na, "NA")) fields$na <- na
  back <- read_bundle_table(file.path(dir, file), fields$columns, fields$class, na)
  if (effort_mark) back <- mark_counts_as_effort(back) # nolint: object_usage_linter
  given <- df
  rownames(given) <- NULL
  if (!isTRUE(all.equal(given, back))) {
    cli::cli_abort(c(
      "The {label} table does not survive being written as CSV.",
      "i" = "Check for list columns or other column types a CSV cannot hold."
    ), class = "creel_error_bundle_table_roundtrip")
  }
  list(fields = fields, md5 = unname(tools::md5sum(file.path(dir, file))))
}

# The extra tables of a manifest step, read and checked like its own table.
bundle_extra_tables <- function(dir, st, manifest, i) {
  lapply(st$extra, function(x) {
    bundle_table(dir, c(list(fn = st$fn), x), manifest, i, guess_date = FALSE)
  })
}

# Steps whose table is survey data, left out by include_data = FALSE.
bundle_data_steps <- c("add_counts", "add_interviews", "add_catch", "add_lengths", "add_ages")

# The argument a step's table is passed to. Catch, lengths and ages all take
# `data`, so the bundle names their tables apart (and read_design() takes them
# back by those names).
step_table_formal <- function(fn, table_arg) {
  if (fn %in% c("add_catch", "add_lengths", "add_ages")) "data" else table_arg
}

bundle_step_fn <- function(fn) {
  switch(fn,
    add_sections = add_sections,
    add_counts = add_counts,
    add_interviews = add_interviews,
    add_catch = add_catch,
    add_lengths = add_lengths,
    add_ages = add_ages,
    cli::cli_abort("The bundle has a step {.fn {fn}}, which this version cannot rebuild.",
                   class = "creel_error_bundle_unsupported")
  )
}

# The shortest form of each number that reads back exactly: 15 significant
# digits, 17 when 15 would round it.
yaml_exact_number <- function(x) {
  f <- format(x, digits = 15, trim = TRUE)
  inexact <- !is.na(x) & suppressWarnings(as.numeric(f)) != x
  f[inexact] <- sprintf("%.17g", x[inexact])
  # Without a decimal point YAML reads "2" back as an integer and "1e+20" as a
  # string, so a whole-valued argument failed the round-trip check (#459).
  whole <- is.finite(x) & !grepl(".", f, fixed = TRUE)
  f[whole] <- sub("^(-?[0-9]+)", "\\1.0", f[whole])
  f[is.na(x)] <- ".na.real"
  structure(f, class = "verbatim")
}

# YAML reads a length-one vector back as a scalar and a longer one as a list.
unlist_scalar <- function(x) if (is.list(x)) unlist(x) else x

check_design_bundleable <- function(design) {
  # On an ice design `site` is resolved against the calendar AND the sampling
  # frame. A positional selector can choose a different column in each, and a
  # step records one column name, so the rebuild would differ (#438 review).
  frame_site <- design$bus_route$site_col
  if (identical(design$design_type, "ice") && !is.null(design$site_col) && !is.null(frame_site) &&
        !frame_site %in% c(".ice_site", design$site_col)) {
    cli::cli_abort(c(
      "This design cannot be written as a bundle.",
      "x" = "{.arg site} chose {.field {design$site_col}} in the calendar and \\
             {.field {frame_site}} in the sampling frame.",
      "i" = "A bundle records one column name. Select the site by name, with the same \\
             column name in both tables."
    ), class = "creel_error_bundle_unsupported")
  }
  if (length(design$steps) == 0L) {
    cli::cli_abort(c(
      "This design has no recorded steps.",
      "i" = "It was built by a version of tidycreel without them; build it again with this version."
    ), class = "creel_error_bundle_no_steps")
  }
}

# Rebuild from the steps and compare, slot by slot (survey objects carry
# environments, so the objects are never identical()). A slot that differs was
# changed outside the steps, and a bundle would silently lose the change.
check_design_rebuilds <- function(design) {
  rebuilt <- NULL
  for (st in design$steps) {
    rebuilt <- suppressMessages(suppressWarnings(
      if (identical(st$fn, "creel_design")) {
        do.call(creel_design, c(list(calendar = st$table), st$args, st$extra))
      } else {
        do.call(bundle_step_fn(st$fn),
                c(list(design = rebuilt),
                  stats::setNames(list(st$table), step_table_formal(st$fn, st$table_arg)), st$args))
      }
    ))
  }
  slots <- union(names(design), names(rebuilt))
  differ <- slots[!vapply(slots, function(s) isTRUE(all.equal(design[[s]], rebuilt[[s]])), logical(1))]
  if (length(differ)) {
    cli::cli_abort(c(
      "This design was changed outside {.fn creel_design} and the {.fn add_*} functions.",
      "x" = "Different from a rebuild: {.field {differ}}.",
      "i" = "A bundle rebuilds the design from its steps, so the change would be lost. \\
             Make it in the input table and build the design again."
    ), class = "creel_error_bundle_hand_edited")
  }
}

column_types <- function(df) {
  lapply(df, function(x) {
    if (inherits(x, "Date")) return(list(type = "Date"))
    if (inherits(x, "POSIXct")) {
      # Written as UTC instants (a local clock repeats in the hour daylight
      # saving ends, and a zoneless clock would be read in the reader's zone);
      # the zone the column displays in is restored, absent when it had none.
      tz <- attr(x, "tzone")
      return(if (is.null(tz)) list(type = "POSIXct") else list(type = "POSIXct", tz = tz[1]))
    }
    if (is.factor(x)) return(list(type = "factor", levels = levels(x), ordered = is.ordered(x)))
    if (is.integer(x)) return(list(type = "integer"))
    if (is.double(x)) return(list(type = "double"))
    if (is.logical(x)) return(list(type = "logical"))
    if (is.character(x)) return(list(type = "character"))
    cli::cli_abort("Column of class {.cls {class(x)[1]}} cannot be written to a bundle.",
                   class = "creel_error_bundle_table_roundtrip")
  })
}

# The marker written for a missing value: "NA", unless a text value is
# literally "NA", which a CSV reader would turn into a missing value.
na_marker <- function(df) {
  text <- unlist(lapply(df, function(x) if (is.character(x) || is.factor(x)) as.character(x)))
  marker <- "NA"
  k <- 0L
  while (marker %in% text) {
    k <- k + 1L
    marker <- if (k == 1L) "<NA>" else sprintf("<NA%d>", k)
  }
  marker
}

write_bundle_table <- function(df, file, na = "NA") {
  out <- as.data.frame(df)
  for (nm in names(out)) {
    x <- out[[nm]]
    if (is.double(x) && !inherits(x, c("Date", "POSIXct"))) {
      # 15 significant digits reads back exactly for most values; 17 always does.
      f <- format(x, digits = 15, trim = TRUE, scientific = FALSE)
      if (!identical(suppressWarnings(as.numeric(f)), as.numeric(x))) f <- sprintf("%.17g", x)
      f[is.na(x)] <- NA
      out[[nm]] <- f
    } else if (inherits(x, "POSIXct")) {
      out[[nm]] <- format(x, "%Y-%m-%d %H:%M:%OS6", tz = "UTC")
    }
  }
  utils::write.csv(out, file, row.names = FALSE, na = na)
}

# The classes a table may carry: what tidycreel builds or accepts, all plain
# data frames underneath. Anything else could hold state a CSV cannot.
bundle_table_classes <- c("creel_schedule", "tbl_df", "tbl", "data.frame")

table_class <- function(df) {
  cls <- class(df)
  if (!all(cls %in% bundle_table_classes)) {
    cli::cli_abort("A table of class {.cls {cls[1]}} cannot be written to a bundle.",
                   class = "creel_error_bundle_table_roundtrip")
  }
  cls
}

read_bundle_table <- function(file, columns, cls = "data.frame", na = "NA") {
  raw <- utils::read.csv(file, colClasses = "character", na.strings = na, check.names = FALSE)
  for (nm in names(columns)) {
    ct <- columns[[nm]]
    x <- raw[[nm]]
    raw[[nm]] <- switch(ct$type,
      Date = as.Date(x),
      POSIXct = {
        t <- as.POSIXct(x, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC")
        attr(t, "tzone") <- ct$tz
        t
      },
      factor = factor(x, levels = unlist(ct$levels), ordered = isTRUE(ct$ordered)),
      integer = as.integer(x),
      double = as.numeric(x),
      logical = as.logical(x),
      character = x,
      cli::cli_abort("Unknown column type {.val {ct$type}} for {.field {nm}}.")
    )
  }
  cls <- unlist(cls)
  if (!all(cls %in% bundle_table_classes)) {
    cli::cli_abort("Unknown table class {.cls {cls}}.", class = "creel_error_bundle_manifest")
  }
  class(raw) <- cls
  raw
}

bundle_table <- function(dir, st, manifest, i, guess_date = TRUE) {
  file <- file.path(dir, st$table)
  if (!file.exists(file)) {
    cli::cli_abort("The bundle is missing {.file {st$table}} (step {i}, {.fn {st$fn}}).",
                   class = "creel_error_bundle_table_missing")
  }
  want <- manifest$tables[[st$table]]
  if (is.null(want)) {
    cli::cli_inform("{.file {st$table}} has no checksum in the manifest; not verified.")
  } else if (!identical(unname(tools::md5sum(file)), want)) {
    cli::cli_abort(c(
      "{.file {st$table}} has changed since the bundle was written.",
      "x" = "Its checksum does not match the manifest.",
      "i" = "Restore the original, or rebuild the design from the changed data and write a new bundle."
    ), class = "creel_error_bundle_checksum")
  }
  if (!is.null(st$columns)) {
    return(read_bundle_table(file, st$columns, if (is.null(st$class)) "data.frame" else st$class,
                             if (is.null(st$na)) "NA" else st$na))
  }
  # Hand-written manifest: guess types, with the calendar's date column a Date.
  df <- utils::read.csv(file, check.names = FALSE, stringsAsFactors = FALSE)
  if (guess_date && identical(st$fn, "creel_design") && !is.null(st$args$date)) {
    df[[st$args$date]] <- as.Date(df[[st$args$date]])
  }
  df
}

check_manifest <- function(m) {
  known <- c("format", "format_version", "tidycreel_version", "written", "include_data",
             "steps", "tables", "notes")
  unknown <- setdiff(names(m), known)
  if (length(unknown)) {
    cli::cli_abort("The manifest has unknown field{?s} {.field {unknown}}.",
                   class = "creel_error_bundle_manifest")
  }
  if (!identical(m$format, design_bundle_format)) {
    cli::cli_abort("This is not a tidycreel design bundle (format {.val {m$format}}).",
                   class = "creel_error_bundle_manifest")
  }
  v <- m$format_version
  if (!is.numeric(v) || length(v) != 1L || v > design_bundle_version) {
    cli::cli_abort(c(
      "The bundle's format version is {.val {v}}; this tidycreel reads up to {design_bundle_version}.",
      "i" = "Update tidycreel to read it."
    ), class = "creel_error_bundle_manifest")
  }
  if (length(m$steps) == 0L || !identical(m$steps[[1]]$fn, "creel_design")) {
    cli::cli_abort("The manifest's first step must be {.fn creel_design}.",
                   class = "creel_error_bundle_manifest")
  }
  step_fields <- c("fn", "args", "table", "columns", "class", "na", "table_arg", "counts_are_effort", "extra")
  for (i in seq_along(m$steps)) {
    bad <- setdiff(names(m$steps[[i]]), step_fields)
    if (length(bad)) {
      cli::cli_abort("Step {i} has unknown field{?s} {.field {bad}}.", class = "creel_error_bundle_manifest")
    }
    # A hand-written manifest may leave it out; each step takes one table.
    if (is.null(m$steps[[i]]$table_arg)) {
      m$steps[[i]]$table_arg <- switch(
        m$steps[[i]]$fn,
        creel_design = "calendar", add_sections = "sections", add_counts = "counts",
        add_interviews = "interviews", add_catch = "catch", add_lengths = "lengths",
        add_ages = "ages", NA_character_
      )
    }
  }
  m
}
