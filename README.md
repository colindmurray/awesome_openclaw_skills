# awesome_openclaw_skills

A curated collection of production-ready skills for [OpenClaw](https://github.com/openclaw) agents. Background task management, audio processing, multi-account GitHub operations, and structured planning workflows — all generalized and ready to install.

## Quick Start

```bash
git clone https://github.com/YOUR_USER/awesome_openclaw_skills.git
cd awesome_openclaw_skills
./install.sh ~/.openclaw
```

The interactive installer lets you pick which skills to install. Use `--all` to install everything:

```bash
./install.sh --all ~/.openclaw
```

## Skills

| Skill | Category | Description |
|-------|----------|-------------|
| **long-running-task** | Task Management | Background task execution with PID monitoring, stall detection, and Discord notifications |
| **coding-agent** | Task Management | AI coding agent delegation patterns with multi-agent fallback strategy |
| **check-on-task** | Task Management | Task status checker with deep agent analysis (phase detection, git progress, hang detection) |
| **audio-summary** | Audio Processing | Text-to-speech with multi-provider fallback (Gemini → OpenAI → ElevenLabs) |
| **audio-transcription** | Audio Processing | Speech-to-text via Gemini multimodal API (supports OGG, MP3, WAV, FLAC, M4A, WEBM) |
| **clone-github-repository** | GitHub & Planning | Clone repos with automatic N-account identity resolution via config file |
| **create-execution-plan** | GitHub & Planning | Structured planning workflow with confirmation protocol and delegation patterns |

### Extras

| Component | Description |
|-----------|-------------|
| **session-context hook** | Injects routing metadata (session ID, channel, target) on agent bootstrap |
| **workspace/HEARTBEAT.md** | 30-minute heartbeat protocol for periodic task monitoring and cleanup |
| **lib/resolve_github_account** | Shared library for N-account GitHub identity resolution |

## Configuration

### GitHub Multi-Account Setup

The clone and task management skills support multiple GitHub accounts. Configure them in `~/.openclaw/github-accounts.json`:

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

An example config is provided at `config/github-accounts.example.json`.

### API Keys (Audio Skills)

Audio skills need API keys. Store them as files in `~/.openclaw/secrets/`:

```bash
mkdir -p ~/.openclaw/secrets
echo "your-gemini-key" > ~/.openclaw/secrets/GEMINI_API_KEY
echo "your-openai-key" > ~/.openclaw/secrets/OPENAI_API_KEY        # optional
echo "your-elevenlabs-key" > ~/.openclaw/secrets/ELEVENLABS_API_KEY  # optional
```

Keys are also read from environment variables if set. At minimum, `GEMINI_API_KEY` is required for audio features.

### Cron Monitoring (Optional)

For automated task monitoring, add cron entries from `examples/monitor.crontab`:

```bash
# Monitor active tasks every 5 minutes
*/5 * * * * ~/.openclaw/skills/long-running-task/bin/monitor_task --channel discord >> ~/.openclaw/logs/monitor.log 2>&1
```

## Directory Structure

```
awesome_openclaw_skills/
├── install.sh                          # Interactive installer
├── README.md
├── LICENSE
├── lib/
│   └── resolve_github_account          # Shared N-account GitHub identity resolver
├── skills/
│   ├── long-running-task/              # Background task execution + monitoring
│   │   ├── SKILL.md
│   │   └── bin/
│   │       ├── execute_long_running_task
│   │       ├── monitor_task
│   │       ├── cleanup_tasks
│   │       ├── check_task
│   │       └── resolve_channel
│   ├── coding-agent/
│   │   └── SKILL.md
│   ├── check-on-task/
│   │   └── SKILL.md
│   ├── audio-summary/
│   │   ├── SKILL.md
│   │   └── bin/
│   │       └── generate_audio
│   ├── audio-transcription/
│   │   ├── SKILL.md
│   │   └── bin/
│   │       └── transcribe_audio
│   ├── clone-github-repository/
│   │   ├── SKILL.md
│   │   └── bin/
│   │       └── clone_github_repository
│   └── create-execution-plan-and-await-confirmation/
│       ├── SKILL.md
│       └── references/
│           └── delegation-patterns.md
├── workspace/
│   └── HEARTBEAT.md
├── hooks/
│   └── session-context/
│       └── handler.js
├── config/
│   ├── github-accounts.example.json
│   └── secrets.example/
│       ├── OPENAI_API_KEY
│       ├── GEMINI_API_KEY
│       └── ELEVENLABS_API_KEY
└── examples/
    └── monitor.crontab
```

## Installer Usage

```bash
./install.sh [OPTIONS] [TARGET_DIR]

Options:
  --all        Install all skills and extras
  --dry-run    Show what would be installed without making changes
  --uninstall  Remove installed skills
  --list       List available skills
  --help       Show help

TARGET_DIR defaults to ~/.openclaw
```

## Dependencies

| Skill | Required |
|-------|----------|
| long-running-task, check-on-task, clone-github-repository | `jq` |
| audio-summary, audio-transcription | `curl`, `jq`, `python3`, `base64` |
| All skills | `bash` 4.0+ |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add your skill under `skills/<skill-name>/` with a `SKILL.md`
4. Add bin scripts under `skills/<skill-name>/bin/` if needed
5. Update `install.sh` to include the new skill
6. Submit a pull request

## License

MIT — see [LICENSE](LICENSE).
