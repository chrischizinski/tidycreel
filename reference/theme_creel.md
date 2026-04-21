# Package-standard ggplot2 theme for tidycreel plots

`theme_creel()` applies a light, publication-friendly theme aligned with
the package website colours. It is designed to be a stable default for
tidycreel examples, vignettes, and `autoplot()` methods.

## Usage

``` r
theme_creel(base_size = 11, base_family = "sans")
```

## Arguments

- base_size:

  Base text size. Default `11`.

- base_family:

  Base font family. Default `"sans"`.

## Value

A ggplot2 theme object.

## See also

Other "Visualisation":
[`autoplot.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_estimates.md),
[`autoplot.creel_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_length_distribution.md),
[`autoplot.creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_schedule.md),
[`creel_palette()`](https://chrischizinski.github.io/tidycreel/reference/creel_palette.md),
[`plot_design()`](https://chrischizinski.github.io/tidycreel/reference/plot_design.md)

## Examples

``` r
if (requireNamespace("ggplot2", quietly = TRUE)) {
  ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point(colour = creel_palette()[["primary"]]) +
    theme_creel()
}

```
