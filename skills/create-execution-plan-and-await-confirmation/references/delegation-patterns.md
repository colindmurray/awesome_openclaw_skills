# Delegation Patterns for Coding Agents

Common patterns for delegating work to coding agents effectively.

## Pattern 1: Single-Issue Fix

Best for: Bug fixes, small features, one-file changes.

```bash
# Create a worktree for isolation
git worktree add -b fix/issue-42 /tmp/fix-42 main

# Launch agent
execute_long_running_task \
  --mode heartbeat \
  --type coding-agent \
  --agent claude \
  --command "Fix issue #42: [description]. Run tests. Commit and push." \
  --workdir /tmp/fix-42 \
  --summary "Fix issue #42"
```

## Pattern 2: PR Review

Best for: Code review, quality checks.

```bash
# Clone to temp for safe review
REVIEW_DIR=$(mktemp -d)
git clone <repo-url> $REVIEW_DIR
cd $REVIEW_DIR && gh pr checkout 42

# Launch reviewer
execute_long_running_task \
  --mode heartbeat \
  --type coding-agent \
  --agent claude \
  --command "Review this PR. Check for bugs, security issues, and style. Post review via gh." \
  --workdir $REVIEW_DIR \
  --summary "Review PR #42"
```

## Pattern 3: Parallel Multi-Issue

Best for: Batch bug fixes, independent tasks.

```bash
# Create worktrees
git worktree add -b fix/issue-1 /tmp/fix-1 main
git worktree add -b fix/issue-2 /tmp/fix-2 main

# Launch agents in parallel (check memory first!)
for i in 1 2; do
  execute_long_running_task \
    --mode heartbeat \
    --type coding-agent \
    --agent claude \
    --command "Fix issue #$i: [description]. Commit and push." \
    --workdir /tmp/fix-$i \
    --summary "Fix issue #$i"
done
```

**Caution:** Each coding agent uses ~1-2GB RAM. Check `check_task --all --json` for memory info before launching parallel agents.

## Pattern 4: Research and Report

Best for: Codebase investigation, architecture analysis, documentation.

```bash
# Agent explores and writes findings
execute_long_running_task \
  --mode heartbeat \
  --type coding-agent \
  --agent claude \
  --command "Investigate the authentication system. Document: 1) How auth flows work 2) Where tokens are stored 3) Security concerns. Write findings to /tmp/auth-report.md" \
  --workdir /path/to/project \
  --summary "Investigate auth system"
```

## Pattern 5: Plan-Then-Execute

Best for: Complex multi-step tasks. Agent plans first, human approves, then agent executes.

```bash
# Step 1: Agent creates plan
claude -p "Analyze the codebase and create a detailed plan for: [task]. Write the plan to /tmp/plan.md. Do NOT execute — planning only."

# Step 2: Human reviews plan
cat /tmp/plan.md

# Step 3: Agent executes approved plan
execute_long_running_task \
  --mode heartbeat \
  --type coding-agent \
  --agent claude \
  --command "Execute this plan exactly: $(cat /tmp/plan.md)" \
  --workdir /path/to/project \
  --summary "Execute plan: [task]"
```

## Prompt Engineering Tips

1. **Be specific about deliverables** — "Commit and push" not "make changes"
2. **Set boundaries** — "Only modify files in src/auth/" prevents scope creep
3. **Include test expectations** — "All existing tests must still pass"
4. **Specify output format** — "Write a summary to /tmp/results.md when done"
5. **Reference existing patterns** — "Follow the same pattern as src/api/users.ts"

## Agent Selection Guide

| Task Type | Recommended Agent | Why |
|-----------|------------------|-----|
| Deep reasoning, complex refactors | Claude | Best at nuanced reasoning |
| Quick fixes, batch operations | Codex | Fast execution |
| Multi-language, Google ecosystem | Gemini | Broad language support |
| Simple tasks, fallback | Any available | When primary is rate-limited |
