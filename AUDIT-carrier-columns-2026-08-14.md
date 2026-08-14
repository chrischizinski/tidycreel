# Statistical Seam Audit — party-size carrier columns (#124 neighborhood)

**Date:** 2026-08-14 · **Audit 2 of 5** · Mode: dimensional/lineage, focused on the
`mean_party_size()` → `derive_angler_count()` → `add_counts()` →
`compute_expansion_var_contribution()` chain.

## Scope

#124 (carriers droppable by `select()`) is already filed and well-characterized;
it is **not** re-reported. This audit searched the same chain for adjacent
failure modes. Three were found and numerically confirmed; all three produce a
non-obvious wrong or missing `se_expansion` with no error and no warning, while
leaving every point estimate untouched.

## Findings

### Finding 1: User-side scaling of the count column silently desynchronizes `expansion_basis`, understating `se_expansion` by exactly the scale factor

**Severity:** High (confirmed by execution)

**Workflow:** `derive_angler_count()` → user `mutate(count × k)` →
`add_counts(count_col = ...)` → `estimate_effort()` → catch/harvest/release totals

**Information at risk:** the party-size variance component. `expansion_basis` is
a derivative, `d(count)/d(party_size)`; the variance term is
`(Σ̂basis × se_p)²`. The invariant "basis stays in the units of the count column"
is maintained by `add_counts()` only for the multiplications *it* performs
(`R/creel-design.R:1703–1706` scales basis by `T_d` alongside the count). A
transformation the user applies before `add_counts()` — the pattern the
companion book uses in all pipeline chapters
(`mutate(angler_hours = total_anglers * shift_hours[period])`) — scales the
count but not the basis, and nothing checks or documents the invariant
(`derive_angler_count()` docs describe the columns but never state that a
transformed count requires an identically transformed basis).

**Minimal reproduction (run 2026-08-14):** identical 6-day design, party
size 2.5, SE 0.1, count scaled ×12 two ways:

| | estimate | `se_expansion` | total se |
|---|---|---|---|
| A: user premultiplies count ×12, carriers kept | 1284 | **3** | 183.79 |
| B: same physics via `period_length_col = 12` | 1284 | **36** | 187.25 |

**Expected:** identical results; **actual:** A's component is understated by
exactly ×12 while being present and non-NULL — it *looks* propagated. This is
strictly harder to detect than #124's `NULL` case, which at least signals
absence.

**Root cause:** the basis-count unit invariant lives only inside
`add_counts()`'s own arithmetic; user-space transformations are invisible to it.

**Downstream consequences:** every count-expanded effort SE where the user
prepares an effort-unit count column themselves, and all catch/harvest/release
totals inheriting it. The book's post-#124 fix (retain carriers) is
insufficient on its own — retained-but-unscaled carriers give this failure.

**Why existing tests missed it:** `test-expansion-variance.R` always lets
`add_counts()` do the scaling or uses unscaled counts; no test transforms the
count column after `derive_angler_count()`.

**Recommended regression test:** the A/B table above as an equality test
(will fail until fixed).

**Recommended correction (conceptual):** couple the guard to #124's print-based
surfacing — e.g. record at derive time which column the basis differentiates
(`to`), and have `add_counts()` warn when `count_col != to` while carriers are
present ("basis derived for `angler_count`; count is `angler_hours` — scale
`expansion_basis` identically or supply `period_length_col`"). Decide exact
mechanism at fix time; do not fix during audit.

---

### Finding 2: A partial carrier set is silently treated as no carrier set

**Severity:** Medium (confirmed by execution)

**Workflow:** `derive_angler_count()` → user drops *one* of the three columns →
`add_counts()` → `estimate_effort()`

`add_counts()` gates on
`all(c("expansion_basis","expansion_se","expansion_group") %in% names(counts))`
(`R/creel-design.R:1659–1661`). Dropping only `expansion_group` (repro run:
`counts[, setdiff(names(counts), "expansion_group")]`) leaves `expansion_se`
sitting visibly in the table, yet `se_expansion` is `NULL` and no message is
emitted. A table carrying one or two carrier columns is malformed — it cannot
have been produced by anything but partial deletion — so it is distinguishable
from the "never had carriers" case, unlike full deletion (#124), and could
abort loudly today.

**Recommended correction (conceptual):** in `add_counts()`, abort (or warn)
when a nonempty proper subset of the three carriers is present.

---

### Finding 3: Reordering a grouped `mean_party_size()` lookup silently swaps per-stratum standard errors

**Severity:** Medium-High (confirmed by execution)

**Workflow:** `mean_party_size(by =)` → any row-reordering operation
(`arrange()`, `merge`, manual sort) → `derive_angler_count()`

**Information at risk:** which stratum's party-size SE multiplies which
stratum's boats.

**Mechanism:** the grouped lookup carries its SEs as a positional `"se"`
attribute ("ride along … in the same row order",
`R/derive-angler-count.R:115–117`). dplyr row operations reorder the tibble's
rows but leave the attribute untouched. `resolve_party_size_se()` then matches
counts rows to lookup rows **by key** (`match()` on the non-numeric columns)
and indexes the attribute **by position** (`as.numeric(se)[idx]`,
`R/derive-angler-count.R:455–460`) — key-correct rows, position-stale SEs.

**Minimal reproduction (run 2026-08-14):** two strata, SEs 0.5774 (weekday) /
0.8819 (weekend); after `arrange(mps, desc(day_type))`:

```
correct  se by day_type: weekday 0.5774 | weekend 0.8819
arranged se by day_type: weekday 0.8819 | weekend 0.5774   # swapped, silent
point estimates equal: TRUE                                 # means join by key
```

The length guard (`length(se) != nrow(party_size)`) makes `filter()` abort
loudly — only length-preserving reorderings are silent, which is exactly
`arrange()`/sorting, the most habitual operations.

**Root cause:** dual addressing — values by key, attribute by position — across
an object users are invited to inspect and manipulate.

**Downstream consequences:** per-stratum `se_expansion` attributed to the wrong
strata; grouped effort/catch SEs wrong in both directions (some over-, some
understated); totals may nearly cancel, hiding it further. The `"group"`
attribute consumed as `attr(party, "group")` shares the positional addressing
and should be checked at fix time for the same hazard.

**Why existing tests missed it:** every test passes the lookup straight from
`mean_party_size()` to `derive_angler_count()` untouched.

**Recommended regression test:** the repro above as
`expect_identical(ok$expansion_se, sw$expansion_se)` (fails today).

**Recommended correction (conceptual):** address SEs by key, not position —
e.g. name the `se` attribute by the paste-key, or store SE as a column in the
lookup (it is excluded from single-numeric-column detection concerns only by
the current design decision; revisit there, not here).

## Relation to #124

All four failures (#124 + these three) share one shape: the variance component
travels as passive data whose integrity depends on user-space handling, with
`NULL`-when-absent as the only signal. The #124 proposed guard (print
"Party-size term: carried / not carried") surfaces #124 and Finding 2, but
**not** Finding 1 (component present, wrong scale) or Finding 3 (component
present, wrong assignment). Issue grouping suggestion: extend #124 with
Finding 2; file Finding 1 and Finding 3 separately (different root causes:
unit-invariant enforcement vs attribute addressing).

## Checked, sound

- `add_counts()` scales the basis correctly for its own `T_d` and within-day
  mean aggregation (`mean_vars = "expansion_basis"`).
- `check_expansion_constant_per_psu()` catches mixed derive calls within a PSU.
- `filter()` on the lookup aborts via the length guard.
- Carrier-column name clash at `derive_angler_count()` entry aborts.
- `se_expansion` NULL-vs-zero discipline holds throughout the estimator read
  path (`compute_expansion_var_contribution()` returns NULL, never 0).
