# Sampling Calendar Schema

Defines the expected structure for sampling calendar data including
temporal strata definitions.

## Format

A tibble with the following columns:

- date:

  Date, sampling date

- stratum_id:

  Character, unique stratum identifier

- day_type:

  Character, type of day (weekday, weekend, holiday)

- season:

  Character, season identifier

- month:

  Character, month identifier

- weekend:

  Logical, TRUE if weekend

- holiday:

  Logical, TRUE if holiday

- shift_block:

  Character, shift identifier (morning, afternoon, evening)

- target_sample:

  Integer, target sample size for stratum

- actual_sample:

  Integer, actual sample size achieved
