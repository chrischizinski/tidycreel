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
#'   design only (the calendar and sections) and the arguments of the other
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
#' - Not yet supported, and refused rather than written in part: catch,
#'   lengths or ages attached ([add_catch()], [add_lengths()], [add_ages()]);
#'   bus-route, ice, camera and aerial designs; counts prepared by
#'   [prep_counts_daily_effort()].
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
  if (file.exists(path)) {
    if (!isTRUE(overwrite)) {
      cli::cli_abort(c("{.path {path}} already exists.", "i" = "Use {.code overwrite = TRUE} to replace it."))
    }
    unlink(path, recursive = TRUE)
  }
  dir <- if (as_zip) file.path(tempfile("tidycreel-bundle-"), "bundle") else path
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  steps <- list()
  tables <- list()
  for (i in seq_along(design$steps)) {
    st <- design$steps[[i]]
    entry <- list(fn = st$fn, args = st$args)
    data_table <- st$fn %in% c("add_counts", "add_interviews")
    if (include_data || !data_table) {
      file <- sprintf("%02d-%s.csv", i, st$table_arg)
      write_bundle_table(st$table, file.path(dir, file))
      entry$table <- file
      entry$columns <- column_types(st$table)
      entry$class <- table_class(st$table)
      tables[[file]] <- unname(tools::md5sum(file.path(dir, file)))
      # Read back now: a table that does not survive the CSV round trip would
      # rebuild a different design, so it is refused here, not discovered later.
      # Class included -- a schedule read back as a plain data frame rebuilds a
      # different calendar.
      back <- read_bundle_table(file.path(dir, file), entry$columns, entry$class)
      given <- st$table
      rownames(given) <- NULL
      if (!isTRUE(all.equal(given, back))) {
        unlink(if (as_zip) dirname(dir) else dir, recursive = TRUE)
        cli::cli_abort(c(
          "The {st$table_arg} table does not survive being written as CSV.",
          "i" = "Check for list columns or other column types a CSV cannot hold."
        ), class = "creel_error_bundle_table_roundtrip")
      }
    } else {
      entry$table <- NULL
    }
    entry$table_arg <- st$table_arg
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
  yaml::write_yaml(manifest, file.path(dir, "manifest.yml"))

  if (as_zip) {
    zip::zip(normalizePath(path, mustWork = FALSE), files = list.files(dir), root = dir)
    unlink(dirname(dir), recursive = TRUE)
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
#' the calendar is read as a date and other columns are guessed with
#' [utils::type.convert()]; tables without a checksum are reported as not
#' verified.
#'
#' @param path A bundle folder or `.zip` file.
#' @param ... Tables for steps the bundle does not carry (written with
#'   `include_data = FALSE`), named by their argument: `counts = `,
#'   `interviews = `.
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
    } else if (!is.null(st$table)) {
      bundle_table(dir, st, manifest, i)
    } else {
      cli::cli_abort(c(
        "Step {i} ({.fn {st$fn}}) has no table in this bundle.",
        "i" = "It was written with {.code include_data = FALSE}; supply it as \\
               {.code read_design(path, {st$table_arg} = <data frame>)}."
      ), class = "creel_error_bundle_table_missing")
    }
    args <- lapply(st$args, unlist_scalar)
    design <- if (identical(st$fn, "creel_design")) {
      do.call(creel_design, c(list(calendar = tbl), args))
    } else {
      fn <- bundle_step_fn(st$fn)
      do.call(fn, c(list(design = design), stats::setNames(list(tbl), st$table_arg), args))
    }
  }
  unused <- setdiff(names(supplied), used)
  if (length(unused)) {
    cli::cli_abort("{.arg ...} names {.val {unused}}, which no step of this bundle takes.")
  }
  design
}

# --- internals ---------------------------------------------------------------

bundle_step_fn <- function(fn) {
  switch(fn,
    add_sections = add_sections,
    add_counts = add_counts,
    add_interviews = add_interviews,
    cli::cli_abort("The bundle has a step {.fn {fn}}, which this version cannot rebuild.",
                   class = "creel_error_bundle_unsupported")
  )
}

# YAML reads a length-one vector back as a scalar and a longer one as a list.
unlist_scalar <- function(x) if (is.list(x)) unlist(x) else x

check_design_bundleable <- function(design) {
  why <- character(0)
  if (!identical(design$design_type, "instantaneous")) {
    why <- c(why, cli::format_inline("a {.val {design$design_type}} design"))
  }
  for (slot in c("catch", "lengths", "ages")) {
    if (!is.null(design[[slot]])) why <- c(why, cli::format_inline("{.fn add_{slot}} data"))
  }
  if (isTRUE(design$counts_are_effort)) {
    why <- c(why, cli::format_inline("counts prepared by {.fn prep_counts_daily_effort}"))
  }
  if (length(why)) {
    cli::cli_abort(c(
      "This design cannot be written as a bundle yet.",
      stats::setNames(why, rep("x", length(why))),
      "i" = "Bundles carry roving and access designs with sections, counts and interviews (#438)."
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
        do.call(creel_design, c(list(calendar = st$table), st$args))
      } else {
        do.call(bundle_step_fn(st$fn),
                c(list(design = rebuilt), stats::setNames(list(st$table), st$table_arg), st$args))
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
      tz <- attr(x, "tzone")
      return(list(type = "POSIXct", tz = if (is.null(tz)) "" else tz[1]))
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

write_bundle_table <- function(df, file) {
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
      tz <- attr(x, "tzone")
      out[[nm]] <- format(x, "%Y-%m-%d %H:%M:%OS6", tz = if (is.null(tz)) "" else tz[1])
    }
  }
  utils::write.csv(out, file, row.names = FALSE, na = "NA")
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

read_bundle_table <- function(file, columns, cls = "data.frame") {
  raw <- utils::read.csv(file, colClasses = "character", na.strings = "NA", check.names = FALSE)
  for (nm in names(columns)) {
    ct <- columns[[nm]]
    x <- raw[[nm]]
    raw[[nm]] <- switch(ct$type,
      Date = as.Date(x),
      POSIXct = as.POSIXct(x, format = "%Y-%m-%d %H:%M:%OS", tz = ct$tz),
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

bundle_table <- function(dir, st, manifest, i) {
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
    return(read_bundle_table(file, st$columns, if (is.null(st$class)) "data.frame" else st$class))
  }
  # Hand-written manifest: guess types, with the calendar's date column a Date.
  df <- utils::read.csv(file, check.names = FALSE, stringsAsFactors = FALSE)
  if (identical(st$fn, "creel_design") && !is.null(st$args$date)) {
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
  step_fields <- c("fn", "args", "table", "columns", "class", "table_arg")
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
        add_interviews = "interviews", NA_character_
      )
    }
  }
  m
}
