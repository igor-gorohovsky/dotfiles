---
allowed-tools: Bash(test:*), Bash(rm:*), Bash(touch:*), Bash(mkdir:*)
description: Toggle agent review hooks pause (mirrors <Leader>cp in nvim)
---

!if [ -f "$HOME/.cache/agent-review-paused" ] || [ -f "$HOME/.cache/claude-review-paused" ]; then rm -f "$HOME/.cache/agent-review-paused" "$HOME/.cache/claude-review-paused" && echo "Review hooks: enabled"; else mkdir -p "$HOME/.cache" && touch "$HOME/.cache/agent-review-paused" && echo "Review hooks: paused"; fi

The shell output above shows the new state of the pause sentinel at `~/.cache/agent-review-paused`. While paused, the PreToolUse hook short-circuits to `allow` and Edit/Write/MultiEdit skip the nvim diff review. Reply with one short line acknowledging the new state — no further action needed.
