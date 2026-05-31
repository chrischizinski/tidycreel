# Current Tasks — tidycreel

## Active
- [x] M022: Documentation and Reporting Polish — COMPLETE. v1.9.0 shipped 2026-05-25
      (PR #62 merged; Phases 95–97 done; git tag v1.9.0 on origin).

## Migration tasks (GSD → agent harness)
- [x] Create AGENTS.md, CLAUDE.md, justfile, opencode.json
- [x] Create .ai/ structure
- [x] Update .Rbuildignore to cover .ai/, justfile, opencode.json, security/
- [x] Archive .gsd/ → .gsd.archive-20260525
- [x] Run `just security` and review findings — 0 leaks (2026-05-25)
- [ ] Archive v1.9.0 milestone, plan v2.0.0 scope

## Backlog
- [ ] CRAN submission — pending final M022 polish
- [ ] Convert useful GSD prompts into .claude/skills/ if needed

## Parking lot (from GSD state — verify currency)
- M019: completed milestone (no action needed)
- Pre-push hook confirms rcmdcheck passes before push — verify hook still present
