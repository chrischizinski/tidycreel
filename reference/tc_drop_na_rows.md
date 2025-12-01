# Drop rows with missing values in required columns; return diagnostics

Drop rows with missing values in required columns; return diagnostics

## Usage

``` r
tc_drop_na_rows(df, required_cols, reason = "missing required fields")
```

## Arguments

- df:

  data.frame

- required_cols:

  character vector of column names

- reason:

  text reason for diagnostics

## Value

list(df = filtered_df, diagnostics = tibble)
