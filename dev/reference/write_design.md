# Save a creel design as a bundle that rebuilds it

Writes the steps that built `design` –
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md),
[`add_sections()`](https://chrischizinski.com/tidycreel/dev/reference/add_sections.md),
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
with the arguments they were given – and the table each step was given,
to a folder (or a `.zip` file).
[`read_design()`](https://chrischizinski.com/tidycreel/dev/reference/read_design.md)
runs the steps again with the installed version of tidycreel, so the
rebuilt design gets every fix made since the bundle was written. Unlike
[`saveRDS()`](https://rdrr.io/r/base/readRDS.html), the bundle can be
read outside R: a YAML manifest and one CSV per table.

## Usage

``` r
write_design(
  design,
  path,
  include_data = TRUE,
  notes = NULL,
  overwrite = FALSE
)
```

## Arguments

- design:

  A
  [`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
  object.

- path:

  A folder to create, or a file name ending in `.zip` (needs the zip
  package).

- include_data:

  `TRUE` (default) writes every table. `FALSE` writes the design only
  (the calendar, any sampling frame, and sections) and the arguments of
  the other steps, e.g. to share a survey plan or when interviews hold
  personal data; supply those tables to
  [`read_design()`](https://chrischizinski.com/tidycreel/dev/reference/read_design.md).

- notes:

  Optional named list written to the manifest as notes, e.g. how the
  schedule was drawn. Notes are never used to rebuild the design.

- overwrite:

  Replace an existing bundle at `path`.

## Value

`path`, invisibly.

## Details

The bundle must rebuild the design exactly, so `write_design()` first
rebuilds it from its steps and compares the result with `design`:

- A design changed by hand after it was built (for example
  `design$calendar$day_type[3] <- "weekend"`) is refused, because the
  edit is in no step and would be lost. Make the change in the input
  table and build the design again.

- A design built by a version of tidycreel without steps is refused;
  build it again with this version.

Each table is written with a checksum and its column types (dates,
date-times with their time zone, factor levels), and is read back and
compared before `write_design()` returns.

## See also

[`read_design()`](https://chrischizinski.com/tidycreel/dev/reference/read_design.md)

## Examples

``` r
data(example_calendar)
data(example_counts)
d <- creel_design(example_calendar, date = date, strata = day_type)
d <- add_counts(d, example_counts, count_col = effort_hours)
#> Warning: No weights or probabilities supplied, assuming equal probability
path <- file.path(tempdir(), "example-design")
write_design(d, path, overwrite = TRUE)
d2 <- read_design(path)
#> Warning: No weights or probabilities supplied, assuming equal probability
unlink(path, recursive = TRUE)
```
