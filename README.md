# tidycreel <img src="man/figures/logo.png" align="right" height="139" alt="" />

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN status](https://www.r-pkg.org/badges/version/tidycreel)](https://CRAN.R-project.org/package=tidycreel)
[![R-CMD-check](https://github.com/cchizinski2/tidycreel/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/cchizinski2/tidycreel/actions/workflows/R-CMD-check.yaml)
[![R-CMD-check](https://github.com/chrischizinski/tidycreel/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/chrischizinski/tidycreel/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

## Overview

`tidycreel` provides a comprehensive framework for designing and analyzing access-point creel surveys in recreational fisheries. Built on the robust `survey` package, it offers a tidy, pipe-friendly interface for survey design construction, data validation, effort estimation, catch rate estimation, and variance estimation.

## Key Features

- **Survey Design Constructors**: Support for access-point, roving, and hybrid survey designs
- **Built-in Validation**: Automatic validation of interview, count, and calendar data
- **Replicate Weights**: Bootstrap, jackknife, and BRR methods for variance estimation
- **Effort Estimation**: Advanced methods for roving survey effort estimation
- **Post-stratification**: Calibration and post-stratification options
- **Tidy Interface**: Full integration with the tidyverse ecosystem

## Installation

You can install the development version from GitHub:

```r
# install.packages("devtools")
devtools::install_github("cchizinski2/tidycreel")
```

## Quick Start

### 1. Load Example Data

```r
library(tidycreel)
library(dplyr)

# Load example datasets
interviews <- readr::read_csv(system.file("extdata/toy_interviews.csv", 
                                        package = "tidycreel"))
counts <- readr::read_csv(system.file("extdata/toy_counts.csv", 
                                    package = "tidycreel"))
calendar <- readr::read_csv(system.file("extdata/toy_calendar.csv", 
                                      package = "tidycreel"))
```

### 2. Create Survey Designs

#### Access-Point Design
```r
# Create access-point survey design
access_design <- design_access(
  interviews = interviews,
  calendar = calendar,
  strata_vars = c("date", "shift_block", "location"),
  weight_method = "standard"
)
```

#### Roving Design
```r
# Create roving survey design
roving_design <- design_roving(
  interviews = interviews,
  counts = counts,
  calendar = calendar,
  strata_vars = c("date", "shift_block", "location"),
  effort_method = "ratio"
)
```

#### Add Replicate Weights
```r
# Add bootstrap replicate weights
rep_design <- design_repweights(
  base_design = access_design,
  replicates = 100,
  method = "bootstrap"
)
```

### 3. Validate Data

All survey design constructors include built-in validation:

```r
# Validate interview data
validate_interviews(interviews)

# Validate count data
validate_counts(counts)

# Validate calendar data
validate_calendar(calendar)
```

## Survey Design Types

### Access-Point Surveys
Access-point surveys are conducted at fixed locations where anglers exit the fishery. Interviewers attempt to interview all exiting anglers during scheduled interview periods.

**Key assumptions:**
- Complete coverage of exiting anglers during interview periods
- Accurate counts of total anglers exiting
- Representative sampling across time and space

### Roving Surveys
Roving surveys involve interviewers moving between locations to conduct interviews. This design requires additional count data to estimate fishing effort.

**Key features:**
- Requires count data for effort estimation
- Uses ratio estimation methods
- Can incorporate coverage correction factors

### Replicate Weights
Replicate weights provide robust variance estimation for complex survey designs.

**Supported methods:**
- **Bootstrap**: Resampling with replacement
- **Jackknife**: Leave-one-out resampling
- **BRR**: Balanced repeated replication

## Advanced Usage

### Custom Stratification

```r
# Custom stratification variables
custom_design <- design_access(
  interviews = interviews,
  calendar = calendar,
  strata_vars = c("date", "location", "mode"),
  weight_method = "post_stratify"
)
```

### Handling Complex Designs

```r
# Hybrid design with multiple modes
hybrid_design <- design_roving(
  interviews = interviews,
  counts = counts,
  calendar = calendar,
  strata_vars = c("date", "shift_block", "location", "mode"),
  effort_method = "separate_ratio",
  coverage_correction = TRUE
)
```

## Data Requirements

### Interview Data
Required columns:
- `date`: Interview date
- `time_start`: Interview start time
- `time_end`: Interview end time
- `location`: Sampling location
- `mode`: Fishing mode (shore, boat, etc.)
- `catch_total`: Total fish caught
- `catch_kept`: Fish kept
- `catch_released`: Fish released
- `hours_fished`: Hours spent fishing
- `party_size`: Number of anglers in party

### Count Data (Roving Surveys)
Required columns:
- `date`: Count date
- `time_start`: Count start time
- `time_end`: Count end time
- `location`: Count location
- `anglers_count`: Number of anglers counted
- `parties_count`: Number of parties counted

### Calendar Data
Required columns:
- `date`: Survey date
- `location`: Survey location
- `shift_block`: Time block identifier
- `weekend`: Weekend indicator
- `holiday`: Holiday indicator
- `target_sample`: Target sample size
- `actual_sample`: Actual sample size

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## License

This package is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Citation

If you use `tidycreel` in your research, please cite:

```bibtex
@software{tidycreel2024,
  title = {tidycreel: Tidy Interface for Creel Survey Design and Analysis},
  author = {Chris Chizinski},
  year = {2024},
  url = {https://github.com/cchizinski2/tidycreel},
  version = {0.0.0.9000}
}
