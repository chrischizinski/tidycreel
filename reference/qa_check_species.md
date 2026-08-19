# Check for Species Identification Issues

Detects potential species identification errors and unlikely species
combinations that may indicate data entry mistakes or misidentification
(Table 17.3, \#7).

## Usage

``` r
qa_check_species(
  interviews,
  species_col = "species",
  location_col = NULL,
  date_col = "date",
  catch_col = "catch_total",
  reference_species = NULL,
  rare_species_threshold = 0.01,
  seasonal_check = TRUE,
  location_check = TRUE,
  min_records_per_species = 3
)
```

## Arguments

- interviews:

  Interview data containing species information

- species_col:

  Column containing species names or codes

- location_col:

  Column containing location/waterbody information

- date_col:

  Column containing date information

- catch_col:

  Column containing catch counts (for validation)

- reference_species:

  Character vector of expected species for the waterbody. If NULL, uses
  all species found in data.

- rare_species_threshold:

  Proportion threshold below which species are considered rare and
  flagged for review (default 0.01 = 1%)

- seasonal_check:

  Logical, whether to check for seasonally unlikely species (requires
  date information). Default TRUE.

- location_check:

  Logical, whether to check for location-inappropriate species. Default
  TRUE.

- min_records_per_species:

  Minimum number of records required for a species to be considered
  established (default 3)

## Value

List with:

- issue_detected:

  Logical, TRUE if species issues detected

- severity:

  "high", "medium", "low", or "none"

- n_total:

  Total number of interviews

- n_species_total:

  Total number of unique species

- n_rare_species:

  Number of rare species (below threshold)

- n_singleton_species:

  Number of species with only 1 record

- n_unlikely_combinations:

  Number of unlikely species combinations

- n_seasonal_outliers:

  Number of seasonally unlikely records

- n_location_outliers:

  Number of location-inappropriate species

- rare_species_records:

  Sample records with rare species

- singleton_species:

  List of species with only 1 record

- unlikely_combinations:

  Sample records with unlikely combinations

- seasonal_outliers:

  Sample seasonally inappropriate records

- location_outliers:

  Sample location-inappropriate records

- species_summary:

  Summary statistics by species

- recommendation:

  Text guidance for remediation

## Details

### Detection Logic

1.  **Rare Species Detection:**

    - Identify species below frequency threshold

    - Flag singleton species (only 1 record)

    - Check for typos in species names

2.  **Unlikely Combinations:**

    - Saltwater species in freshwater locations

    - Cold-water species in warm-water periods

    - Predator-prey species caught together unusually often

3.  **Seasonal Appropriateness:**

    - Ice fishing species in summer

    - Spawning season species outside spawning periods

    - Migration timing inconsistencies

4.  **Location Appropriateness:**

    - Species outside known range

    - Habitat-specific species in wrong habitat types

    - Elevation or climate mismatches

5.  **Data Quality Indicators:**

    - Inconsistent species naming conventions

    - Missing species information

    - Catch records without species identification

### Common Issues Detected

- **Typos**: "Walleye" vs "Waleye", "Bass" vs "Base"

- **Code Errors**: Numeric codes entered incorrectly

- **Habitat Mismatches**: Trout in warm-water lakes

- **Seasonal Errors**: Ice fishing species in July

- **Range Extensions**: Species outside known distribution

- **Identification Errors**: Similar-looking species confused

## See also

[`qa_checks`](qa_checks.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic species validation
species_check <- qa_check_species(
  interviews,
  species_col = "species",
  location_col = "waterbody"
)

# With reference species list
expected_species <- c("Walleye", "Northern Pike", "Yellow Perch", "Bluegill")
species_check <- qa_check_species(
  interviews,
  species_col = "species",
  reference_species = expected_species
)

# Comprehensive check with seasonal validation
species_check <- qa_check_species(
  interviews,
  species_col = "species",
  location_col = "lake",
  date_col = "date",
  seasonal_check = TRUE,
  location_check = TRUE
)
} # }
```
