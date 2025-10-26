#' Print Method for Variance Decomposition Results
#'
#' @param x A variance_decomp object from \code{\link{decompose_variance}}
#' @param ... Additional arguments (not used)
#'
#' @export
print.variance_decomp <- function(x, ...) {
  
  cli::cli_h1("Creel Survey Variance Component Decomposition")
  
  # Method information
  cli::cli_h2("Method Information")
  cli::cli_text("Method: {.strong {x$method_info$method}}")
  cli::cli_text("Response Variable: {.strong {x$method_info$response_variable}}")
  cli::cli_text("Clustering Variables: {.strong {paste(x$method_info$cluster_vars, collapse = ', ')}}")
  cli::cli_text("Confidence Level: {.strong {x$method_info$conf_level * 100}%}")
  
  # Sample size information
  if (!is.null(x$sample_sizes)) {
    cli::cli_h2("Sample Size Information")
    cli::cli_text("Total Observations: {.strong {x$sample_sizes$n_total}}")
    
    for (name in names(x$sample_sizes)) {
      if (startsWith(name, "n_") && name != "n_total") {
        var_name <- sub("n_", "", name)
        cli::cli_text("{stringr::str_to_title(var_name)}: {.strong {x$sample_sizes[[name]]}}")
      }
    }
  }
  
  # Variance components
  cli::cli_h2("Variance Components")
  if (nrow(x$components) > 0) {
    print(x$components)
  } else {
    cli::cli_text("No variance components calculated")
  }
  
  # Proportions
  if (length(x$proportions) > 0) {
    cli::cli_h2("Variance Proportions")
    for (i in seq_along(x$proportions)) {
      prop_pct <- round(x$proportions[i] * 100, 1)
      cli::cli_text("{.strong {names(x$proportions)[i]}}: {prop_pct}%")
    }
  }
  
  # Intraclass correlations
  if (!is.null(x$intraclass_correlations) && nrow(x$intraclass_correlations) > 0) {
    cli::cli_h2("Intraclass Correlations")
    print(x$intraclass_correlations)
  }
  
  # Design effects
  if (!is.null(x$design_effects) && nrow(x$design_effects) > 0) {
    cli::cli_h2("Design Effects")
    print(x$design_effects)
  }
  
  # Optimal allocation recommendations
  if (!is.null(x$optimal_allocation) && nrow(x$optimal_allocation) > 0) {
    cli::cli_h2("Optimal Allocation Recommendations")
    for (i in seq_len(nrow(x$optimal_allocation))) {
      rec <- x$optimal_allocation[i, ]
      cli::cli_alert_info("{rec$recommendation}")
    }
  }
  
  invisible(x)
}

#' Plot Method for Variance Decomposition Results
#'
#' Creates visualizations of variance components, design effects, and 
#' optimal allocation recommendations.
#'
#' @param x A variance_decomp object from \code{\link{decompose_variance}}
#' @param type Type of plot to create. Options:
#'   \describe{
#'     \item{"components"}{Bar plot of variance components (default)}
#'     \item{"proportions"}{Pie chart of variance proportions}
#'     \item{"design_effects"}{Plot of design effects by clustering level}
#'     \item{"icc"}{Plot of intraclass correlations}
#'     \item{"all"}{Multiple plots in a grid}
#'   }
#' @param ... Additional arguments passed to ggplot2 functions
#'
#' @return A ggplot2 object or list of ggplot2 objects (if type = "all")
#'
#' @examples
#' \dontrun{
#' # Create variance decomposition
#' var_decomp <- decompose_variance(design, ~anglers_count)
#' 
#' # Plot variance components
#' plot(var_decomp, type = "components")
#' 
#' # Plot proportions
#' plot(var_decomp, type = "proportions")
#' 
#' # All plots
#' plots <- plot(var_decomp, type = "all")
#' }
#'
#' @export
plot.variance_decomp <- function(x, type = "components", ...) {
  
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("ggplot2 package required for plotting variance decomposition results")
  }
  
  valid_types <- c("components", "proportions", "design_effects", "icc", "all")
  if (!type %in% valid_types) {
    cli::cli_abort("Plot type must be one of: {.val {valid_types}}")
  }
  
  if (type == "all") {
    plots <- list()
    
    # Create individual plots
    if (nrow(x$components) > 0) {
      plots$components <- .plot_variance_components(x, ...)
    }
    
    if (length(x$proportions) > 0) {
      plots$proportions <- .plot_variance_proportions(x, ...)
    }
    
    if (!is.null(x$design_effects) && nrow(x$design_effects) > 0) {
      plots$design_effects <- .plot_design_effects(x, ...)
    }
    
    if (!is.null(x$intraclass_correlations) && nrow(x$intraclass_correlations) > 0) {
      plots$icc <- .plot_icc(x, ...)
    }
    
    return(plots)
  }
  
  # Create single plot based on type
  switch(type,
    "components" = .plot_variance_components(x, ...),
    "proportions" = .plot_variance_proportions(x, ...),
    "design_effects" = .plot_design_effects(x, ...),
    "icc" = .plot_icc(x, ...)
  )
}

# Helper function to plot variance components
.plot_variance_components <- function(x, ...) {
  
  if (nrow(x$components) == 0) {
    cli::cli_warn("No variance components to plot")
    return(NULL)
  }
  
  # Prepare data for plotting
  plot_data <- x$components
  plot_data$component <- factor(plot_data$component, levels = rev(plot_data$component))
  
  # Create bar plot
  p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = component, y = variance)) +
    ggplot2::geom_col(fill = "steelblue", alpha = 0.7) +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "Variance Components",
      subtitle = paste("Method:", x$method_info$method),
      x = "Component",
      y = "Variance"
    ) +
    ggplot2::theme_minimal()
  
  # Add confidence intervals if available
  if ("ci_lower" %in% names(plot_data) && "ci_upper" %in% names(plot_data)) {
    p <- p + ggplot2::geom_errorbar(
      ggplot2::aes(xmin = component, xmax = component, ymin = ci_lower, ymax = ci_upper),
      width = 0.2
    )
  }
  
  return(p)
}

# Helper function to plot variance proportions
.plot_variance_proportions <- function(x, ...) {
  
  if (length(x$proportions) == 0) {
    cli::cli_warn("No variance proportions to plot")
    return(NULL)
  }
  
  # Prepare data for pie chart
  plot_data <- data.frame(
    component = names(x$proportions),
    proportion = as.numeric(x$proportions),
    stringsAsFactors = FALSE
  )
  
  # Create pie chart
  p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = "", y = proportion, fill = component)) +
    ggplot2::geom_bar(stat = "identity", width = 1) +
    ggplot2::coord_polar("y", start = 0) +
    ggplot2::labs(
      title = "Variance Component Proportions",
      subtitle = paste("Total variance decomposition"),
      fill = "Component"
    ) +
    ggplot2::theme_void() +
    ggplot2::theme(legend.position = "right")
  
  return(p)
}

# Helper function to plot design effects
.plot_design_effects <- function(x, ...) {
  
  if (is.null(x$design_effects) || nrow(x$design_effects) == 0) {
    cli::cli_warn("No design effects to plot")
    return(NULL)
  }
  
  plot_data <- x$design_effects
  plot_data$cluster_level <- factor(plot_data$cluster_level)
  
  # Create design effect plot
  p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = cluster_level, y = design_effect)) +
    ggplot2::geom_col(fill = "coral", alpha = 0.7) +
    ggplot2::geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
    ggplot2::labs(
      title = "Design Effects by Clustering Level",
      subtitle = "Values > 1 indicate loss of efficiency due to clustering",
      x = "Clustering Level",
      y = "Design Effect"
    ) +
    ggplot2::theme_minimal()
  
  return(p)
}

# Helper function to plot ICC
.plot_icc <- function(x, ...) {
  
  if (is.null(x$intraclass_correlations) || nrow(x$intraclass_correlations) == 0) {
    cli::cli_warn("No intraclass correlations to plot")
    return(NULL)
  }
  
  plot_data <- x$intraclass_correlations
  plot_data$cluster_level <- factor(plot_data$cluster_level)
  
  # Create ICC plot
  p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = cluster_level, y = icc)) +
    ggplot2::geom_col(fill = "darkgreen", alpha = 0.7) +
    ggplot2::ylim(0, 1) +
    ggplot2::labs(
      title = "Intraclass Correlations",
      subtitle = "Higher values indicate stronger clustering",
      x = "Clustering Level", 
      y = "Intraclass Correlation"
    ) +
    ggplot2::theme_minimal()
  
  return(p)
}

#' Calculate Optimal Sample Allocation
#'
#' Uses variance component decomposition results to calculate optimal
#' allocation of sampling effort across different levels of the survey design.
#'
#' @param variance_decomp A variance_decomp object from \code{\link{decompose_variance}}
#' @param total_budget Total sampling budget (in units or cost)
#' @param cost_per_unit Named vector of costs per sampling unit at each level
#' @param precision_target Target precision (coefficient of variation) for estimates
#'
#' @return List containing optimal allocation recommendations
#'
#' @examples
#' \dontrun{
#' # Calculate optimal allocation
#' var_decomp <- decompose_variance(design, ~anglers_count)
#' 
#' allocation <- optimal_allocation(
#'   var_decomp,
#'   total_budget = 1000,
#'   cost_per_unit = c("day" = 50, "shift" = 20),
#'   precision_target = 0.10
#' )
#' }
#'
#' @export
optimal_allocation <- function(variance_decomp, 
                              total_budget = NULL,
                              cost_per_unit = NULL,
                              precision_target = 0.10) {
  
  if (!inherits(variance_decomp, "variance_decomp")) {
    cli::cli_abort("{.arg variance_decomp} must be output from {.fn decompose_variance}")
  }
  
  components <- variance_decomp$components
  
  if (nrow(components) < 2) {
    cli::cli_warn("Need at least 2 variance components for optimal allocation")
    return(NULL)
  }
  
  # Implement Neyman allocation if costs are provided
  if (!is.null(cost_per_unit) && !is.null(total_budget)) {
    allocation <- .calculate_neyman_allocation(
      components, cost_per_unit, total_budget, precision_target
    )
  } else {
    # Provide general allocation guidance based on variance ratios
    allocation <- .calculate_general_allocation(components, precision_target)
  }
  
  return(allocation)
}

# Helper function for Neyman allocation
.calculate_neyman_allocation <- function(components, costs, budget, precision) {
  
  # Simplified Neyman allocation
  # In practice, this would need more sophisticated optimization
  
  cli::cli_alert_info("Calculating Neyman optimal allocation...")
  
  # Find variance components that correspond to cost levels
  allocation_results <- list()
  
  for (cost_level in names(costs)) {
    component_name <- paste0("among_", cost_level)
    
    if (component_name %in% components$component) {
      var_component <- components$variance[components$component == component_name]
      cost <- costs[cost_level]
      
      # Neyman allocation: n_i ∝ sqrt(var_i) / sqrt(cost_i)
      allocation_weight <- sqrt(var_component) / sqrt(cost)
      
      allocation_results[[cost_level]] <- list(
        variance = var_component,
        cost = cost,
        allocation_weight = allocation_weight
      )
    }
  }
  
  # Normalize allocation weights
  total_weight <- sum(sapply(allocation_results, function(x) x$allocation_weight))
  
  for (level in names(allocation_results)) {
    allocation_results[[level]]$proportion <- 
      allocation_results[[level]]$allocation_weight / total_weight
    allocation_results[[level]]$budget_allocation <- 
      budget * allocation_results[[level]]$proportion
    allocation_results[[level]]$sample_size <- 
      allocation_results[[level]]$budget_allocation / allocation_results[[level]]$cost
  }
  
  return(allocation_results)
}

# Helper function for general allocation guidance
.calculate_general_allocation <- function(components, precision) {
  
  # Provide allocation guidance based on variance component magnitudes
  total_var <- sum(components$variance, na.rm = TRUE)
  
  recommendations <- list()
  
  for (i in seq_len(nrow(components))) {
    component <- components$component[i]
    variance <- components$variance[i]
    proportion <- variance / total_var
    
    if (proportion > 0.5) {
      priority <- "High"
      recommendation <- paste("Focus sampling effort on reducing", component)
    } else if (proportion > 0.25) {
      priority <- "Medium"
      recommendation <- paste("Moderate attention to", component)
    } else {
      priority <- "Low"
      recommendation <- paste("Low priority for", component)
    }
    
    recommendations[[component]] <- list(
      variance = variance,
      proportion = proportion,
      priority = priority,
      recommendation = recommendation
    )
  }
  
  return(recommendations)
}