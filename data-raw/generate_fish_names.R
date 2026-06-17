# Generate release name list from FishBase cached data.
#
# Reads the rfishbase local cache (downloaded by rfishbase on first use)
# and produces data-raw/fish_release_names.txt: one clean English common
# name per line, alphabetically sorted and deduplicated.
#
# Names already used for releases are removed at the bottom of this script.
# Add the new name to the "used" vector before each release.
#
# Run interactively (not sourced during package build):
#   source("data-raw/generate_fish_names.R")

cache_file <- file.path(
  tools::R_user_dir("rfishbase", "data"),
  "comnames_fb_2104.tsv.bz2"
)

if (!file.exists(cache_file)) {
  message("Cache not found. Run `rfishbase::common_names()` once to populate it.")
  message("Requires: install.packages('rfishbase')")
  stop("Cache file missing: ", cache_file)
}

message("Reading FishBase common names cache...")
df <- read.delim(bzfile(cache_file), header = TRUE, quote = "",
                 stringsAsFactors = FALSE)
message(sprintf("Total rows: %d", nrow(df)))

# English only
eng <- df[df[["Language"]] == "English", ]
message(sprintf("English rows: %d", nrow(eng)))

names_raw <- eng[["ComName"]]
names_raw <- names_raw[!is.na(names_raw) & nchar(trimws(names_raw)) > 0]

# Quality filters
names_clean <- names_raw[!grepl("[0-9]", names_raw)]           # no digits
names_clean <- names_clean[!grepl("^[A-Z]{2,}$", names_clean)] # no acronyms
names_clean <- names_clean[nchar(names_clean) >= 5]             # min length
names_clean <- names_clean[!grepl("[,/()]", names_clean)]       # no punctuation
names_clean <- names_clean[
  !grepl("unspecified|unknown", names_clean, ignore.case = TRUE)
]

# Title-case and trim
to_title <- function(x) {
  gsub("(^|\\s)(\\S)", "\\1\\U\\2", trimws(x), perl = TRUE)
}
names_clean <- to_title(names_clean)

# Deduplicate and sort
names_final <- sort(unique(names_clean))

# ── Remove already-used release names ─────────────────────────────────────────
# Add entries here each time a name is assigned to a release.
used <- c(
  "Sauger",  # v2.1.0
  "Goldeye"  # v2.2.0
)
names_final <- names_final[!names_final %in% used]

message(sprintf("Total unique clean names: %d", length(names_final)))

out_path <- file.path("data-raw", "fish_release_names.txt")
writeLines(names_final, out_path)
message(sprintf("Written %d names to %s", length(names_final), out_path))
