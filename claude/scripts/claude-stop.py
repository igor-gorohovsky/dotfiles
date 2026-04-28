#!/usr/bin/env python3
import json
import pathlib
import sys

NOTES_FILE = pathlib.Path("/tmp/claude-review-notes.md")


def main():
    if NOTES_FILE.exists() and NOTES_FILE.stat().st_size > 0:
        notes = NOTES_FILE.read_text().strip()
        NOTES_FILE.unlink(missing_ok=True)
        json.dump(
            {
                "decision": "block",
                "reason": f"Deferred review notes:\n{notes}",
            },
            sys.stdout,
        )
        return

    json.dump({}, sys.stdout)


if __name__ == "__main__":
    main()
