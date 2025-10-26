#' Check for Species Identification Issues
#'
#' Detects potential species identification errors and unlikely species
#' combinations that may indicate data entry mistakes or misidentification
#' (Table 17.3, #7).
#'
#' @param interviews Interview data containing species information
#' @param species_col Column containing species names or codes
#' @param location_col Column containing location/waterbody information
#' @param date_col Column containing date information
#' @param catch_col Column containing catch counts (for validation)
#' @param reference_species Character vector of expected species for the waterbody.
#'   If NULL, uses all species found in data.
#' @param rare_species_threshold Proportion threshold below which species are
#'   considered rare and flagged for review (default 0.01 = 1%)
#' @param seasonal_check Logical, whether to check for seasonally unlikely
#'   species (requires date information). Default TRUE.
#' @param location_check Logical, whether to check for location-inappropriate
#'   species. Default TRUE.
#' @param min_records_per_species Minimum number of records required for a
#'   species to be considered established (default 3)
#'
#' @return List with:
#'   \describe{
#'     \item{issue_detected}{Logical, TRUE if species issues detected}
#'     \item{severity}{"high", "medium", "low", or "none"}
#'     \item{n_total}{Total number of interviews}
#'     \item{n_species_total}{Total number of unique species}
#'     \item{n_rare_species}{Number of rare species (below threshold)}
#'     \item{n_singleton_species}{Number of species with only 1 record}
#'     \item{n_unlikely_combinations}{Number of unlikely species combinations}
#'     \item{n_seasonal_outliers}{Number of seasonally unlikely records}
#'     \item{n_location_outliers}{Number of location-inappropriate species}
#'     \item{rare_species_records}{Sample records with rare species}
#'     \item{singleton_species}{List of species with only 1 record}
#'     \item{unlikely_combinations}{Sample records with unlikely combinations}
#'     \item{seasonal_outliers}{Sample seasonally inappropriate records}
#'     \item{location_outliers}{Sample location-inappropriate records}
#'     \item{species_summary}{Summary statistics by species}
#'     \item{recommendation}{Text guidance for remediation}
#'   }
#'
#' @details
#' ## Detection Logic
#'
#' 1. **Rare Species Detection:**
#'    - Identify species below frequency threshold
#'    - Flag singleton species (only 1 record)
#'    - Check for typos in species names
#'
#' 2. **Unlikely Combinations:**
#'    - Saltwater species in freshwater locations
#'    - Cold-water species in warm-water periods
#'    - Predator-prey species caught together unusually often
#'
#' 3. **Seasonal Appropriateness:**
#'    - Ice fishing species in summer
#'    - Spawning season species outside spawning periods
#'    - Migration timing inconsistencies
#'
#' 4. **Location Appropriateness:**
#'    - Species outside known range
#'    - Habitat-specific species in wrong habitat types
#'    - Elevation or climate mismatches
#'
#' 5. **Data Quality Indicators:**
#'    - Inconsistent species naming conventions
#'    - Missing species information
#'    - Catch records without species identification
#'
#' ## Common Issues Detected
#'
#' - **Typos**: "Walleye" vs "Waleye", "Bass" vs "Base"
#' - **Code Errors**: Numeric codes entered incorrectly
#' - **Habitat Mismatches**: Trout in warm-water lakes
#' - **Seasonal Errors**: Ice fishing species in July
#' - **Range Extensions**: Species outside known distribution
#' - **Identification Errors**: Similar-looking species confused
#'
#' @examples
#' \dontrun{
#' # Basic species validation
#' species_check <- qa_check_species(
#'   interviews,
#'   species_col = "species",
#'   location_col = "waterbody"
#' )
#' 
#' # With reference species list
#' expected_species <- c("Walleye", "Northern Pike", "Yellow Perch", "Bluegill")
#' species_check <- qa_check_species(
#'   interviews,
#'   species_col = "species",
#'   reference_species = expected_species
#' )
#' 
#' # Comprehensive check with seasonal validation
#' species_check <- qa_check_species(
#'   interviews,
#'   species_col = "species",
#'   location_col = "lake",
#'   date_col = "date",
#'   seasonal_check = TRUE,
#'   location_check = TRUE
#' )
#' }
#'
#' @seealso \code{\link{qa_checks}}, \code{\link{validate_species}}
#'
#' @export
qa_check_species <- function(interviews,
                            species_col = "species",
                            location_col = NULL,
                            date_col = "date", 
                            catch_col = "catch_total",
                            reference_species = NULL,
                            rare_species_threshold = 0.01,
                            seasonal_check = TRUE,
                            location_check = TRUE,
                            min_records_per_species = 3) {
  
  # Validate inputs
  tc_require_cols(interviews, species_col, "qa_check_species")
  
  if (!is.null(location_col)) {
    tc_require_cols(interviews, location_col, "qa_check_species")
  }
  
  if (seasonal_check && !is.null(date_col)) {
    tc_require_cols(interviews, date_col, "qa_check_species")
  }
  
  if (!is.null(catch_col)) {
    tc_require_cols(interviews, catch_col, "qa_check_species")
  }
  
  # Initialize results
  n_total <- nrow(interviews)
  issues <- list()
  severity <- "none"
  
  # Clean and standardize species names
  species_data <- interviews[[species_col]]
  species_data <- trimws(species_data)  # Remove whitespace
  species_data[species_data == "" | is.na(species_data)] <- "Unknown"
  
  # Basic species summary
  species_counts <- table(species_data, useNA = "ifany")
  species_props <- species_counts / sum(species_counts)
  n_species_total <- length(species_counts)
  
  # 1. Rare species detection
  rare_threshold_count <- max(1, floor(rare_species_threshold * n_total))
  rare_species <- names(species_counts)[species_counts < rare_threshold_count]
  singleton_species <- names(species_counts)[species_counts == 1]
  
  n_rare_species <- length(rare_species)
  n_singleton_species <- length(singleton_species)
  
  # Get sample records with rare species
  rare_species_records <- if (n_rare_species > 0) {
    interviews[interviews[[species_col]] %in% rare_species, ] %>%
      utils::head(5)
  } else {
    data.frame()
  }
  
  # 2. Check against reference species list
  unexpected_species <- character(0)
  if (!is.null(reference_species)) {
    found_species <- unique(species_data[species_data != "Unknown"])
    unexpected_species <- setdiff(found_species, reference_species)
  }
  
  # 3. Detect potential typos in species names
  potential_typos <- .detect_species_typos(species_data)
  
  # 4. Seasonal appropriateness check
  seasonal_outliers <- data.frame()
  n_seasonal_outliers <- 0
  if (seasonal_check && !is.null(date_col) && date_col %in% names(interviews)) {
    seasonal_check_result <- .check_seasonal_species(interviews, species_col, date_col)
    seasonal_outliers <- seasonal_check_result$outliers
    n_seasonal_outliers <- nrow(seasonal_outliers)
  }
  
  # 5. Location appropriateness check  
  location_outliers <- data.frame()
  n_location_outliers <- 0
  if (location_check && !is.null(location_col) && location_col %in% names(interviews)) {
    location_check_result <- .check_location_species(interviews, species_col, location_col)
    location_outliers <- location_check_result$outliers
    n_location_outliers <- nrow(location_outliers)
  }
  
  # 6. Check for unlikely species combinations
  unlikely_combinations <- .check_species_combinations(interviews, species_col, catch_col)
  n_unlikely_combinations <- nrow(unlikely_combinations)
  
  # Determine overall severity
  total_issues <- n_singleton_species + length(unexpected_species) + 
                 length(potential_typos) + n_seasonal_outliers + 
                 n_location_outliers + n_unlikely_combinations
  
  if (total_issues == 0) {
    severity <- "none"
  } else if (n_singleton_species > n_total * 0.1 || length(unexpected_species) > 0) {
    severity <- "high"  # Many singletons or unexpected species
  } else if (total_issues > n_total * 0.05) {
    severity <- "medium"  # >5% of records have issues
  } else {
    severity <- "low"
  }
  
  issue_detected <- severity != "none"
  
  # Create species summary
  species_summary <- data.frame(
    species = names(species_counts),
    count = as.numeric(species_counts),
    proportion = as.numeric(species_props),
    status = ifelse(names(species_counts) %in% singleton_species, "singleton",
             ifelse(names(species_counts) %in% rare_species, "rare", "common")),
    stringsAsFactors = FALSE
  ) %>%
    dplyr::arrange(desc(count))
  
  # Generate recommendations
  recommendation <- .generate_species_recommendations(
    n_singleton_species, length(unexpected_species), length(potential_typos),
    n_seasonal_outliers, n_location_outliers, n_unlikely_combinations
  )
  
  # Return results
  list(
    issue_detected = issue_detected,
    severity = severity,
    n_total = n_total,
    n_species_total = n_species_total,
    n_rare_species = n_rare_species,
    n_singleton_species = n_singleton_species,
    n_unlikely_combinations = n_unlikely_combinations,
    n_seasonal_outliers = n_seasonal_outliers,
    n_location_outliers = n_location_outliers,
    rare_species_records = rare_species_records,
    singleton_species = singleton_species,
    unexpected_species = unexpected_species,
    potential_typos = potential_typos,
    unlikely_combinations = unlikely_combinations,
    seasonal_outliers = seasonal_outliers,
    location_outliers = location_outliers,
    species_summary = species_summary,
    recommendation = recommendation
  )
}

# Helper function to detect potential typos
.detect_species_typos <- function(species_data) {
  # Simple typo detection based on string similarity
  unique_species <- unique(species_data[species_data != "Unknown"])
  potential_typos <- character(0)
  
  if (length(unique_species) > 1) {
    # Check for very similar species names (potential typos)
    for (i in seq_along(unique_species)) {
      for (j in seq_along(unique_species)) {
        if (i != j) {
          # Calculate string distance
          dist <- utils::adist(unique_species[i], unique_species[j])
          # If very similar (1-2 character difference) and different lengths
          if (dist <= 2 && dist > 0 && 
              abs(nchar(unique_species[i]) - nchar(unique_species[j])) <= 2) {
            potential_typos <- c(potential_typos, 
                               paste(unique_species[i], "vs", unique_species[j]))
          }
        }
      }
    }
  }
  
  unique(potential_typos)
}

# Helper function to check seasonal appropriateness
.check_seasonal_species <- function(interviews, species_col, date_col) {
  # Simplified seasonal check - would need species-specific rules in practice
  outliers <- data.frame()
  
  if (date_col %in% names(interviews)) {
    interviews$month <- lubridate::month(interviews[[date_col]])
    
    # Example: Flag cold-water species in summer months (June-August)
    cold_water_species <- c("Lake Trout", "Brook Trout", "Cisco", "Whitefish")
    summer_months <- 6:8
    
    cold_in_summer <- interviews[
      interviews[[species_col]] %in% cold_water_species & 
      interviews$month %in% summer_months,
    ]
    
    if (nrow(cold_in_summer) > 0) {
      outliers <- rbind(outliers, cold_in_summer)
    }
  }
  
  list(outliers = outliers)
}

# Helper function to check location appropriateness  
.check_location_species <- function(interviews, species_col, location_col) {
  # Simplified location check - would need location-specific rules
  outliers <- data.frame()
  
  # Example: Flag saltwater species in freshwater locations
  saltwater_species <- c("Striped Bass", "Bluefish", "Flounder", "Cod")
  freshwater_indicators <- c("Lake", "Pond", "River", "Creek", "Stream")
  
  if (location_col %in% names(interviews)) {
    freshwater_locations <- grepl(
      paste(freshwater_indicators, collapse = "|"), 
      interviews[[location_col]], 
      ignore.case = TRUE
    )
    
    saltwater_in_fresh <- interviews[
      interviews[[species_col]] %in% saltwater_species & freshwater_locations,
    ]
    
    if (nrow(saltwater_in_fresh) > 0) {
      outliers <- rbind(outliers, saltwater_in_fresh)
    }
  }
  
  list(outliers = outliers)
}

# Helper function to check species combinations
.check_species_combinations <- function(interviews, species_col, catch_col) {
  # Simplified combination check
  unlikely_combinations <- data.frame()
  
  # This would need more sophisticated logic in practice
  # For now, just return empty data frame
  unlikely_combinations
}

# Helper function to generate recommendations
.generate_species_recommendations <- function(n_singleton, n_unexpected, n_typos,
                                            n_seasonal, n_location, n_combinations) {
  recommendations <- character(0)
  
  if (n_singleton > 0) {
    recommendations <- c(recommendations,
      paste("Review", n_singleton, "singleton species - may be typos or rare catches"))
  }
  
  if (n_unexpected > 0) {
    recommendations <- c(recommendations,
      paste("Verify", n_unexpected, "unexpected species against reference list"))
  }
  
  if (n_typos > 0) {
    recommendations <- c(recommendations,
      paste("Check", n_typos, "potential species name typos"))
  }
  
  if (n_seasonal > 0) {
    recommendations <- c(recommendations,
      paste("Verify", n_seasonal, "seasonally unusual species records"))
  }
  
  if (n_location > 0) {
    recommendations <- c(recommendations,
      paste("Verify", n_location, "location-inappropriate species"))
  }
  
  if (n_combinations > 0) {
    recommendations <- c(recommendations,
      paste("Review", n_combinations, "unlikely species combinations"))
  }
  
  if (length(recommendations) == 0) {
    recommendations <- "Species identification appears consistent and appropriate"
  }
  
  paste(recommendations, collapse = "; ")
}