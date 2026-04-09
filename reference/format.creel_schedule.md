# Format a creel_schedule for console printing

Produces a human-readable ASCII monthly calendar grid for a
`creel_schedule` object. Each sampled date shows the day-type
abbreviation (and circuit for bus-route schedules); non-sampled dates
show only the day number.

## Usage

``` r
# S3 method for class 'creel_schedule'
format(x, ...)
```

## Arguments

- x:

  A `creel_schedule` object.

- ...:

  Currently unused.

## Value

A character vector, one element per output line.
