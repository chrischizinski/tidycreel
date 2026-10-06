# Shift times bounded by sunrise and sunset

Returns each date's shifts for a survey whose shifts run from sunrise to
a clock cutoff and from the cutoff to sunset (or between several
cutoffs), in local clock time. The result can be passed straight to
[`generate_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_schedule.md)`(periods = )`,
so each sampled day's drawn shift carries that day's daylight window:
[`attach_count_times()`](https://chrischizinski.com/tidycreel/dev/reference/attach_count_times.md)
then draws count times inside it, and
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
checks the period length against it.

Sunrise and sunset come from NOAA's solar-position equations (the sun's
centre at 0.833 degrees below the horizon by default, allowing for
refraction and the solar disc), which agree with the US Naval
Observatory to about a minute at mid-latitudes. Times are rounded to the
minute, and `hours` is computed from the rounded times so it matches the
shift window exactly.

Day length alone needs only latitude
([`day_length()`](https://chrischizinski.com/tidycreel/dev/reference/day_length.md)),
but *where* a clock cutoff falls within the day also depends on
longitude and the time zone, including daylight saving time, so all
three are required here.
[`day_length()`](https://chrischizinski.com/tidycreel/dev/reference/day_length.md)
uses a different model (Forsythe et al. 1995) and is meant for
simulation; the two can differ by a minute or two.

## Usage

``` r
daylight_shifts(
  date,
  lat,
  lon,
  tz,
  cutoffs = if (night) character(0) else "13:30",
  horizon = "sunset",
  night = FALSE
)
```

## Arguments

- date:

  Dates (a `Date` vector or anything
  [`as.Date()`](https://rdrr.io/r/base/as.Date.html) accepts).

- lat:

  Latitude in decimal degrees, positive north.

- lon:

  Longitude in decimal degrees, positive east (so negative in the
  Americas).

- tz:

  Time zone name, e.g. `"America/Chicago"` (see
  [`OlsonNames()`](https://rdrr.io/r/base/timezones.html)).

- cutoffs:

  Clock times (`"HH:MM"`, local) that divide the day into shifts. One
  cutoff gives two shifts (AM: sunrise to cutoff; PM: cutoff to sunset);
  `k` cutoffs give `k + 1`. With `night = TRUE` they divide the night
  instead, listed from evening to morning (e.g. `"00:30"`, or
  `c("22:00", "01:00")`); the default there is none, one shift from
  sunset to sunrise.

- horizon:

  Sun depression angle that defines sunrise and sunset: as in
  [`day_length()`](https://chrischizinski.com/tidycreel/dev/reference/day_length.md),
  `"sunset"` (default), `"civil"`, `"nautical"`, `"astronomical"`, or a
  number of degrees. `"civil"` adds roughly half an hour at each end,
  for anglers who fish into twilight.

- night:

  `FALSE` (default) for shifts from sunrise to sunset. `TRUE` for night
  shifts from sunset to the next morning's sunrise, each night dated by
  the date it starts (#407). Such shifts cross midnight, so pass them to
  [`generate_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_schedule.md)
  with a `day_start` no shift spans (e.g. `"12:00"`) and with
  `weekend_days`.

## Value

A data frame with one row per date and shift: `date`, `period_id` (1 =
first shift of the day), `start_time` and `end_time` (`"HH:MM"`, local),
and `hours` (decimal hours). For night shifts, `hours` is real elapsed
time in `tz`, so a night that spans a daylight-saving change is an hour
longer or shorter than its clock length;
[`generate_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_schedule.md)
keeps it as `shift_hours`.

## Details

A cutoff that falls before sunrise or after sunset on some date would
give a shift of zero or negative length; that is an error naming the
dates. So is a date on which the sun does not rise or set.

## References

NOAA Global Monitoring Laboratory. General solar position calculations.
<https://gml.noaa.gov/grad/solcalc/solareqns.PDF>

## See also

[`generate_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_schedule.md),
[`attach_count_times()`](https://chrischizinski.com/tidycreel/dev/reference/attach_count_times.md),
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md),
[`day_length()`](https://chrischizinski.com/tidycreel/dev/reference/day_length.md)

Other "Scheduling":
[`attach_count_times()`](https://chrischizinski.com/tidycreel/dev/reference/attach_count_times.md),
[`generate_bus_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_bus_schedule.md),
[`generate_count_times()`](https://chrischizinski.com/tidycreel/dev/reference/generate_count_times.md),
[`generate_progressive_start()`](https://chrischizinski.com/tidycreel/dev/reference/generate_progressive_start.md),
[`generate_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_schedule.md),
[`new_creel_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/new_creel_schedule.md),
[`read_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/read_schedule.md),
[`validate_creel_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/validate_creel_schedule.md),
[`write_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/write_schedule.md)

## Examples

``` r
# Kearney, Nebraska: AM / PM shifts split at 13:30 local time
daylight_shifts(
  as.Date(c("2024-05-01", "2024-06-21", "2024-08-31")),
  lat = 40.699, lon = -99.083, tz = "America/Chicago"
)
#>         date period_id start_time end_time    hours
#> 1 2024-05-01         1      06:34    13:30 6.933333
#> 2 2024-05-01         2      13:30    20:32 7.033333
#> 3 2024-06-21         1      06:05    13:30 7.416667
#> 4 2024-06-21         2      13:30    21:11 7.683333
#> 5 2024-08-31         1      07:03    13:30 6.450000
#> 6 2024-08-31         2      13:30    20:10 6.666667

# Into a schedule: each sampled day's drawn shift carries its own window
days <- seq(as.Date("2024-06-01"), as.Date("2024-06-30"), by = "day")
shifts <- daylight_shifts(days, 40.699, -99.083, "America/Chicago")
sched <- generate_schedule(
  start_date = "2024-06-01", end_date = "2024-06-30", n_periods = 2,
  sampling_rate = 0.3, periods_per_day = 1, periods = shifts, seed = 1
)
head(sched)
#> # A creel_schedule: 6 rows x 7 cols (6 days, 2 periods)
#> June 2024
#> | Sun      | Mon      | Tue      | Wed      | Thu      | Fri      | Sat      |
#> |----------|----------|----------|----------|----------|----------|----------|
#> |          |          |          |          |          |          | 01       |
#> | 02       | WEEKD    | WEEKD    | 05       | 06       | 07       | 08       |
#> | WEEKE    | 10       | 11       | 12       | 13       | 14       | 15       |
#> | 16       | WEEKD    | 18       | 19       | WEEKD    | 21       | WEEKE    |
#> | 23       | 24       | 25       | 26       | 27       | 28       | 29       |
#> | 30       |          |          |          |          |          |          |

# Night shifts, sunset to 00:30 and 00:30 to sunrise, dated by the evening
nights <- daylight_shifts(as.Date(c("2024-11-01", "2024-11-02")), 40.699, -99.083,
                          "America/Chicago", cutoffs = "00:30", night = TRUE)
nights # the second night gains an hour when daylight saving ends
#>         date period_id start_time end_time    hours
#> 1 2024-11-01         1      18:33    00:30 5.950000
#> 2 2024-11-01         2      00:30    08:08 7.633333
#> 3 2024-11-02         1      18:31    00:30 5.983333
#> 4 2024-11-02         2      00:30    07:09 7.650000
```
