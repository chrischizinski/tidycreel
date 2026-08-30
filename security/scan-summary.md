# Security Scan Summary — tidycreel

## Scans to run
```bash
just security
```
Runs: `gitleaks detect --source . --redact`

## Findings
| Date | Scanner | Findings | Action |
|------|---------|----------|--------|
| 2026-05-25 | manual inspection | No cloud credentials found | None required |
| 2026-05-25 | gitleaks v8 | 0 leaks — 1009 commits, 63.4 MB scanned | None required |

## Open items
- [x] Run `just security` (gitleaks) and record findings here
- [x] .Rbuildignore covers security/ directory

## Retired: the 2026-05 GSD credential review

This file previously carried a "GSD migration context" section, written when GSD
Cloud shut down on 2026-05-22. Both of its subjects are gone, verified 2026-08-30:

- `~/.gsd/` no longer exists, so the OAuth tokens it held (Google, GitHub Copilot,
  Google Antigravity, OpenAI Codex — none addressed to GSD Cloud) are gone with it.
  The original finding stands: no GSD Cloud-specific credential was ever found in
  this repo.
- The OpenRouter API key that section flagged for precautionary rotation is no
  longer present in `~/.zshrc`. Whether the key was rotated or merely removed
  locally is not visible from here; if it may still be live, rotate at
  openrouter.ai/keys.

Kept as a record because deleting the reason a key was flagged is how a stale
credential goes unnoticed.
