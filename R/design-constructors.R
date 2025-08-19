#' Survey Design Constructors for Access-Point Creel Surveys
#'
#' These functions create survey design objects for different types of
#' access-point creel surveys, including standard access designs, roving
#' designs, and designs with replicate weights.
#'
#' @name design-constructors
#' @aliases design_access design_roving design_repweights
NULL

#' Create Access-Point Survey Design
#'
#' Constructs a survey design object for access-point creel surveys where
#' interviews are conducted at fixed access locations. This design assumes
#' complete coverage of exiting anglers during interview periods.
#'
#' @param interviews A tibble containing interview data validated by
#'   [validate_interviews()]. Must include columns for location, date,
#'   party_size, hours_fished, and effort_expansion.
#' @param calendar A tibble containing calendar data validated by
#'   [validate_calendar()]. Must include columns for date, stratum_id,
#'   target_sample, and actual_sample.
#' @param locations A character vector of sampling locations. If NULL,
#'   uses unique locations from interview data.
#' @param strata_vars Character vector of variables to use for stratification.
#'   Default is c("date", "shift_block").
#' @param weight_method Character specifying weight calculation method.
#'   Options: "standard" (default), "post_stratify", "calibrate".
#'
#' @return A list object of class "access_design" containing:
#'   \describe{
#'     \item{design_type}{Character: "access_point"}
#'     \item{interviews}{Validated interview data}
#'     \item{calendar}{Validated calendar data}
#'     \item{locations}{Sampling locations}
#'     \item{strata_vars}{Stratification variables}
#'     \item{weight_method}{Weight calculation method}
#'     \item{design_weights}{Calculated design weights}
#'     \item{metadata}{Additional metadata including creation time}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Load example data
#' interviews <- readr::read_csv(system.file("extdata/toy_interviews.csv", 
#'                                          package = "tidycreel"))
#' calendar <- readr::read_csv(system.file("extdata/toy_calendar.csv", 
#'                                       package = "tidycreel"))
#'
#' # Create access design
#' design <- design_access(
#'   interviews = interviews,
#'   calendar = calendar,
#'   strata_vars = c("date", "shift_block", "location")
#' )
#' }
design_access <- function(interviews, calendar, locations = NULL, 
                         strata_vars = c("date", "shift_block"), 
                         weight_method = "standard") {
  
  # Validate inputs
  interviews <- validate_interviews(interviews)
  calendar <- validate_calendar(calendar)
  
  # Set locations
  if (is.null(locations)) {
    locations <- unique(interviews$location)
  }
  
  # Validate weight method
  weight_method <- match.arg(weight_method, 
                           choices = c("standard", "post_stratify", "calibrate"))
  
  # Calculate design weights
  design_weights <- calculate_access_weights(
    interviews = interviews,
    calendar = calendar,
    strata_vars = strata_vars,
    weight_method = weight_method
  )
  
  # Create design object
  design <- list(
    design_type = "access_point",
    interviews = interviews,
    calendar = calendar,
    locations = locations,
    strata_vars = strata_vars,
    weight_method = weight_method,
    design_weights = design_weights,
    metadata = list(
      creation_time = Sys.time(),
      package_version = utils::packageVersion("tidycreel")
    )
  )
  
  class(design) <- c("access_design", "creel_design", "list")
  return(design)
}

#' Create Roving Survey Design
#'
#' Constructs a survey design object for roving creel surveys where
#' interviews are conducted while moving between locations. This design
#' accounts for incomplete coverage and requires effort estimation.
#'
#' @param interviews A tibble containing interview data validated by
#'   [validate_interviews()]. Must include columns for location, date,
#'   time_start, time_end, party_size, hours_fished, and effort_expansion.
#' @param counts A tibble containing instantaneous count data validated by
#'   [validate_counts()]. Must include columns for location, date, time,
#'   anglers_count, and parties_count.
#' @param calendar A tibble containing calendar data validated by
#'   [validate_calendar()]. Must include columns for date, stratum_id,
#'   target_sample, and actual_sample.
#' @param locations A character vector of sampling locations. If NULL,
#'   uses union of locations from interview and count data.
#' @param strata_vars Character vector of variables to use for stratification.
#'   Default is c("date", "shift_block", "location").
#' @param effort_method Character specifying effort estimation method.
#'   Options: "ratio" (default), "calibrate", "model_based".
#' @param coverage_correction Logical, whether to apply coverage correction
#'   for incomplete spatial/temporal coverage. Default TRUE.
#'
#' @return A list object of class "roving_design" containing:
#'   \describe{
#'     \item{design_type}{Character: "roving"}
#'     \item{interviews}{Validated interview data}
#'     \item{counts}{Validated count data}
#'     \item{calendar}{Validated calendar data}
#'     \item{locations}{Sampling locations}
#'     \item{strata_vars}{Stratification variables}
#'     \item{effort_method}{Effort estimation method}
#'     \item{coverage_correction}{Whether coverage correction is applied}
#'     \item{design_weights}{Calculated design weights}
#'     \item{effort_estimates}{Estimated fishing effort by stratum}
#'     \item{metadata}{Additional metadata}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Load example data
#' interviews <- readr::read_csv(system.file("extdata/toy_interviews.csv", 
#'                                          package = "tidycreel"))
#' counts <- readr::read_csv(system.file("extdata/toy_counts.csv", 
#'                                     package = "tidycreel"))
#' calendar <- readr::read_csv(system.file("extdata/toy_calendar.csv", 
#'                                       package = "tidycreel"))
#'
#' # Create roving design
#' design <- design_roving(
#'   interviews = interviews,
#'   counts = counts,
#'   calendar = calendar,
#'   effort_method = "ratio"
#' )
#' }
design_roving <- function(interviews, counts, calendar, locations = NULL,
                         strata_vars = c("date", "shift_block", "location"),
                         effort_method = "ratio",
                         coverage_correction = TRUE) {
  
  # Validate inputs
  interviews <- validate_interviews(interviews)
  counts <- validate_counts(counts)
  calendar <- validate_calendar(calendar)
  
  # Set locations
  if (is.null(locations)) {
    locations <- union(unique(interviews$location), unique(counts$location))
  }
  
  # Validate methods
  effort_method <- match.arg(effort_method,
                           choices = c("ratio", "calibrate", "model_based"))
  
  # Calculate effort estimates
  effort_estimates <- calculate_roving_effort(
    interviews = interviews,
    counts = counts,
    calendar = calendar,
    strata_vars = strata_vars,
    effort_method = effort_method
  )
  
  # Calculate design weights
  design_weights <- calculate_roving_weights(
    interviews = interviews,
    effort_estimates = effort_estimates,
    strata_vars = strata_vars
  )
  
  # Create design object
  design <- list(
    design_type = "roving",
    interviews = interviews,
    counts = counts,
    calendar = calendar,
    locations = locations,
    strata_vars = strata_vars,
    effort_method = effort_method,
    coverage_correction = coverage_correction,
    design_weights = design_weights,
    effort_estimates = effort_estimates,
    metadata = list(
      creation_time = Sys.time(),
      package_version = utils::packageVersion("tidycreel")
    )
  )
  
  class(design) <- c("roving_design", "creel_design", "list")
  return(design)
}

#' Create Survey Design with Replicate Weights
#'
#' Constructs a survey design object that incorporates replicate weights
#' for variance estimation. Supports both access-point and roving designs
#' with bootstrap or jackknife replicate weights.
#'
#' @param base_design A creel design object created by [design_access()] or
#'   [design_roving()].
#' @param replicates Integer specifying number of replicate weights to create.
#'   Default is 100 for bootstrap, or determined by design for jackknife.
#' @param method Character specifying replicate weight method.
#'   Options: "bootstrap" (default), "jackknife", "brr" (balanced repeated replication).
#' @param strata_var Character specifying stratification variable for
#'   replicate creation. If NULL, uses strata from base design.
#' @param cluster_var Character specifying cluster variable for
#'   replicate creation. If NULL, uses location as cluster.
#' @param seed Integer random seed for reproducibility.
#'
#' @return A list object of class "repweights_design" containing:
#'   \describe{
#'     \item{base_design}{Original design object}
#'     \item{replicate_weights}{Matrix of replicate weights}
#'     \item{replicate_method}{Method used to create replicates}
#'     \item{replicates}{Number of replicates}
#'     \item{scale_factors}{Scaling factors for variance estimation}
#'     \item{metadata}{Additional metadata including creation time and seed}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Create base design
#' interviews <- readr::read_csv(system.file("extdata/toy_interviews.csv", 
#'                                          package = "tidycreel"))
#' calendar <- readr::read_csv(system.file("extdata/toy_calendar.csv", 
#'                                       package = "tidycreel"))
#'
#' base_design <- design_access(interviews = interviews, calendar = calendar)
#'
#' # Add replicate weights
#' rep_design <- design_repweights(
#'   base_design = base_design,
#'   replicates = 50,
#'   method = "bootstrap",
#'   seed = 12345
#' )
#' }
design_repweights <- function(base_design, replicates = NULL, 
                            method = "bootstrap", strata_var = NULL,
                            cluster_var = NULL, seed = NULL) {
  
  # Validate base design
  if (!inherits(base_design, "creel_design")) {
    cli::cli_abort("{.arg base_design} must be a creel design object")
  }
  
  # Set method
  method <- match.arg(method, choices = c("bootstrap", "jackknife", "brr"))
  
  # Set seed if provided
  if (!is.null(seed)) {
    set.seed(seed)
  }
  
  # Determine replicates if not specified
  if (is.null(replicates)) {
    replicates <- switch(method,
                       bootstrap = 100,
                       jackknife = nrow(base_design$interviews),
                       brr = max(4, 4 * ceiling(log2(nrow(base_design$interviews))))
    )
  }
  
  # Set stratification and clustering variables
  if (is.null(strata_var)) {
    strata_var <- base_design$strata_vars
  }
  if (is.null(cluster_var)) {
    cluster_var <- "location"
  }
  
  # Create replicate weights
  replicate_weights <- create_replicate_weights(
    base_design = base_design,
    replicates = replicates,
    method = method,
    strata_var = strata_var,
    cluster_var = cluster_var
  )
  
  # Calculate scale factors
  scale_factors <- calculate_scale_factors(
    method = method,
    replicates = replicates,
    base_design = base_design
  )
  
  # Create design object
  design <- list(
    base_design = base_design,
    replicate_weights = replicate_weights,
    replicate_method = method,
    replicates = replicates,
    scale_factors = scale_factors,
    metadata = list(
      creation_time = Sys.time(),
      seed = seed,
      package_version = utils::packageVersion("tidycreel")
    )
  )
  
  class(design) <- c("repweights_design", "creel_design", "list")
  return(design)
}

# Helper functions for weight calculations

#' Calculate Access Design Weights
#'
#' Internal function to calculate design weights for access-point surveys.
#'
#' @keywords internal
calculate_access_weights <- function(interviews, calendar, strata_vars, weight_method) {
  
  # Create strata identifier
  strata_id <- interaction(interviews[strata_vars], drop = TRUE)
  
  # Calculate base weights
  calendar_strata <- interaction(calendar[strata_vars], drop = TRUE)
  target_counts <- tapply(calendar$target_sample, calendar_strata, sum)
  actual_counts <- tapply(calendar$actual_sample, calendar_strata, sum)
  
  # Base weight is ratio of target to actual
  base_weights <- target_counts[strata_id] / actual_counts[strata_id]
  
  # Apply effort expansion
  weights <- base_weights * interviews$effort_expansion
  
  # Post-stratification adjustment if requested
  if (weight_method == "post_stratify") {
    # Simple post-stratification to known totals
    post_strata <- tapply(weights, strata_id, sum)
    adjustment <- target_counts / post_strata
    weights <- weights * adjustment[strata_id]
  }
  
  return(weights)
}

#' Calculate Roving Effort Estimates
#'
#' Internal function to estimate fishing effort for roving surveys.
#'
#' @keywords internal
calculate_roving_effort <- function(interviews, counts, calendar, strata_vars, effort_method) {
  
  # Create strata identifier
  strata_id <- interaction(interviews[strata_vars], drop = TRUE)
  count_strata_id <- interaction(counts[strata_vars], drop = TRUE)
  
  # Calculate effort rates from interviews
  effort_rates <- tapply(
    interviews$hours_fished * interviews$party_size,
    strata_id,
    sum
  )
  
  # Calculate count-based effort estimates
  count_totals <- tapply(
    counts$anglers_count,
    count_strata_id,
    function(x) sum(x) * 60 / mean(counts$count_duration)
  )
  
  # Merge effort estimates
  effort_df <- data.frame(
    strata = names(effort_rates),
    interview_effort = as.numeric(effort_rates),
    count_effort = as.numeric(count_totals[names(effort_rates)])
  )
  
  # Calculate final effort estimates based on method
  if (effort_method == "ratio") {
    effort_df$effort_estimate <- effort_df$interview_effort * 
      (effort_df$count_effort / effort_df$interview_effort)
  } else {
    # For now, use ratio method as default
    effort_df$effort_estimate <- effort_df$interview_effort * 
      (effort_df$count_effort / effort_df$interview_effort)
  }
  
  return(effort_df)
}

#' Calculate Roving Design Weights
#'
#' Internal function to calculate design weights for roving surveys.
#'
#' @keywords internal
calculate_roving_weights <- function(interviews, effort_estimates, strata_vars) {
  
  # Create strata identifier
  strata_id <- interaction(interviews[strata_vars], drop = TRUE)
  
  # Get effort estimates for each interview
  effort_lookup <- setNames(
    effort_estimates$effort_estimate,
    effort_estimates$strata
  )
  
  total_effort <- effort_lookup[strata_id]
  party_hours <- interviews$hours_fished * interviews$party_size
  
  # Weight is ratio of total effort to observed effort
  weights <- total_effort / party_hours
  
  return(weights)
}

#' Create Replicate Weights
#'
#' Internal function to create replicate weights for variance estimation.
#'
#' @keywords internal
create_replicate_weights <- function(base_design, replicates, method, 
                                   strata_var, cluster_var) {
  
  n <- nrow(base_design$interviews)
  weights <- base_design$design_weights
  
  # Initialize replicate weight matrix
  rep_weights <- matrix(NA, nrow = n, ncol = replicates)
  
  if (method == "bootstrap") {
    # Bootstrap resampling
    for (i in 1:replicates) {
      bootstrap_indices <- sample(1:n, replace = TRUE)
      rep_weights[, i] <- weights * (tabulate(bootstrap_indices, nbins = n) + 1)
    }
  } else if (method == "jackknife") {
    # Jackknife resampling
    for (i in 1:replicates) {
      jackknife_weights <- weights * (n / (n - 1))
      jackknife_weights[i] <- 0
      rep_weights[, i] <- jackknife_weights
    }
  } else {
    # BRR - placeholder for now
    rep_weights <- matrix(weights, nrow = n, ncol = replicates)
  }
  
  return(rep_weights)
}

#' Calculate Scale Factors
#'
#' Internal function to calculate scale factors for replicate weights.
#'
#' @keywords internal
calculate_scale_factors <- function(method, replicates, base_design) {
  
  scale_factors <- switch(method,
                        bootstrap = 1 / replicates,
                        jackknife = (replicates - 1) / replicates,
                        brr = 1 / replicates
  )
  
  return(scale_factors)
}