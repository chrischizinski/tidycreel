# Utility: Require Columns

Checks that all required columns are present in a data.frame. Throws an
error listing missing columns.

## Usage

``` r
tc_require_cols(df, cols, context = "")
```

## Arguments

- df:

  Data frame to check

- cols:

  Character vector of required column names

- context:

  Optional string describing the context (for error message)

## Value

Invisibly returns TRUE if all columns are present

## Examples

``` r
tc_require_cols(data.frame(a=1, b=2), c("a", "b"))
```
