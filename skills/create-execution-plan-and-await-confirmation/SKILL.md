---
name: create-execution-plan-and-await-confirmation
description: Create a structured execution plan, present it for approval, and only proceed after explicit confirmation. Prevents wasted effort on misunderstood requirements.
metadata: {"openclaw":{"emoji":"📋"}}
---

# Create Execution Plan and Await Confirmation

A structured planning workflow for complex tasks. Create a detailed plan, present it for approval, and wait for explicit confirmation before executing.

## When to Use

- Tasks that will take >15 minutes or touch >3 files
- Architectural changes or new feature implementations
- Tasks where requirements might be ambiguous
- Multi-step workflows that benefit from upfront alignment
- When delegating to background coding agents

## Workflow

### Step 1: Analyze the Request

Understand what's being asked:
- What is the desired end state?
- What are the constraints?
- What existing code/systems are affected?

### Step 2: Create the Plan

Write a structured plan using this format:

```markdown
## Execution Plan: [Title]

### Goal
[1-2 sentence summary of what will be accomplished]

### Approach
[High-level strategy — which pattern/architecture/technique]

### Steps
1. **[Step title]** — [What will be done, which files affected]
2. **[Step title]** — [What will be done, which files affected]
3. ...

### Files to Modify
- `path/to/file.ts` — [What changes]
- `path/to/other.ts` — [What changes]

### New Files
- `path/to/new-file.ts` — [Purpose]

### Risks & Considerations
- [Potential issues, edge cases, or trade-offs]

### Verification
- [How to confirm the plan was executed correctly]
```

### Step 3: Present and Wait

Present the plan to the user and **explicitly ask for confirmation**:

> Here's my plan for [task]. Should I proceed?

**Do NOT start executing until you receive explicit approval.**

### Step 4: Handle Feedback

If the user requests changes:
1. Update the plan
2. Present the revised version
3. Wait for approval again

### Step 5: Execute

Once approved, execute the plan step by step. Reference the plan as you go:
- "Starting step 1: ..."
- "Step 2 complete. Moving to step 3..."

## For Background Agents

When creating a plan that will be executed by a background coding agent:

1. Write the complete plan to a prompt file
2. Include the plan in the agent's prompt
3. The agent should output its progress against the plan steps

```bash
# Write plan to file
cat > /tmp/plan-prompt.txt << 'EOF'
[Full plan with all steps]
EOF

# Launch agent with plan
execute_long_running_task \
  --mode heartbeat \
  --type coding-agent \
  --agent claude \
  --prompt-file /tmp/plan-prompt.txt \
  --workdir /path/to/project \
  --summary "Execute plan: [title]"
```

## Anti-Patterns

- **Don't skip planning for complex tasks** — "Just do it" leads to rework
- **Don't over-plan simple tasks** — A 2-line bug fix doesn't need a plan
- **Don't plan and execute in the same message** — The user might want changes
- **Don't present options without a recommendation** — Lead with your best approach, note alternatives
