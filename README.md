---
output: github_document
---

# tidycreel

Tidy Interface for Creel Survey Design and Analysis

## Installation

You can install the development version of tidycreel from GitHub:

```r
# install.packages("devtools")
devtools::install_github("chrischizinski/tidycreel")
```

## Overview

tidycreel provides a tidy, pipe-friendly interface for creel survey design, data management, estimation, and reporting. Built on the 'survey' package for robust design-based inference.

## Features

### v0.3.0 (Current Development)

- **Incomplete Trip Support**: Mean-of-ratios estimator for incomplete trip CPUE
  - Trip status tracking (complete vs. incomplete trips)
  - Trip duration calculation (including overnight trips)
  - Trip truncation (threshold-based filtering for short trips)
  - Statistical validation with TOST equivalence testing (`validate_incomplete_trips()`)
  - Diagnostic comparison mode (`use_trips = "diagnostic"`)
- **Default to Complete Trips**: Following Colorado C-SAP best practices
- **Sample Size Warnings**: Alerts when <10% of interviews are complete trips
- **Comprehensive Documentation**: Vignettes covering when and how to use incomplete trip estimation

### v0.2.0

- Interview-based catch and harvest estimation
- Ratio-of-means CPUE/harvest estimation
- Total catch/harvest with delta method variance
- Complete interview data workflow

### v0.1.0

- Survey design constructor with tidy selectors
- Instantaneous count data integration
- Effort estimation with grouped analysis
- Multiple variance methods (Taylor, bootstrap, jackknife)

## Usage

Documentation and examples coming soon as features are implemented.

## License

MIT License - see LICENSE.md for details.
