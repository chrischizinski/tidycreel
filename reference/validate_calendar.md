# Validate Calendar Data

Validates that calendar data conforms to the expected schema.

## Usage

``` r
validate_calendar(calendar, strict = TRUE)
```

## Arguments

- calendar:

  A tibble containing calendar data

- strict:

  Logical, if TRUE throws error on validation failure

## Value

Invisibly returns the validated data, or throws error if invalid

## Examples

``` r
if (FALSE) { # \dontrun{
calendar <- tibble::tibble(
  date = as.Date("2024-01-01"),
  stratum_id = "2024-01-01-weekday-morning",
  day_type = "weekday",
  season = "winter",
  month = "January",
  weekend = FALSE,
  holiday = FALSE,
  shift_block = "morning",
  target_sample = 10L,
  actual_sample = 8L
)
validate_calendar(calendar)
} # }
```
