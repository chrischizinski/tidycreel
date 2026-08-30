---
name: code-review
description: How to review a pull request in tidycreel, an R package that computes recreational fishery estimates. Covers the output contract, the statistical-correctness rules the package turns on, and the vocabulary that is routinely confused.
---

# Reviewing tidycreel

tidycreel estimates recreational fishery statistics from creel survey data: angler
effort, catch, harvest, release, CPUE, and their standard errors.

## Output contract

Report **defects only**.

- **Do not summarize what the diff does.** The author knows. A review that restates the
  change has produced no information.
- **Do not praise.** No "excellent", no "well done", no closing thanks. A good diff earns
  a short review, not a warm one.
- **Every finding needs a concrete failure scenario**: specific inputs or state, and the
  wrong output, wrong number, or error they produce. If you cannot construct one, do not
  report the finding.
- Give file and line.
- Rank most severe first.
- If you found nothing, say so plainly and stop. Do not pad, and do not invent minor
  observations to fill space. "No findings" is a useful review.
- Style and formatting nits are out of scope. `lintr` and `styler` already run in CI, and
  the lint baseline is enforced at exactly its current count.

## What matters most here

Passing `R CMD check`, `testthat`, linting, or snapshot tests is **not** evidence of
statistical correctness. A function can be locally correct while the workflow it sits in
is statistically wrong. Every defect of this class that has shipped in this package
produced **no error, no warning, and a believable number**. That is the failure mode to
hunt for.

Reason through the pipeline:

> estimand → sampling design → observed data → transformation → weighting → expansion →
> variance → derived estimate → reported quantity

At each stage, ask whether the **statistical meaning** of the quantity changed. Never
assume that because information exists in an upstream object it reaches the downstream
calculation. Trace the actual use in the code — not the function names, not the
documentation, not the comments, not the intended behaviour.

## Critical distinctions — never silently equated

- `0` and `NA`; `NA` and absence
- known and estimated quantities
- party-hours and angler-hours; boats and anglers
- sampled days and population days; sampled-day totals and period totals
- independent and shared uncertainty; conditional and unconditional uncertainty
- strata and domains
- point estimates and expansion factors
- a standard error equal to zero, and uncertainty that was never propagated

## Known hot spots

- **Carrier columns** `expansion_basis`, `expansion_se` and `expansion_group` are
  droppable by an ordinary `select()`. Check they survive the pipeline.
- **Units are derived, never declared.** `NA` means unknown and is deliberate. Flag any
  change that defaults a unit rather than deriving it.
- **SE components are `NULL` when absent, `NA` when unknown, and never `0`** — a zero is
  indistinguishable from never having propagated.
- The three `R/creel-estimates-total-*.R` files are near-twins. A seam bug in one is
  almost always in all three; if a diff touches one, check whether the others need the
  same fix.
- Ice designs are degenerate bus routes, and dispatch seams there have failed before.
- **Guards need a fixture per path.** A validation call added for one argument but not
  its sibling leaves the sibling unprotected, and the suite will not notice — this has
  happened, with two guards each tested on one side only.
- **Expansion ratios must count the same kind of thing on both sides.** Dividing row
  counts by sampling-unit counts silently rescales a total by the rows-per-unit factor.
- **Documented preconditions must match the signature.** An argument described as having
  no default while the formal is `NULL` contradicts the generated `\usage{}` block.

## Vocabulary — two axes that are routinely confused

- **Count** methods are `instantaneous`, `bus_route`, `ice`, `camera`, `aerial` — the
  values `creel_schema(survey_type=)` accepts.
- **Interview** modes are `access` (complete trips, intercepted on exit) and `roving`
  (incomplete trips, intercepted while fishing) — `add_interviews(interview_type=)`.
  They take different catch-rate estimators: ratio-of-means and mean-of-ratios
  respectively.

Access and roving are **not** count methods, and a survey mixing the two interview modes
is a *hybrid interview* design. Flag any diff describing access or roving as a count
method, a survey method, or an observation mode.

## Secondary checklist

Consult where the diff touches these. Do not write a section per heading, and do not
report an item merely because the diff is silent about it.

- **Behaviour:** messages via `cli`, errors via `rlang::abort()` with a condition class;
  return types and attributes stable; no side effects on options, RNG, locale, working
  directory or connections.
- **API:** signatures and defaults consistent including `...`; S3 dispatch intact;
  deprecations via `lifecycle`.
- **Edge cases:** length-0 and length-1 input, recycling, `NA`/`NaN`/`Inf`/`NULL`, factor
  versus character, `Date`/`POSIXct` and time zones, tidy-eval safety.
- **Tests:** error-class assertions rather than message matching; a fixture per guarded
  path; snapshot coverage for CLI output.
- **Docs:** `roxygen2` complete; `NAMESPACE` regenerated; `NEWS.md` updated for
  user-visible changes; every new `.Rd` topic listed in `_pkgdown.yml`, or pkgdown fails
  with no local gate to catch it.
