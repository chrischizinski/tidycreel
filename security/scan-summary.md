# Security Scan Summary — tidycreel

## GSD migration context
GSD Cloud shut down 2026-05-22. No GSD Cloud-specific credentials found in this repo
or in ~/.gsd/agent/auth.json. Credentials in ~/.gsd are standard OAuth tokens for
Google, GitHub Copilot, Google Antigravity, and OpenAI Codex — none addressed to
GSD Cloud infrastructure.

## OpenRouter API key
Stored in ~/.zshrc. Used by GSD for model routing. Rotation recommended as a
precautionary measure (route was openrouter → providers; unclear if GSD Cloud
acted as relay). Rotate at openrouter.ai/keys.

## Scans to run
```bash
just security
```
Runs: `gitleaks detect --source . --redact`

## Findings
| Date | Scanner | Findings | Action |
|------|---------|----------|--------|
| 2026-05-25 | manual inspection | No cloud credentials found | None required |
| — | gitleaks | Not yet run | Run `just security` |

## Open items
- [ ] Run `just security` (gitleaks) and record findings here
- [ ] Rotate OpenRouter API key in ~/.zshrc
- [ ] Verify .Rbuildignore covers security/ directory if needed
