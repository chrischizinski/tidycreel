## Script to create the zip_county dataset (GH #376)
##
## One row per 2020 ZIP Code Tabulation Area (ZCTA): the county and state it
## is assigned to. Built from the U.S. Census Bureau's 2020 ZCTA-to-county
## relationship file, which is public domain.
##
## A ZCTA that crosses a county line (about 30% of them) is assigned to the
## county holding the largest share of its land area. Land area is not where
## people live, so a split ZCTA's anglers may live mostly in another county;
## the share is kept in `land_share` so a user can see how split each one is.
##
## ZCTAs are not USPS ZIP codes. PO-box-only and single-organisation ZIPs have
## no ZCTA, so summarize_by_county() reports them as "Unknown" unless the
## caller passes their own `lookup`.

source_url <- paste0(
  "https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/",
  "tab20_zcta520_county20_natl.txt"
)
# SHA-256 of the file as downloaded 2026-11-17. A mismatch means the Census
# Bureau has revised the file: rebuild deliberately, do not just update this.
source_sha256 <- "3ed41278d637dc249e0323306f68be8a6c234e3090f4de88ef328dee71aeaaaf"

path <- tempfile(fileext = ".txt")
utils::download.file(source_url, path, mode = "wb", quiet = TRUE)
got <- unname(cli::hash_file_sha256(path))
if (!identical(got, source_sha256)) {
  stop("Census relationship file changed: sha256 ", got, " != ", source_sha256)
}

x <- utils::read.delim(
  path,
  sep = "|", colClasses = "character", encoding = "UTF-8", check.names = FALSE
)
names(x)[1] <- sub("^﻿", "", names(x)[1])
x <- x[nzchar(x$GEOID_ZCTA5_20), ] # county rows with no ZCTA overlap
x$land <- as.numeric(x$AREALAND_PART)

# State FIPS -> USPS abbreviation for every state code the file uses.
state_fips <- c(
  "01" = "AL", "02" = "AK", "04" = "AZ", "05" = "AR", "06" = "CA",
  "08" = "CO", "09" = "CT", "10" = "DE", "11" = "DC", "12" = "FL",
  "13" = "GA", "15" = "HI", "16" = "ID", "17" = "IL", "18" = "IN",
  "19" = "IA", "20" = "KS", "21" = "KY", "22" = "LA", "23" = "ME",
  "24" = "MD", "25" = "MA", "26" = "MI", "27" = "MN", "28" = "MS",
  "29" = "MO", "30" = "MT", "31" = "NE", "32" = "NV", "33" = "NH",
  "34" = "NJ", "35" = "NM", "36" = "NY", "37" = "NC", "38" = "ND",
  "39" = "OH", "40" = "OK", "41" = "OR", "42" = "PA", "44" = "RI",
  "45" = "SC", "46" = "SD", "47" = "TN", "48" = "TX", "49" = "UT",
  "50" = "VT", "51" = "VA", "53" = "WA", "54" = "WV", "55" = "WI",
  "56" = "WY", "60" = "AS", "66" = "GU", "69" = "MP", "72" = "PR",
  "78" = "VI"
)
st <- substr(x$GEOID_COUNTY_20, 1, 2)
if (!all(st %in% names(state_fips))) {
  stop("Unmapped state FIPS: ", paste(setdiff(st, names(state_fips)), collapse = ", "))
}

total_land <- tapply(x$land, x$GEOID_ZCTA5_20, sum)
# Largest land share first; ties broken by county FIPS so the build is stable.
x <- x[order(x$GEOID_ZCTA5_20, -x$land, x$GEOID_COUNTY_20), ]
top <- x[!duplicated(x$GEOID_ZCTA5_20), ]
n_counties <- table(x$GEOID_ZCTA5_20)

zip_county <- data.frame(
  zip = top$GEOID_ZCTA5_20,
  county = enc2utf8(top$NAMELSAD_COUNTY_20),
  state = unname(state_fips[substr(top$GEOID_COUNTY_20, 1, 2)]),
  county_fips = top$GEOID_COUNTY_20,
  n_counties = as.integer(n_counties[top$GEOID_ZCTA5_20]),
  land_share = round(
    ifelse(total_land[top$GEOID_ZCTA5_20] > 0, top$land / total_land[top$GEOID_ZCTA5_20], 1),
    3
  ),
  stringsAsFactors = FALSE
)
row.names(zip_county) <- NULL

stopifnot(
  !anyDuplicated(zip_county$zip),
  all(nchar(zip_county$zip) == 5L),
  !anyNA(zip_county$state),
  all(zip_county$land_share > 0 & zip_county$land_share <= 1)
)

usethis::use_data(zip_county, overwrite = TRUE, compress = "xz")
