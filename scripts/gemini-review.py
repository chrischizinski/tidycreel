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
        print("No changes found in the diff.")
        with open("review.md", "w", encoding="utf-8") as f:
            f.write("### 🌌 Antigravity Code Review\n\nNo code changes detected in this pull request.")
        return

    # Guard against excessively large diffs to avoid API limits
    MAX_DIFF_CHARS = 200000
    if len(diff_content) > MAX_DIFF_CHARS:
        print(f"Warning: Diff is extremely large ({len(diff_content)} chars). Truncating to {MAX_DIFF_CHARS} chars.")
        diff_content = diff_content[:MAX_DIFF_CHARS] + "\n\n... [Diff truncated due to size limit] ..."

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

    url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" + api_key
    payload = {
        "contents": [{
            "parts": [{
                "text": prompt_text
            }]
        }],
        "systemInstruction": {
            "parts": [{
                "text": (
                    "You are Antigravity, a professional R package reviewer. "
                    "Analyze the diff using the provided guidelines. "
                    "Be constructive, concise, and focused. Start directly with the findings. "
                    "If the diff looks excellent and has no issues, thank the developer and praise their clean code."
                )
            }]
        }
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        print("Calling Gemini API (gemini-2.5-flash)...")
        with urllib.request.urlopen(req) as response:
            res_data = json.loads(response.read().decode("utf-8"))

            # Extract review text from the response structure
            try:
                review_text = res_data["candidates"][0]["content"]["parts"][0]["text"]
            except (KeyError, IndexError) as err:
                print(f"Error parsing Gemini response structure: {err}", file=sys.stderr)
                print(f"Full response: {res_data}", file=sys.stderr)
                sys.exit(1)

    except Exception as e:
        print(f"Error calling Gemini API: {e}", file=sys.stderr)
        sys.exit(1)

    # Write review to file
    with open("review.md", "w", encoding="utf-8") as f:
        f.write("### 🌌 Antigravity Code Review\n\n")
        f.write(review_text)

    print("Successfully generated code review and saved it to review.md")

if __name__ == "__main__":
    main()
