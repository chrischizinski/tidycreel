# Interview Data Schema

Defines the expected structure for angler interview data.

## Format

A tibble with the following columns:

- interview_id:

  Character, unique interview identifier

- date:

  Date, interview date

- time_start:

  POSIXct, interview start time

- time_end:

  POSIXct, interview end time

- location:

  Character, sampling location

- mode:

  Character, fishing mode (bank, boat, ice, etc.)

- party_size:

  Integer, number of anglers in party

- hours_fished:

  Numeric, hours fished by party

- target_species:

  Character, primary target species

- catch_total:

  Integer, total fish caught

- catch_kept:

  Integer, fish kept

- catch_released:

  Integer, fish released

- weight_total:

  Numeric, total weight of catch (kg)

- trip_complete:

  Logical, TRUE if trip was complete at interview

- effort_expansion:

  Numeric, expansion factor for effort estimation
