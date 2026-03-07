## data-raw/create_example_lengths.R
## Produces example_lengths: mixed individual/binned length data
## 14 harvest rows (numeric mm, NA count) + 6 release rows (char bin, int count)

example_lengths <- data.frame(
  interview_id = c(
    1L, 1L, 1L, # 3 harvest walleye
    2L, 2L, # 2 harvest bass
    6L, 6L, 6L, # 3 harvest walleye
    6L, 6L, # 2 release walleye (binned)
    8L, 8L, # 2 harvest panfish
    9L, 9L, # 2 harvest walleye
    9L, 9L, # 2 release bass (binned)
    12L, 12L, # 2 harvest bass
    20L, 20L # 2 release panfish (binned)
  ),
  species = c(
    "walleye", "walleye", "walleye",
    "bass", "bass",
    "walleye", "walleye", "walleye",
    "walleye", "walleye",
    "panfish", "panfish",
    "walleye", "walleye",
    "bass", "bass",
    "bass", "bass",
    "panfish", "panfish"
  ),
  length = c(
    "420", "385", "401",
    "245", "278",
    "512", "488", "501",
    "400-450", "350-400",
    "155", "162",
    "390", "415",
    "250-300", "300-350",
    "268", "283",
    "150-200", "200-250"
  ),
  length_type = c(
    "harvest", "harvest", "harvest",
    "harvest", "harvest",
    "harvest", "harvest", "harvest",
    "release", "release",
    "harvest", "harvest",
    "harvest", "harvest",
    "release", "release",
    "harvest", "harvest",
    "release", "release"
  ),
  count = c(
    NA_integer_, NA_integer_, NA_integer_,
    NA_integer_, NA_integer_,
    NA_integer_, NA_integer_, NA_integer_,
    3L, 2L,
    NA_integer_, NA_integer_,
    NA_integer_, NA_integer_,
    4L, 5L,
    NA_integer_, NA_integer_,
    6L, 3L
  ),
  stringsAsFactors = FALSE
)

# Quality checks
stopifnot(nrow(example_lengths) == 20L)
stopifnot(all(c("interview_id", "species", "length", "length_type", "count") %in%
  names(example_lengths)))
stopifnot(all(example_lengths$length_type %in% c("harvest", "release")))
stopifnot(all(example_lengths$interview_id %in% c(1L, 2L, 6L, 8L, 9L, 12L, 20L)))
harvest_rows <- example_lengths[example_lengths$length_type == "harvest", ]
release_rows <- example_lengths[example_lengths$length_type == "release", ]
stopifnot(nrow(harvest_rows) == 14L)
stopifnot(nrow(release_rows) == 6L)
stopifnot(all(is.na(harvest_rows$count)))
stopifnot(all(!is.na(release_rows$count) & release_rows$count > 0L))

usethis::use_data(example_lengths, overwrite = TRUE)
message("example_lengths: ", nrow(example_lengths), " rows saved")
