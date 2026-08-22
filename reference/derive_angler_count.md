# Derive an angler count from its components

Builds the single angler-count column that
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
needs from the columns a creel clerk actually records. Counts are
commonly split across bank anglers and boats, and the estimators need
one number per count.

Two forms are supported, matching the two ways a boat's anglers get onto
the form:

- **Direct counts** — supply `boat_anglers`, the counted number of
  anglers aboard. Appropriate when the clerk could see and count them.

- **Boat-party expansion** — supply `boat_count` and `party_size`, and
  the boats are expanded by the mean anglers per boat party. Appropriate
  when boats were counted but the people aboard could not be counted
  reliably.

## Usage

``` r
derive_angler_count(
  counts,
  bank = NULL,
  boat_anglers = NULL,
  boat_count = NULL,
  party_size = NULL,
  party_size_se = NULL,
  to = "angler_count"
)
```

## Arguments

- counts:

  A data frame of count observations.

- bank:

  Optional tidy selector for the bank (shore) angler count column.

- boat_anglers:

  Optional tidy selector for a directly counted boat-angler column.
  Mutually exclusive with `boat_count`.

- boat_count:

  Optional tidy selector for the counted number of boats. Requires
  `party_size`. Mutually exclusive with `boat_anglers`.

- party_size:

  Mean anglers per boat party, used to expand `boat_count`. One of: a
  single number; a tidy selector for a numeric column of `counts`; or a
  data frame of the kind
  [`mean_party_size()`](https://chrischizinski.github.io/tidycreel/reference/mean_party_size.md)
  returns with `by`, which is joined onto `counts` by its non-numeric
  columns.

- party_size_se:

  Optional standard error of `party_size`, in the same three shapes.
  Defaults to the `"se"` attribute of `party_size` when it has one, so
  [`mean_party_size()`](https://chrischizinski.github.io/tidycreel/reference/mean_party_size.md)
  output propagates on its own. There is deliberately no zero default;
  see the section above.

- to:

  Name of the column to write. Defaults to `"angler_count"`.

## Value

`counts` with the derived column appended, and the columns consumed to
build it (`bank`, `boat_anglers`, `boat_count`) removed — they are
superseded by the derived count and, where applicable, by
`expansion_basis`. Leaving them in produced a table that varied between
sub-counts of one sampling unit, which
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
cannot distinguish from an undeclared structural dimension (GH \#162).
The destination column is never dropped, even when it is also one of the
inputs.

When a party-size standard error is available, four further columns are
appended for the estimators to read: `expansion_basis` (the boat count,
which is what the multiplier acts on), `expansion_se`, `expansion_group`
(which rows share one estimated multiplier, and so carry perfectly
correlated error), and `expansion_of` (the column the basis is the
derivative of).
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
recognises all four and excludes them from count-column detection.

They must travel together and must reach
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
alongside the column named in `expansion_of`. Transforming that column
in between – multiplying a count by a shift length, say – scales the
count but not its derivative, and
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
refuses rather than propagate a component that is understated by exactly
the scale factor. Pass the per-day count and let `period_length_col` do
the multiplication instead.

All four are written by the package and are not user inputs. In
particular, editing `expansion_of` to name a transformed column silences
that refusal whether or not the basis was actually rescaled, which
re-enables the very defect the check exists to catch. Rescale through
`period_length_col`, which scales both together and can be verified,
rather than by asserting that you did (GH \#148).

## Details

The two boat forms are separate arguments on purpose. `boat_count` is a
count of **hulls**, not people, and adding it to an angler total is a
units error that produces a plausible-looking number. Requiring
`party_size` alongside it makes that mistake impossible to commit by
accident.

Components are added with `na.rm = FALSE`. If bank anglers are missing
for a count and boat anglers are 5, the total is unknown, not 5 — a
missing count and a count of zero are different observations and are
kept different here.

Pooling bank and boat anglers into one count assumes both are detected
the same way and are being reported as one quantity. Where detection
probabilities or catch rates differ between them, estimate the two as
separate domains instead of adding them.

## The party size is an estimate

A mean party size taken from interviews is itself estimated, and it
multiplies the boat component of **every** count. Its error is therefore
perfectly correlated across counts and does not shrink as counts are
added – averaging more counts will not reduce it. Left out, the reported
effort standard error is too small; the estimate itself is unaffected.

Supply `party_size_se` to carry that term through to the effort standard
error.
[`mean_party_size()`](https://chrischizinski.github.io/tidycreel/reference/mean_party_size.md)
returns it as a `"se"` attribute, which is picked up automatically when
its output is passed as `party_size`, so the usual pipeline propagates
the term without any extra argument.

When no standard error is available the term is **omitted rather than
set to zero**. A zero would produce a standard error identical to an
unpropagated one while looking propagated, which is worse than a
documented omission. The returned table carries no expansion columns in
that case, and `attr(<estimates>, "se_expansion")` is `NULL` rather than
`0`.

## See also

[`mean_party_size()`](https://chrischizinski.github.io/tidycreel/reference/mean_party_size.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
[`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md)

Other "Survey Design":
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md),
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md),
[`as_hybrid_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_hybrid_svydesign.md),
[`as_survey_design()`](https://chrischizinski.github.io/tidycreel/reference/as_survey_design.md),
[`compute_angler_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_angler_effort.md),
[`compute_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_effort.md),
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md),
[`creel_vocabulary()`](https://chrischizinski.github.io/tidycreel/reference/creel_vocabulary.md),
[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
[`impute_camera_counts()`](https://chrischizinski.github.io/tidycreel/reference/impute_camera_counts.md),
[`mean_party_size()`](https://chrischizinski.github.io/tidycreel/reference/mean_party_size.md),
[`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md),
[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)

## Examples

``` r
counts <- data.frame(
  date = as.Date("2024-06-01") + 0:1,
  day_type = c("weekday", "weekend"),
  bank_anglers = c(4L, 9L),
  angler_boats = c(3L, 7L),
  boat_anglers = c(7L, 16L)
)

# Direct counts
derive_angler_count(counts, bank = bank_anglers, boat_anglers = boat_anglers)
#>         date day_type angler_boats angler_count
#> 1 2024-06-01  weekday            3           11
#> 2 2024-06-02  weekend            7           25

# Boat-party expansion with a single mean
derive_angler_count(
  counts,
  bank = bank_anglers,
  boat_count = angler_boats,
  party_size = 2.4
)
#>         date day_type boat_anglers angler_count
#> 1 2024-06-01  weekday            7         11.2
#> 2 2024-06-02  weekend           16         25.8

# Expansion with a stratum-specific mean
mps <- data.frame(day_type = c("weekday", "weekend"), mean_party_size = c(2.1, 2.8))
derive_angler_count(
  counts,
  bank = bank_anglers,
  boat_count = angler_boats,
  party_size = mps
)
#>         date day_type boat_anglers angler_count
#> 1 2024-06-01  weekday            7         10.3
#> 2 2024-06-02  weekend           16         28.6
```
