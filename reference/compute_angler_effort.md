# Normalize fishing effort to angler-hours

Multiplies per-trip effort (hours) by party size (number of anglers) to
produce angler-hours. This converts party-level effort records to
individual-angler units, which are required for CPUE and harvest-rate
computations.

This function can be called standalone on a raw data frame or is called
internally by
[`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
when constructing the design object.

## Usage

``` r
compute_angler_effort(data, effort, n_anglers)
```

## Arguments

- data:

  A data frame containing the interview records.

- effort:

  Tidy selector for the effort column (numeric, hours per trip).

- n_anglers:

  Tidy selector for the number-of-anglers column (positive integer).

## Value

The input data frame with an added `.angler_effort` column (numeric,
angler-hours). Existing columns are preserved.

## See also

[`compute_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_effort.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
