#!/usr/bin/env python3
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

AGENT_NAME = os.environ.get("AGENT_REVIEW_AGENT_NAME", "Claude")
AGENT_REVIEW_OPEN = pathlib.Path(
    os.environ.get(
        "AGENT_REVIEW_OPEN",
        str(pathlib.Path.home() / "projects" / "agent-review.nvim" / "bin" / "agent-review-open"),
    )
)
PAUSE_FILE = pathlib.Path(
    os.environ.get(
        "AGENT_REVIEW_PAUSE_FILE",
        str(pathlib.Path.home() / ".cache" / "agent-review-paused"),
    )
)
LEGACY_PAUSE_FILE = pathlib.Path.home() / ".cache" / "claude-review-paused"
NOTES_FILE = pathlib.Path(os.environ.get("AGENT_REVIEW_NOTES_FILE", "/tmp/agent-review-notes.md"))
COMMENTS_FILE = pathlib.Path(os.environ.get("AGENT_REVIEW_COMMENTS_FILE", "/tmp/agent-review-comments.md"))
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


def socket_path(session):
    configured = os.environ.get("AGENT_REVIEW_NVIM_SOCKET")
    if configured:
        return configured

    safe_session = re.sub(r"[^A-Za-z0-9_.-]", "_", session)
    generic = f"/tmp/nvim-agent-review-{safe_session}.sock"
    if os.path.exists(generic):
        return generic

    # Temporary fallback while old nvim configs are migrated.
    legacy = f"/tmp/nvim-claude-{session}.sock"
    if os.path.exists(legacy):
        return legacy

    return generic


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

    if PAUSE_FILE.exists() or LEGACY_PAUSE_FILE.exists():
        emit("allow")
    if tool not in TARGET_TOOLS:
        emit("allow")

    file_path, new_content = compute_pending(tool, inp)
    if file_path is None:
        emit("allow")

    session = os.environ.get("ZELLIJ_SESSION_NAME")
    if not session:
        emit("allow")

    sock = socket_path(session)
    if not os.path.exists(sock) or not AGENT_REVIEW_OPEN.exists():
        emit("allow")

    review_id = uuid.uuid4().hex[:8]
    suffix = pathlib.Path(file_path).suffix
    pending = pathlib.Path(f"/tmp/agent-review-pending-{review_id}{suffix}")
    pending.write_text(new_content)

    fifo_dir = pathlib.Path(tempfile.mkdtemp(prefix="agent-review-fifo-"))
    fifo = fifo_dir / "fifo"
    os.mkfifo(fifo)

    try:
        result = subprocess.run(
            [
                str(AGENT_REVIEW_OPEN),
                "--socket",
                sock,
                "--file",
                file_path,
                "--pending",
                str(pending),
                "--fifo",
                str(fifo),
                "--notes-file",
                str(NOTES_FILE),
                "--comments-file",
                str(COMMENTS_FILE),
                "--agent-name",
                AGENT_NAME,
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode != 0:
            emit("allow")
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
