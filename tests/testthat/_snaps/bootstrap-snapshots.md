# SNAP-BOOT-01: estimate_total_harvest default output is stable

    Code
      tidy(result)
    Output
      # A tibble: 1 x 5
        estimate    se ci_lower ci_upper     n
           <dbl> <dbl>    <dbl>    <dbl> <int>
      1     115.  78.3    -38.8     268.     8

# SNAP-BOOT-02: estimate_total_catch default output is stable

    Code
      tidy(result)
    Output
      # A tibble: 1 x 5
        estimate    se ci_lower ci_upper     n
           <dbl> <dbl>    <dbl>    <dbl> <int>
      1     515.  192.     138.     892.     8

# SNAP-BOOT-03: estimate_angler_n default output is stable

    Code
      tidy(result)
    Output
      # A tibble: 1 x 6
        parameter estimate    se ci_lower ci_upper     n
        <chr>        <dbl> <dbl>    <dbl>    <dbl> <int>
      1 N_hat         931.  232.     407.    1455.    10

# SNAP-BOOT-04: estimate_mr_harvest default output is stable

    Code
      tidy(result)
    Output
      # A tibble: 1 x 6
        parameter     estimate    se ci_lower ci_upper     n
        <chr>            <dbl> <dbl>    <dbl>    <dbl> <int>
      1 total_harvest     326.  81.1     142.     509.    NA

