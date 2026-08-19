# Validate Interview Data

Validates that interview data conforms to the expected schema.

## Usage

``` r
validate_interviews(interviews, strict = TRUE)
```

## Arguments

- interviews:

  A tibble containing interview data

- strict:

  Logical, if TRUE throws error on validation failure

## Value

Invisibly returns the validated data, or throws error if invalid

## Examples

``` r
if (FALSE) { # \dontrun{
interviews <- tibble::tibble(
  interview_id = "INT001",
  date = as.Date("2024-01-01"),
  time_start = as.POSIXct("2024-01-01 08:00:00"),
  time_end = as.POSIXct("2024-01-01 08:15:00"),
  location = "Lake_A",
  mode = "boat",
  party_size = 2L,
  hours_fished = 4.5,
  target_species = "walleye",
  catch_total = 5L,
  catch_kept = 3L,
  catch_released = 2L,
  weight_total = 2.5,
  trip_complete = TRUE,
  effort_expansion = 1.0
)
validate_interviews(interviews)
} # }
```
