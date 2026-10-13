# The warnings recorded on a design or an estimate

Every warning tidycreel raises is also recorded on the object the call
returns, so it can be read back after it has scrolled past. A design
keeps the warnings raised by
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md),
each `add_*()` step and
[`adjust_nonresponse()`](https://chrischizinski.com/tidycreel/dev/reference/adjust_nonresponse.md);
an estimate keeps the warnings raised while it was computed, including
those from a rate a total computes internally.

## Usage

``` r
get_warnings(x)
```

## Arguments

- x:

  A `creel_design` or a `creel_estimates` object.

## Value

A data frame with one row per warning, in the order raised:

- id:

  Position in the session's sequence of tidycreel warnings.

- class:

  The warning's own class, `creel_warning_<fact>`.

- tier:

  1, 2 or 3, as above.

- fn:

  The function that raised it.

- message:

  The warning text, without formatting.

Zero rows when nothing was raised.

## Details

Each warning has a tier, as listed in
[creel_warnings](https://chrischizinski.com/tidycreel/dev/reference/creel_warnings.md):

- 1:

  The estimate may be wrong: units, a missing period length, sections or
  cells left out of a total, an SE that ignores the design.

- 2:

  Data quality or precision: small samples, exclusions, short trips,
  thin cells.

- 3:

  Information: an argument with no effect, an estimator choice.

A warning is recorded even when the caller handles or muffles it, and is
not recorded when it was not raised at all. Warnings raised by other
packages (`survey`, `lme4`) are not recorded.

## See also

[creel_warnings](https://chrischizinski.com/tidycreel/dev/reference/creel_warnings.md)
for every class and its meaning.

## Examples

``` r
design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_counts(design, example_counts)

# The party-size warning is handled for this one call, so it does not
# print, but the design still records it.
design <- withCallingHandlers(
  add_interviews(design, example_interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status
  ),
  creel_warning_no_party_size = function(w) invokeRestart("muffleWarning")
)
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
get_warnings(design)
#>    id                       class tier             fn
#> 1 102 creel_warning_no_party_size    1 add_interviews
#>                                                                                                                                                                                                                                                                    message
#> 1 ! No `n_anglers` provided — assuming 1 angler per interview.\nℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour\n  normalization.\nℹ If the interviews really are one angler each, pass `n_anglers = 1` to state\n  that and silence this warning.
```
