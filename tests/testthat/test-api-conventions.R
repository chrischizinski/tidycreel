# The checkable rules of vignettes/articles/api-conventions.Rmd.
#
# These tests guard the public API against drift: a new export must belong to
# a function family, take the family's first argument, and use the shared
# argument names in the shared order. Where the package does not meet a rule
# today, the gap is listed below as a named exception with its reason. The
# lists can only shrink: an exception that is no longer needed fails the test,
# so a rename that fixes a gap must also delete its entry.

exported_functions <- function() {
  ns <- asNamespace("tidycreel")
  fx <- getNamespaceExports("tidycreel")
  sort(fx[vapply(fx, function(n) is.function(get(n, envir = ns)), logical(1))])
}

export_formals <- function(fx) {
  ns <- asNamespace("tidycreel")
  lapply(stats::setNames(fx, fx), function(n) names(formals(get(n, envir = ns))))
}

# Prefixes (or whole names) of the function families in the conventions article.
family_pattern <- paste0(
  "^(",
  paste(
    c(
      "creel_design$", "add_", "prep_", "estimate_", "summarize_",
      "validate_", "check_", "generate_", "creel_n_", "get_", "as_",
      "write_", "read_", "compare_", "simulate_",
      "autoplot$", "theme_creel$", "creel_palette$"
    ),
    collapse = "|"
  ),
  ")"
)

# Exports outside every family, with the reason each is allowed for now.
family_exceptions <- c(
  # #477: est_* and estimate_* coexist.
  est_age_distribution = "#477",
  est_biomass = "#477",
  est_compliance = "#477",
  est_effort_camera = "#477",
  est_effort_camera_mi = "#477",
  est_length_distribution = "#477",
  est_mean_age = "#477",
  est_mean_length = "#477",
  # Sample-size planning uses several patterns besides creel_n_*().
  creel_power = "planning",
  power_creel = "planning",
  optimal_n = "planning",
  cv_from_n = "planning",
  reallocate_strata = "planning",
  # Schema and vocabulary objects.
  creel_schema = "schema",
  creel_vocabulary = "schema",
  # Data preparation helpers outside prep_*().
  compute_angler_effort = "data preparation",
  compute_effort = "data preparation",
  derive_angler_count = "data preparation",
  preprocess_camera_timestamps = "data preparation",
  impute_camera_counts = "data preparation",
  standardize_species = "data preparation",
  flag_outliers = "data preparation",
  adjust_nonresponse = "data preparation",
  mean_party_size = "data preparation",
  # Schedule helpers outside generate_*().
  attach_count_times = "scheduling",
  new_creel_schedule = "scheduling",
  day_length = "scheduling",
  daylight_shifts = "scheduling",
  # Diagnostics and reporting outside validate_*()/summarize_*().
  audit_strata = "diagnostics",
  validation_report = "diagnostics",
  season_summary = "reporting",
  plot_design = "plotting"
)

# Members of design-first families whose first argument is not `design`.
design_first_exceptions <- c(
  # Calculators: they take summary numbers or another estimate, not a design.
  estimate_angler_n = "calculator",
  estimate_angler_trips = "calculator",
  estimate_effort_per_acre = "calculator",
  estimate_exploitation_rate = "calculator",
  estimate_mr_harvest = "calculator",
  as_hybrid_svydesign = "builds a design from count frames",
  get_site_contributions = "reads a creel_estimates result",
  get_warnings = "reads a design or a creel_estimates result (#496)"
)

# Exports whose shared arguments are not in the shared relative order.
order_exceptions <- c(
  estimate_exploitation_rate = "calculator; by follows its stratification arguments",
  # by was appended after target (#366) so existing positional calls kept working.
  estimate_effort_aerial_glmm = "by appended last (#366)"
)

test_that("every export belongs to a function family or is a listed exception", {
  fx <- exported_functions()
  outside <- fx[!grepl(family_pattern, fx)]

  # A new export outside every family has to be a deliberate, reviewed choice.
  expect_identical(setdiff(outside, names(family_exceptions)), character(0))
  # An exception that now fits a family (or no longer exists) must be removed.
  expect_identical(setdiff(names(family_exceptions), outside), character(0))
})

test_that("design-first families take the design as their first argument", {
  fx <- exported_functions()
  fx <- fx[grepl("^(add_|estimate_|summarize_|get_|as_)", fx)]
  first <- vapply(export_formals(fx), function(a) if (length(a)) a[[1]] else "", "")
  offenders <- names(first)[first != "design"]

  # The design first is what makes creel_design() |> add_*() |> estimate_*() pipe.
  expect_identical(setdiff(offenders, names(design_first_exceptions)), character(0))
  expect_identical(setdiff(names(design_first_exceptions), offenders), character(0))
})

test_that("shared arguments keep one name and one relative order", {
  args <- export_formals(exported_functions())

  # One name per concept: a synonym for by/variance/conf_level would make users
  # guess per function.
  synonyms <- c(
    "level", "conf", "confidence", "ci_level", "group", "groups",
    "grouping", "strata_var", "var_method", "variance_method"
  )
  uses_synonym <- Filter(length, lapply(args, intersect, synonyms))
  expect_identical(names(uses_synonym), character(0))

  shared <- c("by", "variance", "conf_level", "target")
  out_of_order <- names(Filter(function(a) {
    pos <- match(shared, a)
    is.unsorted(pos[!is.na(pos)])
  }, args))
  expect_identical(setdiff(out_of_order, names(order_exceptions)), character(0))
  expect_identical(setdiff(names(order_exceptions), out_of_order), character(0))
})

test_that("function names use the summarize spelling", {
  fx <- exported_functions()
  expect_identical(grep("summarise", fx, value = TRUE), character(0))
})
