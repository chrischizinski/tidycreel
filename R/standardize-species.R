# standardize_species() -------------------------------------------------------

# Internal AFS species lookup table.
# Sources: AFS Common and Scientific Names of Fishes (8th ed.)
# Covers freshwater sport fish common in creel surveys.
.afs_lookup <- data.frame(
  afs_code    = c(
    "WAE", "SMB", "LMB", "NOP", "MUE", "YEP",
    "BLG", "RBT", "BNT", "LKT", "CHS", "CHN",
    "COH", "SOC", "ATL", "PAC", "WPR", "SAU",
    "FHC", "CCF", "BUF", "CRP", "GPS", "WCR",
    "SPB", "STB", "WHB", "STR", "HYB", "BAS",
    "CRK", "BKT", "LAT", "GRY", "MWF", "ELP",
    "GLF", "BPS", "RSF", "CAS"
  ),
  common_name = c(
    "walleye", "smallmouth bass", "largemouth bass", "northern pike",
    "muskellunge", "yellow perch", "bluegill", "rainbow trout",
    "brown trout", "lake trout", "chinook salmon", "chinook salmon",
    "coho salmon", "sockeye salmon", "atlantic salmon", "pacific salmon",
    "white perch", "sauger", "flathead catfish", "channel catfish",
    "buffalo", "common carp", "gizzard shad", "white crappie",
    "spotted bass", "striped bass", "white bass", "shovelnose sturgeon",
    "hybrid striped bass", "bass", "creek chub", "brook trout",
    "lake whitefish", "arctic grayling", "mountain whitefish",
    "emerald shiner", "golden shiner", "black crappie", "redear sunfish",
    "caspian tern"
  ),
  aliases = c(
    "saugeye;pike-perch;yellow pike",
    "smallmouth;bronzeback;smb",
    "largemouth;bigmouth;lmb;green bass",
    "pike;northern",
    "muskie;musky;tiger muskie",
    "perch;ring perch;lake perch",
    "bream;sunfish;blugill",
    "rainbow;steelhead;redsides;rbt",
    "brown;german brown;loch leven;bnt",
    "lakers;mackinaw;lkt",
    "king salmon;chinook;tyee",
    "king salmon;chinook;tyee",
    "silver salmon;coho",
    "red salmon;kokanee",
    "atlantic;salmon",
    "pacific salmon;oncorhynchus",
    "silver perch;white perch",
    "sauger;sand pike",
    "flathead;shovelhead;mudcat",
    "channel cat;blue channel",
    "bigmouth buffalo;smallmouth buffalo",
    "carp;german carp;mirror carp",
    "shad;gizzard shad",
    "white crappie;papermouth",
    "spotted;ky bass;kentucky bass",
    "striper;rockfish;striped bass",
    "white bass;sand bass",
    "sturgeon;shovelnose",
    "hybrid;sunshine bass;palmetto bass",
    "bass",
    "creek;chub",
    "brook;speckled trout;squaretail;bkt",
    "whitefish;lake whitefish;tullibee",
    "grayling",
    "mountain whitefish;rocky mountain whitefish",
    "shiner;emerald",
    "golden shiner;bream",
    "black crappie;papermouth;specks",
    "redear;shellcracker;stumpknocker",
    "tern;caspian"
  ),
  stringsAsFactors = FALSE
)

#' Standardize species names to AFS codes
#'
#' Maps free-text species names in a data frame to canonical American
#' Fisheries Society (AFS) species codes, appending a `species_code` column.
#' Matching is case-insensitive and checks both exact common names and
#' comma-separated aliases bundled with the package.  Values that already
#' look like a known AFS code (all-uppercase, 3 characters) are passed
#' through directly.  Unmatched values are left as `NA` with a `cli` warning
#' listing the unrecognised inputs.
#'
#' @param data A data frame containing a species name column.
#' @param species_col Character scalar naming the column that holds species
#'   names.  Default `"species"`.
#' @param lookup Character scalar identifying the code system to use.
#'   Currently only `"AFS"` (default) is supported; passing any other value
#'   raises an error.
#' @param fuzzy Logical.  If `TRUE` (default), aliases (common abbreviations
#'   and alternate names) are also searched.  Set `FALSE` for strict
#'   common-name matching only.
#' @param keep_original Logical.  If `TRUE` (default), the original
#'   `species_col` column is preserved unchanged.  Set `FALSE` to drop it.
#'
#' @return `data` with an additional `species_code` character column appended.
#'   Unmatched rows receive `NA_character_`.
#'
#' @examples
#' interviews <- data.frame(
#'   date    = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
#'   species = c("walleye", "Largemouth Bass", "UNKNOWN"),
#'   kept    = c(2L, 1L, 0L)
#' )
#' standardize_species(interviews)
#'
#' @export
standardize_species <- function(
    data,
    species_col    = "species",
    lookup         = "AFS",
    fuzzy          = TRUE,
    keep_original  = TRUE) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame.")
  }
  bad_col <- !is.character(species_col) || length(species_col) != 1L
  if (bad_col) {
    cli::cli_abort("{.arg species_col} must be a single character string.")
  }
  if (!species_col %in% names(data)) {
    cli::cli_abort(
      "Column {.field {species_col}} not found in {.arg data}."
    )
  }
  bad_lookup <- !is.character(lookup) ||
    length(lookup) != 1L ||
    toupper(lookup) != "AFS"
  if (bad_lookup) {
    cli::cli_abort(
      "{.arg lookup} must be {.val AFS}; no other code systems are ",
      "currently supported."
    )
  }

  raw <- data[[species_col]]
  codes <- .resolve_species_codes(raw, fuzzy = fuzzy)

  unmatched <- unique(raw[is.na(codes) & !is.na(raw)])
  if (length(unmatched) > 0L) {
    cli::cli_warn(c(
      "{length(unmatched)} species value(s) could not be matched to an ",
      "AFS code and will be {.val NA}:",
      stats::setNames(
        paste0("{.val ", unmatched, "}"),
        rep("*", length(unmatched))
      )
    ))
  }

  if (!keep_original) {
    data[[species_col]] <- NULL
  }

  data[["species_code"]] <- codes
  data
}

# ---- Internal helpers -------------------------------------------------------

# Vectorised species code resolver.
.resolve_species_codes <- function(raw, fuzzy) {
  lkp   <- .afs_lookup
  lower <- tolower(trimws(raw))

  # Pass-through: looks like a known 3-letter AFS code already.
  known_codes <- toupper(lkp$afs_code)
  is_code     <- toupper(raw) %in% known_codes & !is.na(raw)

  codes <- ifelse(is_code, toupper(raw), NA_character_)

  # Exact common-name match (case-insensitive).
  lkp_lower <- tolower(lkp$common_name)
  name_idx  <- match(lower, lkp_lower)
  codes     <- ifelse(is.na(codes) & !is.na(name_idx),
    lkp$afs_code[name_idx],
    codes
  )

  # Alias match (case-insensitive, semicolon-separated within each row).
  if (fuzzy) {
    codes <- .match_aliases(codes, lower, lkp)
  }

  codes
}

# Match remaining NAs against alias strings.
.match_aliases <- function(codes, lower, lkp) {
  still_na <- which(is.na(codes))
  if (length(still_na) == 0L) return(codes)

  for (i in seq_len(nrow(lkp))) {
    aliases <- strsplit(lkp$aliases[i], ";")[[1]]
    aliases <- trimws(tolower(aliases))
    hit     <- lower[still_na] %in% aliases
    if (any(hit)) {
      codes[still_na[hit]] <- lkp$afs_code[i]
      still_na <- still_na[!hit]
    }
    if (length(still_na) == 0L) break
  }

  codes
}
