#!/usr/bin/env bash
# Independent pre-push code review: send a diff to several non-Claude models in
# parallel and collate what they say.
#
# WHY THIS EXISTS
#
# Copilot reviews every push (.github/workflows/copilot-review-check.yml requests
# one automatically -- do NOT request a second one by hand, each costs a premium
# request and the monthly allowance is exhaustible). Its findings are good, but
# they arrive one round per push: a real finding means another commit, another
# push, another review, and on #269 that ran to four rounds before the quota ran
# out mid-PR.
#
# Running this BEFORE the first push collapses those rounds. On #269's first-push
# diff, where the three findings Copilot eventually produced were known in
# advance, this ensemble found all three -- and no single model found more than
# two, which is why it runs several rather than picking a champion.
#
# It also catches a class Copilot missed entirely. Reviewing the fix commits, the
# ensemble found that a new test fixture confounded trip_status with the grouping
# variable, so the test passed for the wrong reason.
#
# WHAT IT DOES NOT DO
#
# It is not a gate and its output is not trustworthy on its own. On the last run
# five of eight claims were false positives -- a factor coercion in columns that
# are character, a seed that is used, a variable that is assigned. Every finding
# must be checked against the code before it is acted on, and a claim that
# survives that check is worth more than the reviewer that produced it.
#
# USAGE
#
#   scripts/ensemble-review.sh                    # diff against main
#   scripts/ensemble-review.sh HEAD~1..HEAD       # a specific range
#   scripts/ensemble-review.sh main...HEAD "extra context for the reviewers"
#
#   GATES="suite 6043/0/9, lint 100, R CMD check 0/0/1" scripts/ensemble-review.sh
#
# Set GATES to whatever the local gates actually report before running. It is
# pasted into the prompt, and it is the single highest-value thing you can give
# these models -- see FALSE POSITIVES below.
#
# FALSE POSITIVES: what they actually look like
#
# Measured on #276: 7 findings, 5 false, and every false one was the same shape --
# an assertion that something is MISSING, made about code the model could not see.
# "callers were not updated" (they were, in the same diff), "the assignment is
# never made" (it is, forty lines outside the hunk), "the test file still uses the
# old signature" (it does not). Three separate models, one class.
#
# The two true findings were the same defect in two different functions, found by
# two different models, neither of which saw both sites. That is the near-twin
# pattern this package keeps producing, and it is the argument for running several
# models rather than the best one: acting on either finding alone would have left
# half the bug in place.
#
# Two counter-measures, both cheap:
#   - the diff is generated with 25 lines of context, not 3
#   - every function whose definition changed gets a CALL SITES inventory
#     appended, listing every reference in R/ and tests/ from the post-change
#     tree, so "the caller was not updated" is checkable rather than guessable
#
# And the prompt now states that the local gates passed. Every false finding on
# #276 predicted a runtime error or a failing test, which a green suite refutes
# outright.
#
# Findings are written to one file per model under .ai/reviews/ (gitignored) and
# printed to stdout.
#
# REQUIREMENTS
#
# An OpenRouter key, plus jq and python3. The key is read from
# $OPENROUTER_API_KEY, falling back to opencode's auth store at
# ~/.local/share/opencode/auth.json. It is never printed, never passed on a
# command line, and never written to a file.

set -euo pipefail

RANGE="${1:-main...HEAD}"
EXTRA_CONTEXT="${2:-}"
OUT_DIR=".ai/reviews"

# The lineup, and why each is here. Measured on #269's labelled diff:
#
#   gpt-oss-120b       the ORDER finding -- the only model that saw it, and the
#                      only statistical defect in the set. $0.0014.
#   nemotron-3-super   the NA-subsetting finding. Free.
#   nemotron-3-ultra   both documentation findings, zero false positives. Free.
#   deepseek-v4-pro    the widest net: 3 of 4, top-ranked the subtlest, and found
#                      the confounded fixture nothing else did. $0.03-0.08, and
#                      the slowest at ~9 minutes, which is why it was the model
#                      that kept vanishing: curl's --max-time was 560s and
#                      `set -e` killed the reporting path before it could say so.
#                      Limit is now 900s and a failure is always announced.
#                      Returned NOTHING on #286, then
#                      on #276 found a real defect that only one other model saw
#                      (and in a different function). High variance; still earns
#                      its slot. Do not drop it for being slow or 90x the cost of
#                      gpt-oss: on that same #276 diff gpt-oss cost $0.0005 and
#                      produced three findings, all false -- worse than nothing,
#                      because each one costs a verification to refute.
#
# The cost of this script is NOT the API spend, which is under five cents a run.
# It is the time spent refuting false findings. Optimise for that.
#
# Rejected after measurement, do not add back without new evidence. These are
# single-diff observations on THIS package's code, not general model rankings --
# the workload is R, statistical, and semantic rather than syntactic, and a model
# that does poorly here may do well elsewhere:
#   qwen3-coder (480B)   0 of 4, with 4 false positives, on #269's diff.
#   kimi-k2.7-code       no output on two attempts, spending the budget on
#                        reasoning and not emitting a findings section.
#   deepseek-v3.2        "no findings" on a diff that had four.
MODELS=(
  "openai/gpt-oss-120b"
  "nvidia/nemotron-3-super-120b-a12b:free"
  "nvidia/nemotron-3-ultra-550b-a55b:free"
  "deepseek/deepseek-v4-pro-0813"
)

key() {
  if [ -n "${OPENROUTER_API_KEY:-}" ]; then
    printf '%s' "$OPENROUTER_API_KEY"
    return
  fi
  local auth="$HOME/.local/share/opencode/auth.json"
  if [ -r "$auth" ]; then
    jq -r '.openrouter.key // empty' "$auth"
    return
  fi
  echo "" >&2
}

KEY="$(key)"
if [ -z "$KEY" ]; then
  echo "No OpenRouter key: set OPENROUTER_API_KEY or authenticate opencode." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

# Clear this run's model files first. A model that fails leaves the PREVIOUS
# run's file in place, and a stale file is indistinguishable from a fresh one --
# on #271 that made a discarded review look like current findings. Only the
# lineup's own files are removed; other documents in the directory are left.
for m in "${MODELS[@]}"; do
  rm -f "$OUT_DIR/$(printf '%s' "$m" | tr '/:' '__').md"
done
DIFF_FILE="$(mktemp)"
BODY_BASE="$(mktemp)"
trap 'rm -f "$DIFF_FILE" "$BODY_BASE" "${FACTS_FILE:-}"' EXIT

# 25 lines of context, not the default 3. Most false findings on #276 were
# assertions that something was missing, made about lines just outside the hunk.
git diff -U25 "$RANGE" > "$DIFF_FILE"
if [ ! -s "$DIFF_FILE" ]; then
  echo "No changes in range '$RANGE'." >&2
  exit 1
fi

# Every function whose definition changed, with every reference to it in the
# post-change tree. A model cannot grep, so without this it guesses about
# callers -- and on #276 three models guessed wrong in the same direction,
# including one that named a function which does not call the changed helper at
# all. Appended to the prompt as checkable fact.
FACTS_FILE="$(mktemp)"
CHANGED_FNS="$(
  grep -oE '^[+-][a-zA-Z_.][a-zA-Z0-9_.]*[[:space:]]*<-[[:space:]]*function' "$DIFF_FILE" \
    | sed -E 's/^[+-]//; s/[[:space:]]*<-[[:space:]]*function//' \
    | sort -u || true
)"
if [ -n "$CHANGED_FNS" ]; then
  {
    echo "--- CALL SITES (post-change tree, authoritative) ---"
    echo "Every reference to each function whose definition the diff touches."
    echo "A claim that a caller was not updated is FALSE unless it contradicts"
    echo "this listing. These lines are the current state of the files, not the diff."
    echo
    while IFS= read -r fn; do
      [ -z "$fn" ] && continue
      echo "## $fn"
      git grep -n -F "$fn" -- R tests 2>/dev/null | grep -v "^[^:]*:[0-9]*:#" | head -40 || true
      echo
    done <<< "$CHANGED_FNS"
  } > "$FACTS_FILE"
fi

echo "Reviewing $RANGE ($(wc -c < "$DIFF_FILE" | tr -d ' ') bytes, -U25) with ${#MODELS[@]} models."
if [ -s "$FACTS_FILE" ]; then
  echo "  call-site inventory: $(echo "$CHANGED_FNS" | grep -c . || true) changed function(s)"
fi
if [ -n "${GATES:-}" ]; then
  echo "  gates reported to models: $GATES"
else
  echo "  WARNING: GATES unset. Set it (see header) -- it is the cheapest way to" >&2
  echo "  suppress the 'this will error at runtime' false-positive class." >&2
fi

python3 - "$DIFF_FILE" "$BODY_BASE" "$EXTRA_CONTEXT" "${FACTS_FILE:-}" "${GATES:-}" <<'PY'
import json, os, sys
diff_file, out_file, extra = sys.argv[1], sys.argv[2], sys.argv[3]
facts_file, gates = sys.argv[4], sys.argv[5]

# The prompt asks for defects and consequences and explicitly refuses summary and
# praise: without that, every model spends most of its output restating the diff.
# The four listed attention areas are the classes that actually escaped review on
# this package -- documentation that describes the wrong quantity, messages that
# name the wrong thing, argument handling, statement ORDER, and tests that pass
# without discriminating.
instructions = """You are reviewing a pull request diff for tidycreel, an R package that estimates
fisheries creel survey quantities (effort, catch, harvest, release) from angler
interviews and instantaneous counts.

Report only defects you can justify from the material below. For each finding give:
- the file
- a one-line statement of the defect
- the concrete consequence: what a user sees, or gets wrong
- THE CHECK: the exact grep, command, or line number a reviewer would run to
  confirm it. If you cannot name one, do not report the finding.

Rank most severe first. Do not summarise the change. Do not praise it. Do not
raise stylistic preferences. If you find nothing, say "no findings".

BEFORE REPORTING THAT SOMETHING IS MISSING, READ THIS.

The most common false finding on this package is an assertion that something is
absent -- a caller that was not updated, an assignment that is never made, a test
still using an old signature -- asserted about code outside the visible hunk. On
the last review three separate models made this mistake, and one of them named a
function that does not call the changed code at all.

The diff below carries 25 lines of context, and a CALL SITES section lists every
reference to every function whose definition changed, taken from the files as
they are after the change. If your finding is "X was not updated", check that
section first. If X appears there in updated form, your finding is wrong and you
must not report it. Absence of something from the diff is not evidence of its
absence from the code.

Pay particular attention to:
- user-facing documentation and error messages that name the wrong quantity,
  function, or design type
- argument handling: values accepted and then ignored, or not reaching every
  code path
- the ORDER in which operations happen relative to one another, especially
  filtering relative to validation and warnings
- whether tests actually discriminate the behaviour they claim to test, or
  would pass even with the change reverted
- statistical meaning: a quantity that silently changes meaning between stages
  (party-hours vs angler-hours, sampled days vs population days, 0 vs NA)
"""
if gates.strip():
    instructions += f"""
LOCAL GATES ON THIS EXACT DIFF: {gates.strip()}

They passed. A finding that predicts a runtime error, an aborted call, or a
failing test is therefore wrong unless you can name a specific code path that no
test reaches, and say which. Every false finding on the previous review predicted
exactly this and a green suite refuted all of them.
"""

if extra.strip():
    instructions += "\nAdditional context from the author:\n" + extra.strip() + "\n"

body = instructions
if facts_file and os.path.exists(facts_file) and os.path.getsize(facts_file):
    body += "\n" + open(facts_file).read()
body += "\n--- DIFF (25 lines of context) ---\n" + open(diff_file).read()

json.dump({"messages": [{"role": "user", "content": body}]}, open(out_file, "w"))
PY

run_one() {
  local model="$1"
  local slug
  slug="$(printf '%s' "$model" | tr '/:' '__')"
  local body resp
  body="$(mktemp)"
  resp="$(mktemp)"

  # effort=low matters: without it the reasoning models spend the whole token
  # budget thinking and return an empty message with finish_reason "length".
  python3 -c "
import json, sys
b = json.load(open('$BODY_BASE'))
b['model'] = '$model'
b['max_tokens'] = 60000
b['reasoning'] = {'effort': 'low'}
json.dump(b, open('$body', 'w'))"

  # `|| rc=$?` is load-bearing. With `set -e` active, a non-zero curl -- most
  # often exit 28, the --max-time timeout -- killed run_one BEFORE the reporting
  # parser below could run, so the model vanished from the output entirely: no
  # row, no error line, no file. That is indistinguishable from "the script only
  # runs three models", and it silently happened to deepseek on both #286 and
  # #285, because deepseek is the only model slow enough to reach the limit.
  #
  # A model that fails must SAY so. "Found nothing" and "never ran" are different
  # facts and the triage depends on which one it was.
  local rc=0
  curl -s --max-time 900 https://openrouter.ai/api/v1/chat/completions \
    -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" \
    -d @"$body" > "$resp" 2>&1 || rc=$?

  if [ "$rc" -ne 0 ]; then
    if [ "$rc" -eq 28 ]; then
      echo "  $model: TIMED OUT after 900s (curl 28) -- DID NOT RUN, not 'no findings'."
    else
      echo "  $model: curl failed with exit $rc -- DID NOT RUN, not 'no findings'."
    fi
    rm -f "$body" "$resp"
    return 0
  fi

  python3 - "$resp" "$OUT_DIR/$slug.md" "$model" <<'PY'
import datetime, json, os, sys
resp, out, model = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    d = json.load(open(resp))
except Exception:
    print(f"  {model}: no response (timeout or unparseable)")
    raise SystemExit
if not d.get("choices"):
    print(f"  {model}: ERROR {str(d.get('error'))[:100]}")
    raise SystemExit
choice = d["choices"][0]
text = choice["message"].get("content") or ""
usage = d.get("usage", {})
if not text.strip():
    print(f"  {model}: empty answer (finish={choice.get('finish_reason')}) -- "
          f"spent {usage.get('completion_tokens')} tokens without emitting")
    raise SystemExit
# A reasoning model that hits the cap returns its chain-of-thought as content:
# non-empty, confident, and containing no findings at all. Writing that as a
# review is worse than writing nothing, because the file then looks fresh.
if choice.get("finish_reason") == "length":
    print(f"  {model}: TRUNCATED at the token cap (finish=length, "
          f"{usage.get('completion_tokens')} tokens) -- no findings section "
          f"reached, discarding. Raise max_tokens if this repeats.")
    raise SystemExit
open(out, "w").write(f"# {model}\n\n{text}\n")
print(f"  {model}: ${usage.get('cost', 0):.4f}, {len(text)} chars -> {out}")

# Scoreboard. The lineup rationale in this script's header is a snapshot from
# one PR and nothing has accumulated since -- which is why "deepseek returned
# nothing last time" and "deepseek found the only real defect this time" both
# live in recollection rather than in a file. verified/false are left blank and
# filled in by hand after triage; a row with them blank is an untriaged run.
board = os.environ.get("SCOREBOARD", ".ai/reviews/scoreboard.tsv")
new_board = not os.path.exists(board)
with open(board, "a") as fh:
    if new_board:
        fh.write("date\trange\tmodel\tcost\tchars\tverified_true\tfalse\tnotes\n")
    fh.write("\t".join([
        datetime.date.today().isoformat(),
        os.environ.get("REVIEW_RANGE", "?"),
        model,
        f"{usage.get('cost', 0):.4f}",
        str(len(text)),
        "", "", "",
    ]) + "\n")
PY

  rm -f "$body" "$resp"
}

export REVIEW_RANGE="$RANGE"
for m in "${MODELS[@]}"; do
  run_one "$m" &
done
wait

echo
echo "=============================================================="
echo "Findings. Verify EVERY claim against the code before acting on"
echo "it -- the false-positive rate is high and the confident tone is"
echo "identical either way."
echo "=============================================================="
for m in "${MODELS[@]}"; do
  f="$OUT_DIR/$(printf '%s' "$m" | tr '/:' '__').md"
  [ -e "$f" ] || continue
  echo
  cat "$f"
done

echo
echo "--------------------------------------------------------------"
echo "After triage, fill in verified_true / false in"
echo "  ${SCOREBOARD:-.ai/reviews/scoreboard.tsv}"
echo "A row left blank is an untriaged run, and the lineup above is"
echo "only re-derivable from those numbers."
echo "--------------------------------------------------------------"
