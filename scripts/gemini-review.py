#!/usr/bin/env python3
import os
import sys
import json
import urllib.request

def main():
    print("Starting Gemini Code Review script...")
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("Error: GEMINI_API_KEY environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    # Read the diff
    diff_path = "pr.diff"
    if not os.path.exists(diff_path):
        print(f"Error: {diff_path} file not found.", file=sys.stderr)
        sys.exit(1)

    with open(diff_path, "r", encoding="utf-8", errors="ignore") as f:
        diff_content = f.read()

    if not diff_content.strip():
        # Nothing to review. Leave review.md absent so the workflow skips posting
        # rather than commenting on a PR with no code changes. Exiting 0 keeps
        # this distinct from a failure, which exits non-zero and reddens the job.
        print("No changes found in the diff; nothing to review.")
        return

    # Guard against excessively large diffs to avoid API limits
    MAX_DIFF_CHARS = 200000
    truncation_notice = ""
    if len(diff_content) > MAX_DIFF_CHARS:
        full_len = len(diff_content)
        pct = round(100.0 * MAX_DIFF_CHARS / full_len)
        print(f"Warning: Diff is extremely large ({full_len} chars). Truncating to {MAX_DIFF_CHARS} chars.")
        diff_content = diff_content[:MAX_DIFF_CHARS] + "\n\n... [Diff truncated due to size limit] ..."
        # A review of part of a diff reads exactly like a review of all of it, so
        # "No findings" would otherwise be unfalsifiable. Say so in the review body.
        truncation_notice = (
            f"> **Only the first {pct}% of this diff was reviewed.** "
            f"The diff is {full_len:,} characters and was truncated at "
            f"{MAX_DIFF_CHARS:,}. Findings below cover the reviewed portion only.\n\n"
        )

    # Read review prompt instructions
    prompt_path = ".github/review_prompt.md"
    if os.path.exists(prompt_path):
        with open(prompt_path, "r", encoding="utf-8", errors="ignore") as f:
            instructions = f.read()
        print("Successfully loaded domain review guidelines from review_prompt.md")
    else:
        instructions = "Review the following git diff for bugs, edge cases, compatibility, and code quality."
        print("Using default guidelines (review_prompt.md not found)")

    # Construct the prompt text
    prompt_text = (
        f"{instructions}\n\n"
        f"Here is the git diff of the changes to review:\n"
        f"```diff\n{diff_content}\n```\n"
    )

    # Model availability depends on the API key's tier, which CI cannot see: asking
    # for gemini-2.5-pro on a key without it returns 404 and no review. Try the
    # stronger model first and fall back only on 404, so a genuine failure (auth,
    # quota, 5xx) still reddens the job instead of being retried into silence.
    # GEMINI_MODEL pins one model and disables the fallback.
    pinned = os.environ.get("GEMINI_MODEL", "").strip()
    models = [pinned] if pinned else ["gemini-2.5-pro", "gemini-2.5-flash"]

    payload = {
        "contents": [{
            "parts": [{
                "text": prompt_text
            }]
        }],
        "generationConfig": {
            "temperature": 0
        },
        "systemInstruction": {
            "parts": [{
                "text": (
                    "You are reviewing a diff for an R package that computes survey "
                    "estimates. Report defects only.\n\n"
                    "Do not summarize what the diff does -- the author knows. Do not "
                    "praise, thank, or compliment; a good diff earns a short review, not "
                    "a warm one.\n\n"
                    "For each finding give the file and line, one sentence stating the "
                    "defect, and a concrete failure scenario: specific inputs or state, "
                    "and the wrong output they produce. If you cannot construct a failure "
                    "scenario, do not report the finding. Rank most severe first.\n\n"
                    "If you found nothing, write exactly \"No findings.\" and stop. Do "
                    "not pad and do not invent minor observations to fill space.\n\n"
                    "The highest-value defects in this package produce no error, no "
                    "warning, and a believable number. Follow the guidelines supplied "
                    "with the diff."
                )
            }]
        }
    }

    body = json.dumps(payload).encode("utf-8")
    res_data = None

    for i, model in enumerate(models):
        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{model}:generateContent?key={api_key}"
        )
        req = urllib.request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        try:
            print(f"Calling Gemini API ({model})...")
            with urllib.request.urlopen(req) as response:
                res_data = json.loads(response.read().decode("utf-8"))
            print(f"Review generated by {model}.")
            break
        except urllib.error.HTTPError as e:
            if e.code == 404 and i + 1 < len(models):
                print(
                    f"Model {model} unavailable on this key (404); "
                    f"falling back to {models[i + 1]}.",
                    file=sys.stderr
                )
                continue
            print(f"Error calling Gemini API ({model}): {e}", file=sys.stderr)
            sys.exit(1)
        except Exception as e:
            print(f"Error calling Gemini API ({model}): {e}", file=sys.stderr)
            sys.exit(1)

    if res_data is None:
        print("Error: no model produced a response.", file=sys.stderr)
        sys.exit(1)

    try:
        review_text = res_data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError) as err:
        print(f"Error parsing Gemini response structure: {err}", file=sys.stderr)
        print(f"Full response: {res_data}", file=sys.stderr)
        sys.exit(1)

    if not review_text.strip():
        print("Error: Gemini returned an empty review.", file=sys.stderr)
        sys.exit(1)

    # Write review to file
    with open("review.md", "w", encoding="utf-8") as f:
        f.write("### 🌌 Antigravity Code Review\n\n")
        f.write(truncation_notice)
        f.write(review_text)

    print("Successfully generated code review and saved it to review.md")

if __name__ == "__main__":
    main()
