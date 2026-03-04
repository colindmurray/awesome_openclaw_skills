---
name: check-on-task
description: Check status of background tasks and coding agents — discover running processes, detect stalls, analyze progress, and generate clear reports.
metadata: {"openclaw":{"emoji":"🔍","requires":{"anyBins":["jq"]}}}
---

# Check on Task

Check the status of ANY background task launched by `execute_long_running_task`.

## Usage

```bash
# Check a specific task
~/.openclaw/skills/long-running-task/bin/check_task --task-id <TASK_ID>

# Check all tasks for a session
~/.openclaw/skills/long-running-task/bin/check_task --session-id <SESSION_ID>

# Check all active tasks
~/.openclaw/skills/long-running-task/bin/check_task --all

# JSON output (for programmatic use — includes system memory info)
~/.openclaw/skills/long-running-task/bin/check_task --all --json

# Custom stall threshold (default 600s = 10 min)
~/.openclaw/skills/long-running-task/bin/check_task --task-id <ID> --stall-threshold 300
```

## Status Meanings

| Status | Meaning |
|--------|---------|
| **running** | PID alive, output flowing normally |
| **stalled** | PID alive but no output for >stall-threshold seconds |
| **completed** | Process exited with code 0 |
| **failed** | Process exited with non-zero code |
| **dead** | PID not found (auto-moved to failed) |

## Health Indicators

| Health | Meaning |
|--------|---------|
| **ok** | Everything normal |
| **stalled** | Output file not written to recently |
| **hang-detected** | (Coding agents) Result event received but PID still alive — safe to kill |
| **error** | Process failed or PID dead |

## Monitor Watchdog

Each background task launched with `--mode heartbeat` gets a **monitor watchdog** (`monitorPid`):
- Runs as a sibling process that survives if the task dies (OOM, SIGKILL)
- Checks PID liveness every 120 seconds
- If the task dies unexpectedly, the monitor:
  - Moves the manifest to `failed/` with `monitorDetected: true`
  - Sends a Discord notification immediately
  - Fires a system event to wake the AI for retry decisions

### Interpreting Monitor Fields

| Field | Meaning |
|-------|---------|
| `monitorPid` | PID of the watchdog process |
| `monitorPid (alive)` | Monitor is actively watching the task |
| `monitorPid (dead)` | Monitor died — task has no fast-path death detection |
| `monitorDetected: true` | Task death was caught by monitor (fast-path, <2 min) |
| No `monitorDetected` | Task death was caught by cleanup_tasks (slow-path, up to 30 min) |

If `monitorDetected: true`, the user has already been notified via Discord — focus on interpretation and retry decisions, not re-notification.

## For Coding Agents

When the task type is `coding-agent`, you get deeper analysis:

- **Tool counts**: how many Read/Edit/Bash tools the agent has used
- **Error count**: error events in the NDJSON stream
- **Phase estimation**: exploring (read-heavy), implementing (edit-heavy), testing (bash-heavy)
- **Git progress**: commits since task start, unstaged changes
- **Hang detection**: Claude stream-json bug where process stays alive after `result` event
- **System memory**: current memory usage (useful for OOM risk assessment)

For advanced agent analysis techniques, see `AGENT_ANALYSIS.md`.

## Caution on Killing

Only kill a process if you are **certain** it is stuck:
- Output has been completely silent for a long time (not just slow)
- Error loops detected (same error repeating)
- Hang detected (result event + PID alive)

Processes that are slow but making progress should be **left alone**. Coding agents often have long thinking pauses between tool calls — this is normal.
