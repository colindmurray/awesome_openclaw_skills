/**
 * Session Context Hook for OpenClaw
 *
 * Injects the current session ID and routing metadata into the agent's
 * bootstrap context as a virtual file. Fires on agent:bootstrap — before
 * workspace files are injected and before the agent starts processing.
 */

const handler = async (event) => {
  if (!event || typeof event !== 'object') return;
  if (event.type !== 'agent' || event.action !== 'bootstrap') return;
  if (!event.context || typeof event.context !== 'object') return;
  if (!Array.isArray(event.context.bootstrapFiles)) return;

  // Extract session info from the event
  const sessionKey = event.sessionKey || '';
  const sessionId =
    (event.context.sessionEntry && event.context.sessionEntry.sessionId) ||
    event.context.sessionId ||
    '';

  if (!sessionId) return; // Nothing to inject

  // Parse channel info from the session key
  // Format: agent:<agentId>:<channel>:<type>:<id>
  const parts = sessionKey.split(':');
  const agentId = parts[1] || 'main';
  let channel = '';
  let targetType = '';
  let targetId = '';

  if (parts.length >= 5) {
    channel = parts[2];       // e.g., "discord"
    targetType = parts[3];    // e.g., "channel" or "group" or "dm"
    targetId = parts[4];      // e.g., "1473820496435876053"
  } else if (parts.length >= 3) {
    channel = parts[2];
  }

  // Build the context document
  const lines = [
    '## Your Session Identity',
    '',
    'This is **your** current OpenClaw session. These values identify the live conversation you are participating in right now.',
    'Any callback or background task that uses this session ID will resume **this exact chat thread** with the user.',
    '',
    '| Field | Value | Meaning |',
    '|-------|-------|---------|',
    `| Session ID | \`${sessionId}\` | **Your** unique session identifier for this conversation |`,
    `| Session Key | \`${sessionKey}\` | Routing key that maps to this chat |`,
    `| Agent | \`${agentId}\` | The agent identity you are running as |`,
  ];

  if (channel) lines.push(`| Channel | \`${channel}\` | The chat platform this session is connected to |`);
  if (targetType) lines.push(`| Target Type | \`${targetType}\` | How the chat target is addressed |`);
  if (targetId) lines.push(`| Target ID | \`${targetId}\` | The specific chat/channel/group ID |`);

  lines.push('');
  lines.push('### Callback Template');
  lines.push('');
  lines.push('When spawning background tasks that need to report back to **this** session, use:');
  lines.push('');
  lines.push('```bash');

  const channelFlag = channel ? ` --channel ${channel}` : '';
  lines.push(
    `openclaw agent --agent ${agentId} --session-id ${sessionId}${channelFlag} -m "YOUR_MESSAGE" --deliver`
  );

  lines.push('```');
  lines.push('');
  lines.push('This resumes **this conversation** — the user will see the reply in the same thread they originally messaged you in.');

  // Shell Script Flags section — provides exact flags for execute_long_running_task
  if (targetId || channel || sessionId) {
    lines.push('');
    lines.push('### Shell Script Flags');
    lines.push('');
    lines.push('When launching background tasks via `execute_long_running_task`, **ALWAYS** include these flags:');
    lines.push('');
    lines.push('```');

    const flagParts = [];
    if (targetId) flagParts.push(`--target ${targetId}`);
    if (channel) flagParts.push(`--channel ${channel}`);
    if (sessionId) flagParts.push(`--session-id ${sessionId}`);

    lines.push(flagParts.join(' '));
    lines.push('```');
    lines.push('');
    lines.push('This ensures the task sends notifications to the correct channel when it starts, completes, fails, or dies unexpectedly.');
  }

  event.context.bootstrapFiles.push({
    path: 'SESSION_CONTEXT.md',
    content: lines.join('\n'),
    virtual: true,
  });
};

module.exports = handler;
module.exports.default = handler;
