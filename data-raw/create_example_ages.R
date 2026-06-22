## data-raw/create_example_ages.R
## Produces example_ages: individual fish age records (one row per aged fish)
## Ages are discrete integers (0-6); both harvest and release fates.
## Interview IDs reference a subset of example_interviews IDs.

example_ages <- data.frame(
  interview_id = c(
    1L, 1L, 1L, # 3 harvest walleye
    2L, 2L, # 2 harvest bass
    6L, 6L, 6L, # 3 harvest walleye
    6L, 6L, # 2 release walleye
    8L, 8L, # 2 harvest panfish
    9L, # 1 harvest walleye
    9L, 9L, # 2 release bass
    12L, # 1 harvest bass
    20L, 20L # 2 release panfish
  ),
  species = c(
    "walleye", "walleye", "walleye",
    "bass", "bass",
    "walleye", "walleye", "walleye",
    "walleye", "walleye",
    "panfish", "panfish",
    "walleye",
    "bass", "bass",
    "bass",
    "panfish", "panfish"
  ),
  age = c(
    4L, 3L, 5L,
    2L, 3L,
    6L, 5L, 6L,
    3L, 4L,
    1L, 2L,
    4L,
    2L, 3L,
    3L,
    0L, 1L
  ),
  age_type = c(
    "harvest", "harvest", "harvest",
    "harvest", "harvest",
    "harvest", "harvest", "harvest",
    "release", "release",
    "harvest", "harvest",
    "harvest",
    "release", "release",
    "harvest",
    "release", "release"
  ),
  stringsAsFactors = FALSE
)

# Quality checks
stopifnot(nrow(example_ages) == 18L)
stopifnot(all(c("interview_id", "species", "age", "age_type") %in%
  names(example_ages)))
stopifnot(all(example_ages$age_type %in% c("harvest", "release")))
stopifnot(all(example_ages$interview_id %in% c(1L, 2L, 6L, 8L, 9L, 12L, 20L)))
stopifnot(all(example_ages$age >= 0L & example_ages$age <= 6L))
stopifnot(length(unique(example_ages$species)) == 3L)
stopifnot(sum(example_ages$age_type == "harvest") == 12L)
stopifnot(sum(example_ages$age_type == "release") == 6L)

usethis::use_data(example_ages, overwrite = TRUE)
message("example_ages: ", nrow(example_ages), " rows saved")
