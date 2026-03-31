# Generate a bus-route sampling frame

Converts a creel schedule calendar and circuit definitions into a
sampling frame tibble with `inclusion_prob` and `p_period` columns ready
for `creel_design(survey_type = "bus_route")`.

Inclusion probability formula: `inclusion_prob = p_site * p_period`
where `p_period = crew / n_circuits`.

`n_circuits` is the number of distinct circuit values in
`sampling_frame` (or 1 when `circuit` is `NULL`). `crew` is the number
of field crews deployed simultaneously.

## Usage

``` r
generate_bus_schedule(
  schedule,
  sampling_frame,
  site,
  p_site,
  circuit = NULL,
  crew,
  seed = NULL
)
```

## Arguments

- schedule:

  A `creel_schedule` tibble from
  [`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md).
  Currently unused in computation but required to ensure the caller has
  built a valid schedule before constructing the sampling frame.

- sampling_frame:

  A data frame with site and p_site columns (and optionally circuit).

- site:

  Column in `sampling_frame` giving site identifiers (tidy selector:
  bare name, quoted string, or tidyselect helper).

- p_site:

  Column in `sampling_frame` giving per-site selection probability
  within the circuit. Values must sum to 1.0 per circuit (tolerance
  1e-6).

- circuit:

  Optional column giving circuit assignment. If `NULL`, all sites are
  treated as a single circuit.

- crew:

  Integer scalar: number of crews in the field simultaneously.

- seed:

  Optional integer seed (reserved for future randomised designs;
  currently unused as the function is deterministic).

## Value

A tibble: `sampling_frame` columns plus `p_period` and `inclusion_prob`.
`inclusion_prob = p_site * p_period`.
