# New-estimator audit checklist

Work through every section before a new estimator (or a new dispatch path of an
existing one) is merged. "Not applicable" is an acceptable answer; "unstated" is
not. Companion: `pr-statistical-review-checklist.md` for reviewing changes to
existing estimators.

## Estimand

- [ ] What population quantity is estimated? (State it in one sentence.)
- [ ] What is the observational unit?
- [ ] What is the sampling unit?
- [ ] What is the reporting unit?
- [ ] Is it a sampled-day quantity, a stratum total, or a period total — and is
      that stated in the docs and the result metadata?

## Design

- [ ] What are the strata?
- [ ] What are the PSUs?
- [ ] Are inclusion probabilities required? Where do they enter?
- [ ] Are finite-population or temporal expansion factors required? Where do
      they enter, and where do the population counts (e.g. population days)
      come from?
- [ ] Which survey types dispatch here? (Remember: ice is a degenerate
      bus-route; missing dispatch has shipped bugs before.)

## Dimensions

- [ ] Units of every input?
- [ ] Units after every transformation, written algebraically
      (e.g. `boats × anglers/boat = anglers`)?
- [ ] Output units — and is `unit` **derived from the arithmetic performed**,
      never just labelled? (`NA` = unknown is the correct default.)
- [ ] Party-level vs angler-level quantities kept distinct throughout?

## Uncertainty

- [ ] Which inputs are estimated rather than known?
- [ ] Which carry SE/variance, and in what form (`NULL` = absent, `NA` =
      unknown — never a silent `0`)?
- [ ] Are any uncertainty components **shared** (one parameter reused across
      many observations)? If so, verified that they do not shrink with n?
- [ ] Are covariance terms needed (e.g. correlated regression parameters —
      see the #117 pivot-length treatment)?
- [ ] What degrees of freedom are appropriate, and is t vs z chosen per
      `?creel_confidence_intervals`?
- [ ] Are CI bounds clamped to the parameter space where bounded (≥ 0, [0,1])?

## Propagation

- [ ] Which downstream estimators consume this result?
- [ ] Does uncertainty propagate to all of them?
- [ ] Does grouping propagate?
- [ ] Does unit metadata propagate?
- [ ] Does estimand metadata propagate?
- [ ] Are any carrier columns/attributes droppable by ordinary dplyr verbs
      (cf. #124)? If so, is that failure detectable?

## Adversarial tests

- [ ] Can the point estimate be hand-calculated on a tiny dataset? Test added?
- [ ] Can the uncertainty be independently calculated (base R, no tidycreel
      helpers)? Test added?
- [ ] What extreme-but-valid values would expose a bug? Tested?
- [ ] What invariant must always hold (row order, irrelevant columns, scaling,
      known-vs-estimated)? Added to `test-statistical-audit-*.R`?
- [ ] Integration test covering the full chain into and out of this estimator?

## Reporting

- [ ] Does `print()` describe the quantity correctly?
- [ ] Does `tidy()` preserve required metadata?
- [ ] Does `autoplot()` use the correct unit?
- [ ] Does `write_estimates()` describe the same quantity?
- [ ] Do the docs state the estimand and cite the source formula?
