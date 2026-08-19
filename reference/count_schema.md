# Instantaneous Count Schema

Defines the expected structure for instantaneous count data.

## Format

A tibble with the following columns:

- count_id:

  Character, unique count identifier

- date:

  Date, count date

- time:

  POSIXct, count time

- location:

  Character, sampling location

- mode:

  Character, fishing mode

- anglers_count:

  Integer, number of anglers observed

- parties_count:

  Integer, number of fishing parties observed

- weather_code:

  Character, weather condition code

- temperature:

  Numeric, temperature in Celsius

- wind_speed:

  Numeric, wind speed

- visibility:

  Character, visibility conditions

- count_duration:

  Numeric, duration of count in minutes
