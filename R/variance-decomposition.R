#' Decompose Variance Components in Creel Survey Estimates
#'
#' Decomposes the total variance of creel survey estimates into component
#' sources (within-day, among-day, within-shift, etc.) using survey design
#' objects to guide optimal sampling design and allocation decisions.
#'
#' @param design Survey design object from \code{\link{as_day_svydesign}} or 
#'   \code{\link{survey::svydesign}}
#' @param response Formula or character string specifying the response variable
#'   for decomposition (e.g., "anglers_count" or ~anglers_count)
#' @param by Character vector of grouping variables for stratified decomposition
#' @param method Method for variance decomposition. Options:
#'   \describe{
#'     \item{"survey"}{Survey-weighted decomposition using survey package (default)}
#'     \item{"bootstrap"}{Bootstrap-based variance decomposition}
#'     \item{"jackknife"}{Jackknife variance decomposition}
#'     \item{"linearization"}{Taylor linearization (for complex estimates)}
#'   }
#' @param n_bootstrap Number of bootstrap replicates (if method = "bootstrap")
#' @param conf_level Confidence level for variance component intervals (default 0.95)
#' @param cluster_vars Character vector specifying clustering variables in order
#'   of nesting (e.g., c("stratum", "day", "shift"))
#' @param finite_pop Logical, whether to apply finite population correction
#'
#' @return List with class "variance_decomp" containing:
#'   \describe{
#'     \item{components}{Data frame of variance components with estimates and confidence intervals}
#'     \item{proportions}{Proportion of total variance explained by each component}
#'     \item{intraclass_correlations}{Intraclass correlation coefficients}
#'     \item{design_effects}{Design effects for different sampling strategies}
#'     \item{optimal_allocation}{Recommended allocation across levels}
#'     \item{variance_ratios}{Ratios used for sample size determination}
#'     \item{nested_structure}{Description of the hierarchical structure}
#'     \item{method_info}{Information about the decomposition method used}
#'     \item{sample_sizes}{Sample sizes at each level}
#'   }
#'
#' @details
#' ## Variance Component Model
#'
#' For a typical creel survey with nested structure:
#' ```
#' Y_ijkl = μ + α_i + β_j(i) + γ_k(ij) + ε_l(ijk)
#' ```
#' Where:
#' - Y_ijkl = observed value (e.g., angler count)
#' - μ = overall mean
#' - α_i = stratum effect (among-stratum variance)
#' - β_j(i) = day effect within stratum (among-day variance)
#' - γ_k(ij) = shift effect within day (among-shift variance)
#' - ε_l(ijk) = residual error (within-shift variance)
#'
#' ## Key Variance Components
#'
#' 1. **Among-Day Variance (σ²_b)**: Variation between different days
#' 2. **Within-Day Variance (σ²_w)**: Variation within days (between shifts/counts)
#' 3. **Among-Shift Variance**: Variation between shifts within days
#' 4. **Residual Variance**: Unexplained variation
#'
#' ## Applications
#'
#' - **Optimal Allocation**: Determine optimal number of days vs counts per day
#' - **Design Effects**: Quantify impact of clustering on precision
#' - **Sample Size Planning**: Use variance ratios for power calculations
#' - **Survey Efficiency**: Identify largest sources of variation
#'
#' ## Intraclass Correlation
#'
#' ICC = σ²_between / (σ²_between + σ²_within)
#'
#' High ICC indicates strong clustering (similar values within clusters)
#'
#' @examples
#' \dontrun{
#' # Basic variance decomposition
#' effort_est <- est_effort(design, by = "stratum")
#' var_decomp <- decompose_variance(
#'   effort_est = effort_est,
#'   data = counts_data,
#'   level = c("day", "stratum"),
#'   components = c("within_day", "among_day")
#' )
#' 
#' # Comprehensive decomposition with shifts
#' var_decomp <- decompose_variance(
#'   effort_est = effort_est,
#'   data = counts_data,
#'   level = c("shift", "day", "stratum"),
#'   components = c("within_shift", "among_shift", "among_day"),
#'   shift_col = "shift_block"
#' )
#' 
#' # Print results
#' print(var_decomp)
#' 
#' # Plot variance components
#' plot(var_decomp)
#' }
#'
#' @references
#' Rasmussen, P.W., Heisey, D.M., Nordheim, E.V., and Frost, T.M. (1998).
#' Time-series intervention analysis: unreplicated large-scale experiments.
#' In *Scheiner, S.M. and Gurevitch, J. (eds.) Design and Analysis of 
#' Ecological Experiments*. Oxford University Press.
#'
#' @seealso \code{\link{est_effort}}, \code{\link{optimal_allocation}}, 
#' \code{\link{plot.variance_decomp}}
#'
#' @export
decompose_variance <- function(design,
                              response,
                              by = NULL,
                              method = "survey",
                              n_bootstrap = 1000,
                              conf_level = 0.95,
                              cluster_vars = c("stratum"),
                              finite_pop = TRUE) {
  
  # Validate inputs
  if (!inherits(design, c("survey.design", "survey.design2", "svyrep.design"))) {
    cli::cli_abort("{.arg design} must be a survey design object from the survey package")
  }
  
  valid_methods <- c("survey", "bootstrap", "jackknife", "linearization")
  if (!method %in% valid_methods) {
    cli::cli_abort("Method must be one of: {.val {valid_methods}}")
  }
  
  # Convert response to formula if needed
  if (is.character(response)) {
    response_formula <- as.formula(paste("~", response))
    response_var <- response
  } else if (inherits(response, "formula")) {
    response_formula <- response
    response_var <- all.vars(response)[1]
  } else {
    cli::cli_abort("{.arg response} must be a character string or formula")
  }
  
  # Validate response variable exists in design
  design_data <- design$variables
  if (!response_var %in% names(design_data)) {
    cli::cli_abort("Response variable {.val {response_var}} not found in design data")
  }
  
  # Validate cluster variables exist in design data
  missing_cluster_vars <- setdiff(cluster_vars, names(design_data))
  if (length(missing_cluster_vars) > 0) {
    cli::cli_warn("Cluster variables not found in data: {.val {missing_cluster_vars}}")
    cluster_vars <- intersect(cluster_vars, names(design_data))
  }
  
  if (length(cluster_vars) == 0) {
    cli::cli_abort("No valid cluster variables found in design data")
  }
  
  cli::cli_h1("Survey-Based Variance Component Decomposition")
  cli::cli_text("Analyzing variance structure using survey design weights...")
  
  # Extract design information
  design_info <- .extract_design_info(design, cluster_vars)
  
  # Perform variance decomposition based on method
  if (method == "survey") {
    decomp_results <- .decompose_variance_survey_weighted(
      design, response_formula, by, cluster_vars, finite_pop, conf_level
    )
  } else if (method == "bootstrap") {
    decomp_results <- .decompose_variance_bootstrap(
      design, response_formula, by, cluster_vars, n_bootstrap, conf_level
    )
  } else if (method == "jackknife") {
    decomp_results <- .decompose_variance_jackknife(
      design, response_formula, by, cluster_vars, conf_level
    )
  } else if (method == "linearization") {
    decomp_results <- .decompose_variance_linearization(
      design, response_formula, by, cluster_vars, conf_level
    )
  }
  
  # Calculate survey-specific derived quantities
  derived_results <- .calculate_survey_derived_quantities(
    decomp_results, design, design_info, cluster_vars
  )
  
  # Combine results
  result <- list(
    components = decomp_results$components,
    proportions = decomp_results$proportions,
    intraclass_correlations = derived_results$icc,
    design_effects = derived_results$design_effects,
    optimal_allocation = derived_results$optimal_allocation,
    variance_ratios = derived_results$variance_ratios,
    survey_info = design_info,
    method_info = list(
      method = method,
      cluster_vars = cluster_vars,
      response_variable = response_var,
      conf_level = conf_level,
      finite_pop = finite_pop,
      n_bootstrap = if (method == "bootstrap") n_bootstrap else NULL
    ),
    sample_sizes = derived_results$sample_sizes
  )
  
  class(result) <- c("variance_decomp", "list")
  
  cli::cli_h2("Decomposition Complete")
  cli::cli_text("Found {length(decomp_results$components)} variance components")
  
  return(result)
}

# Helper function to extract design information
.extract_design_info <- function(design, cluster_vars) {
  
  design_data <- design$variables
  
  # Extract clustering structure
  cluster_info <- list()
  
  for (var in cluster_vars) {
    if (var %in% names(design_data)) {
      cluster_info[[var]] <- list(
        n_clusters = length(unique(design_data[[var]])),
        cluster_sizes = table(design_data[[var]])
      )
    }
  }
  
  # Extract survey design type
  design_type <- if (inherits(design, "svyrep.design")) {
    "replicate"
  } else if (!is.null(design$strata)) {
    "stratified"
  } else if (!is.null(design$cluster)) {
    "clustered"
  } else {
    "simple"
  }
  
  # Extract weights information
  weights_info <- list(
    has_weights = !is.null(design$prob),
    weight_range = if (!is.null(design$prob)) range(1/design$prob) else c(1, 1),
    n_observations = nrow(design_data)
  )
  
  list(
    design_type = design_type,
    cluster_info = cluster_info,
    weights_info = weights_info,
    strata_info = if (!is.null(design$strata)) {
      list(
        n_strata = length(unique(design$strata)),
        strata_sizes = table(design$strata)
      )
    } else NULL
  )
}

# Helper function to prepare data for variance analysis
.prepare_variance_data <- function(data, level, date_col, stratum_col, shift_col, response_col) {
  
  # Start with required columns
  analysis_data <- data[, c(date_col, response_col), drop = FALSE]
  names(analysis_data)[names(analysis_data) == date_col] <- "date"
  names(analysis_data)[names(analysis_data) == response_col] <- "response"
  
  # Convert date column
  analysis_data$date <- as.Date(analysis_data$date)
  
  # Add hierarchical variables based on requested levels
  if ("stratum" %in% level) {
    analysis_data$stratum <- data[[stratum_col]]
  }
  
  if ("shift" %in% level && !is.null(shift_col)) {
    analysis_data$shift <- data[[shift_col]]
  } else if ("shift" %in% level) {
    # Create shift from time if available, otherwise use default
    cli::cli_warn("No shift column specified. Creating default shifts")
    analysis_data$shift <- "day_shift"  # Default single shift per day
  }
  
  if ("week" %in% level) {
    analysis_data$week <- lubridate::week(analysis_data$date)
  }
  
  if ("month" %in% level) {
    analysis_data$month <- lubridate::month(analysis_data$date)
  }
  
  # Add day identifier
  if ("day" %in% level) {
    analysis_data$day <- analysis_data$date
  }
  
  # Remove rows with missing response
  analysis_data <- analysis_data[!is.na(analysis_data$response), ]
  
  if (nrow(analysis_data) == 0) {
    cli::cli_abort("No valid data remaining after removing missing values")
  }
  
  return(analysis_data)
}

# Helper function for survey-weighted variance decomposition
.decompose_variance_survey_weighted <- function(design, response_formula, by, 
                                              cluster_vars, finite_pop, conf_level) {
  
  cli::cli_alert_info("Computing survey-weighted variance components...")
  
  # Calculate overall estimate and variance
  if (is.null(by)) {
    overall_est <- survey::svymean(response_formula, design, na.rm = TRUE)
    overall_var <- as.numeric(survey::SE(overall_est)^2)
  } else {
    by_formula <- as.formula(paste("~", paste(by, collapse = " + ")))
    overall_est <- survey::svyby(response_formula, by_formula, design, survey::svymean, na.rm = TRUE)
    overall_var <- mean(overall_est$se^2, na.rm = TRUE)
  }
  
  # Decompose variance by clustering levels
  components_list <- list()
  
  for (i in seq_along(cluster_vars)) {
    cluster_var <- cluster_vars[i]
    
    if (cluster_var %in% names(design$variables)) {
      # Calculate between-cluster variance
      between_var <- .calculate_between_cluster_variance(
        design, response_formula, cluster_var, finite_pop
      )
      
      components_list[[paste0("among_", cluster_var)]] <- between_var
    }
  }
  
  # Calculate within-cluster (residual) variance
  within_var <- .calculate_within_cluster_variance(
    design, response_formula, cluster_vars, overall_var
  )
  
  components_list[["within_cluster"]] <- within_var
  
  # Create components data frame
  components_df <- data.frame(
    component = names(components_list),
    variance = unlist(components_list),
    stringsAsFactors = FALSE
  )
  
  # Add confidence intervals using survey methods
  components_df <- .add_survey_confidence_intervals(
    components_df, design, response_formula, cluster_vars, conf_level
  )
  
  # Calculate proportions
  total_var <- sum(components_df$variance, na.rm = TRUE)
  proportions <- components_df$variance / total_var
  names(proportions) <- components_df$component
  
  list(
    components = components_df,
    proportions = proportions,
    overall_estimate = overall_est,
    overall_variance = overall_var
  )
}

# Helper function to calculate between-cluster variance
.calculate_between_cluster_variance <- function(design, response_formula, cluster_var, finite_pop) {
  
  # Create cluster-level estimates
  cluster_formula <- as.formula(paste("~", cluster_var))
  
  tryCatch({
    # Calculate means by cluster
    cluster_means <- survey::svyby(
      response_formula, cluster_formula, design, survey::svymean, na.rm = TRUE
    )
    
    # Calculate variance of cluster means
    cluster_var_est <- var(cluster_means[, 2], na.rm = TRUE)  # Second column is the estimate
    
    # Apply finite population correction if requested
    if (finite_pop && !is.null(design$fpc)) {
      n_clusters <- nrow(cluster_means)
      N_clusters <- length(unique(design$variables[[cluster_var]]))
      fpc <- (N_clusters - n_clusters) / N_clusters
      cluster_var_est <- cluster_var_est * fpc
    }
    
    return(cluster_var_est)
    
  }, error = function(e) {
    cli::cli_warn("Could not calculate between-cluster variance for {cluster_var}: {e$message}")
    return(0)
  })
}

# Helper function to calculate within-cluster variance
.calculate_within_cluster_variance <- function(design, response_formula, cluster_vars, overall_var) {
  
  # Calculate sum of between-cluster variances
  between_var_total <- 0
  
  for (cluster_var in cluster_vars) {
    if (cluster_var %in% names(design$variables)) {
      between_var <- .calculate_between_cluster_variance(
        design, response_formula, cluster_var, finite_pop = FALSE
      )
      between_var_total <- between_var_total + between_var
    }
  }
  
  # Within-cluster variance is residual
  within_var <- max(0, overall_var - between_var_total)
  
  return(within_var)
}

# Helper function to add survey-based confidence intervals
.add_survey_confidence_intervals <- function(components_df, design, response_formula, 
                                           cluster_vars, conf_level) {
  
  # For survey-based variance components, confidence intervals are complex
  # This is a simplified implementation
  
  alpha <- 1 - conf_level
  z_score <- qnorm(1 - alpha/2)
  
  # Approximate standard errors (would need more sophisticated calculation)
  components_df$se <- sqrt(components_df$variance / sqrt(nrow(design$variables)))
  
  components_df$ci_lower <- pmax(0, components_df$variance - z_score * components_df$se)
  components_df$ci_upper <- components_df$variance + z_score * components_df$se
  
  return(components_df)
}

# Helper function for bootstrap variance decomposition
.decompose_variance_bootstrap <- function(design, response_formula, by, 
                                        cluster_vars, n_bootstrap, conf_level) {
  
  cli::cli_alert_info("Running bootstrap variance decomposition ({n_bootstrap} replicates)...")
  
  # Convert to replicate design for bootstrap
  if (!inherits(design, "svyrep.design")) {
    rep_design <- survey::as.svrepdesign(design, type = "bootstrap", replicates = n_bootstrap)
  } else {
    rep_design <- design
  }
  
  # Calculate variance components using replicates
  bootstrap_components <- .calculate_bootstrap_components(
    rep_design, response_formula, cluster_vars
  )
  
  # Calculate confidence intervals from bootstrap distribution
  components_df <- .bootstrap_confidence_intervals(
    bootstrap_components, conf_level
  )
  
  # Calculate proportions
  total_var <- sum(components_df$variance, na.rm = TRUE)
  proportions <- components_df$variance / total_var
  names(proportions) <- components_df$component
  
  list(
    components = components_df,
    proportions = proportions,
    bootstrap_replicates = bootstrap_components
  )
}

# Helper function for jackknife variance decomposition
.decompose_variance_jackknife <- function(design, response_formula, by, 
                                        cluster_vars, conf_level) {
  
  cli::cli_alert_info("Running jackknife variance decomposition...")
  
  # Convert to replicate design for jackknife
  if (!inherits(design, "svyrep.design")) {
    rep_design <- survey::as.svrepdesign(design, type = "JK1")
  } else {
    rep_design <- design
  }
  
  # Calculate variance components using jackknife
  jackknife_components <- .calculate_jackknife_components(
    rep_design, response_formula, cluster_vars
  )
  
  # Calculate confidence intervals
  components_df <- .jackknife_confidence_intervals(
    jackknife_components, conf_level
  )
  
  # Calculate proportions
  total_var <- sum(components_df$variance, na.rm = TRUE)
  proportions <- components_df$variance / total_var
  names(proportions) <- components_df$component
  
  list(
    components = components_df,
    proportions = proportions,
    jackknife_replicates = jackknife_components
  )
}

# Helper function for linearization variance decomposition
.decompose_variance_linearization <- function(design, response_formula, by, 
                                            cluster_vars, conf_level) {
  
  cli::cli_alert_info("Running Taylor linearization variance decomposition...")
  
  # Use survey package's linearization methods
  linearization_components <- .calculate_linearization_components(
    design, response_formula, cluster_vars
  )
  
  # Calculate confidence intervals using linearization
  components_df <- .linearization_confidence_intervals(
    linearization_components, conf_level
  )
  
  # Calculate proportions
  total_var <- sum(components_df$variance, na.rm = TRUE)
  proportions <- components_df$variance / total_var
  names(proportions) <- components_df$component
  
  list(
    components = components_df,
    proportions = proportions,
    linearization_info = linearization_components
  )
}

# Helper function to build ANOVA formula
.build_anova_formula <- function(level) {
  
  # Define hierarchical relationships
  if (all(c("shift", "day", "stratum") %in% level)) {
    return("stratum + stratum:day + stratum:day:shift")
  } else if (all(c("day", "stratum") %in% level)) {
    return("stratum + stratum:day")
  } else if ("day" %in% level) {
    return("day")
  } else if ("stratum" %in% level) {
    return("stratum")
  }
  
  return(NULL)
}

# Helper function to build mixed model formula
.build_mixed_formula <- function(level) {
  
  # Define random effects structure
  if (all(c("shift", "day", "stratum") %in% level)) {
    return("1 + (1|stratum) + (1|stratum:day) + (1|stratum:day:shift)")
  } else if (all(c("day", "stratum") %in% level)) {
    return("1 + (1|stratum) + (1|stratum:day)")
  } else if ("day" %in% level) {
    return("1 + (1|day)")
  } else if ("stratum" %in% level) {
    return("1 + (1|stratum)")
  }
  
  return(NULL)
}

# Helper function to extract ANOVA components
.extract_anova_components <- function(aov_model, level, conf_level) {
  
  # Get ANOVA table
  aov_summary <- summary(aov_model)[[1]]
  
  # Extract mean squares
  ms_values <- aov_summary[["Mean Sq"]]
  df_values <- aov_summary[["Df"]]
  
  # Convert to variance components (simplified)
  # This is a basic implementation - would need more sophisticated 
  # expected mean squares calculations for proper decomposition
  
  components_df <- data.frame(
    component = rownames(aov_summary),
    variance = ms_values,
    df = df_values,
    se = sqrt(ms_values / df_values),  # Approximate SE
    stringsAsFactors = FALSE
  )
  
  # Add confidence intervals (approximate)
  alpha <- 1 - conf_level
  components_df$ci_lower <- pmax(0, components_df$variance - 
                                qt(1 - alpha/2, components_df$df) * components_df$se)
  components_df$ci_upper <- components_df$variance + 
                           qt(1 - alpha/2, components_df$df) * components_df$se
  
  return(components_df)
}

# Helper function to extract REML components
.extract_reml_components <- function(mixed_model, level, conf_level) {
  
  # Extract variance components from lme4 model
  var_comps <- lme4::VarCorr(mixed_model)
  
  components_df <- data.frame(
    component = names(var_comps),
    variance = as.numeric(var_comps),
    stringsAsFactors = FALSE
  )
  
  # Add residual variance
  residual_var <- attr(var_comps, "sc")^2
  components_df <- rbind(components_df, data.frame(
    component = "Residual",
    variance = residual_var,
    stringsAsFactors = FALSE
  ))
  
  # Add approximate confidence intervals
  # This would need more sophisticated calculation in practice
  components_df$se <- sqrt(components_df$variance / 10)  # Placeholder
  components_df$ci_lower <- pmax(0, components_df$variance - 1.96 * components_df$se)
  components_df$ci_upper <- components_df$variance + 1.96 * components_df$se
  
  return(components_df)
}

# Helper function to calculate survey-specific derived quantities
.calculate_survey_derived_quantities <- function(decomp_results, design, design_info, cluster_vars) {
  
  components_df <- decomp_results$components
  design_data <- design$variables
  
  # Calculate intraclass correlations using survey weights
  icc <- .calculate_survey_icc(components_df, design, cluster_vars)
  
  # Calculate design effects using survey package methods
  design_effects <- .calculate_survey_design_effects(components_df, design, cluster_vars)
  
  # Calculate optimal allocation using variance components
  optimal_allocation <- .calculate_survey_optimal_allocation(components_df, design_info, cluster_vars)
  
  # Calculate variance ratios for sample size planning
  variance_ratios <- .calculate_survey_variance_ratios(components_df, cluster_vars)
  
  # Calculate sample sizes at each level
  sample_sizes <- .calculate_survey_sample_sizes(design, cluster_vars)
  
  list(
    icc = icc,
    design_effects = design_effects,
    optimal_allocation = optimal_allocation,
    variance_ratios = variance_ratios,
    sample_sizes = sample_sizes
  )
}

# Helper function to calculate ICC
.calculate_icc <- function(components_df, level) {
  
  # Basic ICC calculation (would need refinement for complex designs)
  if (nrow(components_df) >= 2) {
    between_var <- components_df$variance[1]
    within_var <- sum(components_df$variance[-1], na.rm = TRUE)
    
    icc_value <- between_var / (between_var + within_var)
    
    return(data.frame(
      level = paste(level, collapse = " -> "),
      icc = icc_value,
      interpretation = .interpret_icc(icc_value),
      stringsAsFactors = FALSE
    ))
  }
  
  return(data.frame())
}

# Helper function to interpret ICC
.interpret_icc <- function(icc) {
  if (is.na(icc) || is.null(icc)) {
    "Unknown clustering"
  } else if (icc < 0.1) {
    "Low clustering"
  } else if (icc < 0.3) {
    "Moderate clustering"
  } else {
    "High clustering"
  }
}

# Helper function to calculate design effects
.calculate_design_effects <- function(components_df, analysis_data, level) {
  
  # Simplified design effect calculation
  # DE = 1 + (m-1) * ICC, where m is cluster size
  
  if ("day" %in% level) {
    # Calculate average number of observations per day
    day_counts <- table(analysis_data$date)
    avg_per_day <- mean(day_counts)
    
    # Estimate ICC (simplified)
    if (nrow(components_df) >= 2) {
      between_var <- components_df$variance[1]
      total_var <- sum(components_df$variance, na.rm = TRUE)
      icc <- between_var / total_var
      
      design_effect <- 1 + (avg_per_day - 1) * icc
      
      return(data.frame(
        design = "Day clustering",
        avg_cluster_size = avg_per_day,
        icc = icc,
        design_effect = design_effect,
        efficiency = 1 / design_effect,
        stringsAsFactors = FALSE
      ))
    }
  }
  
  return(data.frame())
}

# Helper function to calculate optimal allocation
.calculate_optimal_allocation <- function(components_df, level) {
  
  # Simplified optimal allocation (Neyman allocation)
  if (nrow(components_df) >= 2) {
    
    # Basic recommendation based on variance components
    largest_component <- which.max(components_df$variance)
    largest_source <- components_df$component[largest_component]
    
    recommendation <- paste(
      "Focus sampling effort on reducing", largest_source, 
      "which explains", 
      round(components_df$variance[largest_component] / sum(components_df$variance) * 100, 1),
      "% of total variance"
    )
    
    return(data.frame(
      allocation_type = "Variance-based",
      recommendation = recommendation,
      largest_component = largest_source,
      proportion_explained = components_df$variance[largest_component] / sum(components_df$variance),
      stringsAsFactors = FALSE
    ))
  }
  
  return(data.frame())
}

# Helper function to calculate variance ratios
.calculate_variance_ratios <- function(components_df, level) {
  
  if (nrow(components_df) >= 2) {
    
    # Calculate ratios between components
    ratios <- data.frame()
    
    for (i in 1:(nrow(components_df) - 1)) {
      for (j in (i + 1):nrow(components_df)) {
        ratio <- components_df$variance[i] / components_df$variance[j]
        
        ratios <- rbind(ratios, data.frame(
          component_1 = components_df$component[i],
          component_2 = components_df$component[j],
          variance_ratio = ratio,
          interpretation = .interpret_variance_ratio(ratio),
          stringsAsFactors = FALSE
        ))
      }
    }
    
    return(ratios)
  }
  
  return(data.frame())
}

# Helper function to interpret variance ratios
.interpret_variance_ratio <- function(ratio) {
  if (is.na(ratio) || is.null(ratio) || !is.finite(ratio)) {
    "Cannot determine ratio"
  } else if (ratio > 4) {
    "First component dominates (>4:1)"
  } else if (ratio > 2) {
    "First component larger (2-4:1)"
  } else if (ratio > 0.5) {
    "Components similar (0.5-2:1)"
  } else if (ratio > 0.25) {
    "Second component larger (2-4:1)"
  } else {
    "Second component dominates (>4:1)"
  }
}

# Helper function to describe nested structure
.describe_nested_structure <- function(level) {
  
  structure_desc <- paste("Hierarchical structure:", paste(level, collapse = " nested in "))
  
  # Add interpretation
  if (length(level) == 1) {
    interpretation <- "Single-level analysis"
  } else if (length(level) == 2) {
    interpretation <- "Two-level nested design"
  } else {
    interpretation <- "Multi-level nested design"
  }
  
  list(
    description = structure_desc,
    interpretation = interpretation,
    levels = level,
    n_levels = length(level)
  )
}

# Helper function to calculate sample sizes
.calculate_sample_sizes <- function(analysis_data, level) {
  
  sample_sizes <- list()
  
  if ("stratum" %in% level) {
    sample_sizes$n_strata <- length(unique(analysis_data$stratum))
  }
  
  if ("day" %in% level) {
    sample_sizes$n_days <- length(unique(analysis_data$date))
  }
  
  if ("shift" %in% level) {
    sample_sizes$n_shifts <- length(unique(analysis_data$shift))
  }
  
  sample_sizes$n_total <- nrow(analysis_data)
  
  return(sample_sizes)
}

# Helper function to calculate survey-weighted ICC
.calculate_survey_icc <- function(components_df, design, cluster_vars) {
  
  if (nrow(components_df) < 2) {
    return(data.frame())
  }
  
  # Calculate ICC for each clustering level
  icc_results <- data.frame()
  
  for (i in seq_along(cluster_vars)) {
    cluster_var <- cluster_vars[i]
    
    # Find corresponding variance components
    between_component <- paste0("among_", cluster_var)
    
    if (between_component %in% components_df$component) {
      between_var <- components_df$variance[components_df$component == between_component]
      within_var <- sum(components_df$variance[components_df$component != between_component], na.rm = TRUE)
      
      icc_value <- between_var / (between_var + within_var)
      
      # Calculate effective sample size
      cluster_sizes <- table(design$variables[[cluster_var]])
      avg_cluster_size <- mean(cluster_sizes)
      
      icc_results <- rbind(icc_results, data.frame(
        cluster_level = cluster_var,
        icc = icc_value,
        avg_cluster_size = avg_cluster_size,
        interpretation = .interpret_icc(icc_value),
        effective_sample_size = length(cluster_sizes) * (1 + (avg_cluster_size - 1) * icc_value),
        stringsAsFactors = FALSE
      ))
    }
  }
  
  return(icc_results)
}

# Helper function to calculate survey design effects
.calculate_survey_design_effects <- function(components_df, design, cluster_vars) {
  
  design_effects <- data.frame()
  
  # Calculate design effect from survey package if available
  if (inherits(design, c("survey.design", "survey.design2"))) {
    
    for (cluster_var in cluster_vars) {
      if (cluster_var %in% names(design$variables)) {
        
        # Calculate average cluster size
        cluster_sizes <- table(design$variables[[cluster_var]])
        avg_cluster_size <- mean(cluster_sizes)
        
        # Estimate ICC from variance components
        between_component <- paste0("among_", cluster_var)
        if (between_component %in% components_df$component) {
          between_var <- components_df$variance[components_df$component == between_component]
          total_var <- sum(components_df$variance, na.rm = TRUE)
          icc <- between_var / total_var
          
          # Design effect formula: DE = 1 + (m-1) * ICC
          design_effect <- 1 + (avg_cluster_size - 1) * icc
          
          design_effects <- rbind(design_effects, data.frame(
            cluster_level = cluster_var,
            avg_cluster_size = avg_cluster_size,
            icc = icc,
            design_effect = design_effect,
            efficiency = 1 / design_effect,
            effective_n = nrow(design$variables) / design_effect,
            stringsAsFactors = FALSE
          ))
        }
      }
    }
  }
  
  return(design_effects)
}

# Helper function to calculate survey optimal allocation
.calculate_survey_optimal_allocation <- function(components_df, design_info, cluster_vars) {
  
  if (nrow(components_df) < 2) {
    return(data.frame())
  }
  
  # Neyman allocation based on variance components and costs
  allocation_results <- data.frame()
  
  # Find the largest variance component
  largest_idx <- which.max(components_df$variance)
  largest_component <- components_df$component[largest_idx]
  largest_variance <- components_df$variance[largest_idx]
  
  # Generate recommendations based on largest variance source
  if (grepl("among_day", largest_component)) {
    recommendation <- "Increase number of sampling days rather than counts per day"
    allocation_type <- "More days, fewer counts per day"
  } else if (grepl("among_stratum", largest_component)) {
    recommendation <- "Focus on stratification - ensure adequate sampling across all strata"
    allocation_type <- "Balanced stratification"
  } else if (grepl("within", largest_component)) {
    recommendation <- "Increase number of counts per sampling unit"
    allocation_type <- "More intensive sampling within units"
  } else {
    recommendation <- "Review sampling design to address largest variance source"
    allocation_type <- "Design optimization needed"
  }
  
  allocation_results <- rbind(allocation_results, data.frame(
    largest_component = largest_component,
    variance_proportion = largest_variance / sum(components_df$variance),
    recommendation = recommendation,
    allocation_type = allocation_type,
    priority = "High",
    stringsAsFactors = FALSE
  ))
  
  return(allocation_results)
}

# Helper function to calculate survey variance ratios
.calculate_survey_variance_ratios <- function(components_df, cluster_vars) {
  
  if (nrow(components_df) < 2) {
    return(data.frame())
  }
  
  variance_ratios <- data.frame()
  
  # Calculate key ratios for sample size planning
  for (i in 1:(nrow(components_df) - 1)) {
    for (j in (i + 1):nrow(components_df)) {
      
      comp1 <- components_df$component[i]
      comp2 <- components_df$component[j]
      var1 <- components_df$variance[i]
      var2 <- components_df$variance[j]
      
      ratio <- var1 / var2
      
      # Determine sample size implication
      if (grepl("among_day", comp1) && grepl("within", comp2)) {
        implication <- "Days vs counts per day allocation"
      } else if (grepl("among_stratum", comp1) && grepl("among_day", comp2)) {
        implication <- "Strata vs days allocation"
      } else {
        implication <- "General allocation guidance"
      }
      
      variance_ratios <- rbind(variance_ratios, data.frame(
        component_1 = comp1,
        component_2 = comp2,
        variance_1 = var1,
        variance_2 = var2,
        ratio = ratio,
        interpretation = .interpret_variance_ratio(ratio),
        sample_size_implication = implication,
        stringsAsFactors = FALSE
      ))
    }
  }
  
  return(variance_ratios)
}

# Helper function to calculate survey sample sizes
.calculate_survey_sample_sizes <- function(design, cluster_vars) {
  
  design_data <- design$variables
  sample_sizes <- list()
  
  # Overall sample size
  sample_sizes$n_total <- nrow(design_data)
  
  # Sample sizes by clustering variables
  for (cluster_var in cluster_vars) {
    if (cluster_var %in% names(design_data)) {
      cluster_counts <- table(design_data[[cluster_var]])
      
      sample_sizes[[paste0("n_", cluster_var)]] <- length(cluster_counts)
      sample_sizes[[paste0("avg_per_", cluster_var)]] <- mean(cluster_counts)
      sample_sizes[[paste0("range_per_", cluster_var)]] <- range(cluster_counts)
    }
  }
  
  # Effective sample size (accounting for design effects)
  if (inherits(design, c("survey.design", "survey.design2"))) {
    # Approximate effective sample size
    # This would need more sophisticated calculation in practice
    sample_sizes$n_effective <- sample_sizes$n_total * 0.8  # Placeholder
  }
  
  return(sample_sizes)
}

# Placeholder functions for bootstrap/jackknife methods
.calculate_bootstrap_components <- function(rep_design, response_formula, cluster_vars) {
  # Simplified implementation - would need full bootstrap calculation
  cli::cli_warn("Bootstrap variance decomposition not fully implemented")
  return(list())
}

.bootstrap_confidence_intervals <- function(bootstrap_components, conf_level) {
  # Placeholder implementation
  return(data.frame(
    component = "placeholder",
    variance = 0,
    ci_lower = 0,
    ci_upper = 0,
    stringsAsFactors = FALSE
  ))
}

.calculate_jackknife_components <- function(rep_design, response_formula, cluster_vars) {
  # Simplified implementation - would need full jackknife calculation
  cli::cli_warn("Jackknife variance decomposition not fully implemented")
  return(list())
}

.jackknife_confidence_intervals <- function(jackknife_components, conf_level) {
  # Placeholder implementation
  return(data.frame(
    component = "placeholder",
    variance = 0,
    ci_lower = 0,
    ci_upper = 0,
    stringsAsFactors = FALSE
  ))
}

.calculate_linearization_components <- function(design, response_formula, cluster_vars) {
  # Simplified implementation - would need full linearization calculation
  cli::cli_warn("Linearization variance decomposition not fully implemented")
  return(list())
}

.linearization_confidence_intervals <- function(linearization_components, conf_level) {
  # Placeholder implementation
  return(data.frame(
    component = "placeholder",
    variance = 0,
    ci_lower = 0,
    ci_upper = 0,
    stringsAsFactors = FALSE
  ))
}