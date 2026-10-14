# Counts to Effort: How the Estimate and its Error Are Built

This page explains what
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
computes from angler counts and why its standard error has the parts it
has. It is for readers who know their survey and want to see the
arithmetic behind the numbers. For the steps of an analysis, see
[`vignette("tidycreel")`](https://chrischizinski.com/tidycreel/dev/articles/tidycreel.md).

The chain has three steps, and each section below takes one:

    one count  ->  one day's effort  ->  stratum total  ->  standard error
                  (count x hours)       (N_h / n_h x sum)   (between days, within days)

``` r

library(tidycreel)
```

## The sampling unit is the day

A creel season is divided into **strata**, groups of days expected to be
alike, such as weekdays and weekend days. Within a stratum, some days
are sampled and the rest are not. Each day belongs to exactly one
stratum, and the day is the **primary sampling unit** (PSU): it is what
was drawn at random, so it is what the standard error is computed over.

Write $`N_h`$ for the number of days in stratum $`h`$ and $`n_h`$ for
the number sampled. Everything below happens within one stratum. Strata
are estimated separately and added.

## From a count to a day’s effort

An **instantaneous count** is the number of anglers fishing at one
moment. It is a number of anglers, not an amount of effort. If the count
was taken at a random moment in a fishing period of length $`T`$ hours,
the count times $`T`$ is an unbiased estimate of the angler-hours in
that period (Hoenig et al. 1993):

``` math
\hat{e}_i = c_i \times T_i
```

tidycreel makes this multiplication when you name the column holding
$`T`$ with `period_length_col`, and reports the result in angler-hours.
Without it, the estimate is the counts expanded but not multiplied, its
unit is `NA`, and
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
warns that no period length was supplied. tidycreel never assumes a unit
it was not given.

## From sampled days to the stratum total

The stratum total is the number of days times the mean daily effort on
the sampled days:

``` math
\hat{E}_h = N_h \, \bar{e}_h = \frac{N_h}{n_h} \sum_{i=1}^{n_h} \hat{e}_i
```

$`N_h / n_h`$ is the expansion factor: when one day in two was sampled,
each sampled day stands for two.

Here is a stratum of 8 weekdays, 4 of them sampled, with one count per
day on a 10-hour fishing day:

``` r

calendar <- data.frame(
  date     = as.Date("2024-06-03") + 0:7,
  day_type = "weekday"
)
counts <- data.frame(
  date      = as.Date("2024-06-03") + 0:3,
  day_type  = "weekday",
  n_anglers = c(15L, 25L, 35L, 45L),
  hours     = 10
)

design <- creel_design(calendar, date = date, strata = day_type)
design <- add_counts(design, counts, period_length_col = hours)
estimate_effort(design, target = "period_total")
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: period_total
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     2400  365.       365.         0    1238.    3562.     4
```

By hand: daily effort is 150, 250, 350 and 450 angler-hours, a mean of
300, and $`\hat{E} = 8 \times 300 = 2{,}400`$ angler-hours.

`target = "period_total"` asks for the total over all 8 days. The
default, `target = "sampled_days"`, is the total over the 4 days counted
(1,200 here);
[`vignette("tidycreel")`](https://chrischizinski.com/tidycreel/dev/articles/tidycreel.md)
shows the two side by side.

## The standard error: variation between days

The estimate is uncertain because a different draw of days would have
given a different mean. That uncertainty is estimated from how much the
sampled days differ from each other:

``` math
\widehat{\text{Var}}_{\text{between}}(\hat{E}_h) =
N_h^2 \left(1 - \frac{n_h}{N_h}\right) \frac{s_b^2}{n_h}
```

where $`s_b^2`$ is the sample variance of the daily efforts
$`\hat{e}_i`$. The factor $`1 - n_h/N_h`$ is the **finite-population
correction**: days are drawn without replacement, so sampling half the
stratum removes part of the day-to-day uncertainty, and sampling all of
it would remove all of it. (Not the uncertainty from when in each day a
count fell; see the next section.)

For the stratum above, $`s_b^2 = 16{,}667`$, so

``` math
\widehat{\text{Var}} = 64 \times 0.5 \times \frac{16{,}667}{4} = 133{,}333,
\qquad \text{SE} = 365.1
```

which is the `se` and `se_between` printed above.

### One count per day: `se_within` is 0, and what that means

With one count per day, `se_within` is reported as 0. That does **not**
mean the number of anglers was steady through the day. Each day’s single
count landed at one moment out of many, and that chance is part of why
the sampled days differ, so $`s_b^2`$ contains it. With one count per
day it cannot be separated out: the 0 is a placeholder for “not
estimated”, and \#504 proposes reporting `NA` there instead.

It also means the standard error is **too small** when a large share of
the days is sampled. The finite-population correction is right for the
day-to-day part of $`s_b^2`$: sampling more of the days leaves less of
that to chance. It is wrong for the within-day part: even if every day
is sampled, when in the day each count fell is still chance. With all
days sampled the correction is 0 and tidycreel reports an SE of 0,
although a count at another moment would have given a different total.
The size of the shortfall grows with $`n_h / N_h`$ and with how much
activity varies within a day; it cannot be estimated from one count per
day. The two-stage formula below puts the missing part back when there
are several counts per day. \#505 is open to fix the one-count case;
until then, read the SE from a single count per day as a lower bound
when a large share of the days was sampled.

## Several counts per day: two-stage variance

When a day has $`k`$ counts at random times, the day’s effort is
estimated from their mean, and the day is now itself a sample: of the
moments in the day, $`k`$ were observed. That makes the design
**two-stage** (days, then moments within days), and the variance has a
term for each stage (Cochran 1977, chapter 10):

``` math
\widehat{\text{Var}}(\hat{E}_h) =
\underbrace{N_h^2 \left(1 - \frac{n_h}{N_h}\right) \frac{s_b^2}{n_h}}_{\text{between days}}
\; + \;
\underbrace{N_h \, \frac{s_w^2}{k}}_{\text{within days}}
```

- $`s_b^2`$ is the sample variance of the daily mean efforts.
- $`s_w^2 = \dfrac{\sum_i \sum_j (\hat{e}_{ij} - \bar{e}_i)^2}{n_h (k - 1)}`$
  is the within-day variance, pooled over the sampled days.

The within-day term is the second-stage term of Cochran’s two-stage
variance, $`f_1 (1 - f_2) s_2^2 / (nm)`$ scaled to a total, with the
second-stage sampling fraction $`f_2`$ taken as zero because a day
contains effectively unlimited moments. Pope et al. (Chapter 17 draft)
give the same two terms for creel counts. `se_between` and `se_within`
are the square roots of the two terms, and `se` the square root of their
sum.

**What within-day variance measures.** It is how much the number of
anglers present changes over the day: a morning bite and an empty
afternoon give a large $`s_w^2`$. It is not observer error; an exact
count at a different moment would still differ.

The same stratum, now with a morning and an afternoon count on each
sampled day. The daily means are the same as before (150, 250, 350, 450
angler-hours), so the between-day term does not change:

``` r

counts_2 <- data.frame(
  date       = rep(as.Date("2024-06-03") + 0:3, each = 2),
  day_type   = "weekday",
  count_time = rep(c("am", "pm"), 4),
  n_anglers  = c(10L, 20L, 20L, 30L, 30L, 40L, 40L, 50L),
  hours      = 10
)

design_2 <- creel_design(calendar, date = date, strata = day_type)
design_2 <- add_counts(design_2, counts_2,
  count_time_col = count_time, period_length_col = hours
)
estimate_effort(design_2, target = "period_total")
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: period_total
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     2400  392.       365.      141.    1154.    3646.     4
```

By hand: each day’s two efforts differ by 100 angler-hours, so each
day’s sum of squares is $`2 \times 50^2 = 5{,}000`$ and
$`s_w^2 = 4 \times 5{,}000 / (4 \times 1) = 5{,}000`$. The within-day
variance is $`8 \times 5{,}000 / 2 = 20{,}000`$, an SE of 141.4. The
total SE is $`\sqrt{133{,}333 + 20{,}000} = 391.6`$.

The formula assumes every sampled day in a stratum has the same number
of counts. Days with different numbers of counts are open as \#405.

### More days or more counts per day?

The two terms show where the uncertainty comes from, but not, on their
own, what to change. Adding sampled days reduces all of the variance,
the day-to-day part and the within-day part; adding counts per day
reduces only the within-day part, and is usually cheaper than adding a
day. The best split depends on both the variance components and the cost
of a day versus the cost of a count; Cochran (1977, section 10.6,
equation 10.26) gives the optimum number of counts per day. There is no
fixed ratio of `se_within` to `se` beyond which one choice wins.

## Progressive counts

A **progressive count** is a different field method. The observer
travels the whole section once (a **circuit**, taking $`\tau`$ hours)
and counts every angler passed. The day’s effort is

``` math
\hat{e}_d = C_d \times T_d
```

where $`C_d`$ is the circuit’s count and $`T_d`$ the hours the fishery
is open that day.

**Why $`\tau`$ does not appear.** Follow Hoenig et al. (1993, p. 725).
The circuit samples one $`\tau`$-hour block of the day, so the count
expands over its own duration first: $`C_d \times \tau`$. The day is
made of $`K = T_d / \tau`$ such blocks, and the circuit’s block was
drawn at random from them, so the day’s effort is

``` math
\hat{e}_d = C_d \times \tau \times \frac{T_d}{\tau} = C_d \times T_d
```

$`\tau`$ enters twice, once expanding the block and once counting the
blocks, and cancels. It has already done its work in **defining the
blocks the circuit was scheduled within**, which is why
[`generate_progressive_start()`](https://chrischizinski.com/tidycreel/dev/reference/generate_progressive_start.md)
needs it and the final arithmetic does not.
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
still requires it: a fishing period shorter than one circuit ($`K < 1`$)
is an error, since no circuit could finish, and $`\tau = T_d`$
($`K = 1`$) is the legitimate all-day circuit of Robson (1961).

Six weekdays, three sampled, a 2-hour circuit on an 8-hour day:

``` r

calendar_p <- data.frame(
  date     = as.Date("2024-06-03") + 0:5,
  day_type = "weekday"
)
prog_counts <- data.frame(
  date        = as.Date("2024-06-03") + 0:2,
  day_type    = "weekday",
  n_anglers   = c(15L, 20L, 25L),
  shift_hours = 8
)

design_p <- creel_design(calendar_p, date = date, strata = day_type)
design_p <- add_counts(design_p, prog_counts,
  count_type = "progressive",
  circuit_time = 2,
  period_length_col = shift_hours
)

design_p$counts
#>         date day_type n_anglers
#> 1 2024-06-03  weekday       120
#> 2 2024-06-04  weekday       160
#> 3 2024-06-05  weekday       200
estimate_effort(design_p, target = "period_total")
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: period_total
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1      960  98.0       98.0         0     538.    1382.     3
```

[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
stores each day’s $`C_d \times T_d`$: 120, 160 and 200 angler-hours. The
total is $`6 \times 160 = 960`$ angler-hours. One circuit a day gives
one estimate a day, so the variance is the between-day term alone, as
for one instantaneous count a day, and it is too small in the same way
when a large share of the days is sampled (#505).

The estimate is unbiased only when the circuit’s start time, start point
and direction were randomised and the observer moved faster than the
anglers. None of that can be checked from the counts table;
[`vignette("progressive-count-surveys")`](https://chrischizinski.com/tidycreel/dev/articles/progressive-count-surveys.md)
gives the field conditions.

## Summary

| Data | Day’s effort | Variance terms | `se_within` |
|----|----|----|----|
| One instantaneous count per day | $`c_i T_i`$ | between days only; too small when $`n_h/N_h`$ is large (#505) | 0: not estimated (#504) |
| $`k`$ instantaneous counts per day | mean of $`c_{ij} T_i`$ | between days + within days | estimated |
| One progressive circuit per day | $`C_d T_d`$ | between days only; too small when $`n_h/N_h`$ is large (#505) | 0: not estimated (#504) |

In every case the stratum total is $`N_h`$ times the mean daily effort,
the between-day term carries the finite-population correction, and
strata are added.

## References

- Cochran, W. G. (1977). *Sampling Techniques*, 3rd edition. Wiley, New
  York. Chapter 10, subsampling with units of equal size.
- Hoenig, J. M., Robson, D. S., Jones, C. M., and Pollock, K. H. (1993).
  Scheduling counts in the instantaneous and progressive count methods
  for estimating sportfishing effort. *North American Journal of
  Fisheries Management*, 13, 723–736.
- Pope, K. L., et al. Creel surveys. Chapter 17 (unpublished draft).
- Robson, D. S. (1961). On the statistical theory of a roving creel
  census of fishermen. *Biometrics*, 17, 415–437.
