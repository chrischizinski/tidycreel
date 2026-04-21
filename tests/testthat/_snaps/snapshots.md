# print.creel_design snapshot

    Code
      print(design)
    Output

      -- Creel Survey Design ---------------------------------------------------------
      Type: "instantaneous"
      Date column: date
      Strata: day_type
      Calendar: 2 days (2024-06-01 to 2024-06-02)
      day_type: 2 levels
      Counts: "none"
      Interviews: "none"
      Sections: "none"

# print.creel_estimates_mor snapshot

    Code
      print(result)
    Output
      -- DIAGNOSTIC: MOR Estimator (Incomplete Trips) --------------------------------
      ! Complete trips preferred for CPUE estimation.
      This estimate uses incomplete trip interviews (10 of 10 total).
      Truncation: 0 trips excluded (threshold: 0.5 hours)
      Validate with `validate_incomplete_trips()` before use (Phase 19).


      -- Creel Survey Estimates ------------------------------------------------------
      Method: Mean-of-Ratios CPUE
      Variance: Taylor linearization
      Confidence level: 95%

      # A tibble: 1 x 5
        estimate    se ci_lower ci_upper     n
           <dbl> <dbl>    <dbl>    <dbl> <int>
      1     1.34 0.143     1.06     1.62    10

# print.creel_schedule snapshot

    Code
      print(sched)
    Output
      # A creel_schedule: 18 rows x 3 cols (18 days, 1 periods)
      June 2024
      | Sun      | Mon      | Tue      | Wed      | Thu      | Fri      | Sat      |
      |----------|----------|----------|----------|----------|----------|----------|
      |          |          |          |          |          |          | WEEKE    |
      | WEEKE    | 03       | WEEKD    | 05       | WEEKD    | WEEKD    | 08       |
      | WEEKE    | 10       | WEEKD    | 12       | WEEKD    | WEEKD    | WEEKE    |
      | WEEKE    | 17       | 18       | 19       | WEEKD    | WEEKD    | 22       |
      | WEEKE    | 24       | WEEKD    | 26       | 27       | WEEKD    | WEEKE    |
      | WEEKE    |          |          |          |          |          |          |
