# HEARTBEAT.md

The heartbeat is a **safety net**, not the primary detection mechanism. Tasks have their own `monitor_pid()` watchdog that detects death within ~2 minutes and sends notifications directly. The 5-minute `monitor_task` cron provides a second layer. This heartbeat (every 30 minutes) catches anything that slipped through both layers.

## 1. Run task monitoring and maintenance

First, run the active task scanner (catches anything the per-task monitors missed):

```bash
~/.openclaw/skills/long-running-task/bin/monitor_task --channel <YOUR_CHANNEL>
```

Then run the full cleanup (dead PIDs, stall warnings, pruning, worktree cleanup):

```bash
~/.openclaw/skills/long-running-task/bin/cleanup_tasks --channel <YOUR_CHANNEL>
```

## 2. Route completed/failed task summaries to their origin channels

The `cleanup_tasks` output contains `=== TASK <STATUS>: <task_id> ===` blocks. Each block now includes `Target:`, `Channel:`, and `Session:` lines naming the chat that originally launched the task.

For EACH block, compose a 3-5 bullet interpretive summary and route it back to that origin channel using the helper script:

```bash
~/.openclaw/skills/long-running-task/bin/post_task_summary --task-id <TASK_ID> --message "<SUMMARY>"
```

The helper reads the manifest, extracts `notifyTarget` + `channel`, and calls `openclaw message send` for you — you do not need to parse JSON or remember which channel each task came from. If a task has no recorded target (rare — usually only manually-launched tasks), the helper falls back to a system event automatically.

Example summary content (the message body you pass via `--message`):

```
**Task completed:** Merge PR #42 and run CI
- **Status:** Succeeded (exit code 0)
- **Duration:** 25 minutes (14:00 → 14:25)
- **Results:** PR merged, all 47 tests passing, deployed to staging
```

For failed tasks:

```
**Task failed:** Deploy to production
- **Status:** Failed (exit code 1)
- **Duration:** 8 minutes
- **Reason:** Connection timeout to deploy server
```

Rules:
- Use the actual task data from the cleanup script output (Summary, Started, Ended, exit code, output lines)
- Use simple formatting (bold, bullet lists) suitable for chat platforms
- Keep each summary to 3-5 bullet points max
- For long messages, write to a temp file and pass `--message-file <path>` instead

## 3. Handle monitorDetected tasks

If a failed task has `monitorDetected: true` in its note or manifest, it means the monitor already sent a deterministic notification to the user. Do **not** call `post_task_summary` again — that would double-notify. Instead:
- Focus on **interpreting** the failure (what likely happened, based on the output and context)
- Decide whether to **retry** — but NEVER retry silently. If retrying, tell the user what failed and what you're doing differently. Use `post_task_summary` to deliver the retry decision so it lands in the right channel.
- Check if there's already a retry in progress (look for active tasks with the same `sessionId`)

## 4. Retry awareness

Check for suspicious patterns:
- A failed task AND an active task with the same `sessionId` → a retry is in progress. If the user wasn't notified about the retry, notify them now via `post_task_summary` against the original task ID.
- Multiple failed tasks with similar summaries in quick succession → possible loop. Alert the user.

## 5. If nothing needs attention

If the cleanup script reports "No issues found. All clear." and there are no tasks awaiting notification, reply with exactly: HEARTBEAT_OK

Do NOT fabricate task statuses from memory or prior conversations. Only report what the cleanup script actually found.
