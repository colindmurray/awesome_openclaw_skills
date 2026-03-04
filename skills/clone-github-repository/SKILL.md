---
name: clone-github-repository
description: Clone a GitHub repository with automatic credential switching (SSH + PAT) based on repo owner, and route it to the correct directory based on purpose.
metadata: {"openclaw":{"emoji":"📦","requires":{"anyBins":["git","jq"]}}}
---

# Clone GitHub Repository

Clone any GitHub repo with the correct identity and destination — automatically.

## How It Works

The script reads your GitHub account configuration from `~/.openclaw/github-accounts.json` and automatically detects which account to use based on the **repo owner** in the URL.

Each account maps GitHub usernames/orgs to SSH credentials and PATs:

```json
{
  "accounts": {
    "personal": {
      "github_username": "myuser",
      "ssh_host": "github-personal",
      "ssh_key": "~/.ssh/id_ed25519_personal",
      "pat_file": "~/.secrets/PERSONAL_GITHUB_PAT",
      "owners": ["myuser", "my-org"]
    },
    "work": {
      "github_username": "work-user",
      "ssh_host": "github-work",
      "ssh_key": "~/.ssh/id_ed25519_work",
      "pat_file": "~/.secrets/WORK_GITHUB_PAT",
      "owners": ["work-org", "work-team"]
    }
  },
  "default_account": "personal"
}
```

When the repo owner matches an entry in an account's `owners` array, that account's credentials are used. If no match is found, the `default_account` is used.

## Clone Destinations

The `--purpose` flag determines where the repo is cloned:

| Purpose | Directory | When to Use |
|---------|-----------|-------------|
| `contributor` (default) | `$OPENCLAW_PROJECTS_DIR/<repo>` (default: `~/Projects/`) | User intends to contribute, push commits, open PRs |
| `external` | `$OPENCLAW_EXTERNAL_DIR/<repo>` (default: `~/external-github-repos/`) | Non-temporary reference repo, reading/learning, not contributing |
| `temporary` | `$OPENCLAW_TEMP_DIR/<repo>` (default: `/tmp/github/`) | Quick investigation, throwaway, will be deleted soon |

### Deciding the Purpose

Read the user's intent carefully:

- **"clone X so I can work on it"** / **"I need to fix a bug in X"** / **"set up X for development"** → `contributor`
- **"clone X so I can look at how they did Y"** / **"I want to reference X"** → `external`
- **"just clone X real quick"** / **"I want to check something in X"** / **"clone for investigation"** → `temporary`
- If unclear, **default to `contributor`** and mention the directory in your response.

## Setup

1. Copy the example config:
   ```bash
   cp config/github-accounts.example.json ~/.openclaw/github-accounts.json
   ```

2. Edit `~/.openclaw/github-accounts.json` with your accounts, SSH hosts, and PAT file paths.

3. Ensure your SSH config (`~/.ssh/config`) has host aliases matching the `ssh_host` values.

## Usage

```bash
~/.openclaw/skills/clone-github-repository/bin/clone_github_repository \
  --url <URL_OR_OWNER/REPO> \
  [--account <account_name>] \
  [--purpose contributor|external|temporary] \
  [--name DIR_NAME]
```

## Examples

### Clone own repo (auto-detects account)
```bash
clone_github_repository --url https://github.com/myuser/my-project
# → ~/Projects/my-project, using personal account credentials
```

### Clone work org repo (auto-detects work account)
```bash
clone_github_repository --url work-org/internal-tool
# → ~/Projects/internal-tool, using work account credentials
```

### Clone third-party repo for reference
```bash
clone_github_repository --url https://github.com/vercel/next.js --purpose external
# → ~/external-github-repos/next.js, using default account credentials
```

### Clone with explicit account override
```bash
clone_github_repository --url https://github.com/some-org/private-repo --account work
# → ~/Projects/private-repo, using work account credentials
```

### Quick temporary investigation
```bash
clone_github_repository --url torvalds/linux --purpose temporary
# → /tmp/github/linux, using default account credentials
```

## Flags Reference

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--url` | Yes | — | GitHub URL, `git@` URL, or `owner/repo` shorthand |
| `--account` | No | auto-detect | Force a specific account from `github-accounts.json` |
| `--purpose` | No | `contributor` | Where to clone: `contributor`, `external`, or `temporary` |
| `--name` | No | repo name | Override the clone directory name |

## Post-Clone

After cloning, the script:
1. Verifies `.git/` exists
2. Confirms the remote is set to the correct SSH host alias
3. Checks `gh` API access and reports permission level (admin/push/pull)

The clone directory is ready to use immediately — correct SSH identity for push/pull, correct PAT for `gh` CLI operations.

## Account Override Guidance

When a user asks to clone a repo owned by someone not in the configured accounts:
- The default account is used silently
- **Only ask** the user about a specific account if they mention a particular team or collaboration context
- If the user explicitly names an account, pass `--account <name>`

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCLAW_GITHUB_ACCOUNTS_FILE` | `~/.openclaw/github-accounts.json` | Path to the account config file |
| `OPENCLAW_PROJECTS_DIR` | `~/Projects` | Destination for `contributor` clones |
| `OPENCLAW_EXTERNAL_DIR` | `~/external-github-repos` | Destination for `external` clones |
| `OPENCLAW_TEMP_DIR` | `/tmp/github` | Destination for `temporary` clones |
