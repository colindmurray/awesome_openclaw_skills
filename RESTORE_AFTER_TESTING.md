# Restore After Testing

Files backed up before installing awesome_openclaw_skills to `~/.openclaw/`.
Run the restore commands below to revert to the original versions.

## Backed-up Files

### workspace
```bash
cp ~/.openclaw/workspace/HEARTBEAT.md.bak ~/.openclaw/workspace/HEARTBEAT.md
```

### check-on-task
```bash
cp ~/.openclaw/skills/check-on-task/AGENT_ANALYSIS.md.bak ~/.openclaw/skills/check-on-task/AGENT_ANALYSIS.md
cp ~/.openclaw/skills/check-on-task/SKILL.md.bak ~/.openclaw/skills/check-on-task/SKILL.md
```

### clone-github-repository
```bash
cp ~/.openclaw/skills/clone-github-repository/bin/clone_github_repository.bak ~/.openclaw/skills/clone-github-repository/bin/clone_github_repository
cp ~/.openclaw/skills/clone-github-repository/SKILL.md.bak ~/.openclaw/skills/clone-github-repository/SKILL.md
```

### coding-agent
```bash
cp ~/.openclaw/skills/coding-agent/SKILL.md.bak ~/.openclaw/skills/coding-agent/SKILL.md
```

### long-running-task
```bash
cp ~/.openclaw/skills/long-running-task/bin/check_task.bak ~/.openclaw/skills/long-running-task/bin/check_task
cp ~/.openclaw/skills/long-running-task/bin/cleanup_tasks.bak ~/.openclaw/skills/long-running-task/bin/cleanup_tasks
cp ~/.openclaw/skills/long-running-task/bin/execute_long_running_task.bak ~/.openclaw/skills/long-running-task/bin/execute_long_running_task
cp ~/.openclaw/skills/long-running-task/SKILL.md.bak ~/.openclaw/skills/long-running-task/SKILL.md
```

## New files added by installer (remove if reverting)

These files/dirs were added by the installer and don't have originals:
```bash
rm -rf ~/.openclaw/skills/audio-summary
rm -rf ~/.openclaw/skills/audio-transcription
rm -rf ~/.openclaw/skills/create-execution-plan-and-await-confirmation
rm -f ~/.openclaw/lib/resolve_github_account
rm -f ~/.openclaw/skills/long-running-task/bin/monitor_task
rm -f ~/.openclaw/skills/long-running-task/bin/resolve_channel
rm -f ~/.openclaw/coding-agents.json
# workspace/HEARTBEAT.md — only if it didn't exist before
# hooks/session-context/handler.js — only if it didn't exist before
```

## Restore all at once
```bash
# Restore all backed-up originals (only skills/workspace/lib dirs)
find ~/.openclaw/skills ~/.openclaw/workspace -name "*.bak" 2>/dev/null | while read -r bak; do
  orig="${bak%.bak}"
  cp "$bak" "$orig"
  echo "Restored: $orig"
done

# Clean up .bak files (only in installer-managed dirs)
find ~/.openclaw/skills ~/.openclaw/workspace -name "*.bak" -delete 2>/dev/null

# Remove new skills that didn't exist before
rm -rf ~/.openclaw/skills/audio-summary
rm -rf ~/.openclaw/skills/audio-transcription
rm -rf ~/.openclaw/skills/create-execution-plan-and-await-confirmation
rm -f ~/.openclaw/lib/resolve_github_account
rm -f ~/.openclaw/skills/long-running-task/bin/monitor_task
rm -f ~/.openclaw/skills/long-running-task/bin/resolve_channel
rm -f ~/.openclaw/coding-agents.json
```
