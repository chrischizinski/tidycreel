# inst/hex/sticker.R
# Sync the committed tidycreel hex sticker to package and website asset paths.
# The canonical art is a hand-authored PNG, not a programmatic hexSticker build.
# Run from the package root: source("inst/hex/sticker.R")

source_png <- "man/figures/logo.png"

stopifnot(
  "Run from package root: source('inst/hex/sticker.R')" =
    file.exists(source_png)
)

dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)

target_files <- c(
  "man/figures/tidycreel-hex.png"
)

copied <- file.copy(source_png, target_files, overwrite = TRUE)

stopifnot(
  "Failed to sync one or more hex sticker outputs." = all(copied)
)

message("Synced hex sticker to:")
for (target in target_files) {
  message("  - ", target)
}

if (dir.exists("docs")) {
  docs_logo <- "docs/logo.png"
  stopifnot(
    "Failed to sync docs/logo.png." =
      file.copy(source_png, docs_logo, overwrite = TRUE)
  )
  message("  - ", docs_logo)
}

if (!requireNamespace("magick", quietly = TRUE)) {
  message("Package 'magick' not installed; skipping favicon regeneration.")
  invisible(target_files)
} else {
  favicon_dir <- "pkgdown/favicon"
  dir.create(favicon_dir, recursive = TRUE, showWarnings = FALSE)

  img <- magick::image_read(source_png)

  magick::image_write(
    magick::image_resize(img, "180x180"),
    path = file.path(favicon_dir, "apple-touch-icon.png"),
    format = "png"
  )
  magick::image_write(
    magick::image_resize(img, "96x96"),
    path = file.path(favicon_dir, "favicon-96x96.png"),
    format = "png"
  )
  magick::image_write(
    magick::image_resize(img, "192x192"),
    path = file.path(favicon_dir, "web-app-manifest-192x192.png"),
    format = "png"
  )
  magick::image_write(
    magick::image_resize(img, "512x512"),
    path = file.path(favicon_dir, "web-app-manifest-512x512.png"),
    format = "png"
  )

  message("Regenerated pkgdown favicon PNG assets.")

  if (dir.exists("docs")) {
    docs_targets <- c(
      "apple-touch-icon.png",
      "favicon-96x96.png",
      "web-app-manifest-192x192.png",
      "web-app-manifest-512x512.png"
    )
    copied_docs <- file.copy(
      from = file.path(favicon_dir, docs_targets),
      to = file.path("docs", docs_targets),
      overwrite = TRUE
    )
    stopifnot(
      "Failed to sync one or more docs favicon PNG assets." = all(copied_docs)
    )
    message("Synced docs favicon PNG assets.")
  }

  message("Update favicon.ico and favicon.svg separately if the source art changes.")
  invisible(c(target_files, favicon_dir))
}
