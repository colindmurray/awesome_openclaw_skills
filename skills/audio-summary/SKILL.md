---
name: audio-summary
description: Generate conversational audio summaries using text-to-speech. Supports multiple providers (Gemini TTS, OpenAI TTS, ElevenLabs) with preference order and automatic fallback. Uploads audio to Discord for playback.
metadata:
  openclaw:
    emoji: 🔊
    requires:
      envVars:
        - GEMINI_API_KEY | OPENAI_API_KEY | ELEVENLABS_API_KEY
---

# Audio Summary Skill

Generates conversational audio summaries and uploads them to Discord.

## When to Use

- User says "give me an audio summary"
- User says "audio summary please"
- User says "tell me in voice"
- User explicitly requests audio/voice response

## How It Works

1. **Generate summary text** — Create a conversational summary (150 words max, 30-60 seconds)
2. **Convert to audio** — Use TTS provider (Gemini → OpenAI → ElevenLabs fallback)
3. **Upload to Discord** — Use message tool with `media` parameter

## Provider Preference Order

| Priority | Provider | Model | Voice | Output | Quality |
|----------|----------|-------|-------|--------|---------|
| 1 | Gemini TTS | `gemini-2.5-flash-preview-tts` | Aoede | WAV (24kHz) | Best, free tier |
| 2 | OpenAI TTS | `gpt-4o-mini-tts` | nova | MP3 | High, paid |
| 3 | ElevenLabs | `eleven_multilingual_v2` | Rachel | MP3 | Excellent, paid |

> **Note:** Gemini outputs `.wav` (PCM wrapped with WAV header), not `.mp3`. The script
> returns the actual file path — callers should use the echoed path, not assume `.mp3`.

## Usage

```bash
# Generate audio from text (auto-deletes after Discord upload)
~/.openclaw/skills/audio-summary/bin/generate_audio "Your summary text here" --cleanup

# With custom output path
~/.openclaw/skills/audio-summary/bin/generate_audio "Text" --output /tmp/custom.mp3

# Use specific provider
~/.openclaw/skills/audio-summary/bin/generate_audio "Text" --provider openai --cleanup
```

## Cleanup After Upload

**IMPORTANT:** Audio files are transient. Delete them immediately after uploading to Discord.

**Pattern:**
```bash
# Generate, upload, delete
AUDIO_FILE=$(~/.openclaw/skills/audio-summary/bin/generate_audio "text" --provider openai)
message --action send --channel discord --target <channel> --media "$AUDIO_FILE" --caption "🔊 Audio"
rm -f "$AUDIO_FILE"
```

**Why:** Audio files can build up quickly. A 30-second clip is ~400KB. Clean up after every upload.

**Incoming audio cleanup:** Discord voice messages in `~/.openclaw/media/inbound/` should also be cleaned periodically:
```bash
# Clean up audio older than 1 day
find ~/.openclaw/media/inbound -name "*.ogg" -mtime +1 -delete
```
```

## Script Output

Returns the path to the generated MP3 file:

```
/tmp/audio-summary-1738123456.mp3
```

## Discord Upload

After generating audio, upload to Discord:

```javascript
message({
  action: "send",
  channel: "discord",
  target: "<channel_id>",
  media: "/tmp/audio-summary-1738123456.mp3",
  caption: "🔊 Audio summary"
})
```

## Summary Style Guidelines

- **Conversational** — Not robotic, like talking to a friend
- **Brief** — 150 words max (30-60 seconds)
- **Friendly** — Warm tone
- **Actionable** — Highlight what was done and what's next

**Example:**
> "Hey! Just wrapped up the audio transcription skill. It uses Gemini to convert Discord voice messages to text in real time. Tested it on a few sample recordings — works like a charm. The multi-provider fallback is also wired up, so if Gemini is down, it'll automatically try OpenAI and then ElevenLabs. Everything's ready to go!"

## Configuration

Set provider preference in `TOOLS.md`:

```markdown
### Audio Summary
- Preferred provider: gemini
- Fallback: openai
- Voice: nova (openai), Zuben (gemini)
```

## Environment Variables

| Variable | Required For | Notes |
|----------|--------------|-------|
| `GEMINI_API_KEY` | Gemini TTS | Free tier available |
| `OPENAI_API_KEY` | OpenAI TTS | Paid, high quality |
| `ELEVENLABS_API_KEY` | ElevenLabs | Best quality, paid |

## Files

- `bin/generate_audio` — Main TTS script with multi-provider support
- `bin/providers/` — Provider-specific implementations
- `SKILL.md` — This documentation

## Troubleshooting

### "No TTS provider available"
- Check that at least one API key is set
- Verify keys are set in your environment or `~/.openclaw/secrets/` directory

### "Audio file too large for Discord"
- Keep summaries under 150 words
- Use `--provider openai` for MP3 (smaller than WAV)

### "Gemini TTS failed"
- Falls back to OpenAI automatically
- Check Gemini API status at https://status.cloud.google.com
- Requires `GEMINI_API_KEY` with Gemini 2.5 Flash access
