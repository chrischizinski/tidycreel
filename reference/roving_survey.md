# Example Roving Survey Interview Data

Simulated roving creel survey data with incomplete trip interviews.
Designed to demonstrate [`est_cpue_roving()`](est_cpue_roving.md) with
length-bias correction.

## Usage

``` r
roving_survey
```

## Format

A tibble with 50 rows and 7 columns:

- interview_id:

  Unique interview identifier (1-50)

- location:

  Fishing location: "River" or "Lake"

- target_species:

  Target species: "Trout" or "Bass"

- catch_total:

  Total fish caught at time of interview (count)

- catch_kept:

  Fish kept at time of interview (count, \<= catch_total)

- hours_fished:

  Observed effort at interview time (hours, 0.5-8.0)

- total_hours_planned:

  Total planned trip effort (hours, \>= hours_fished)

## Source

Simulated data generated in `data-raw/roving_survey.R`

## Details

This dataset simulates 50 roving (on-site) interviews conducted during
incomplete fishing trips. Key features:

- **Incomplete trips**: All interviews occurred while anglers were still
  fishing, so `hours_fished` represents effort-to-date, not complete
  trip effort.

- **Length-bias sampling**: Longer trips have higher probability of
  being sampled (Robson 1961). The Pollock et al. (1997) correction uses
  `total_hours_planned` to adjust for this bias.

- **Realistic variation**: Catch rates vary by location (River: ~1
  fish/hr, Lake: ~1.5 fish/hr) with natural Poisson variation.

## Usage

Use with [`est_cpue_roving()`](est_cpue_roving.md) to estimate CPUE
accounting for incomplete trips:

    library(survey)

    # Basic CPUE estimate without length-bias correction
    svy <- svydesign(ids = ~1, data = roving_survey)
    est_cpue_roving(svy, length_bias_correction = "none")

    # CPUE with Pollock correction for length-bias
    est_cpue_roving(
      svy,
      length_bias_correction = "pollock",
      total_trip_effort_col = "total_hours_planned"
    )

    # Grouped estimates by location
    est_cpue_roving(
      svy,
      by = "location",
      length_bias_correction = "pollock",
      total_trip_effort_col = "total_hours_planned"
    )

## References

Pollock, K. H., C. M. Jones, and T. L. Brown. 1997. Angler survey
methods and their applications in fisheries management. American
Fisheries Society, Special Publication 25, Bethesda, Maryland.

Robson, D. S. 1961. On the statistical theory of a roving creel census
of fishermen. Biometrics 17:415-437.

## See also

[`est_cpue_roving()`](est_cpue_roving.md) for estimation from roving
survey data.

## Examples

``` r
# Load and examine the data
data(roving_survey)
head(roving_survey)
#> # A tibble: 6 × 7
#>   interview_id location target_species catch_total catch_kept hours_fished
#>          <int> <chr>    <chr>                <int>      <dbl>        <dbl>
#> 1            1 Lake     Trout                    1          1          5  
#> 2            2 Lake     Bass                     1          0          2.2
#> 3            3 River    Bass                     3          1          0.5
#> 4            4 Lake     Trout                    6          5          4.1
#> 5            5 River    Bass                     3          2          3.5
#> 6            6 Lake     Trout                    3          3          5.2
#> # ℹ 1 more variable: total_hours_planned <dbl>

# Summary statistics
summary(roving_survey)
#>   interview_id     location         target_species      catch_total  
#>  Min.   : 1.00   Length:50          Length:50          Min.   :0.00  
#>  1st Qu.:13.25   Class :character   Class :character   1st Qu.:3.00  
#>  Median :25.50   Mode  :character   Mode  :character   Median :4.00  
#>  Mean   :25.50                                         Mean   :3.96  
#>  3rd Qu.:37.75                                         3rd Qu.:5.00  
#>  Max.   :50.00                                         Max.   :9.00  
#>    catch_kept    hours_fished   total_hours_planned
#>  Min.   :0.00   Min.   :0.500   Min.   :1.700      
#>  1st Qu.:2.25   1st Qu.:2.125   1st Qu.:4.500      
#>  Median :3.00   Median :3.300   Median :5.050      
#>  Mean   :3.48   Mean   :3.140   Mean   :5.308      
#>  3rd Qu.:4.00   3rd Qu.:4.050   3rd Qu.:6.300      
#>  Max.   :8.00   Max.   :7.300   Max.   :8.500      

# Basic CPUE estimation
library(survey)
#> Loading required package: grid
#> Loading required package: Matrix
#> Loading required package: survival
#> 
#> Attaching package: ‘survey’
#> The following object is masked from ‘package:graphics’:
#> 
#>     dotchart
svy <- svydesign(ids = ~1, data = roving_survey)
#> Warning: No weights or probabilities supplied, assuming equal probability
est_cpue_roving(svy, length_bias_correction = "none")
#> # A tibble: 1 × 7
#>   estimate    se ci_low ci_high     n method                        diagnostics 
#>      <dbl> <dbl>  <dbl>   <dbl> <int> <chr>                         <list>      
#> 1     2.01 0.330   1.36    2.65    50 cpue_roving:mean_of_ratios:c… <named list>
```
