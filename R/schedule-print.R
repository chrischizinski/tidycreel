# Private helpers and S3 methods for printing creel_schedule objects.
# Provides format.creel_schedule(), print.creel_schedule(), and
# knit_print.creel_schedule() for console and document rendering.

# ---------------------------------------------------------------------------
# Helper: make_day_abbrevs
# ---------------------------------------------------------------------------

#' Create unique abbreviations for day-type labels
#'
#' Finds the minimum prefix length k (starting at 2) such that
#' `toupper(substr(label, 1, k))` is unique across all labels. Returns a
#' named character vector mapping each unique label to its abbreviation.
#'
#' @param day_type_labels Character vector of day type labels (duplicates ok).
#'
#' @return Named character vector: label -> abbreviation.
#'
#' @noRd
make_day_abbrevs <- function(day_type_labels) {
  unique_labels <- unique(day_type_labels)
  max_k <- max(nchar(unique_labels))
  for (k in seq(2L, max_k)) {
    abbrevs <- toupper(substr(unique_labels, 1L, k))
    if (!anyDuplicated(abbrevs)) {
      return(stats::setNames(abbrevs, unique_labels))
    }
  }
  # Fallback: full label uppercased (should never happen for distinct labels)
  stats::setNames(toupper(unique_labels), unique_labels)
}

# ---------------------------------------------------------------------------
# Helper: build_cell_lookup
# ---------------------------------------------------------------------------

#' Build a date-to-cell-content lookup for the calendar grid
#'
#' @param x A creel_schedule data frame (already filtered to a single month
#'   if needed, but accepts full schedule — dates outside the current month
#'   are simply absent from the lookup).
#' @param abbrev_map Named character vector: day_type label -> abbreviation.
#' @param mode "ascii" uses newline separator; "pandoc" uses "<br>".
#'
#' @return Named character vector: date string (as.character(date)) ->
#'   cell content string. Only sampled dates are included.
#'
#' @noRd
build_cell_lookup <- function(x, abbrev_map, mode = "ascii") {
  sep <- if (mode == "pandoc") "<br>" else "\n"

  # Keep only sampled rows
  if ("sampled" %in% names(x)) {
    x <- x[x$sampled, ]
  }

  if (nrow(x) == 0L) {
    return(character(0))
  }

  # Deduplicate to one row per date for day_type lookup
  x_unique <- x[!duplicated(x$date), ]

  abbrevs <- abbrev_map[x_unique$day_type]
  names(abbrevs) <- as.character(x_unique$date)

  if ("circuit" %in% names(x)) {
    # Aggregate circuits per date
    circuit_by_date <- tapply(
      x$circuit,
      as.character(x$date),
      function(v) paste(sort(unique(v)), collapse = ",")
    )
    # Combine abbreviation + circuit
    date_keys <- names(abbrevs)
    cell_content <- vapply(date_keys, function(d) {
      paste(abbrevs[[d]], circuit_by_date[[d]], sep = sep)
    }, character(1))
    names(cell_content) <- date_keys
    return(cell_content)
  }

  abbrevs
}

# ---------------------------------------------------------------------------
# Helper: build_month_grid
# ---------------------------------------------------------------------------

#' Build calendar grid lines for a single month
#'
#' @param month_start Date scalar: first day of the month.
#' @param cell_lookup Named character vector from build_cell_lookup().
#' @param mode "ascii" or "pandoc".
#'
#' @return Character vector of lines (one element per output line).
#'
#' @noRd
build_month_grid <- function(month_start, cell_lookup, mode = "ascii") {
  # Full calendar month
  month_end <- lubridate::ceiling_date(month_start, "month") - lubridate::days(1)
  all_dates <- seq(month_start, month_end, by = "day")

  # Pad left so row starts on Sunday (wday returns 1 for Sunday with week_start=7)
  pad_left <- lubridate::wday(month_start, week_start = 7L) - 1L
  pad_right <- (7L - (length(all_dates) + pad_left) %% 7L) %% 7L

  date_slots <- c(rep(NA, pad_left), all_dates, rep(NA, pad_right))

  # Cell content for each slot
  cell_content <- vapply(seq_along(date_slots), function(i) {
    d <- date_slots[[i]]
    if (is.na(d)) {
      return("")
    }
    key <- as.character(as.Date(d, origin = "1970-01-01"))
    val <- cell_lookup[key] # single bracket: returns NA if key not present
    if (!is.na(val)) {
      val
    } else {
      format(as.Date(d, origin = "1970-01-01"), "%d")
    }
  }, character(1))

  if (mode == "pandoc") {
    .build_pandoc_grid(cell_content)
  } else {
    .build_ascii_grid(cell_content)
  }
}

# Day-of-week column headers
.dow_headers <- c("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")

#' Build ASCII text lines for a calendar month grid
#' @noRd
.build_ascii_grid <- function(cell_content) {
  n_cells <- length(cell_content)
  stopifnot(n_cells %% 7L == 0L)
  n_rows <- n_cells %/% 7L

  # Determine max lines per cell (for multi-line bus-route cells)
  # Split on newline to get line counts
  cell_lines <- strsplit(cell_content, "\n", fixed = TRUE)
  max_subrows <- max(vapply(cell_lines, length, integer(1)), na.rm = TRUE)

  # Determine max character width per cell (across all sub-lines)
  all_widths <- vapply(cell_lines, function(cl) {
    if (length(cl) == 0L || (length(cl) == 1L && cl == "")) 0L else max(nchar(cl))
  }, integer(1))
  cell_w <- max(max(all_widths, na.rm = TRUE), 8L)

  pad_cell <- function(s, w) {
    formatC(s, width = w, flag = "-")
  }

  # Header line
  header_cells <- vapply(.dow_headers, pad_cell, character(1), w = cell_w)
  header_line <- paste0("| ", paste(header_cells, collapse = " | "), " |")

  # Separator line
  sep_dash <- paste(rep("-", cell_w), collapse = "")
  sep_line <- paste0("|-", paste(rep(sep_dash, 7L), collapse = "-|-"), "-|")

  lines <- c(header_line, sep_line)

  for (r in seq_len(n_rows)) {
    week_cells <- cell_lines[(r - 1L) * 7L + seq_len(7L)]
    # Render one sub-row per logical line in the cell (bus-route = 2+ lines)
    for (sub in seq_len(max_subrows)) {
      sub_row_cells <- vapply(week_cells, function(cl) {
        if (sub <= length(cl)) cl[[sub]] else ""
      }, character(1))
      padded <- vapply(sub_row_cells, pad_cell, character(1), w = cell_w)
      lines <- c(lines, paste0("| ", paste(padded, collapse = " | "), " |"))
    }
  }

  lines
}

#' Build pandoc pipe-table lines for a calendar month grid
#' @noRd
.build_pandoc_grid <- function(cell_content) {
  n_cells <- length(cell_content)
  stopifnot(n_cells %% 7L == 0L)
  n_rows <- n_cells %/% 7L

  header_line <- paste0("| ", paste(.dow_headers, collapse = " | "), " |")
  sep_line <- paste0("|", paste(rep("-----|", 7L), collapse = ""))

  lines <- c(header_line, sep_line)

  for (r in seq_len(n_rows)) {
    week_cells <- cell_content[(r - 1L) * 7L + seq_len(7L)]
    # In pandoc mode, cell_content already uses <br> for multi-line
    # Replace any stray \n just in case
    week_cells <- gsub("\n", "<br>", week_cells, fixed = TRUE)
    lines <- c(lines, paste0("| ", paste(week_cells, collapse = " | "), " |"))
  }

  lines
}

# ---------------------------------------------------------------------------
# format.creel_schedule
# ---------------------------------------------------------------------------

#' Format a creel_schedule for console printing
#'
#' Produces a human-readable ASCII monthly calendar grid for a
#' `creel_schedule` object. Each sampled date shows the day-type
#' abbreviation (and circuit for bus-route schedules); non-sampled dates
#' show only the day number.
#'
#' @param x A `creel_schedule` object.
#' @param ... Currently unused.
#'
#' @return A character vector, one element per output line.
#'
#' @export
format.creel_schedule <- function(x, ...) {
  # One-line summary header (match existing cli_text format)
  header <- cli::cli_format_method({
    cli::cli_text(
      "# A creel_schedule: {nrow(x)} rows x {ncol(x)} cols ",
      "({if ('date' %in% names(x)) length(unique(x$date)) else NA_integer_} days, ",
      "{if ('period_id' %in% names(x)) length(unique(x$period_id)) else 1L} periods)"
    )
  })

  if (!"date" %in% names(x)) {
    return(c(header, "(no date column to render calendar)"))
  }

  abbrev_map <- make_day_abbrevs(unique(x$day_type))
  cell_lookup <- build_cell_lookup(x, abbrev_map, mode = "ascii")

  # Group by calendar month
  month_starts <- sort(unique(lubridate::floor_date(x$date, "month")))

  grid_lines <- character(0)
  for (i in seq_along(month_starts)) {
    ms <- month_starts[[i]]
    month_label <- format(ms, "%B %Y")
    month_grid <- build_month_grid(ms, cell_lookup, mode = "ascii")
    if (i > 1L) {
      grid_lines <- c(grid_lines, "")
    }
    grid_lines <- c(grid_lines, month_label, month_grid)
  }

  c(header, grid_lines)
}

# ---------------------------------------------------------------------------
# print.creel_schedule
# ---------------------------------------------------------------------------

#' Print a creel_schedule as a monthly calendar grid
#'
#' Prints a formatted ASCII monthly calendar to the console. Sampled dates
#' show day-type abbreviations; bus-route schedules additionally show circuit
#' assignments.
#'
#' @param x A `creel_schedule` object.
#' @param ... Additional arguments passed to [format.creel_schedule()].
#'
#' @return Invisibly returns `x`.
#'
#' @examples
#' sched <- generate_schedule(
#'   start_date = "2024-06-01",
#'   end_date = "2024-07-31",
#'   n_periods = 1,
#'   sampling_rate = c(weekday = 0.3, weekend = 0.6),
#'   seed = 42
#' )
#' print(sched)
#'
#' @export
print.creel_schedule <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

# ---------------------------------------------------------------------------
# knit_print.creel_schedule
# ---------------------------------------------------------------------------

#' Render a creel_schedule as a pandoc pipe-table in R Markdown / Quarto
#'
#' Called automatically by knitr when a `creel_schedule` object is the last
#' expression in a code chunk. Produces one `### Month YYYY` heading and one
#' pandoc pipe-table per calendar month. Bus-route schedule cells use HTML
#' `<br>` to separate the day-type abbreviation from the circuit assignment.
#'
#' @param x A `creel_schedule` object.
#' @param ... Additional arguments (currently unused).
#'
#' @return A `knitr::asis_output()` object containing raw markdown.
#'
#' @examples
#' \dontrun{
#' sched <- generate_schedule(
#'   start_date = "2024-06-01",
#'   end_date = "2024-07-31",
#'   n_periods = 1,
#'   sampling_rate = c(weekday = 0.3, weekend = 0.6),
#'   seed = 42
#' )
#' # In an R Markdown chunk, just print the object:
#' sched
#' }
#'
#' @rawNamespace S3method(knitr::knit_print, creel_schedule)
knit_print.creel_schedule <- function(x, ...) {
  rlang::check_installed("knitr", reason = "to render creel_schedule in documents")

  if (!"date" %in% names(x)) {
    return(knitr::asis_output("*(no date column to render calendar)*"))
  }

  abbrev_map <- make_day_abbrevs(unique(x$day_type))
  cell_lookup <- build_cell_lookup(x, abbrev_map, mode = "pandoc")

  month_starts <- sort(unique(lubridate::floor_date(x$date, "month")))

  all_lines <- character(0)
  for (i in seq_along(month_starts)) {
    ms <- month_starts[[i]]
    month_label <- paste0("### ", format(ms, "%B %Y"))
    month_grid <- build_month_grid(ms, cell_lookup, mode = "pandoc")
    all_lines <- c(all_lines, month_label, month_grid, "")
  }

  knitr::asis_output(paste(all_lines, collapse = "\n"))
}
