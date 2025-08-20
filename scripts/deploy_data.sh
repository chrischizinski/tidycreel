#!/bin/bash
set -e

# Process all toy datasets
Rscript -e 'library(usethis);
toy_interviews <- read.csv("inst/extdata/toy_interviews.csv");
toy_counts <- read.csv("inst/extdata/toy_counts.csv");
toy_catch <- read.csv("inst/extdata/toy_catch.csv");
usethis::use_data(toy_interviews, toy_counts, toy_catch, overwrite = TRUE)'

# Generate documentation
Rscript -e 'devtools::document()'

# Basic validation
Rscript -e 'data(toy_interviews, toy_counts, toy_catch);
cat("Successfully loaded", nrow(toy_interviews), "interview records\n",
    nrow(toy_counts), "count records\n",
    nrow(toy_catch), "catch records\n")'
