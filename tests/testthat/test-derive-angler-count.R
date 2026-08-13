test_counts <- function() {
  data.frame(
    date = as.Date("2024-06-01") + c(0L, 0L, 1L, 1L),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    bank_anglers = c(4L, 2L, 9L, 1L),
    angler_boats = c(3L, 0L, 7L, 2L),
    boat_anglers = c(7L, 0L, 16L, 5L),
    stringsAsFactors = FALSE
  )
}

test_that("direct-count form adds bank and counted boat anglers", {
  out <- derive_angler_count(test_counts(), bank = bank_anglers, boat_anglers = boat_anglers)

  expect_equal(out$angler_count, c(11, 2, 25, 6))
})

test_that("expansion multiplies boats by party size before adding bank anglers", {
  # The order matters: bank anglers are people already, boats are not. Adding
  # first and expanding after would scale the shore count too.
  out <- derive_angler_count(
    test_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5
  )

  expect_equal(out$angler_count, c(4 + 7.5, 2 + 0, 9 + 17.5, 1 + 5))
})

test_that("boat_count without party_size is rejected because boats are not anglers", {
  # The whole point of separating boat_count from boat_anglers: a count of hulls
  # entering an angler total is a units error that yields a plausible number.
  expect_error(
    derive_angler_count(test_counts(), bank = bank_anglers, boat_count = angler_boats),
    "requires"
  )
})

test_that("supplying both boat forms is rejected because it would double the boat anglers", {
  expect_error(
    derive_angler_count(
      test_counts(),
      boat_anglers = boat_anglers,
      boat_count = angler_boats,
      party_size = 2
    ),
    "not both"
  )
})

test_that("party_size without boat_count is rejected", {
  expect_error(
    derive_angler_count(test_counts(), bank = bank_anglers, party_size = 2),
    "without"
  )
})

test_that("at least one component is required", {
  expect_error(derive_angler_count(test_counts()), "No count components")
})

test_that("a missing component yields a missing total rather than being treated as zero", {
  # A count that was not taken and a count of zero anglers are different
  # observations. Treating the first as the second understates nothing visibly
  # and biases the mean upward.
  counts <- test_counts()
  counts$bank_anglers[2] <- NA_integer_

  out <- derive_angler_count(counts, bank = bank_anglers, boat_anglers = boat_anglers)

  expect_true(is.na(out$angler_count[2]))
  expect_false(anyNA(out$angler_count[-2]))
})

test_that("a party-size lookup is applied per group", {
  lookup <- data.frame(
    day_type = c("weekday", "weekend"),
    mean_party_size = c(2, 3),
    stringsAsFactors = FALSE
  )

  out <- derive_angler_count(
    test_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = lookup
  )

  expect_equal(out$angler_count, c(4 + 6, 2 + 0, 9 + 21, 1 + 6))
})

test_that("a lookup that misses a count is an error, not a silent NA", {
  # An unmatched count has no defensible expansion. Returning NA would drop it
  # from the effort total and understate the season.
  lookup <- data.frame(
    day_type = "weekday",
    mean_party_size = 2,
    stringsAsFactors = FALSE
  )

  expect_error(
    derive_angler_count(test_counts(), boat_count = angler_boats, party_size = lookup),
    "no row for"
  )
})

test_that("a lookup must carry exactly one numeric column", {
  lookup <- data.frame(
    day_type = c("weekday", "weekend"),
    mean_party_size = c(2, 3),
    n = c(10, 20),
    stringsAsFactors = FALSE
  )

  expect_error(
    derive_angler_count(test_counts(), boat_count = angler_boats, party_size = lookup),
    "exactly one numeric column"
  )
})

test_that("a non-positive party size is rejected", {
  # A boat party holds at least one angler, so a mean of zero cannot be real and
  # would erase the boat component of every count.
  expect_error(
    derive_angler_count(test_counts(), boat_count = angler_boats, party_size = 0),
    "greater than zero"
  )
  expect_error(
    derive_angler_count(test_counts(), boat_count = angler_boats, party_size = -1),
    "greater than zero"
  )
})

test_that("party_size names a column of counts even when an object of that name exists", {
  # Resolution is decided from the expression, not by evaluating it, so the
  # column the user is looking at wins over a same-named object in their session.
  counts <- test_counts()
  counts$party <- c(2, 2, 3, 3)
  party <- 99

  out <- derive_angler_count(counts, boat_count = angler_boats, party_size = party)

  expect_equal(out$angler_count, c(6, 0, 21, 6))
})

test_that("writing over an existing column is refused", {
  counts <- test_counts()
  counts$angler_count <- 1

  expect_error(
    derive_angler_count(counts, bank = bank_anglers, boat_anglers = boat_anglers),
    "already exists"
  )
})

test_that("the output column can be renamed", {
  out <- derive_angler_count(
    test_counts(),
    bank = bank_anglers,
    boat_anglers = boat_anglers,
    to = "total_anglers"
  )

  expect_true("total_anglers" %in% names(out))
  expect_false("angler_count" %in% names(out))
})

test_that("a non-numeric component is rejected by name", {
  counts <- test_counts()
  counts$bank_anglers <- as.character(counts$bank_anglers)

  expect_error(
    derive_angler_count(counts, bank = bank_anglers, boat_anglers = boat_anglers),
    "numeric"
  )
})


test_interviews <- function() {
  data.frame(
    day_type = c("weekday", "weekday", "weekend", "weekend", "weekend"),
    angler_type = c("boat", "bank", "boat", "boat", "bank"),
    n_anglers = c(2, 10, 3, 5, 20),
    stringsAsFactors = FALSE
  )
}

test_that("mean_party_size uses boat parties only", {
  # Bank parties must not enter the multiplier that expands a count of boats.
  # The bank values here are large on purpose: including them would show.
  out <- mean_party_size(test_interviews(), n_anglers, angler_type = angler_type)

  expect_equal(as.numeric(out), mean(c(2, 3, 5)))
  # The standard error must be computed over the same restricted set. A bank
  # party leaking into the spread would inflate it without touching the mean.
  expect_equal(attr(out, "se"), sd(c(2, 3, 5)) / sqrt(3))
})

test_that("mean_party_size over every row when no angler_type is given", {
  out <- mean_party_size(test_interviews(), n_anglers)

  expect_equal(as.numeric(out), mean(c(2, 10, 3, 5, 20)))
  expect_equal(attr(out, "se"), sd(c(2, 10, 3, 5, 20)) / sqrt(5))
})

test_that("mean_party_size returns one value per group when by is supplied", {
  out <- mean_party_size(
    test_interviews(),
    n_anglers,
    angler_type = angler_type,
    by = day_type
  )

  expect_equal(nrow(out), 2L)
  expect_equal(out$mean_party_size[out$day_type == "weekday"], 2)
  expect_equal(out$mean_party_size[out$day_type == "weekend"], 4)
})

test_that("mean_party_size errors when no row matches boat_value", {
  # Silently returning NaN here would propagate into every expanded count.
  expect_error(
    mean_party_size(test_interviews(), n_anglers, angler_type = angler_type, boat_value = "vessel"),
    "No boat parties"
  )
})

test_that("mean_party_size output feeds derive_angler_count as a lookup", {
  lookup <- mean_party_size(
    test_interviews(),
    n_anglers,
    angler_type = angler_type,
    by = day_type
  )

  out <- derive_angler_count(
    test_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = lookup
  )

  expect_equal(out$angler_count, c(4 + 3 * 2, 2, 9 + 7 * 4, 1 + 2 * 4))
})
