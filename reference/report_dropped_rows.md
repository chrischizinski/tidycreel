# Report dropped rows

Returns a summary of rows dropped due to missing or invalid data.

## Usage

``` r
report_dropped_rows(original, filtered)
```

## Arguments

- original:

  Original data.frame

- filtered:

  Filtered data.frame

## Value

List with n_dropped and dropped_rows

## Examples

``` r
df_original <- data.frame(id = 1:3, value = c(10, NA, 30))
df_cleaned <- data.frame(id = c(1, 3), value = c(10, 30))
report_dropped_rows(df_original, df_cleaned)
#> $n_dropped
#> [1] 1
#> 
#> $dropped_rows
#>   id value
#> 1  2    NA
#> 
```
