---
name: coding-agent
description: Run Codex CLI, Claude Code, OpenCode, or Pi Coding Agent via background process for programmatic control. Beyond coding, these agents excel at investigating large codebases, analyzing complex systems, writing documentation, creating specs, and executing multi-step workflows that require deep reasoning and file exploration.
metadata: {"openclaw":{"emoji":"🧩","requires":{"anyBins":["claude","codex","opencode","pi"]}}}
---

# Coding Agent (bash-first)

Use **bash** (with optional background mode) for all coding agent work. Simple and effective.

## Beyond Coding

These agents are powerful general-purpose assistants that excel at:

- **Investigation**: Exploring large codebases to understand architecture, find bugs, trace data flows
- **Analysis**: Deep-diving into complex systems, identifying patterns, root cause analysis
- **Documentation**: Writing specs, creating detailed action plans, generating comprehensive comments
- **Multi-step workflows**: Tasks requiring iteration, exploration, and decision-making
- **Heavy-duty tasks**: Anything that benefits from autonomous exploration and reasoning

When you need deep investigation or complex analysis, delegate to these agents rather than doing it yourself.

---

## Launching Coding Agents

### Background mode (tasks >5 min)

Use `execute_long_running_task` with `--type coding-agent`. This handles manifests,
NDJSON streaming, watchdogs, notifications, and monitor watchdog automatically.

**Read:** `~/.openclaw/skills/long-running-task/SKILL.md` for templates.

```bash
~/.openclaw/skills/long-running-task/bin/execute_long_running_task \
  --mode heartbeat \
  --type coding-agent \
  --agent claude \
  --command "<PROMPT>" \
  --workdir "<WORKDIR>" \
  --summary "<PROMPT>" \
  --session-id "<SESSION_ID>" \
  --channel discord \
  --target "<TARGET_ID>"
```

**ALWAYS include `--target`** with the Discord target ID from `SESSION_CONTEXT.md`. This enables auto-notifications for start/complete/fail/die events.

### Direct mode (quick tasks <5 min)

Run the agent directly and wait for the response:

```bash
claude -p --dangerously-skip-permissions "<PROMPT>"
gemini -y "<PROMPT>"
codex -s danger-full-access --dangerously-bypass-approvals-and-sandbox exec "<PROMPT>"
```

No manifest needed — you're blocking and will see the result immediately.

### Checking on background agents

Use the **check-on-task** skill:

```bash
~/.openclaw/skills/long-running-task/bin/check_task --task-id <TASK_ID>
~/.openclaw/skills/long-running-task/bin/check_task --all
```

---

## Progress Updates (Responsibility Split)

### Scripts auto-handle (you don't need to post these):
- **Task started** — Discord notification sent within ~1 second of launch
- **Task completed** — Discord notification sent immediately on exit with summary, duration, last output
- **Task failed** — Discord notification sent immediately with exit code, error context
- **Task died** (OOM/crash) — Discord notification sent within ~2 minutes by PID monitor

### AI must handle:
- **Retry decisions** — NEVER retry silently. ALWAYS notify the user before retrying. Include what failed, why you're retrying, both task IDs.
- **Milestone updates** — When checking on a long task, share significant progress (e.g., "tests passing", "PR created")
- **Result interpretation** — When a task completes, explain what was accomplished and what to do next
- **Kill decisions** — If you kill a session, immediately say you killed it and why

### Memory Constraints

Concurrent coding agents use significant RAM and risk OOM kills:
- A single Claude Code agent uses ~1-2GB
- Two concurrent agents will likely trigger OOM
- **Check active tasks before launching parallel agents**: `check_task --all`
- If memory is tight, wait for one task to finish before starting another

---

## Quotas & Usage Strategy

### Anthropic / Claude Code

**Quota:** Depends on your plan. Subscription (MAX/Pro) provides generous token allowance. API key billing is usage-based.

**Strategy:** Use as **primary agent** for:
- Deep reasoning tasks requiring extended thinking
- Token-expensive operations (large codebase analysis, multi-file refactors)
- Long-running background tasks
- Parallel batch operations
- Complex investigation requiring many turns
- Nuanced reasoning, careful code review

**Use the default model** (Opus) for best results. Adjust model choice based on your quota.

### OpenAI / Codex

**Quota:** Depends on your plan. Subscription or API key billing available.

**Strategy:** Use as **secondary agent**:
- When Claude is unavailable or rate-limited
- For tasks where Codex's strengths matter (tight OpenAI ecosystem integration)
- Batch work when Claude quota is running low

### Gemini / Pi / OpenCode

**Quota:** Variable — check your specific plan.

**Strategy:** Use as tertiary fallbacks when both Claude and Codex are unavailable.

---

## Fallback Strategy

| Priority | Agent | Quota | When to Use |
|----------|-------|-------|-------------|
| 1 | **Claude** | Subscription/API | Default for ALL tasks — heavy or light |
| 2 | **Codex** | Subscription/API | When Claude unavailable or rate-limited |
| 3 | **Gemini** | Variable | When both above unavailable |
| 4 | **Pi/OpenCode** | Variable | Final fallback |

**Signs you need to fall back:**
- "You've hit your usage limit"
- Rate limit / 429 errors
- Model overloaded messages

---

## PTY Mode Required!

Coding agents (Codex, Claude Code, Pi) are **interactive terminal applications** that need a pseudo-terminal (PTY) to work correctly. Without PTY, you'll get broken output, missing colors, or the agent may hang.

**Always use `pty:true`** when running coding agents:

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
| `pty` | boolean | **Use for coding agents!** Allocates a pseudo-terminal for interactive CLIs |
| `workdir` | string | Working directory (agent sees only this folder's context) |
| `background` | boolean | Run in background, returns sessionId for monitoring |
| `timeout` | number | Timeout in seconds (kills process on expiry) |
| `elevated` | boolean | Run on host instead of sandbox (if allowed) |

### Process Tool Actions (for background sessions)

| Action | Description |
|--------|-------------|
| `list` | List all running/recent sessions |
| `poll` | Check if session is still running |
| `log` | Get session output (with optional offset/limit) |
| `write` | Send raw data to stdin |
| `submit` | Send data + newline (like typing and pressing Enter) |
| `send-keys` | Send key tokens or hex bytes |
| `paste` | Paste text (with optional bracketed mode) |
| `kill` | Terminate the session |

---

## Quick Start: One-Shot Tasks

For quick prompts/chats, create a temp git repo and run:

```bash
# Quick chat (Codex needs a git repo!)
SCRATCH=$(mktemp -d) && cd $SCRATCH && git init && codex exec "Your prompt here"

# Or in a real project - with PTY!
bash pty:true workdir:~/Projects/myproject command:"codex exec 'Add error handling to the API calls'"
```

**Why git init?** Codex refuses to run outside a trusted git directory. Creating a temp repo solves this for scratch work.

---

## The Pattern: workdir + background + pty

For longer tasks, use background mode with PTY:

```bash
# Start agent in target directory (with PTY!)
bash pty:true workdir:~/project background:true command:"codex exec --full-auto 'Build a snake game'"
# Returns sessionId for tracking

# Monitor progress
process action:log sessionId:XXX

# Check if done
process action:poll sessionId:XXX

# Send input (if agent asks a question)
process action:write sessionId:XXX data:"y"

# Submit with Enter (like typing "yes" and pressing Enter)
process action:submit sessionId:XXX data:"yes"

# Kill if needed
process action:kill sessionId:XXX
```

**Why workdir matters:** Agent wakes up in a focused directory, doesn't wander off reading unrelated files (like your soul.md).

---

## Codex CLI

**Model:** `gpt-5.2-codex` is the default (set in ~/.codex/config.toml)

### Flags

| Flag | Effect |
|------|--------|
| `exec "prompt"` | One-shot execution, exits when done |
| `--full-auto` | Sandboxed but auto-approves in workspace |
| `-s danger-full-access --dangerously-bypass-approvals-and-sandbox` | NO sandbox, NO approvals (fastest, most dangerous) |

### Building/Creating
```bash
# Quick one-shot (auto-approves) - remember PTY!
bash pty:true workdir:~/project command:"codex exec --full-auto 'Build a dark mode toggle'"

# Background for longer work
bash pty:true workdir:~/project background:true command:"codex -s danger-full-access --dangerously-bypass-approvals-and-sandbox 'Refactor the auth module'"
```

### Reviewing PRs

**CRITICAL: Never review PRs in your workspace folder!**
Clone to temp folder or use git worktree.

```bash
# Clone to temp for safe review
REVIEW_DIR=$(mktemp -d)
git clone https://github.com/user/repo.git $REVIEW_DIR
cd $REVIEW_DIR && gh pr checkout 130
bash pty:true workdir:$REVIEW_DIR command:"codex review --base origin/main"
# Clean up after: trash $REVIEW_DIR

# Or use git worktree (keeps main intact)
git worktree add /tmp/pr-130-review pr-130-branch
bash pty:true workdir:/tmp/pr-130-review command:"codex review --base main"
```

### Batch PR Reviews (parallel army!)
```bash
# Fetch all PR refs first
git fetch origin '+refs/pull/*/head:refs/remotes/origin/pr/*'

# Deploy the army - one Codex per PR (all with PTY!)
bash pty:true workdir:~/project background:true command:"codex exec 'Review PR #86. git diff origin/main...origin/pr/86'"
bash pty:true workdir:~/project background:true command:"codex exec 'Review PR #87. git diff origin/main...origin/pr/87'"

# Monitor all
process action:list

# Post results to GitHub
gh pr comment <PR#> --body "<review content>"
```

---

## Claude Code

**Primary agent.** Claude MAX provides generous quota — use the default model (Opus).

| Mode | Command |
|------|---------|
| One-shot | `env -u ANTHROPIC_API_KEY claude -p "prompt"` |
| Auto-edit | `env -u ANTHROPIC_API_KEY claude -p --permission-mode acceptEdits "Fix the bug"` |
| Full auto (headless) | `env -u ANTHROPIC_API_KEY claude -p --dangerously-skip-permissions "prompt"` |

**Note:** If using subscription billing (MAX/Pro), prefix with `env -u ANTHROPIC_API_KEY` to force OAuth instead of API key billing. If using API key billing, omit this prefix.

```bash
# Standard usage — default model is fine with MAX quota
# Unset API key to use subscription quota (omit env -u if using API key billing)
env -u ANTHROPIC_API_KEY claude -p "Add error handling to src/api.ts"
env -u ANTHROPIC_API_KEY claude -p --permission-mode acceptEdits "Fix the bug"

# Interactive (with PTY)
bash pty:true workdir:~/project command:"env -u ANTHROPIC_API_KEY claude 'Your task'"

# Background (use execute_long_running_task instead for long tasks)
# execute_long_running_task automatically adds env -u ANTHROPIC_API_KEY
```

**Why `env -u ANTHROPIC_API_KEY`?** Claude Code prioritizes the `ANTHROPIC_API_KEY` environment variable over OAuth. If using subscription billing and the env var is set, Claude Code uses API billing instead. Unsetting it forces OAuth subscription quota. Skip this if you want API key billing.

---

## Gemini CLI

**Alternative fallback with different model family.**

| Codex | Gemini Equivalent |
|-------|-------------------|
| `codex exec "prompt"` | `gemini "prompt"` |
| `codex --full-auto` | `gemini --approval-mode auto_edit "prompt"` |
| `codex -s danger-full-access --dangerously-bypass-approvals-and-sandbox` | `gemini -y "prompt"` |

```bash
# Non-interactive (one-shot)
gemini "Add error handling to src/api.ts"
gemini -y "Build a REST API"  # yolo mode

# Interactive (with PTY)
bash pty:true workdir:~/project command:"gemini -i 'Your task'"
```

**Detailed docs:** See `references/gemini-cli.md`

---

## OpenCode

```bash
bash pty:true workdir:~/project command:"opencode run 'Your task'"
```

---

## Pi Coding Agent

```bash
# Install: npm install -g @mariozechner/pi-coding-agent
bash pty:true workdir:~/project command:"pi 'Your task'"

# Non-interactive mode (PTY still recommended)
bash pty:true command:"pi -p 'Summarize src/'"

# Different provider/model
bash pty:true command:"pi --provider openai --model gpt-4o-mini -p 'Your task'"
```

**Note:** Pi now has Anthropic prompt caching enabled (PR #584, merged Jan 2026)!

---

## Parallel Issue Fixing with git worktrees

For fixing multiple issues in parallel, use git worktrees:

```bash
# 1. Create worktrees for each issue
git worktree add -b fix/issue-78 /tmp/issue-78 main
git worktree add -b fix/issue-99 /tmp/issue-99 main

# 2. Launch Codex in each (background + PTY!)
bash pty:true workdir:/tmp/issue-78 background:true command:"pnpm install && codex -s danger-full-access --dangerously-bypass-approvals-and-sandbox 'Fix issue #78: <description>. Commit and push.'"
bash pty:true workdir:/tmp/issue-99 background:true command:"pnpm install && codex -s danger-full-access --dangerously-bypass-approvals-and-sandbox 'Fix issue #99: <description>. Commit and push.'"

# 3. Monitor progress
process action:list
process action:log sessionId:XXX

# 4. Create PRs after fixes
cd /tmp/issue-78 && git push -u origin fix/issue-78
gh pr create --repo user/repo --head fix/issue-78 --title "fix: ..." --body "..."

# 5. Cleanup
git worktree remove /tmp/issue-78
git worktree remove /tmp/issue-99
```

---

## tmux Orchestration (Alternative)

For advanced multi-agent control, use the **tmux skill** instead of bash background mode.

### When to Use tmux vs bash background

| Use Case | Recommended |
|----------|-------------|
| Quick one-shot tasks | `bash pty:true` |
| Long-running with monitoring | `bash background:true` |
| Multiple parallel agents | **tmux** |
| Agent forking (context transfer) | **tmux** |
| Session persistence (survives disconnects) | **tmux** |
| Interactive debugging (pdb, REPL) | **tmux** |

### Quick Example

```bash
SOCKET="${TMPDIR:-/tmp}/coding-agents.sock"

# Create sessions for parallel work
tmux -S "$SOCKET" new-session -d -s agent-1 -c /tmp/worktree-1
tmux -S "$SOCKET" new-session -d -s agent-2 -c /tmp/worktree-2

# Launch agents
tmux -S "$SOCKET" send-keys -t agent-1 "codex -s danger-full-access --dangerously-bypass-approvals-and-sandbox 'Fix issue #1'" Enter
tmux -S "$SOCKET" send-keys -t agent-2 "claude 'Fix issue #2'" Enter

# Monitor (check for shell prompt to detect completion)
tmux -S "$SOCKET" capture-pane -p -t agent-1 -S -100

# Attach to watch live
tmux -S "$SOCKET" attach -t agent-1
```

### Agent Forking

Transfer context between agents (e.g., plan with Codex, execute with Claude):

```bash
# Capture context from current agent
CONTEXT=$(tmux -S "$SOCKET" capture-pane -p -t planner -S -500)

# Fork to new agent with context
tmux -S "$SOCKET" new-session -d -s executor
tmux -S "$SOCKET" send-keys -t executor "claude -p 'Based on this plan: $CONTEXT

Execute step 1.'" Enter
```

**Full docs:** See the `tmux` skill for socket conventions, wait-for-text helpers, and cleanup.

---

## Rules

1. **Always use pty:true** - coding agents need a terminal!
2. **Respect tool choice** - if user asks for Codex, use Codex.
   - Orchestrator mode: do NOT hand-code patches yourself.
   - If an agent fails/hangs, respawn it or ask the user for direction, but don't silently take over.
3. **Be patient** - don't kill sessions because they're "slow"
4. **Monitor with process:log** - check progress without interfering
5. **--full-auto for building** - auto-approves changes
6. **vanilla for reviewing** - no special flags needed
7. **Parallel is OK** - run many Codex processes at once for batch work (but check memory first on this server!)
8. **NEVER start Codex in your workspace folder** - it'll read your soul docs and get weird ideas about the org chart!
9. **NEVER checkout branches in your main project folder** - that's the LIVE instance!
10. **Use `check_task` to monitor background agents** - not process:log. The manifest system gives you richer analysis.
11. **Never assemble raw headless flags** — `execute_long_running_task --type coding-agent` handles `--output-format stream-json`, `--dangerously-skip-permissions`, etc. automatically. For direct mode, use the exact templates above.

---

## Worktree Cleanup After PR Merge

**Important:** When a coding agent successfully merges a PR, it should clean up its worktree to avoid disk space waste.

Add this to your agent prompt when working on PRs:

```
### Cleanup After Merge
Once the PR is successfully merged:
1. Delete the remote branch: `git push origin --delete <branch-name>` (if not auto-deleted by merge)
2. Remove the local worktree: `cd /path/to/main/repo && git worktree remove <worktree-path>`
3. Or simply remove the directory: `rm -rf <worktree-path>`

This keeps the workspace clean and prevents accumulation of old worktrees.
```

**Automatic cleanup:** The heartbeat cleanup script will also remove worktrees for merged PRs after 30 minutes. This is a safety net — agents should clean up themselves for immediate cleanup.

---

## Learnings

- **PTY is essential:** Coding agents are interactive terminal apps. Without `pty:true`, output breaks or agent hangs.
- **Git repo required:** Codex won't run outside a git directory. Use `mktemp -d && git init` for scratch work.
- **exec is your friend:** `codex exec "prompt"` runs and exits cleanly - perfect for one-shots.
- **submit vs write:** Use `submit` to send input + Enter, `write` for raw data without newline.
- **Beyond coding:** These agents are powerful for investigation, analysis, documentation, and complex multi-step workflows. Delegate heavy exploration tasks to them.
