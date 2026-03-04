---
name: coding-agent
description: Run coding agents (Claude Code, Codex, Gemini, OpenCode, Pi) via background process for programmatic control. These agents excel at investigating codebases, analyzing systems, writing documentation, and executing multi-step workflows.
metadata: {"openclaw":{"emoji":"🧩","requires":{"anyBins":["claude","codex","opencode","pi"]}}}
---

# Coding Agent

Use **bash** (with optional background mode) to launch coding agents. Simple and effective.

## Use Cases

Coding agents are powerful general-purpose assistants that excel at:

- **Investigation**: Exploring large codebases to understand architecture, find bugs, trace data flows
- **Analysis**: Deep-diving into complex systems, identifying patterns, root cause analysis
- **Documentation**: Writing specs, creating detailed action plans, generating comprehensive comments
- **Multi-step workflows**: Tasks requiring iteration, exploration, and decision-making

---

## Launching Coding Agents

### Background mode (tasks >5 min)

Use `execute_long_running_task` with `--type coding-agent`. This handles manifests,
NDJSON streaming, watchdogs, notifications, and monitoring automatically.

**Read:** `~/.openclaw/skills/long-running-task/SKILL.md` for templates.

```bash
~/.openclaw/skills/long-running-task/bin/execute_long_running_task \
  --mode heartbeat \
  --type coding-agent \
  --agent claude \
  --command "<PROMPT>" \
  --workdir "<WORKDIR>" \
  --summary "<DESCRIPTION>" \
  --session-id "<SESSION_ID>" \
  --channel <CHANNEL> \
  --target "<TARGET_ID>"
```

### Direct mode (quick tasks <5 min)

Run the agent directly and wait for the response:

```bash
claude -p --dangerously-skip-permissions "<PROMPT>"
gemini -y -p "<PROMPT>"
codex -s danger-full-access --dangerously-bypass-approvals-and-sandbox exec "<PROMPT>"
```

No manifest needed — you're blocking and will see the result immediately.

### Checking on background agents

```bash
~/.openclaw/skills/long-running-task/bin/check_task --task-id <TASK_ID>
~/.openclaw/skills/long-running-task/bin/check_task --all
```

---

## Progress Updates (Responsibility Split)

### Scripts auto-handle:
- **Task started** — notification sent within ~1 second of launch
- **Task completed** — notification sent immediately on exit with summary, duration, last output
- **Task failed** — notification sent immediately with exit code, error context
- **Task died** (OOM/crash) — notification sent within ~2 minutes by PID monitor

### AI must handle:
- **Retry decisions** — NEVER retry silently. ALWAYS notify the user before retrying.
- **Milestone updates** — Significant progress points during long tasks
- **Result interpretation** — What the task output means, what to do next

---

## Memory Safety

Coding agents use significant RAM (~1-2GB each). The task launcher **automatically blocks** new coding agents when system memory is below 1.5GB, preventing cascading OOM kills.

- Override with `--force` if you're certain there's enough headroom
- Adjust threshold: `export OPENCLAW_MIN_MEMORY_MB=2048`
- Check current usage: `check_task --all --json` (shows per-task RSS + system memory)
- On low-memory systems, run agents sequentially

---

## Supported Agents

### Claude Code

| Mode | Command |
|------|---------|
| One-shot | `claude -p "prompt"` |
| Auto-edit | `claude -p --permission-mode acceptEdits "prompt"` |
| Full auto (headless) | `claude -p --dangerously-skip-permissions "prompt"` |

### Codex CLI

| Flag | Effect |
|------|--------|
| `exec "prompt"` | One-shot execution, exits when done |
| `--full-auto` | Sandboxed but auto-approves in workspace |
| `-s danger-full-access --dangerously-bypass-approvals-and-sandbox` | NO sandbox, NO approvals |

**Note:** Codex requires a git repository. Use `mktemp -d && git init` for scratch work.

### Gemini CLI

| Gemini | Description |
|--------|-------------|
| `gemini -p "prompt"` | Non-interactive one-shot |
| `gemini --approval-mode auto_edit -p "prompt"` | Auto-approve edits, headless |
| `gemini -y -p "prompt"` | Full auto (yolo mode, headless) |

### Pi Coding Agent

```bash
pi 'Your task'                                    # Interactive
pi -p 'Summarize src/'                            # Non-interactive
pi --provider openai --model gpt-4o-mini -p '...' # Custom provider
```

### OpenCode

```bash
opencode run 'Your task'
```

---

## Configuration

Configure agent preferences and billing in `~/.openclaw/coding-agents.json`. The installer creates this interactively, or create it manually from the inline example below.

### Config Format

```json
{
  "agents": {
    "claude": { "enabled": true, "billing": "subscription" },
    "codex": { "enabled": true, "billing": "api_key" },
    "gemini": { "enabled": false, "billing": "api_key" }
  },
  "preference_order": ["claude", "codex"],
  "default_agent": "claude"
}
```

### Fields

| Field | Description |
|-------|-------------|
| `agents.<name>.enabled` | Whether this agent is available for use |
| `agents.<name>.billing` | `api_key` (default) or `subscription` — controls how the agent authenticates |
| `preference_order` | Ordered list of agents to try (primary, backup, third choice) |
| `default_agent` | Which agent to use when none is specified |

### Billing Modes

- **`api_key`** (default) — Uses the standard API key environment variable (e.g., `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`)
- **`subscription`** — For agents that support OAuth/subscription billing. Currently only affects Claude: unsets `ANTHROPIC_API_KEY` so Claude Code falls back to OAuth subscription billing. Other agents ignore this setting for now.

The billing mode can also be overridden per-invocation with `OPENCLAW_UNSET_ANTHROPIC_KEY=true|false`.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCLAW_CODING_AGENTS_FILE` | `~/.openclaw/coding-agents.json` | Path to the coding agent config |
| `OPENCLAW_UNSET_ANTHROPIC_KEY` | (unset) | Override Claude billing: `true` forces subscription, `false` forces API key |

---

## PTY Mode

Coding agents are **interactive terminal applications** that need a pseudo-terminal (PTY) to work correctly.

```bash
# Correct - with PTY
bash pty:true command:"codex exec 'Your prompt'"

# Wrong - no PTY, agent may break
bash command:"codex exec 'Your prompt'"
```

### Bash Tool Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `command` | string | The shell command to run |
| `pty` | boolean | Allocates a pseudo-terminal for interactive CLIs |
| `workdir` | string | Working directory for the agent |
| `background` | boolean | Run in background, returns sessionId for monitoring |
| `timeout` | number | Timeout in seconds |

### Process Tool Actions (for background sessions)

| Action | Description |
|--------|-------------|
| `list` | List all running/recent sessions |
| `poll` | Check if session is still running |
| `log` | Get session output |
| `write` | Send raw data to stdin |
| `submit` | Send data + newline |
| `kill` | Terminate the session |

---

## Parallel Issue Fixing with git worktrees

```bash
# 1. Create worktrees for each issue
git worktree add -b fix/issue-78 /tmp/issue-78 main
git worktree add -b fix/issue-99 /tmp/issue-99 main

# 2. Launch agents in each
execute_long_running_task --mode heartbeat --type coding-agent --agent claude \
  --command "Fix issue #78: <description>. Commit and push." \
  --workdir /tmp/issue-78 --summary "Fix issue #78"

execute_long_running_task --mode heartbeat --type coding-agent --agent claude \
  --command "Fix issue #99: <description>. Commit and push." \
  --workdir /tmp/issue-99 --summary "Fix issue #99"

# 3. Monitor
check_task --all

# 4. Cleanup after merge
git worktree remove /tmp/issue-78
git worktree remove /tmp/issue-99
```

---

## PR Review

```bash
# Clone to temp for safe review (never review in your main working directory)
REVIEW_DIR=$(mktemp -d)
git clone <repo-url> $REVIEW_DIR
cd $REVIEW_DIR && gh pr checkout 42
bash pty:true workdir:$REVIEW_DIR command:"codex review --base origin/main"

# Or use git worktree
git worktree add /tmp/pr-42-review pr-42-branch
bash pty:true workdir:/tmp/pr-42-review command:"codex review --base main"
```

---

## tmux Orchestration (Alternative)

For advanced multi-agent control, use tmux instead of bash background mode.

| Use Case | Recommended |
|----------|-------------|
| Quick one-shot tasks | `bash pty:true` |
| Long-running with monitoring | `bash background:true` |
| Multiple parallel agents | **tmux** |
| Session persistence | **tmux** |

```bash
SOCKET="${TMPDIR:-/tmp}/coding-agents.sock"

# Create sessions for parallel work
tmux -S "$SOCKET" new-session -d -s agent-1 -c /tmp/worktree-1
tmux -S "$SOCKET" new-session -d -s agent-2 -c /tmp/worktree-2

# Launch agents
tmux -S "$SOCKET" send-keys -t agent-1 "codex exec 'Fix issue #1'" Enter
tmux -S "$SOCKET" send-keys -t agent-2 "claude 'Fix issue #2'" Enter

# Monitor
tmux -S "$SOCKET" capture-pane -p -t agent-1 -S -100
```

---

## Best Practices

1. **Always use pty:true** — coding agents need a terminal
2. **Use `--workdir`** — keeps agent focused on the target project, prevents reading unrelated files
3. **Never review PRs in your main working directory** — use temp dirs or worktrees
4. **Use `check_task` to monitor background agents** — the manifest system provides richer analysis than raw logs
5. **Let `execute_long_running_task` handle headless flags** — don't assemble `--dangerously-skip-permissions`, `--output-format stream-json`, etc. manually

---

## Worktree Cleanup After PR Merge

When a coding agent merges a PR, clean up the worktree:

```
1. Delete the remote branch: git push origin --delete <branch-name>
2. Remove the local worktree: git worktree remove <worktree-path>
```

The heartbeat cleanup script also removes worktrees for merged PRs after 30 minutes as a safety net.
