# inst/hex/sticker.R
# Reproducible hex sticker generator for the tidycreel package.
# Run from the package root: source("inst/hex/sticker.R")
#
# Brand palette (also used in _pkgdown.yml Phase 53):
#   Primary (h_fill) : #1B4F72  deep navy blue
#   Accent  (h_color): #5DADE2  teal border
#   Text    (p_color): #FFFFFF  white

library(hexSticker)
library(sysfonts)
library(showtext)

# Guard: must be run from package root
stopifnot(
  "Run from package root: source('inst/hex/sticker.R')" =
    file.exists("inst/hex/creel-basket.png")
)
stopifnot(
  "Font file missing: inst/hex/font/Nunito-Bold.ttf" =
    file.exists("inst/hex/font/Nunito-Bold.ttf")
)

# Load committed font — no network required
font_add("Nunito", regular = "inst/hex/font/Nunito-Bold.ttf", bold = "inst/hex/font/Nunito-Bold.ttf")
showtext_auto()

# Ensure output directory exists
dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)

# Generate sticker
# dpi = 694 yields ~1200x1390px at the standard 43.9x50.8mm hex physical size
sticker(
  subplot    = "inst/hex/creel-basket.png",
  s_x        = 1,
  s_y        = 0.88,
  s_width    = 0.53,
  s_height   = 0.53,
  package    = "tidycreel",
  p_x        = 1,
  p_y        = 1.52,
  p_color    = "#FFFFFF",
  p_family   = "Nunito",
  p_fontface = "bold",
  p_size     = 32,
  h_fill     = "#1B4F72",
  h_color    = "#5DADE2",
  h_size     = 1.6,
  filename   = "man/figures/logo.png",
  dpi        = 694
)

message("Logo written to man/figures/logo.png")
