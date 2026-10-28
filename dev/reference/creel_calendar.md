# Build a season calendar

`creel_calendar()` returns every day of the season, one row per date,
with its day type and stratum: the calendar
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
takes. Unsampled days must be in the calendar, because they are the
population days the totals expand to, and each date must appear once.

## Usage

``` r
creel_calendar(
  start,
  end,
  strata = c("month", "day_type"),
  weekend_days = NULL,
  holidays = NULL,
  special_periods = NULL,
  season_blocks = NULL
)
```

## Arguments

- start, end:

  First and last day of the season, as a `Date` or `"YYYY-MM-DD"`.

- strata:

  Character vector: the parts of the stratum label, any of
  `"season_block"`, `"month"`, `"week"` and `"day_type"`, in the order
  they appear in the label.

- weekend_days:

  Day names (full or three-letter English, any case) that form the
  weekend. `NULL` (default) means Saturday and Sunday. The weekend days
  must be consecutive, because the week starts after them.

- holidays:

  Optional `Date` vector (or `"YYYY-MM-DD"` strings) of days treated as
  weekend days.

- special_periods:

  Optional data frame of periods that are strata of their own:
  `start_date`, `end_date` and `label`, with an optional `reason`, as
  [`generate_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_schedule.md)
  takes. Periods with different labels cannot overlap.

- season_blocks:

  Optional data frame with `start_date` and `label`. Each row starts a
  block that runs until the next row's `start_date`; the first must be
  the season's first day. Required when `strata` includes
  `"season_block"`, and refused otherwise.

## Value

A data frame with one row per day of the season: `date`, `month`
(integer), `week` (integer, week of the season), `day_type`
(`"weekday"`, `"weekend"` or `"special"`), `season_block` (when
`season_blocks` is supplied) and `stratum`.

## Strata

`strata` names the parts the stratum label is built from, in order:

- `"season_block"`: the block's label from `season_blocks`;

- `"month"`: the month, as `"06"`;

- `"week"`: the week of the season, as `"wk01"`. Week 1 starts on the
  season's first day, and each later week starts on the day after the
  last weekend day (Monday when the weekend is Saturday and Sunday), so
  a weekend is never split between two weeks. The first and last weeks
  can be partial;

- `"day_type"`: `"weekday"` or `"weekend"`.

The default, `c("month", "day_type")`, gives labels such as
`"06_weekend"`.

## Holidays and special periods

A date in `holidays` is a weekend day of its stratum: its `day_type` is
`"weekend"`, and a holiday Monday in June falls in `"06_weekend"`. It
does not move week boundaries: a holiday Monday is in the week it
starts.

A date in `special_periods` is a stratum of its own: its `day_type` is
`"special"` and its `stratum` is the period's `label`, whatever `strata`
says. A period is not split by month, week or block, so a holiday
weekend running from 30 June to 2 July is one stratum. (Apportioning
such a stratum's total back to months is \#429.) A date that is both a
holiday and in a special period is in the special period.

Holidays and special periods are dates, not rules: the package does not
know which holidays an agency observes or how it blocks them.

A holiday or special period outside the season is refused, not dropped:
it usually means the wrong year.

## See also

Other "Scheduling":
[`attach_count_times()`](https://chrischizinski.com/tidycreel/dev/reference/attach_count_times.md),
[`daylight_shifts()`](https://chrischizinski.com/tidycreel/dev/reference/daylight_shifts.md),
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
cal <- creel_calendar(
  "2024-05-01", "2024-09-02",
  holidays = as.Date(c("2024-05-27", "2024-09-02")),
  special_periods = data.frame(
    start_date = "2024-07-04", end_date = "2024-07-07",
    label = "july4"
  )
)
table(cal$stratum)
#> 
#> 05_weekday 05_weekend 06_weekday 06_weekend 07_weekday 07_weekend 08_weekday 
#>         22          9         20         10         21          6         22 
#> 08_weekend 09_weekend      july4 
#>          9          2          4 

creel_design(cal, date = date, strata = stratum)

# Early and late season blocks, by day type
creel_calendar(
  "2024-05-01", "2024-08-31",
  strata = c("season_block", "day_type"),
  season_blocks = data.frame(
    start_date = c("2024-05-01", "2024-07-01"),
    label = c("early", "late")
  )
) |> head()
#>         date month week day_type season_block       stratum
#> 1 2024-05-01     5    1  weekday        early early_weekday
#> 2 2024-05-02     5    1  weekday        early early_weekday
#> 3 2024-05-03     5    1  weekday        early early_weekday
#> 4 2024-05-04     5    1  weekend        early early_weekend
#> 5 2024-05-05     5    1  weekend        early early_weekend
#> 6 2024-05-06     5    2  weekday        early early_weekday
```
