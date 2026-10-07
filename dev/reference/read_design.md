# Rebuild a creel design from a bundle

Reads a bundle written by
[`write_design()`](https://chrischizinski.com/tidycreel/dev/reference/write_design.md)
(a folder or `.zip` file), checks each table against its checksum and
restores its column types, then runs the recorded steps with the
installed version of tidycreel.

## Usage

``` r
read_design(path, ...)
```

## Arguments

- path:

  A bundle folder or `.zip` file.

- ...:

  Tables for steps the bundle does not carry (written with
  `include_data = FALSE`), named by their argument: `counts = `,
  `interviews = `.

## Value

A
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
object.

## Details

A manifest written by hand works too: list the steps and their tables,
as
[`write_design()`](https://chrischizinski.com/tidycreel/dev/reference/write_design.md)
does. Without recorded column types, the date column of the calendar is
read as a date and other columns take the types
[`utils::read.csv()`](https://rdrr.io/r/utils/read.table.html) guesses;
tables without a checksum are reported as not verified.

## See also

[`write_design()`](https://chrischizinski.com/tidycreel/dev/reference/write_design.md)

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
