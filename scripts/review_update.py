#!/usr/bin/env python3
"""Update a row in .ai/REVIEW-MANIFEST.md after a function review."""
import re
import sys

def main():
    if len(sys.argv) != 7:
        print("Usage: review_update.py <file> <status> <notes> <sha> <commit_date> <review_date>")
        sys.exit(1)

    rfile, status, notes, sha, commit_date, review_date = sys.argv[1:]
    manifest = ".ai/REVIEW-MANIFEST.md"

    with open(manifest) as fh:
        text = fh.read()

    # Match the row for this file (any current values in SHA/date/reviewed/reviewer/status cols)
    escaped = re.escape(rfile)
    pattern = (
        r"(\| " + escaped + r" \| )"
        r"[a-f0-9]+ \| [0-9-]+ \| "   # last commit sha + date
        r"[^\|]* \| [^\|]* \| [a-z-]+"  # last reviewed + reviewer + status
        r"( \|[^\n]*)"
    )
    replacement = (
        r"\g<1>"
        f"{sha} | {commit_date} | {review_date} | claude-opus-4 | {status}"
        r"\g<2>"
    )

    new_text, count = re.subn(pattern, replacement, text)
    if count == 0:
        print(f"WARNING: row for {rfile} not matched — edit .ai/REVIEW-MANIFEST.md manually")
        print(f"  Expected row starting with: | {rfile} |")
        sys.exit(0)

    # Also update Notes column if notes provided
    if notes and notes != '""' and notes != "''":
        # Find the updated row and tack notes onto the last column
        # Notes col is the last | ... | segment; replace it
        notes_pattern = (
            r"(\| " + escaped + r" \| "
            + re.escape(sha) + r" \| " + re.escape(commit_date) + r" \| "
            + re.escape(review_date) + r" \| claude-opus-4 \| " + re.escape(status)
            + r" \| )[^\n]*(\|)"
        )
        notes_repl = r"\g<1>" + f" {notes} " + r"\g<2>"
        new_text, _ = re.subn(notes_pattern, notes_repl, new_text)

    with open(manifest, "w") as fh:
        fh.write(new_text)

    print(f"Updated {rfile} -> {status}")

if __name__ == "__main__":
    main()
