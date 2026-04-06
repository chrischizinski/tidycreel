# tidycreel 1.1.0 (2026-04-02)

## New features

* `generate_count_times()` adds three sampling strategies for allocating
  interview periods within a survey day: random, systematic, and
  fixed-interval. Supports a `seed` argument for reproducibility; returns a
  `creel_schedule` object compatible with `write_schedule()`.

* The `survey-scheduling` vignette now covers the full pre- and post-season
  planning workflow: `generate_count_times()` through `validate_design()`,
  `check_completeness()`, and `season_summary()`.

## Documentation

* GitHub issue templates now use structured forms with
  `blank_issues_enabled: false`, routing how-to questions to GitHub Discussions
  to keep answers searchable for all users.

* `CONTRIBUTING.md` has been rewritten with current workflow guidance,
  contribution types, and community norms for the v1.x release line.

# tidycreel 1.0.0 (2026-03-31)

* Launched the pkgdown documentation site at
  https://chrischizinski.github.io/tidycreel with a custom Bootstrap 5 theme,
  full function reference index (46 exports + 15 datasets), and a
  workflow-driven navbar.

* Added a GitHub Actions CI/CD workflow to deploy the pkgdown site
  automatically on every push to main.
