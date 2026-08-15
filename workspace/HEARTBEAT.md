# HEARTBEAT.md

The heartbeat is a **safety net**, not the primary detection mechanism. Tasks have their own `monitor_pid()` watchdog that detects death within ~2 minutes and sends notifications directly. The 5-minute `monitor_task` cron provides a second layer. This heartbeat (every 30 minutes) catches anything that slipped through both layers.

## 1. Run task monitoring and maintenance

First, run the active task scanner (catches anything the per-task monitors missed):

```bash
~/.openclaw/skills/long-running-task/bin/monitor_task --channel <YOUR_CHANNEL>
```

Then run the full cleanup (dead PIDs, stall warnings, summary stub generation, pruning, worktree cleanup):

```bash
~/.openclaw/skills/long-running-task/bin/cleanup_tasks --channel <YOUR_CHANNEL>
```

`cleanup_tasks` writes a structured **summary stub** for each completed/failed task that hasn't been delivered yet. Stubs live in `~/.openclaw/tasks/pending-summaries/<taskId>.json` and contain everything you need to compose an interpretive summary — no manifest parsing required.

## 2. Deliver per-task summaries from the stub queue

List the pending stubs and process each one:

```bash
ls ~/.openclaw/tasks/pending-summaries/*.json 2>/dev/null
```

For EACH stub, read it (`jq . <stub-path>`), compose a 3–5 bullet interpretive summary, then deliver:

```bash
~/.openclaw/skills/long-running-task/bin/post_task_summary \
  --consume <STUB_PATH> \
  --message "<YOUR_INTERPRETIVE_SUMMARY>"
```

`--consume` is atomic: on successful delivery, it sets `notifiedAt` on the manifest AND removes the stub. On delivery failure, the stub stays in place and the next heartbeat retries. **You never have to track which tasks you've already notified** — stub presence is the source of truth.

### What's in a stub

| Field | Use |
|-------|-----|
| `taskId`, `manifestPath` | Reference / follow-up |
| `status`, `exitCode`, `failureNote` | Was it success or failure? Why? |
| `summary`, `type`, `agent` | What kind of task |
| `startedAt`, `endedAt`, `durationStr` | Timing |
| `channel`, `notifyTarget`, `sessionId` | Routing (post_task_summary uses these automatically — you don't need to read them) |
| `outputTail` | Last 1500 chars of output |
| `agentLastText`, `agentStats` | For coding agents: final assistant text + tool/error counts |
| `worktree` | Git worktree path if the task ran in one |
| `monitorDetected` | Whether the per-task monitor caught the death first |

### Composition guidance

- 3–5 bullets max
- Lead with **status** and **what happened**
- Use `agentLastText` and `outputTail` to ground the interpretation in real output
- For failures: include the cause (from `failureNote` and last output lines), suggest next steps
- Markdown formatting (bold, bullets) renders well on chat platforms
- For long messages, write to `/tmp/<taskId>-summary.md` and pass `--message-file` instead of `--message`

Example stub-to-summary translation:

Stub:
```json
{
  "status": "completed", "exitCode": 0, "summary": "Run integration tests",
  "durationStr": "12m 30s", "agent": "claude",
  "agentStats": {"toolCalls": 47, "errors": 0, "resultEvent": true},
  "agentLastText": "All 23 integration tests passing. ..."
}
```

Your summary:
```
**Task completed:** Run integration tests
- **Status:** Succeeded (exit 0) in 12m 30s
- **Activity:** 47 tool calls, 0 errors (claude)
- **Result:** All 23 integration tests passing
```

## 3. Handle monitorDetected tasks

If a stub has `monitorDetected: true`, the per-task watchdog already sent the user a deterministic "Task died" notification. You should still:
- Compose a brief **interpretation** (what likely happened, based on `outputTail` + `failureNote`)
- Decide whether to **retry** — but NEVER retry silently. If retrying, your interpretive summary should explain what failed and what you're doing differently.
- Check for active tasks with the same `sessionId` — that means a retry is already in progress, don't duplicate it.

The deterministic "Task died" went to the user already, so your job is interpretation, not re-notification.

## 4. Retry awareness

Suspicious patterns to flag:
- Multiple failed stubs with similar `summary` in quick succession → possible loop. Alert the user via the relevant target.
- A failed task AND an active task with the same `sessionId` → a retry is in progress. If the user wasn't told about the retry, deliver a notice now.

## 5. If nothing needs attention

Reply with exactly: `HEARTBEAT_OK`

The condition for "nothing needs attention":
- `cleanup_tasks` reported `No issues found. All clear.`
- `ls ~/.openclaw/tasks/pending-summaries/*.json` shows no files

Do NOT fabricate task statuses from memory or prior conversations. Only act on what the cleanup script and the stub directory actually contain.

## Back-compat note

The older flow used `post_task_summary --task-id <ID>` with a hand-composed message. That path still works — it now also clears any matching stub and sets `notifiedAt` on success. Use it for ad-hoc summaries (e.g., notifying about a task you launched yourself in this session). The stub queue is the recommended path for the heartbeat itself because it's deterministic and idempotent.
