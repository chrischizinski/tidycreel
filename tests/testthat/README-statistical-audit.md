# Statistical-audit test framework

Adversarial statistical tests live in files named `test-statistical-audit-*.R`
(kept flat in `tests/testthat/` because `testthat::test_dir()` does not recurse
into subdirectories). Shared helpers: `helper-statistical-audit.R`.

## Purpose

Ordinary unit tests verify that functions run and return the shapes they claim.
This family verifies that **statistical meaning survives function boundaries** —
the bug class behind the v3.0.0 dimensional-seam audit (33 findings) and the
v3.2.0 uncertainty-propagation fixes (#117, #121), none of which any unit test
caught. The dangerous failure is a plausible number with no error and no warning.

## Test patterns (use these, in priority order)

1. **Exact hand calculations** — tiny synthetic datasets where the correct
   answer is computable manually. Reference results must be derived in minimal
   base R, never via tidycreel internal helpers (shared helper = shared bug).
2. **Invariants** — properties that must always hold: row-order invariance,
   irrelevant-column invariance, scale invariance (counts × k ⇒ linear
   quantities × k), CI ordering, nonnegativity (see also `test-invariants.R`
   for the quickcheck-based INV-01…INV-06 family).
3. **Metamorphic properties** — known mathematical relationship between a
   perturbed and an unperturbed run: double the population days ⇒ period total
   doubles, sampled-day estimate unchanged; increase an upstream SE with points
   fixed ⇒ downstream SE must not shrink; split/merge identical strata.
   Determine the expected relationship BEFORE running the test.
4. **Propagation** — a parameter treated as known (SE absent) versus estimated
   (SE > 0) must yield different downstream uncertainty; `0` and `NA` inputs
   must not be silently equivalent.
5. **Integration workflows** — full chains from near-raw data to a
   management-relevant estimate; component tests do not establish composition.

## Conventions

- Every test carries a comment stating **why the property matters
  statistically** (which failure it makes visible), not just what it checks.
- Do not duplicate ordinary unit tests, `test-invariants.R`, or
  `test-unit-propagation.R` — extend them or add here, not both.
- No exact-value snapshots of realistic data; prefer values that make a bug
  obvious (extreme but valid).
- Keep datasets tiny. If the expected answer needs the package to compute it,
  the test is circular.
- Findings discovered while writing tests are recorded (GH issue / audit doc),
  not fixed inline — see the Statistical Correctness section of `CLAUDE.md`.

## Relationship to the audit skill

`/statistical-seam-audit` (`.claude/skills/statistical-seam-audit/SKILL.md`)
produces findings reports; each confirmed finding should gain a regression test
here as part of its fix PR. Checklists for new estimators and PR review:
`inst/audit/`.
