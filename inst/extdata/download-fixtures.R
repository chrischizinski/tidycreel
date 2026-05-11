# Download validation fixture data from the UNL Creel Survey API
#
# Fetches raw CSV data for all validation surveys and saves them under
# inst/extdata/<survey-slug>/. Run from the package root:
#
#   Rscript inst/extdata/download-fixtures.R
#
# Requires: jsonlite
# Note: includes design tables (design_general, design_periods, design_sections)
# needed to build sampling frames programmatically in validation scripts.

suppressPackageStartupMessages(library(jsonlite))

BASE_URL <- "https://creelsurvey.unl.edu/api/"

SURVEYS <- list(
  list(slug = "standing-bear-2019",    uid = "b87bda6a-1541-e911-b61d-0050568372f9", label = "Standing Bear 2019"),
  list(slug = "prairie-queen-2019",    uid = "a2837ba7-1741-e911-b61d-0050568372f9", label = "Prairie Queen 2019"),
  list(slug = "lake-halleck-2019",     uid = "a9a8c572-1841-e911-b61d-0050568372f9", label = "Lake Halleck 2019"),
  list(slug = "schwer-pond-2019",      uid = "052a2ac5-1841-e911-b61d-0050568372f9", label = "Schwer Pond 2019"),
  list(slug = "flanagan-2021",         uid = "c233b709-7464-ea11-b77b-0050568372f9", label = "Flanagan 2021"),
  list(slug = "walnut-creek-2021",     uid = "bebb3132-7464-ea11-b77b-0050568372f9", label = "Walnut Creek 2021"),
  list(slug = "benson-2021",           uid = "82121216-7464-ea11-b77b-0050568372f9", label = "Benson 2021"),
  list(slug = "offutt-2021",           uid = "6b2e9446-fb85-eb11-b77b-0050568372f9", label = "Offutt Base Lake 2021"),
  list(slug = "zorinsky-2022",         uid = "4fdea59c-2b9b-ec11-9136-00505686f278", label = "Zorinsky 2022"),
  list(slug = "lawrence-youngman-2022",uid = "dccd25a8-2e9b-ec11-9136-00505686f278", label = "Lawrence Youngman 2022"),
  list(slug = "mcconaughy-spawn-2022", uid = "72b3c7b3-329b-ec11-9136-00505686f278", label = "McConaughy Walleye Spawn 2022"),
  list(slug = "mcconaughy-spawn-2023", uid = "33038b0a-49cc-ed11-9148-00505686f278", label = "McConaughy Walleye Spawn 2023")
)

ENDPOINTS <- list(
  design_general  = "AnalysisData/GetDesignGeneral",
  design_periods  = "AnalysisData/GetDesignPeriods",
  design_sections = "AnalysisData/GetDesignSections",
  interviews      = "AnalysisData/GetInterviewData",
  counts          = "AnalysisData/GetCountData",
  catch           = "AnalysisData/GetCatchData",
  harvest_lengths = "AnalysisData/GetHarvestLengthData",
  release_lengths = "AnalysisData/GetReleaseLengthData"
)

api_get <- function(endpoint, uid) {
  url <- paste0(BASE_URL, endpoint, "?Creel_UIDs=", uid)
  message("  GET ", url)
  tryCatch(
    fromJSON(url, flatten = TRUE),
    error = function(e) {
      warning(sprintf("Failed: %s: %s", endpoint, conditionMessage(e)))
      NULL
    }
  )
}

save_table <- function(df, out_dir, name) {
  if (is.null(df) || (is.data.frame(df) && nrow(df) == 0)) {
    message(sprintf("  [skip] %s — empty", name))
    return(invisible(NULL))
  }
  if (!is.data.frame(df)) df <- as.data.frame(df)
  df <- df[, !grepl("^\\$", names(df)), drop = FALSE]
  path <- file.path(out_dir, paste0(name, ".csv"))
  write.csv(df, path, row.names = FALSE)
  message(sprintf("  [saved] %s (%d rows)", name, nrow(df)))
  invisible(path)
}

extdata_dir <- file.path("inst", "extdata")

for (survey in SURVEYS) {
  message("\n=== ", survey$label, " ===")
  out_dir <- file.path(extdata_dir, survey$slug)
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  for (table_name in names(ENDPOINTS)) {
    df <- api_get(ENDPOINTS[[table_name]], survey$uid)
    if (!is.null(df) && !is.data.frame(df)) df <- as.data.frame(df)
    save_table(df, out_dir, table_name)
  }
}

message("\nDone. Fixtures saved under inst/extdata/")
