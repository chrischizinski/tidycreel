# Day length for a latitude and date

Computes the number of hours between sunrise and sunset at a given
latitude on a given date, using the CBM model of Forsythe et al. (1995).
The calculation is a closed form – no lookup tables, network access, or
location database is involved.

Only latitude is needed. Longitude and time zone shift *when* sunrise
and sunset occur but not the interval between them, so they are not
arguments.

## Usage

``` r
day_length(lat, date, horizon = "sunset")
```

## Arguments

- lat:

  Numeric latitude in decimal degrees, positive north, in \[-90, 90\].
  Recycled against `date`.

- date:

  A `Date` vector (or anything
  [`as.Date()`](https://rdrr.io/r/base/as.Date.html) accepts). Recycled
  against `lat`.

- horizon:

  How far the sun must be below the horizon for the day to count as
  over. Either one of `"sunset"` (the default; 0.833 degrees, accounting
  for the solar disc and atmospheric refraction), `"civil"` (6),
  `"nautical"` (12), `"astronomical"` (18), or a number giving the
  depression angle in degrees directly.

## Value

A numeric vector of day lengths in hours, the length of the longer of
`lat` and `date`.

## Details

Day length is astronomical, and the effort estimators want something
else. In Hoenig et al. (1993) and Pope et al. (Ch. 17), the daily
expansion factor \\T_d\\ is the length of the period the counts were
*randomised within* – a property of the survey design, set by
regulation, access hours, or the field protocol. It is often close to
daylight and it is not the same quantity. Use `day_length()` to build
simulated or planned surveys, and pass the period your protocol actually
used to
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).

Above the Arctic and Antarctic circles the sun may not rise or set at
all. In those cases the result saturates at `0` or `24` rather than
erroring.

## References

Forsythe, W.C., Rykiel, E.J., Stahl, R.S., Wu, H., Schoolfield, R.M.
(1995). A model comparison for daylength as a function of latitude and
day of year. Ecological Modelling 80:87-95.
[doi:10.1016/0304-3800(94)00034-F](https://doi.org/10.1016/0304-3800%2894%2900034-F)

Hoenig, J.M., Robson, D.S., Jones, C.M., Pollock, K.H. (1993).
Scheduling counts in the instantaneous and progressive count methods for
estimating sportfishing effort. North American Journal of Fisheries
Management 13:723-736.

## See also

[`simulate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/simulate_creel_data.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)

Other "Simulation":
[`simulate_creel_catch()`](https://chrischizinski.github.io/tidycreel/reference/simulate_creel_catch.md),
[`simulate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/simulate_creel_data.md)

## Examples

``` r
# A single day at Kearney, Nebraska
day_length(40.699, as.Date("2024-06-21"))
#> [1] 15.09385

# A whole season, for use as a simulated expansion factor
season <- seq(as.Date("2024-05-01"), as.Date("2024-08-31"), by = "day")
summary(day_length(40.699, season))
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>   13.14   14.14   14.63   14.50   14.97   15.09 

# Anglers fish into twilight; civil twilight adds roughly an hour in June
day_length(40.699, as.Date("2024-06-21"), horizon = "civil")
#> [1] 16.2079

# Latitude drives the seasonal swing
day_length(c(25, 45, 65), as.Date("2024-12-21"))
#> [1] 10.580278  8.761470  3.571631
```
