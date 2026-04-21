# Package-standard colour palette for tidycreel plots

`creel_palette()` returns a small set of package-standard colours
derived from the tidycreel site palette. Use these colours directly in
custom plots or pair them with
[`theme_creel()`](https://chrischizinski.github.io/tidycreel/reference/theme_creel.md)
for a consistent visual style.

## Usage

``` r
creel_palette(n = NULL)
```

## Arguments

- n:

  Optional integer number of colours to return. When `NULL` (default),
  returns the full named palette.

## Value

When `n` is `NULL`, a named character vector of hex colours. Otherwise,
a character vector of length `n` recycling through the base palette as
needed.

## See also

Other "Visualisation":
[`autoplot.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_estimates.md),
[`autoplot.creel_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_length_distribution.md),
[`autoplot.creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_schedule.md),
[`plot_design()`](https://chrischizinski.github.io/tidycreel/reference/plot_design.md),
[`theme_creel()`](https://chrischizinski.github.io/tidycreel/reference/theme_creel.md)

## Examples

``` r
creel_palette()
#>   primary      link    accent      warm   neutral     light 
#> "#1B4F72" "#5DADE2" "#2c7fb8" "#d7191c" "#636e72" "#dfe6e9" 
creel_palette(3)
#>   primary      link    accent 
#> "#1B4F72" "#5DADE2" "#2c7fb8" 
```
