# Validate Count Data

Validates that instantaneous count data conforms to the expected schema.

## Usage

``` r
validate_counts(counts, strict = TRUE)
```

## Arguments

- counts:

  A tibble containing count data

- strict:

  Logical, if TRUE throws error on validation failure

## Value

Invisibly returns the validated data, or throws error if invalid

## Examples

``` r
if (FALSE) { # \dontrun{
counts <- tibble::tibble(
  count_id = "CNT001",
  date = as.Date("2024-01-01"),
  time = as.POSIXct("2024-01-01 09:00:00"),
  location = "Lake_A",
  mode = "boat",
  anglers_count = 15L,
  parties_count = 8L,
  weather_code = "clear",
  temperature = 22.5,
  wind_speed = 5.2,
  visibility = "good",
  count_duration = 15
)
validate_counts(counts)
} # }
```
