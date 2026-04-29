#!/usr/bin/env python3
import json
import pathlib
import sys

COMMENTS_FILE = pathlib.Path("/tmp/claude-review-comments.md")


def main():
    sys.stdin.read()
    if COMMENTS_FILE.exists() and COMMENTS_FILE.stat().st_size > 0:
        comments = COMMENTS_FILE.read_text().strip()
        COMMENTS_FILE.unlink(missing_ok=True)
        body = f"Inline review comments:\n{comments}"
        json.dump(
            {
                "systemMessage": body,
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": body,
                },
            },
            sys.stdout,
        )
        return
    json.dump({}, sys.stdout)


if __name__ == "__main__":
    main()
