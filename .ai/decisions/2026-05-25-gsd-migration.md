# Decision: Migrate off GSD — tidycreel

## Date
2026-05-25

## Context
GSD Cloud (the upstream maintainer of the get-shit-done framework) shut down on
2026-05-22 in a rug pull. The npm packages are now unmaintained. Continuing to rely
on GSD creates supply-chain risk (abandoned packages can be squatted) and workflow
fragility (cloud endpoints are gone).

## Decision
Replace GSD with a repo-owned agent harness:
- `AGENTS.md` — shared instructions for all coding agents
- `CLAUDE.md` — Claude Code supplement
- `justfile` — trusted command surface
- `opencode.json` — OpenCode permissions
- `.ai/` — project memory, tasks, decisions, handoffs
- `.claude/skills/` — optional repeatable workflows

Treat `.gsd/` as historical read-only artifacts. Archive only after Chris approves.

## GSD material transferred
- Active milestone (M022) → `.ai/tasks/current.md`
- Package conventions and invariants → `AGENTS.md`
- Build/test commands → `justfile`
- Creel domain notes and key references → `AGENTS.md`
- MCP server config → `.ai/repo-map.md`

## GSD material intentionally ignored
- `doctor-history.jsonl`, `event-log.jsonl`, `notifications.jsonl` — transient logs
- `gsd.db` — GSD internal database
- `metrics.json` — token/cost tracking (GSD-internal)
- `state-manifest.json` — GSD state engine (not project knowledge)
- `RELEASE-CANDIDATE.md` — GSD-generated artifact
- `worktrees/` — old worktree internals (M014; appears stale)
- Model provider config (openrouter, ollama) — not project knowledge

## Consequences
- More transparent, version-controlled workflow readable by all agents
- No dependency on external framework or cloud infrastructure
- Some GSD convenience features must be rebuilt as just targets or skills if needed
- OpenRouter API key in ~/.zshrc should be rotated (precautionary)
