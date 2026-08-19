# Run All Schema Validation Functions

This function runs all available schema validation functions on a named
list of tibbles. It returns a list of results (invisible if all pass,
errors if any fail).

## Usage

``` r
schema_test_runner(data_list, strict = TRUE)
```

## Arguments

- data_list:

  Named list of tibbles: names must match schema types (calendar,
  interviews, counts, auxiliary, reference)

- strict:

  Logical, if TRUE throws error on validation failure

## Value

Invisibly returns validated data, or errors if invalid

## Examples

``` r
# \donttest{
if (FALSE) { # \dontrun{
schema_test_runner(list(
  calendar = calendar_tbl,
  interviews = interviews_tbl,
  counts = counts_tbl,
  auxiliary = auxiliary_tbl,
  reference = reference_tbl
))
} # }
# }
```
