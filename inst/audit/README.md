# Statistical audit infrastructure

tidycreel's highest-risk defect class is a plausible number produced with no
error and no warning, caused by information silently dropped, transformed
incorrectly, or not propagated at a function boundary ("seam"). Two shipped
examples: the v3.0.0 dimensional-seam audit (33 findings; `AUDIT-dimensional-seams.md`
at the repo root, not shipped in the package) and the v3.2.0
uncertainty-propagation fixes (#117, #121).

The audit system has four parts:

| Part | Location |
|---|---|
| Standing principles for any statistical change | `CLAUDE.md` → "Statistical Correctness and Workflow Auditing" |
| Audit protocol (Claude Code skill, 4 modes) | `.claude/skills/statistical-seam-audit/SKILL.md` |
| Adversarial test framework | `tests/testthat/test-statistical-audit-*.R` + `README-statistical-audit.md` |
| Checklists (this directory) | `new-estimator-checklist.md`, `pr-statistical-review-checklist.md` |

Scope always includes `tidycreel.connect` (in-repo subpackage): the audited
workflow starts at the database/CSV/API source, not at `creel_design()`.

Invocation (Claude Code):

```text
/statistical-seam-audit               # full protocol
/statistical-seam-audit dimensional   # units, estimands, lineage, grouping
/statistical-seam-audit uncertainty   # SE/variance/covariance propagation
/statistical-seam-audit design        # frames, weights, expansion, HT
```

Audits produce a findings report first; fixes happen in a separate task.
