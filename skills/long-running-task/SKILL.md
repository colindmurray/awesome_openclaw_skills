---
name: long-running-task
description: Use when launching any background process expected to take more than ~5 minutes — coding agents, system commands, disk repairs, test suites, deployments. Pair with check-on-task for status checks. Tasks notify their origin channel on start/complete/fail/die.
metadata: {"openclaw":{"emoji":"⏳","requires":{"anyBins":["jq"]}}}
---

# Long-Running Task System

Unified background process management. Every background task — agent or not — gets manifests, PID tracking, output capture, stall detection, and discoverability.

## Channel Attribution (Read SESSION_CONTEXT.md First)

If `SESSION_CONTEXT.md` is in your bootstrap context (it is, on every OpenClaw agent run), it lists `Target ID`, `Channel`, and `Session ID` for the chat that's talking to you right now. **Pass these into every `execute_long_running_task` invocation** via `--target`, `--channel`, `--session-id`. The script writes them into the task manifest, and each lifecycle event (started, completed, failed, died) auto-routes a notification back to that same chat. The `post_task_summary` helper uses the same recorded fields to deliver heartbeat-time interpretive summaries to the right channel.

If a task lacks `--target`, the heartbeat falls back to a system event — visible to the AI on the next heartbeat tick, but not visible to the user in their original chat thread.

## Quick Start Templates

### Background coding agent (most common)

Substitute `<PROMPT>`, `<WORKDIR>`, `<SESSION_ID>`, `<TARGET_ID>`:

```bash
~/.openclaw/skills/long-running-task/bin/execute_long_running_task \
  --mode heartbeat \
  --type coding-agent \
  --agent claude \
  --command "<PROMPT>" \
  --workdir "<WORKDIR>" \
  --summary "<PROMPT>" \
  --session-id "<SESSION_ID>" \
  --channel <YOUR_CHANNEL> \
  --target "<TARGET_ID>"
```

### Background system command

```bash
~/.openclaw/skills/long-running-task/bin/execute_long_running_task \
  --mode heartbeat \
  --command "<COMMAND>" \
  --summary "<DESCRIPTION>" \
  --session-id "<SESSION_ID>" \
  --channel <YOUR_CHANNEL> \
  --target "<TARGET_ID>"
```

### Silent command with timeout (no output expected)

```bash
~/.openclaw/skills/long-running-task/bin/execute_long_running_task \
  --mode heartbeat \
  --command "<COMMAND>" \
  --timeout 7200 \
  --summary "<DESCRIPTION>" \
  --session-id "<SESSION_ID>" \
  --channel <YOUR_CHANNEL> \
  --target "<TARGET_ID>"
```

**IMPORTANT:** ALWAYS include `--target` with the target ID from your `SESSION_CONTEXT.md`. This ensures notifications reach the user immediately.

---

## Notification System

The script handles **deterministic** notifications automatically — the AI does NOT need to post these:

| Event | Auto-notified by | When |
|-------|-----------------|------|
| Task started | `execute_long_running_task` | ~1 second after launch |
| Task completed | `finalize_task()` | Immediately on exit |
| Task failed (clean exit) | `finalize_task()` | Immediately on exit |
| Task died (OOM/SIGKILL) | `monitor_pid()` | Within ~2 minutes |
| Task died (missed) | `monitor_task` cron | Within ~5 minutes |
| Output stale | `monitor_task` cron | Within ~5 minutes |
| Memory pressure | `monitor_task` cron | Within ~5 minutes |

**AI must handle:**
- **Retry decisions** — NEVER retry silently. ALWAYS notify the user before retrying a failed task.
- **Milestone updates** — Significant progress points during long tasks
- **Result interpretation** — What the task output means, what to do next

### Retry Protocol

When a task fails and you decide to retry:
1. **ALWAYS** tell the user BEFORE retrying: what failed, why you're retrying, what the new task is
2. Include both the old and new task IDs
3. Never assume the user wants a retry — ask if unclear

---

## Flags Reference

### Required

| Flag | Description |
|------|-------------|
| `--command` | The command string to execute (for coding agents: the prompt text) |

### Notification (ALWAYS include these)

| Flag | Description |
|------|-------------|
| `--target` | Chat channel/group target ID from `SESSION_CONTEXT.md` — enables auto-notifications |
| `--channel` | Notification channel (e.g., `discord`, `slack`) |
| `--session-id` | UUID linking this task to a session |

### Execution Mode

| Flag | Description |
|------|-------------|
| `--mode heartbeat` | Launch in background, print task info, exit immediately |
| (no --mode) | Launch and wait for completion (blocking) |

### Task Type

| Flag | Description |
|------|-------------|
| `--type command` | Default. Generic command — stdout/stderr captured to log file |
| `--type coding-agent` | Coding agent — NDJSON stream captured, auto-headless flags added |

### Agent Options (only when `--type coding-agent`)

| Flag | Description |
|------|-------------|
| `--agent claude` | Use Claude Code CLI. Default: `--dangerously-skip-permissions --output-format stream-json` (full access) |
| `--agent gemini` | Use Gemini CLI. Default: `-y` (yolo/full access) |
| `--agent codex` | Use Codex CLI. Default: `--json -s danger-full-access --dangerously-bypass-approvals-and-sandbox` (full access) |

**Never assemble raw headless flags yourself.** The script handles them.

### Process Control

| Flag | Description |
|------|-------------|
| `--timeout SECS` | Kill process after N seconds. For silent commands, NOT coding agents |
| `--workdir PATH` | Working directory for the process (default: current dir) |
| `--worktree PATH` | Git worktree path (for agent git progress tracking) |
| `--prompt-file PATH` | File containing the prompt (piped to agent stdin) |
| `--force` | Bypass the pre-launch memory gate (use with caution) |

### Metadata

| Flag | Description |
|------|-------------|
| `--summary` | Human-readable description of what this task does |

---

## When to Use `--timeout`

Use timeout when:
- The command produces little or no stdout (e.g., `grep -r` over huge filesystem, disk repair)
- Always over-estimate significantly (2x-3x expected duration)

Do NOT use timeout for:
- Coding agents — they get stall detection via `check_task` instead
- Commands that actively stream output — output freshness is a better signal

## When NOT to Use Background Mode

- Quick coding agent tasks expected to finish in <5 minutes
- Run the agent directly: `claude -p --dangerously-skip-permissions "<PROMPT>"`
- The coding-agent skill covers both patterns (direct and background)
- **Note:** Direct mode does not apply billing settings from `coding-agents.json`. For subscription billing in direct mode, use `env -u ANTHROPIC_API_KEY claude ...` manually.

---

## Manifest System

Every background task gets a manifest at `~/.openclaw/tasks/active/{taskId}.json` with:
- PID, monitorPid, command, summary, timestamps
- Output file location
- NDJSON stream file (coding agents only)
- Session, channel, notifyTarget, agent metadata

### Manifest Fields

| Field | Description |
|-------|-------------|
| `pid` | The main task process ID |
| `monitorPid` | The PID watchdog process ID (detects OOM/SIGKILL within ~2 min) |
| `notifyTarget` | Channel/group ID for notifications |
| `monitorDetected` | `true` if death was detected by monitor (fast-path) |

On completion: manifest moves to `completed/` with `completedAt` + `exitCode`
On failure: manifest moves to `failed/` with `failedAt` + `exitCode` + `note`

## Checking on Tasks

Use the **check-on-task** skill or run directly:

```bash
~/.openclaw/skills/long-running-task/bin/check_task --task-id <TASK_ID>
~/.openclaw/skills/long-running-task/bin/check_task --session-id <SESSION_ID>
~/.openclaw/skills/long-running-task/bin/check_task --all
```

## Posting Per-Task Summaries (HEARTBEAT)

`post_task_summary` is the deterministic way to deliver an AI-composed summary back to the chat that originally launched a task. It reads `notifyTarget` and `channel` from the manifest — no JSON parsing, no remembering channel IDs.

```bash
# By argument
post_task_summary --task-id <TASK_ID> --message "**Task completed:** ..."

# By file (preferred for long messages)
post_task_summary --task-id <TASK_ID> --message-file /tmp/summary.md

# By stdin
echo "**Task failed:** OOM at 2GB" | post_task_summary --task-id <TASK_ID>

# Verify routing without sending
post_task_summary --task-id <TASK_ID> --message "test" --dry-run
```

Returns 0 on successful delivery, 2 if the manifest is missing, 3 if no target is recorded (falls back to a system event automatically). Failures never crash the heartbeat.

## Defense in Depth: Task Monitoring

Three layers detect task death:

1. **`monitor_pid()`** — per-task watchdog, checks every 120s, <2 min detection
2. **`monitor_task`** — cron every 5 min, scans all active tasks, checks memory
3. **`cleanup_tasks`** — heartbeat every 30 min, safety net, prunes old files

## Memory Safety

### Pre-launch memory gate

Coding agents use significant RAM (~1-2GB each). The launcher **automatically refuses** to start a coding agent if system available memory is below 1.5GB (default). This prevents cascading OOM kills that take down all running agents.

- **Threshold:** `OPENCLAW_MIN_MEMORY_MB` env var (default: `1536` = 1.5GB)
- **Bypass:** `--force` flag (use with caution)
- The gate checks `/proc/meminfo` MemAvailable and reports active coding agent count

### Periodic memory logging

The `monitor_task` cron (every 5 min) logs memory snapshots to each active coding agent's output file:
```
[memory] 2026-03-04T15:00:00Z | system: 2048MB free of 7680MB | task RSS: 890MB | pid: 12345
```
These breadcrumbs enable post-mortem analysis of memory growth leading to OOM kills.

### OOM detection

Death detection uses multiple signals (not just `dmesg`, which often requires root):
1. Memory pressure at detection time (>90% usage = likely OOM)
2. `journalctl --user` for OOM messages
3. `dmesg` as fallback (if readable)
4. Exit code 137 = SIGKILL = almost always OOM killer

### Best practice

Before launching concurrent agents:
- Check memory with `check_task --all --json` (includes per-task RSS and system memory)
- On low-memory systems, run agents sequentially

---

## Data Directory

```
~/.openclaw/tasks/
  active/        <- manifests for running processes
  completed/     <- moved here on success
  failed/        <- moved here on failure/crash
  output/        <- stdout/stderr capture for ALL tasks
  streams/       <- NDJSON streams for coding agents only
```
