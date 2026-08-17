---
name: tweetclaw
description: Install and use @xquik/tweetclaw, the OpenClaw plugin for structured X/Twitter workflows including tweet search, reply search, approved posting, follower export, media handling, direct messages, monitors, webhooks, and giveaway draws.
metadata: {"openclaw":{"requires":{"anyBins":["openclaw"]}}}
---

# TweetClaw

Use this skill when a user wants OpenClaw to work with X/Twitter through the official `@xquik/tweetclaw` plugin.

TweetClaw is a separate OpenClaw runtime plugin published from <https://github.com/Xquik-dev/tweetclaw>. This skill gives setup and safety guidance; it does not bundle the plugin runtime.

## Install

Install the plugin through ClawHub:

```bash
openclaw plugins install clawhub:@xquik/tweetclaw
```

TweetClaw can be installed before credentials are configured. In that state, the free `explore` catalog remains available and live API calls return setup guidance.

## Configure

For account-backed X/Twitter automation, create an Xquik API key at <https://dashboard.xquik.com/> and store it in OpenClaw plugin config:

```bash
openclaw config set plugins.entries.tweetclaw.config.apiKey "$XQUIK_API_KEY"
```

For accountless pay-per-use reads, configure the MPP signing key instead:

```bash
openclaw config set plugins.entries.tweetclaw.config.tempoSigningKey "$MPP_SIGNING_KEY"
```

Keep keys out of chats, logs, docs, and shell history. Prefer environment variables so OpenClaw writes sensitive values directly into local config.

If the agent can see this skill but cannot call TweetClaw tools, allow the plugin tools:

```bash
openclaw config set tools.alsoAllow '["explore", "tweetclaw"]'
```

Verify registration:

```bash
openclaw plugins inspect tweetclaw
openclaw skills info tweetclaw
```

## When To Use

Use TweetClaw for:

- Search tweets or search tweet replies
- Post tweets or post tweet replies after explicit approval
- Export followers, following, verified followers, list members, or list followers
- Look up users, timelines, bookmarks, notifications, trends, articles, quotes, retweeters, or favoriters
- Upload media, download authenticated media, and post tweets with media
- Send direct messages when the user owns or manages the account
- Create monitors and webhooks for user-approved X/Twitter events
- Run giveaway draws from tweet replies or other eligible entries
- Check Xquik account status, usage, and credit balance

Do not use TweetClaw for X ads, browser browsing, scheduling future posts, account evasion, spam, impersonation, credential collection, bulk unsolicited DMs, or bulk follow, like, or retweet campaigns.

## Safety Rules

Before any visible, state-changing, paid, or recurring action, summarize the exact account, target, action, final text or media when relevant, and requested limit. Wait for explicit user approval before calling the live `tweetclaw` tool.

This approval rule covers posts, replies, deletes, likes, retweets, follows, unfollows, DMs, profile edits, media uploads, monitors, webhooks, extraction jobs, and giveaway draws.

For private or account-scoped reads, confirm that the user owns or is authorized to access the connected account before showing results. Redact credentials and avoid exposing sensitive personal data unless the user requests that exact data.

MPP mode is read-only. Do not attempt posts, DMs, monitors, webhooks, profile changes, media uploads, or account-backed actions when only an MPP signing key is configured.

For bulk extraction, monitor, webhook, or draw requests, keep limits narrow by default. Ask for approval again if the user expands the scope, changes the target, or asks for recurring monitoring.

## Tools

TweetClaw registers 2 OpenClaw tools:

- `explore`: Free endpoint catalog search. No network request.
- `tweetclaw`: Structured Xquik endpoint invoker. Calls only catalog-listed endpoints and injects configured auth at runtime.

Use `explore` first when the user asks what is possible or when endpoint parameters are unclear. Use `tweetclaw` only after the target endpoint, parameters, account, and approval requirements are clear.

## Workflow Examples

Search tweets:

1. Use `explore` to find the tweet search endpoint.
2. Ask for limits or filters if the request is broad.
3. Use `tweetclaw` with the query parameters.
4. Summarize returned tweet IDs, authors, timestamps, text, and URLs.

Post a tweet:

1. Draft the final text and list all media.
2. Ask the user to approve the exact post.
3. Use `tweetclaw` to find the connected account and post.
4. Return the posted tweet ID and URL.

Create a monitor:

1. Confirm the target account or query, event types, and notification behavior.
2. Ask for explicit approval because monitors are recurring.
3. Create the monitor with `tweetclaw`.
4. Explain how the user can pause or delete it later.

Run a giveaway draw:

1. Confirm the source tweet, eligibility rules, and entry limit.
2. Ask for explicit approval before running the draw.
3. Use `tweetclaw` to archive eligible entries and run the draw.
4. Return the draw result and public result link if available.

## Links

- TweetClaw GitHub: <https://github.com/Xquik-dev/tweetclaw>
- npm package: <https://www.npmjs.com/package/@xquik/tweetclaw>
- Xquik: <https://xquik.com>
- Xquik docs: <https://docs.xquik.com>
- Skills.sh: <https://skills.sh/xquik-dev/tweetclaw>

Xquik is an independent third-party service. Not affiliated with X Corp. "Twitter" and "X" are trademarks of X Corp.
