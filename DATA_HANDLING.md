# Data handling

tidycreel is a public R package. It ships no personal data and no agency data.

## What this repository contains

| Data | Location | Contains PII? | Notes |
|---|---|---|---|
| Package datasets | `data/*.rda` | no | Synthetic or aggregate examples built by `data-raw/` scripts |
| Calamus 2016 fixtures | `inst/calamus-2016/*.csv` | no | Interview- and count-level survey records with no angler identifiers; shipped on purpose for validation |
| Absent-zero guard baseline | `scripts/absent-zero-guard-baseline.tsv` | no | Code-location baseline for a CI check |

## What stays outside this repository

- Agency survey data, interview records, permit or licence data, and any
  dataset with angler names, contact details or licence numbers. These live
  in private analysis repositories or on the agency's own systems, never here.
- Agency-specific field-name profiles: local YAML files that are never
  committed (see `creel_schema()` and `api_field_map`).
- External validation data and the scripts that read it.

## Credentials

- Never written in code, tests, vignettes or examples. Read from the OS
  keyring (`keyring::key_get()`) or an environment file outside the repo.
- Use read-only database and API accounts for analysis.
- A credential that appears in a commit, log, issue or chat transcript is
  treated as compromised and rotated.

## Safeguards

- `.gitignore` is deny-by-default for data formats, archives and credential
  files. The files listed above are whitelisted explicitly; anything else
  needs a deliberate `git add -f` after review.
- A local pre-commit hook (gitleaks plus a staged-file PII audit) blocks
  staged secrets and identifier columns.
- Code that will touch identified data is developed and tested against
  synthetic data.

## If something leaks

Treat the repository as public: a leaked file or secret has been exposed even
if it is removed later. Back up, rewrite history in a throwaway clone, verify
with count-only checks, force-push with explicit approval, ask GitHub to purge
cached views, realign local clones, and rotate any exposed credential.
