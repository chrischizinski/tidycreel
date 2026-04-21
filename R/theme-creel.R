# Package plotting theme helpers ----

#' Package-standard colour palette for tidycreel plots
#'
#' @description
#' `creel_palette()` returns a small set of package-standard colours derived
#' from the tidycreel site palette. Use these colours directly in custom plots
#' or pair them with [theme_creel()] for a consistent visual style.
#'
#' @param n Optional integer number of colours to return. When `NULL` (default),
#'   returns the full named palette.
#'
#' @return When `n` is `NULL`, a named character vector of hex colours.
#'   Otherwise, a character vector of length `n` recycling through the base
#'   palette as needed.
#'
#' @examples
#' creel_palette()
#' creel_palette(3)
#'
#' @family "Visualisation"
#' @export
creel_palette <- function(n = NULL) {
  palette_vals <- c(
    primary = "#1B4F72",
    link = "#5DADE2",
    accent = "#2c7fb8",
    warm = "#d7191c",
    neutral = "#636e72",
    light = "#dfe6e9"
  )

  if (is.null(n)) {
    return(palette_vals)
  }

  if (!is.numeric(n) || length(n) != 1L || n < 1) {
    cli::cli_abort("{.arg n} must be a single positive number when provided.")
  }

  palette_vals[seq_len(n) %% length(palette_vals)]
}

#' Package-standard ggplot2 theme for tidycreel plots
#'
#' @description
#' `theme_creel()` applies a light, publication-friendly theme aligned with the
#' package website colours. It is designed to be a stable default for tidycreel
#' examples, vignettes, and `autoplot()` methods.
#'
#' @param base_size Base text size. Default `11`.
#' @param base_family Base font family. Default `"sans"`.
#'
#' @return A ggplot2 theme object.
#'
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
#'     ggplot2::geom_point(colour = creel_palette()[["primary"]]) +
#'     theme_creel()
#' }
#'
#' @family "Visualisation"
#' @export
theme_creel <- function(base_size = 11, base_family = "sans") {
  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(
        face = "bold",
        colour = creel_palette()[["primary"]]
      ),
      plot.subtitle = ggplot2::element_text(
        colour = creel_palette()[["neutral"]]
      ),
      axis.title = ggplot2::element_text(
        face = "bold",
        colour = creel_palette()[["primary"]]
      ),
      axis.text = ggplot2::element_text(
        colour = creel_palette()[["neutral"]]
      ),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_line(
        colour = creel_palette()[["light"]],
        linewidth = 0.3
      ),
      strip.text = ggplot2::element_text(
        face = "bold",
        colour = creel_palette()[["primary"]]
      ),
      legend.title = ggplot2::element_text(
        face = "bold",
        colour = creel_palette()[["primary"]]
      ),
      legend.text = ggplot2::element_text(
        colour = creel_palette()[["neutral"]]
      )
    )
}
