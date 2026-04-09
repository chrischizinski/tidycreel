# Phase 63: Visual Calendar - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Add `print.creel_schedule()` (ASCII monthly grid) and `knit_print.creel_schedule()` (pandoc-ready pipe table) to the existing `creel_schedule` S3 class. Both render the schedule as a human-readable month-grid calendar. Exporting to external calendar formats (iCal, Google Calendar) is out of scope.

</domain>

<decisions>
## Implementation Decisions

### Cell content — bus-route schedules (have `circuit` column)
- Each date cell shows two lines: day_type abbreviation on line 1, circuit assignment(s) on line 2
- Example: `WD\nC1` for a weekday with circuit 1; `WD\nC1,C2` for a day with multiple circuits
- Multiple circuits on the same date (from different periods) are shown comma-separated on one line
- This applies to both console (newline separator) and pandoc (HTML `<br>` separator) output

### Cell content — instantaneous (and other non-bus-route) schedules
- Each date cell shows the day_type abbreviation only (no circuit row)
- No separate "sampled" marker needed — presence in the cell implies sampled

### Day type abbreviations
- Derive dynamically from the actual `day_type` label stored in the data: first 2 characters, uppercased
- Do NOT hardcode WD/WE; this ensures custom labels (e.g., "holiday", "closure") abbreviate correctly
- Example: "weekday" → "WE", "weekend" → "WE"... wait, first 2 chars uppercased: "weekday" → "WE", "weekend" → "WE" — Claude should handle collision gracefully (e.g., use 3 chars if first 2 are identical across day types)

### Non-sampled day rendering
- Always render the full calendar month grid (Mon–Sun structure, all weeks), regardless of whether the schedule was generated with `include_all = TRUE` or `FALSE`
- Non-sampled dates: show the date number only (e.g., `15`) with no day_type or circuit content
- When the schedule has a `sampled` column (`include_all = TRUE` was used), non-sampled rows (`sampled == FALSE`) are ignored during rendering — they display the same as dates not in the tibble at all
- Net effect: the calendar always looks like a real calendar with sampled dates filled in and non-sampled dates blank

### Week layout
- Calendar grid starts on **Sunday** (US convention: Sun Mon Tue Wed Thu Fri Sat)
- One row per week; one column per day of week

### Console print (print.creel_schedule)
- Retain the existing one-line summary header above the grid: `# A creel_schedule: {N} rows x {M} cols ({D} days, {P} periods)`
- Calendar grid(s) follow immediately below the header
- Do NOT call `NextMethod()` — the calendar fully replaces the raw data frame dump
- For multi-month schedules, show ALL months (a full creel season is 3–6 months — not excessive)
- Separate consecutive month grids with a blank line; label each with the month and year above it

### Document knit_print (knit_print.creel_schedule)
- Same week-grid layout as the console calendar: 7 columns (Sun–Sat), one row per week, same cell content logic
- Each month gets a `### Month YYYY` markdown heading immediately above its pipe table
- Multi-line cell content uses HTML `<br>` tag (e.g., `WD<br>C1`) — renders correctly in pandoc HTML output
- Method uses `rlang::check_installed("knitr")` guard (consistent with `writexl`/`readxl` pattern in this package)
- Returns `knitr::asis_output()` wrapping raw markdown — do not use `knitr::kable()`
- Add `knitr` to `Suggests` in DESCRIPTION

### Claude's Discretion
- Exact ASCII cell width and border characters (dashes, pipes) for the console grid
- Whether to use `cli` for console output or plain `cat()` (either is fine)
- File placement: new file (e.g., `R/schedule-print.R`) or added to `R/schedule-generators.R`
- Whether to export `knit_print.creel_schedule` via `@export` or `@exportS3Method knitr knit_print`

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `print.creel_schedule()` in `R/schedule-generators.R` (line 29): existing method to be replaced — already handles the one-line summary; keep the summary text, replace the `NextMethod()` with calendar rendering
- `print-methods.R`: established pattern — `format.X()` builds character output, `print.X()` calls `cat(format(x), sep = "\n")` and returns `invisible(x)`. Consider splitting into `format.creel_schedule()` + `print.creel_schedule()` for testability
- `rlang::check_installed()`: used for `readxl` and `writexl` — apply same pattern for `knitr`

### Established Patterns
- S3 dispatch: tibble subclass `c("creel_schedule", "data.frame")` — both `print` and `knit_print` generics will dispatch to these methods automatically
- `day_type` stored as character (not factor) throughout — no `levels()` call needed for cell rendering
- `circuit` column is present only in bus-route designs — use `"circuit" %in% names(x)` to branch behavior
- Error handling: `cli::cli_abort()` with named vector format throughout the package

### Integration Points
- `R/schedule-generators.R`: replace existing `print.creel_schedule()` (or relocate to `R/schedule-print.R`)
- `DESCRIPTION Suggests`: add `knitr`
- `NAMESPACE`: ensure `knit_print.creel_schedule` is registered (either `@exportS3Method` or explicit `S3method(knitr::knit_print, creel_schedule)`)
- No changes needed to `creel_design()`, estimation functions, or vignettes for this phase

</code_context>

<specifics>
## Specific Ideas

- The console calendar should feel like a standard desk calendar — date number in the top-left of the cell, day_type + circuit content below it
- Abbreviation collision handling: if two day_type labels share the same first-2-char abbreviation, fall back to 3 chars (or more) until unique — prevents ambiguous calendar cells
- Month label format above each grid: `"May 2025"` (full month name + year), not `"2025-05"`

</specifics>

<deferred>
## Deferred Ideas

- **iCal / Google Calendar export vignette**: Export a `creel_schedule` (with shift times and count times) to `.ics` format so field staff can load their survey days on phones via Google Calendar or Outlook. Mentioned by user — strong field-workflow value. Belongs in its own phase (requires `ics` or similar package, iCal format generation).

</deferred>

---

*Phase: 63-visual-calendar*
*Context gathered: 2026-04-05*
