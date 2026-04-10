# Standardize species names to AFS codes

Maps free-text species names in a data frame to canonical American
Fisheries Society (AFS) species codes, appending a `species_code`
column. Matching is case-insensitive and checks both exact common names
and comma-separated aliases bundled with the package. Values that
already look like a known AFS code (all-uppercase, 3 characters) are
passed through directly. Unmatched values are left as `NA` with a `cli`
warning listing the unrecognised inputs.

## Usage

``` r
standardize_species(
  data,
  species_col = "species",
  lookup = "AFS",
  fuzzy = TRUE,
  keep_original = TRUE
)
```

## Arguments

- data:

  A data frame containing a species name column.

- species_col:

  Character scalar naming the column that holds species names. Default
  `"species"`.

- lookup:

  Character scalar identifying the code system to use. Currently only
  `"AFS"` (default) is supported; passing any other value raises an
  error.

- fuzzy:

  Logical. If `TRUE` (default), aliases (common abbreviations and
  alternate names) are also searched. Set `FALSE` for strict common-name
  matching only.

- keep_original:

  Logical. If `TRUE` (default), the original `species_col` column is
  preserved unchanged. Set `FALSE` to drop it.

## Value

`data` with an additional `species_code` character column appended.
Unmatched rows receive `NA_character_`.

## Examples

``` r
interviews <- data.frame(
  date    = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
  species = c("walleye", "Largemouth Bass", "UNKNOWN"),
  kept    = c(2L, 1L, 0L)
)
standardize_species(interviews)
#> Warning: 1 species value(s) could not be matched to an
#> AFS code and will be "NA":
#> • "UNKNOWN"
#>         date         species kept species_code
#> 1 2024-06-01         walleye    2          WAE
#> 2 2024-06-02 Largemouth Bass    1          LMB
#> 3 2024-06-03         UNKNOWN    0         <NA>
```
