#!/usr/bin/env bash
# Guard against new "absent silently becomes zero" conversions (GH #317).
#
# WHY THIS EXISTS
#
# Across #310, #312, #318, #320 and #322, thirteen separate review findings
# turned out to be one defect: a quantity that was *unknown* or *absent* was
# allowed to behave like a **zero**. None errored, none warned, and every one
# produced a plausible number.
#
# The cause is not carelessness. R's default path from "absent" to a number is
# zero at nearly every boundary -- a match() miss, an nrow() == 0 guard,
# NA * FALSE, sum(NULL). Every defensive branch lands there unless it is
# deliberately written not to, and zero *feels* like the safe value to return
# while being the most dangerous one in an estimator.
#
# WHY IT IS NOT A LINT
#
# A pure syntactic rule would be wrong, and the hits prove it: most of the
# current ones are CORRECT. `two-phase-rescale.R` reads an interview absent from
# the catch table as having caught none, which is what add_catch() documents.
# `creel-estimates.R` returns a zero covariance when there is no expansion
# component, which is a statistical claim, not an oversight. A rule that cries
# wolf on those trains reviewers to skip it.
#
# So this is a grep with a TRIAGED BASELINE. Every accepted hit carries a
# one-line justification in the baseline file. A NEW hit fails the build until
# it is either fixed or justified -- which puts the absent-vs-unknown decision
# in front of the author at the point of writing, where it is cheap.
#
# USAGE
#
#   scripts/absent-zero-guard.sh            # check against the baseline
#   scripts/absent-zero-guard.sh --list     # print current hits, baseline format
#
# Covers BOTH tracked package source roots: `R/` and `tidycreel.connect/R`.
#
# To accept a new hit, add its row to scripts/absent-zero-guard-baseline.tsv
# with a justification that says why absence means zero HERE. "It is fine" is
# not a justification; name the semantics that make it true.
#
# The baseline is keyed on the file and the code, never on the line number:
# line numbers move on every edit above them, and a baseline that goes stale on
# an unrelated change is a baseline people delete.

set -euo pipefail

cd "$(dirname "$0")/.."

BASELINE="scripts/absent-zero-guard-baseline.tsv"

# The fingerprint. Three shapes, all of them "a missing value became a zero":
#   x[is.na(x)] <- 0        a match miss or a join miss, zeroed
#   x[is.na(x)] <- FALSE    the same, in a group mask
#   rep(0, n)               a zero vector in a return position
#
# `rep(0` alone also matches `rep(0.5, 3)` in roxygen examples, so the digit is
# anchored: `rep(0,`, `rep(0L`, `rep(0)`. The zero itself may be `0` or `0L` --
# leaving `0L` out made nine real conversions invisible to the first version of
# this script. See current_hits() for how comments are handled.
current_hits() {
  # Comments are stripped from every line BEFORE the shape is matched, not
  # filtered out as whole lines. Ensemble review found both halves of that
  # mattering, in opposite directions:
  #
  #   foo <- bar   # rep(0, n) is just an example    <- was a false hit
  #   x[is.na(x)] <- 0  # why absence means zero     <- EVADED the guard,
  #                                                     because the shape was
  #                                                     anchored to end of line
  #
  # The second is the dangerous one: writing the very justification the rule
  # asks for was enough to make the line invisible. `0L` evaded it too.
  #
  # A `#` inside a string literal truncates that line early, which can only
  # cause a MISS, never a false alarm. Accepted: a conversion whose sole
  # trigger sits after a `#` in a string is not a shape worth contorting the
  # heuristic for.
  #
  # `|| true` on the head of the pipeline: grep exits 1 when nothing matches,
  # and under `set -e` that aborted `--list` on a tree with no hits at all.
  # Both tracked package source roots, not just `R/`. The repo also carries
  # `tidycreel.connect/`, and a new conversion there would have passed every run
  # of this guard without a justification or a failure. It contributes zero hits
  # today, so covering it costs nothing and closes the gap before it matters.
  # (Found by Codex, which could see the second package because it reads the
  # repo rather than a diff.)
  #
  # This used to justify itself with "whose live-API path is explicitly still
  # unaudited". That framing was stale: the connect ingestion seam WAS audited,
  # its five filed findings are closed, and the audit's remaining questions
  # named fields the agency-agnostic rewrite deleted. What is actually still
  # open is narrower -- no request has ever been made against a real endpoint --
  # and it is tracked as GH #330. The reason to scan the second package does not
  # depend on any of that.
  local roots=(R)
  [ -d tidycreel.connect/R ] && roots+=(tidycreel.connect/R)
  { grep -rnE '\[is\.na\(|rep\(0[,L)]' "${roots[@]}" 2>/dev/null || true; } |
    sed -E 's/[[:space:]]*#.*$//' |
    grep -E '<-[[:space:]]*0L?[[:space:]]*$|<-[[:space:]]*FALSE|rep\(0[,L)]' |
    # file <TAB> code, with the code's leading indent and trailing space
    # normalised so a re-indent is not a new finding.
    sed -E 's/^([^:]+):[0-9]+:[[:space:]]*/\1\t/' |
    sed -E 's/[[:space:]]+$//' |
    sort || true
}

if [ "${1:-}" = "--list" ]; then
  current_hits
  exit 0
fi

if [ ! -f "$BASELINE" ]; then
  echo "absent-zero guard: baseline $BASELINE not found." >&2
  exit 2
fi

# Baseline rows are file <TAB> code <TAB> justification. Compare on the first
# two fields only; the justification is for humans.
baseline_hits() {
  grep -vE '^[[:space:]]*(#|$)' "$BASELINE" |
    cut -f1,2 |
    sort
}

added=$(comm -23 <(current_hits) <(baseline_hits) || true)
removed=$(comm -13 <(current_hits) <(baseline_hits) || true)

status=0

if [ -n "$added" ]; then
  status=1
  cat >&2 <<'MSG'

absent-zero guard: NEW conversion of a missing value to zero
============================================================

R turns "absent" into zero at almost every boundary, and in an estimator that
is indistinguishable from a real result. Every one of these has to be a
decision, not a default.

New hit(s):
MSG
  echo "$added" | sed 's/^/  /' >&2
  cat >&2 <<'MSG'

Do one of two things:

  1. If absence really does mean zero here, say WHY in a comment next to the
     line -- name the semantics that make it true, the way
     `species_counts_per_interview()` distinguishes "no rows for this pair"
     from "no caught row for this pair" -- and add the row to
     scripts/absent-zero-guard-baseline.tsv with that reason.

  2. If it might mean "unknown", keep it apart from zero. Test the KEY rather
     than the value: an absent key contributed nothing; a present key holding
     NA is unknown and must stay NA. `estimate_effort_grouped()` does this for
     both variance components.

See GH #317 for thirteen worked examples of getting this wrong.
MSG
fi

if [ -n "$removed" ]; then
  # Not a failure. A baseline that still lists code nobody can find is a
  # baseline nobody trusts, so say so and let the author tidy it.
  echo "" >&2
  echo "absent-zero guard: baseline lists hit(s) that no longer exist:" >&2
  echo "$removed" | sed 's/^/  /' >&2
  echo "" >&2
  echo "Drop the stale row(s) from $BASELINE." >&2
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "absent-zero guard: $(current_hits | wc -l | tr -d ' ') hit(s), all triaged."
fi

exit "$status"
