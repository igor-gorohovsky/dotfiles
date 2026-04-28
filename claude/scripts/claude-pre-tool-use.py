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
TARGET_TOOLS = {"Edit", "Write", "MultiEdit"}


def emit(decision, reason=None):
    out = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
        }
    }
    if reason:
        out["hookSpecificOutput"]["permissionDecisionReason"] = reason
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
    pending = pathlib.Path(f"/tmp/claude-pending-{review_id}")
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
            f"notes_file=[[{NOTES_FILE}]]"
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
        emit("deny", reason)
    emit("allow")


if __name__ == "__main__":
    main()
