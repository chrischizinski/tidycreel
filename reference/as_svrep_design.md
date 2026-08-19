# Extract replicate weights survey design from a repweights_design

Returns the embedded
[`survey::svrepdesign`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
object for bootstrap/jackknife/BRR designs.

## Usage

``` r
as_svrep_design(design)
```

## Arguments

- design:

  A `repweights_design` object

## Value

A
[`survey::svrepdesign`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
object

## Details

Use this helper for advanced variance estimation and resampling-based
inference. Raises an error if no embedded svrepdesign is found.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a replicate weights design first
# (design_repweights is an internal function)
access_design <- design_access(interviews, calendar)
# Then extract the survey design for advanced use
# svyrep <- as_svrep_design(rep_design)
} # }
```
