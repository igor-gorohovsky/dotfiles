#!/usr/bin/env python3
import json
import os
import pathlib
import sys

NOTES_FILE = pathlib.Path(os.environ.get("AGENT_REVIEW_NOTES_FILE", "/tmp/agent-review-notes.md"))
COMMENTS_FILE = pathlib.Path(os.environ.get("AGENT_REVIEW_COMMENTS_FILE", "/tmp/agent-review-comments.md"))


def read_and_clear(path):
    if path.exists() and path.stat().st_size > 0:
        text = path.read_text().strip()
        path.unlink(missing_ok=True)
        return text
    return ""


def main():
    notes = read_and_clear(NOTES_FILE)
    comments = read_and_clear(COMMENTS_FILE)

    sections = []
    if notes:
        sections.append(f"Deferred review notes:\n{notes}")
    if comments:
        sections.append(f"Inline review comments:\n{comments}")

    if sections:
        json.dump(
            {
                "decision": "block",
                "reason": "\n\n".join(sections),
            },
            sys.stdout,
        )
        return

    json.dump({}, sys.stdout)


if __name__ == "__main__":
    main()
