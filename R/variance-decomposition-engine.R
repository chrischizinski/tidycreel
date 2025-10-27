#' Variance Decomposition Engine for tidycreel
#'
#' Native variance component decomposition built from the ground up.
#' Integrates seamlessly with tc_compute_variance() and tidycreel estimators.
#'
#' @name variance-decomposition-engine
NULL

#' Decompose Variance into Components
#'
#' Decomposes total variance into component sources for creel survey estimates.
#' Built-in to tidycreel estimators through the `decompose_variance` parameter.
#'
#' @param design Survey design object
#' @param response Response variable (formula or character)
#' @param cluster_vars Character vector of clustering variables in order of nesting
#'   (e.g., c("stratum", "day", "shift"))
#' @param method Decomposition method:
#'   \describe{
#'     \item{"anova"}{ANOVA-based decomposition (default)}
#'     \item{"mixed_model"}{Mixed model variance components}
#'     \item{"survey_weighted"}{Survey-weighted decomposition}
#'   }
#' @param conf_level Confidence level for component intervals (default 0.95)
#'
#' @return List with class "tc_variance_decomp" containing:
#'   \describe{
#'     \item{components}{Data frame of variance components}
#'     \item{proportions}{Proportion of total variance by component}
#'     \item{intraclass_correlations}{ICC values}
#'     \item{design_effects}{Design effects by component}
#'     \item{optimal_allocation}{Recommended sample allocation}
#'     \item{variance_ratios}{Ratios for sample size planning}
#'     \item{method}{Decomposition method used}
#'   }
#'
#' @details
#' ## Variance Component Model
#'
#' For nested creel survey structure:
#' \deqn{Y_{ijkl} = \mu + \alpha_i + \beta_{j(i)} + \gamma_{k(ij)} + \epsilon_{l(ijk)}}
#'
#' Where:
#' - \eqn{\alpha_i} = stratum effect (among-stratum variance)
#' - \eqn{\beta_{j(i)}} = day effect within stratum (among-day variance)
#' - \eqn{\gamma_{k(ij)}} = shift effect within day (among-shift variance)
#' - \eqn{\epsilon_{l(ijk)}} = residual (within-shift variance)
#'
#' ## Key Applications
#'
#' - **Optimal Allocation**: Determine optimal days vs counts per day
#' - **Design Effects**: Quantify clustering impact
#' - **Sample Size Planning**: Use variance ratios for power analysis
#' - **Efficiency Analysis**: Identify largest variance sources
#'
#' @examples
#' \dontrun{
#' # Decompose variance for effort estimate
#' decomp <- tc_decompose_variance(
#'   design = creel_design,
#'   response = "effort_hours",
#'   cluster_vars = c("stratum", "day")
#' )
#'
#' # View components
#' print(decomp)
#' decomp$components
#' decomp$proportions
#'
#' # Optimal allocation recommendations
#' decomp$optimal_allocation
#' }
#'
#' @export
tc_decompose_variance <- function(design,
                                  response,
                                  cluster_vars = c("stratum"),
                                  method = "anova",
                                  conf_level = 0.95) {

  # Validate inputs
  if (!inherits(design, c("survey.design", "survey.design2", "svyrep.design"))) {
    cli::cli_abort("{.arg design} must be a survey design object")
  }

  valid_methods <- c("anova", "mixed_model", "survey_weighted")
  method <- match.arg(method, valid_methods)

  # Convert response to variable name
  if (is.character(response)) {
    response_var <- response
  } else if (inherits(response, "formula")) {
    response_var <- all.vars(response)[1]
  } else {
    cli::cli_abort("{.arg response} must be character or formula")
  }

  # Validate response exists
  if (!response_var %in% names(design$variables)) {
    cli::cli_abort(
      "Response variable {.val {response_var}} not found in design"
    )
  }

  # Validate cluster variables
  design_data <- design$variables
  missing_vars <- setdiff(cluster_vars, names(design_data))
  if (length(missing_vars) > 0) {
    cli::cli_warn(
      c(
        "!" = "Cluster variables not found: {.val {missing_vars}}",
        "i" = "Using available variables only"
      )
    )
    cluster_vars <- intersect(cluster_vars, names(design_data))
  }

  if (length(cluster_vars) == 0) {
    cli::cli_abort("No valid cluster variables found for decomposition")
  }

  # Dispatch to decomposition method
  result <- switch(method,
    "anova" = .tc_decompose_anova(design_data, response_var, cluster_vars, conf_level),
    "mixed_model" = .tc_decompose_mixed_model(design_data, response_var, cluster_vars, conf_level),
    "survey_weighted" = .tc_decompose_survey_weighted(design, response_var, cluster_vars, conf_level)
  )

  # Add metadata
  result$method <- method
  result$response_variable <- response_var
  result$cluster_vars <- cluster_vars
  result$conf_level <- conf_level

  class(result) <- c("tc_variance_decomp", "list")

  return(result)
}

# Internal decomposition methods ----

#' ANOVA-Based Variance Decomposition
#'
#' Uses nested ANOVA to decompose variance components.
#'
#' @keywords internal
#' @noRd
.tc_decompose_anova <- function(data, response_var, cluster_vars, conf_level) {

  # Build nested formula
  # For c("stratum", "day", "shift") creates: response ~ stratum/day/shift
  formula_str <- paste(
    response_var,
    "~",
    paste(cluster_vars, collapse = "/")
  )
  formula_nested <- as.formula(formula_str)

  # Fit nested ANOVA
  aov_fit <- tryCatch(
    aov(formula_nested, data = data),
    error = function(e) {
      cli::cli_warn("ANOVA fit failed: {e$message}")
      return(NULL)
    }
  )

  if (is.null(aov_fit)) {
    return(.tc_decompose_fallback(data, response_var, cluster_vars))
  }

  # Extract variance components
  aov_summary <- summary(aov_fit)[[1]]

  # Calculate variance components
  ms <- aov_summary$`Mean Sq`
  df <- aov_summary$Df

  n_components <- length(cluster_vars)
  components <- data.frame(
    component = character(n_components + 1),
    variance = numeric(n_components + 1),
    proportion = numeric(n_components + 1),
    stringsAsFactors = FALSE
  )

  # Residual variance (within lowest level)
  residual_var <- ms[length(ms)]
  components$component[n_components + 1] <- paste0("within_", cluster_vars[n_components])
  components$variance[n_components + 1] <- residual_var

  # Between-group variances (working backwards)
  for (i in seq_len(n_components)) {
    between_var <- (ms[i] - residual_var) / (df[i] + 1)
    between_var <- max(0, between_var)  # Variance cannot be negative

    components$component[i] <- paste0("among_", cluster_vars[i])
    components$variance[i] <- between_var
  }

  # Calculate proportions
  total_var <- sum(components$variance)
  components$proportion <- components$variance / total_var

  # Calculate intraclass correlations
  icc <- .tc_calculate_icc(components$variance, cluster_vars)

  # Calculate design effects
  deff <- .tc_calculate_component_deff(components, nrow(data))

  # Optimal allocation
  optimal <- .tc_optimal_allocation(components, cluster_vars)

  list(
    components = components,
    proportions = setNames(components$proportion, components$component),
    intraclass_correlations = icc,
    design_effects = deff,
    optimal_allocation = optimal,
    variance_ratios = .tc_variance_ratios(components),
    method_details = list(
      anova_summary = aov_summary,
      formula = formula_nested
    )
  )
}

#' Mixed Model Variance Decomposition
#'
#' Uses mixed effects models for variance component estimation.
#' Requires lme4 package.
#'
#' @keywords internal
#' @noRd
.tc_decompose_mixed_model <- function(data, response_var, cluster_vars, conf_level) {

  # Check for lme4
  if (!requireNamespace("lme4", quietly = TRUE)) {
    cli::cli_warn(
      c(
        "!" = "lme4 package required for mixed model decomposition",
        "i" = "Install with: install.packages('lme4')",
        "i" = "Falling back to ANOVA method"
      )
    )
    return(.tc_decompose_anova(data, response_var, cluster_vars, conf_level))
  }

  # Build random effects formula
  # For c("stratum", "day") creates: response ~ 1 + (1|stratum/day)
  random_effects <- paste(
    "(1|", paste(cluster_vars, collapse = "/"), ")"
  )
  formula_str <- paste(response_var, "~ 1 +", random_effects)
  formula_mixed <- as.formula(formula_str)

  # Fit mixed model
  lmer_fit <- tryCatch(
    lme4::lmer(formula_mixed, data = data),
    error = function(e) {
      cli::cli_warn("Mixed model fit failed: {e$message}")
      return(NULL)
    }
  )

  if (is.null(lmer_fit)) {
    return(.tc_decompose_anova(data, response_var, cluster_vars, conf_level))
  }

  # Extract variance components
  vc <- lme4::VarCorr(lmer_fit)
  vc_df <- as.data.frame(vc)

  # Build components data frame
  n_components <- nrow(vc_df)
  components <- data.frame(
    component = character(n_components),
    variance = numeric(n_components),
    proportion = numeric(n_components),
    stringsAsFactors = FALSE
  )

  for (i in seq_len(n_components)) {
    if (vc_df$grp[i] == "Residual") {
      components$component[i] <- paste0("within_", tail(cluster_vars, 1))
    } else {
      components$component[i] <- paste0("among_", vc_df$grp[i])
    }
    components$variance[i] <- vc_df$vcov[i]
  }

  # Calculate proportions
  total_var <- sum(components$variance)
  components$proportion <- components$variance / total_var

  # Other statistics
  icc <- .tc_calculate_icc(components$variance, cluster_vars)
  deff <- .tc_calculate_component_deff(components, nrow(data))
  optimal <- .tc_optimal_allocation(components, cluster_vars)

  list(
    components = components,
    proportions = setNames(components$proportion, components$component),
    intraclass_correlations = icc,
    design_effects = deff,
    optimal_allocation = optimal,
    variance_ratios = .tc_variance_ratios(components),
    method_details = list(
      lmer_fit = lmer_fit,
      formula = formula_mixed
    )
  )
}

#' Survey-Weighted Variance Decomposition
#'
#' Uses survey weights in decomposition.
#'
#' @keywords internal
#' @noRd
.tc_decompose_survey_weighted <- function(design, response_var, cluster_vars, conf_level) {

  # For now, use ANOVA on design$variables
  # Future enhancement: incorporate survey weights properly
  cli::cli_warn(
    c(
      "!" = "Survey-weighted decomposition using ANOVA on design data",
      "i" = "Full survey-weighted decomposition coming in next iteration"
    )
  )

  .tc_decompose_anova(design$variables, response_var, cluster_vars, conf_level)
}

#' Fallback Decomposition
#'
#' Simple variance decomposition when advanced methods fail.
#'
#' @keywords internal
#' @noRd
.tc_decompose_fallback <- function(data, response_var, cluster_vars) {

  # Calculate total variance
  total_var <- var(data[[response_var]], na.rm = TRUE)

  # Simple between/within for first clustering variable
  first_cluster <- cluster_vars[1]
  between_var <- tryCatch({
    group_means <- tapply(
      data[[response_var]],
      data[[first_cluster]],
      mean,
      na.rm = TRUE
    )
    var(group_means, na.rm = TRUE)
  }, error = function(e) total_var * 0.5)

  within_var <- total_var - between_var

  components <- data.frame(
    component = c(paste0("among_", first_cluster), "within_residual"),
    variance = c(between_var, within_var),
    proportion = c(between_var / total_var, within_var / total_var),
    stringsAsFactors = FALSE
  )

  list(
    components = components,
    proportions = setNames(components$proportion, components$component),
    intraclass_correlations = list(icc_overall = between_var / total_var),
    design_effects = NULL,
    optimal_allocation = NULL,
    variance_ratios = NULL,
    method_details = list(fallback = TRUE)
  )
}

# Helper functions ----

#' Calculate Intraclass Correlation Coefficients
#'
#' @keywords internal
#' @noRd
.tc_calculate_icc <- function(variances, cluster_vars) {

  n_comp <- length(variances)
  total_var <- sum(variances)

  icc_list <- list()

  # Overall ICC (between first level / total)
  if (n_comp >= 2) {
    icc_list$icc_overall <- variances[1] / total_var

    # Level-specific ICCs
    for (i in seq_len(n_comp - 1)) {
      level_name <- paste0("icc_", cluster_vars[min(i, length(cluster_vars))])
      icc_list[[level_name]] <- variances[i] / sum(variances[i:n_comp])
    }
  }

  return(icc_list)
}

#' Calculate Design Effects for Components
#'
#' @keywords internal
#' @noRd
.tc_calculate_component_deff <- function(components, n_obs) {

  n_comp <- nrow(components)
  total_var <- sum(components$variance)

  deff_df <- data.frame(
    component = components$component,
    deff = numeric(n_comp),
    stringsAsFactors = FALSE
  )

  # Simple DEFF calculation: ratio to SRS variance
  srs_var <- total_var / n_obs

  for (i in seq_len(n_comp)) {
    deff_df$deff[i] <- components$variance[i] / srs_var
  }

  return(deff_df)
}

#' Calculate Optimal Allocation
#'
#' Recommend optimal sample allocation based on variance components.
#'
#' @keywords internal
#' @noRd
.tc_optimal_allocation <- function(components, cluster_vars) {

  n_levels <- length(cluster_vars)

  if (n_levels < 2) {
    return(NULL)
  }

  # Extract between and within variances
  between_var <- components$variance[1]
  within_var <- sum(components$variance[-1])

  # Optimal allocation formula: n_primary / n_secondary = sqrt(V_between / V_within)
  optimal_ratio <- sqrt(between_var / within_var)

  list(
    primary_level = cluster_vars[1],
    secondary_level = cluster_vars[2],
    variance_ratio = between_var / within_var,
    optimal_ratio = optimal_ratio,
    recommendation = sprintf(
      "For every %.1f %s, sample %.1f %s",
      optimal_ratio,
      cluster_vars[1],
      1,
      cluster_vars[2]
    )
  )
}

#' Calculate Variance Ratios
#'
#' Ratios used for sample size determination.
#'
#' @keywords internal
#' @noRd
.tc_variance_ratios <- function(components) {

  n_comp <- nrow(components)

  if (n_comp < 2) {
    return(NULL)
  }

  ratios <- list()

  for (i in seq_len(n_comp - 1)) {
    ratio_name <- paste0(
      components$component[i],
      "_to_",
      components$component[i + 1]
    )
    ratios[[ratio_name]] <- components$variance[i] / components$variance[i + 1]
  }

  return(ratios)
}

# Print method ----

#' @export
print.tc_variance_decomp <- function(x, ...) {

  cli::cli_h1("Variance Component Decomposition")

  cli::cli_h2("Method")
  cli::cli_text("Decomposition method: {.strong {x$method}}")
  cli::cli_text("Response variable: {.strong {x$response_variable}}")
  cli::cli_text("Clustering: {.val {x$cluster_vars}}")

  cli::cli_h2("Variance Components")
  print(x$components)

  cli::cli_h2("Intraclass Correlations")
  for (name in names(x$intraclass_correlations)) {
    val <- x$intraclass_correlations[[name]]
    cli::cli_text("{name}: {.val {round(val, 3)}}")
  }

  if (!is.null(x$optimal_allocation)) {
    cli::cli_h2("Optimal Allocation")
    cli::cli_text(x$optimal_allocation$recommendation)
    cli::cli_text("Variance ratio: {.val {round(x$optimal_allocation$variance_ratio, 2)}}")
  }

  invisible(x)
}
