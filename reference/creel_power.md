# Estimate statistical power to detect a change in CPUE between seasons

Calculates the probability of detecting a fractional change in CPUE
given a target sample size per season, a historical CV, and a
significance level. Uses a two-sample normal approximation with equal
group sizes.

## Usage

``` r
creel_power(
  n,
  cv_historical,
  delta_pct,
  alpha = 0.05,
  alternative = c("two.sided", "one.sided")
)
```

## Arguments

- n:

  Integerish scalar (\>= 1). Number of interviews per season.

- cv_historical:

  Numeric scalar (\> 0). Coefficient of variation of CPUE from
  historical or pilot data.

- delta_pct:

  Numeric scalar (\> 0). Fractional change to detect, expressed as a
  proportion — e.g., 0.20 for a 20 percent change. Note: this is a
  fraction, not a percentage point.

- alpha:

  Numeric scalar in (0, 0.5\]. Type I error rate. Default is 0.05.

- alternative:

  Character. Either `"two.sided"` (default) or `"one.sided"`.

## Value

A numeric scalar in (0, 1): estimated statistical power.

## Details

Implements the two-sample normal approximation for power under equal
group sizes, parameterised in terms of the CV:

\$\$ncp = \|\delta\| \cdot \sqrt{n/2} \\ / \\ CV\_{historical}\$\$

For `alternative = "two.sided"`: \$\$power = \Phi(ncp - z\_{\alpha/2}) +
\Phi(-ncp - z\_{\alpha/2})\$\$

For `alternative = "one.sided"`: \$\$power = \Phi(ncp - z\_{\alpha})\$\$

where `delta` is the fractional effect size (`delta_pct`), `n` is the
number of interviews per season, and `CV_historical` is the pilot CV of
CPUE.

A warning is issued when `delta_pct > 5` because values greater than 5
are almost certainly input in percentage-point form rather than
fractional form (e.g., 20 instead of 0.20).

## References

Cohen, J. 1988. Statistical Power Analysis for the Behavioral Sciences,
2nd ed. Lawrence Erlbaum Associates, Hillsdale, NJ.

## See also

Other "Planning & Sample Size":
[`compare_designs()`](https://chrischizinski.github.io/tidycreel/reference/compare_designs.md),
[`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md),
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
[`cv_from_n()`](https://chrischizinski.github.io/tidycreel/reference/cv_from_n.md),
[`power_creel()`](https://chrischizinski.github.io/tidycreel/reference/power_creel.md)

## Examples

``` r
# Two-sided power at n = 100, CV = 0.5, 20 percent change
creel_power(n = 100, cv_historical = 0.5, delta_pct = 0.20)
#> [1] 0.8074304

# One-sided test (higher power for same inputs)
creel_power(n = 100, cv_historical = 0.5, delta_pct = 0.20, alternative = "one.sided")
#> [1] 0.881709
```
