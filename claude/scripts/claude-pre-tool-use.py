#!/usr/bin/env python3
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import uuid

PAUSE_FILE = pathlib.Path.home() / ".cache" / "claude-review-paused"
NOTES_FILE = pathlib.Path("/tmp/claude-review-notes.md")
COMMENTS_FILE = pathlib.Path("/tmp/claude-review-comments.md")
TARGET_TOOLS = {"Edit", "Write", "MultiEdit"}


def emit(decision, reason=None, additional_context=None, system_message=None):
    out = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
        }
    }
    if reason:
        out["hookSpecificOutput"]["permissionDecisionReason"] = reason
    if additional_context:
        out["hookSpecificOutput"]["additionalContext"] = additional_context
    if system_message:
        out["systemMessage"] = system_message
    json.dump(out, sys.stdout)
    sys.exit(0)


def compute_pending(tool, inp):
    file_path = inp.get("file_path")
    if not file_path:
        return None, None
    p = pathlib.Path(file_path)
    if tool == "Write":
        return file_path, inp.get("content", "")
    if tool == "Edit":
        text = p.read_text() if p.exists() else ""
        return file_path, text.replace(inp["old_string"], inp["new_string"], 1)
    if tool == "MultiEdit":
        text = p.read_text() if p.exists() else ""
        for edit in inp.get("edits", []):
            text = text.replace(edit["old_string"], edit["new_string"], 1)
        return file_path, text
    return None, None


def main():
    data = json.load(sys.stdin)
    tool = data.get("tool_name", "")
    inp = data.get("tool_input", {})

    if PAUSE_FILE.exists():
        emit("allow")
    if tool not in TARGET_TOOLS:
        emit("allow")

    file_path, new_content = compute_pending(tool, inp)
    if file_path is None:
        emit("allow")

    session = os.environ.get("ZELLIJ_SESSION_NAME")
    if not session:
        emit("allow")

    sock = f"/tmp/nvim-claude-{session}.sock"
    if not os.path.exists(sock):
        emit("allow")

    review_id = uuid.uuid4().hex[:8]
    suffix = pathlib.Path(file_path).suffix
    pending = pathlib.Path(f"/tmp/claude-pending-{review_id}{suffix}")
    pending.write_text(new_content)

    fifo_dir = pathlib.Path(tempfile.mkdtemp(prefix="claude-fifo-"))
    fifo = fifo_dir / "fifo"
    os.mkfifo(fifo)

    try:
        lua = (
            "require('claude_review').start({"
            f"file=[[{file_path}]],"
            f"pending=[[{pending}]],"
            f"fifo=[[{fifo}]],"
            f"notes_file=[[{NOTES_FILE}]],"
            f"comments_file=[[{COMMENTS_FILE}]]"
            "})"
        )
        subprocess.run(
            ["nvim", "--server", sock, "--remote-send", f"<C-\\><C-n>:lua {lua}<CR>"],
            check=False,
        )
        subprocess.run(
            ["zellij", "action", "move-focus", "left"],
            check=False,
            stderr=subprocess.DEVNULL,
        )

        with open(fifo, "r") as f:
            decision = (f.readline() or "").strip()

        subprocess.Popen(
            ["zellij", "action", "move-focus", "right"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    finally:
        pending.unlink(missing_ok=True)
        shutil.rmtree(fifo_dir, ignore_errors=True)

    if decision == "allow":
        emit("allow")
    if decision.startswith("deny:"):
        reason = decision[5:] or "declined"
        if COMMENTS_FILE.exists() and COMMENTS_FILE.stat().st_size > 0:
            comments = COMMENTS_FILE.read_text().strip()
            COMMENTS_FILE.unlink(missing_ok=True)
            body = f"Inline review comments:\n{comments}"
            emit("deny", reason, additional_context=body, system_message=body)
        emit("deny", reason)
    emit("allow")


if __name__ == "__main__":
    main()
