# PR statistical-review checklist

For any PR touching estimators, survey designs, data processing, or uncertainty
(in `tidycreel` or `tidycreel.connect`). Short by design — answer each with
yes/no/n-a; any unexamined "yes" blocks merge.

- [ ] Does this change alter an **estimand**?
- [ ] Does it alter **units**?
- [ ] Does it introduce or remove an **expansion factor**?
- [ ] Does it introduce an **estimated parameter**?
- [ ] Does that parameter have **uncertainty** (and is absence `NULL`/`NA`,
      never `0`)?
- [ ] Does that uncertainty **propagate downstream** (shared vs independent
      treated correctly)?
- [ ] Does it affect **strata/grouping**?
- [ ] Does it affect **inclusion probabilities or survey weights**?
- [ ] Does it affect **degrees of freedom or CIs**?
- [ ] Does it affect **downstream total estimators** (remember the three
      near-twin `creel-estimates-total-*.R` files — fix in triplicate)?
- [ ] Is there an **integration test** for the full chain?
- [ ] Is there an **invariant/metamorphic test**
      (`tests/testthat/test-statistical-audit-*.R`)?
- [ ] Is there an **independent reference calculation** (base R, no tidycreel
      helpers)?
