# Auxiliary Data Schema

Defines the expected structure for auxiliary data (sunrise/sunset,
holidays).

## Format

A tibble with the following columns:

- date:

  Date, date of auxiliary data

- sunrise:

  POSIXct, sunrise time

- sunset:

  POSIXct, sunset time

- holiday:

  Character, holiday name (if any)
