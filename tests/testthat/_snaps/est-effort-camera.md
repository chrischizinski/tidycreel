# CEST-24: imputed-count warning text states n, share, and the SE gap (GH #137)

    Code
      res <- est_effort_camera(d, h_open = 14)
    Condition
      Warning:
      2 of 5 count days (40%) are imputed.
      x Prediction uncertainty for imputed counts is not included in the SE.
      i Imputed counts also vary less than observed ones, so the between-day component is understated as well; the reported SE is a lower bound.

