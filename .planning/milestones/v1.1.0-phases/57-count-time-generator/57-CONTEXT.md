# Phase 57: Count Time Generator - Context

**Gathered:** 2026-04-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement `generate_count_times()` — a function that generates within-day count time windows using random, systematic, or fixed strategies and returns a `creel_schedule`-compatible data frame. Estimation functions, power calculations, and vignette updates are out of scope for this phase.

</domain>

<decisions>
## Implementation Decisions

### Time input format
- `start_time` and `end_time` accept character `"HH:MM"` only — no seconds, no POSIXct, no hms objects
- `window_size` is an integer in minutes (e.g., `window_size = 60` for one-hour counts)
- `start_time`/`end_time` are validated against the `"HH:MM"` format; `end_time > start_time` is enforced

### Output structure
- Standalone function — returns its own data frame, not an augmentation of an existing `creel_schedule`
- Columns: `start_time` (character "HH:MM"), `end_time` (character "HH:MM"), `window_id` (integer)
- Output wrapped as `creel_schedule` S3 object via `new_creel_schedule()` — directly compatible with `write_schedule()`
- No `strategy` column in output

### Strategy API
- Single `strategy` argument with enum: `"random"`, `"systematic"`, `"fixed"`
- `strategy` is required — no default; omitting it throws a `cli_abort()` error
- Unknown strategy values produce a clear error (validated via `match.arg()` or explicit check)
- `fixed_windows` argument accepts a data frame with `start_time` and `end_time` columns
- When `strategy = "fixed"`, `fixed_windows` is used and `start_time`/`end_time`/`n_windows`/`window_size` are silently ignored
- `seed` argument required for `"random"` and `"systematic"` strategies (consistent with `generate_schedule()`)

### Pollock count-time model (random and systematic)
- Both `n_windows` (integer count of windows per day) and `window_size` (integer minutes) are **required** — no defaults
- The fishing day (`start_time` to `end_time`) is divided into `n_windows` equal strata of `k = total_minutes / n_windows` minutes
- **Random strategy**: one count start time selected randomly within each stratum independently; `window_size` minutes wide
- **Systematic strategy** (preferred per Pollock et al. 1994): random `t₁` selected within the first stratum; subsequent times are `t₁ + k`, `t₁ + 2k`, etc. — guarantees even spacing, avoids clustering
- Total span must be divisible by `n_windows`; function errors if not (e.g., "480 minutes / 3 = 160 — ok; 480 / 7 — error")
- Count windows must not extend past `end_time` — error if `window_size > k`

### Minimum gap enforcement
- `min_gap` argument in integer minutes — required minimum buffer between count end and next count start
- Validation only: function errors if `window_size + min_gap > stratum_length (k)` — does NOT shrink the placement window
- Error message should state: "stratum is X min, window_size + min_gap = Y min — reduce n_windows, window_size, or min_gap"

### Claude's Discretion
- Whether `min_gap = 0` is a valid default or must be explicitly set (suggest required, consistent with strategy/window_size)
- Exact `window_id` numbering (1-based integer sequence, left to right by `start_time`)
- Whether to validate that `fixed_windows` rows are non-overlapping (suggested: yes, via sorted start_time check)
- Internal time arithmetic approach using `lubridate` (already in Imports)
- `withr::with_seed()` scoping for RNG isolation (established pattern from `generate_schedule()`)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `new_creel_schedule()` (`R/schedule-generators.R`): constructor that wraps a data frame as `c("creel_schedule", "data.frame")` — use directly for output
- `select_sampled_days()`: stratified random selection pattern — analogous logic for within-stratum random time selection
- `withr::with_seed()`: RNG isolation without mutating global state — use for random/systematic strategies
- `cli::cli_abort()` with `c("Header:", x = "issue", i = "fix hint")` structure — use for all error messages
- `resolve_single_col()`: tidy selector resolution — not needed here (no column selection), but validates the coding pattern

### Established Patterns
- Mutually exclusive required args: `if (!is.null(a) && !is.null(b)) cli_abort(...)` pattern from `generate_schedule()` — adapt for `fixed_windows` vs `n_windows`/`window_size`
- `match.arg()` or explicit `%in%` check for enum arguments — `survey_type` in `creel_design()` uses explicit check
- `lubridate::ymd()` + `seq.Date()` for date sequences — analogous: `lubridate::hm()` + arithmetic for time sequences
- Integer arithmetic in minutes avoids DST/timezone issues — times are within-day, not absolute datetimes

### Integration Points
- Output passes directly to `write_schedule()` (accepts any `creel_schedule` object)
- `generate_count_times()` belongs in `R/schedule-generators.R` alongside `generate_schedule()` and `generate_bus_schedule()`
- Export and document in same `schedule-generators.R` file; add to reference index grouped under planning suite

</code_context>

<specifics>
## Specific Ideas

- **Pollock et al. (1994) systematic model**: "A random number on the range 1–k is chosen, t₁. The sequence of n start times is t₁, t₁+k, t₁+2k, …" — implement this exactly
- **Colorado CPW (2012) framing**: "Systematic sample is preferred to avoid randomly selecting count times with close intervals" — consider noting this preference in the `?generate_count_times` documentation
- Both `n_windows` and `window_size` are truly independent parameters (stratum count vs. count duration) — they serve different roles and are not substitutes for each other

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 57-count-time-generator*
*Context gathered: 2026-04-01*
