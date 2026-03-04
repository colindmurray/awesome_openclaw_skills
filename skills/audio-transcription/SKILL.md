---
name: audio-transcription
description: Transcribe voice messages and audio files using Gemini's multimodal API. Automatically handles OGG/Opus format, extracts text content, and provides actionable summaries.
metadata:
  openclaw:
    emoji: 🎙️
    requires:
      envVars:
        - GEMINI_API_KEY
---

# Audio Transcription Skill

Transcribes voice messages and audio files using Gemini's multimodal API.

## When to Use

- User sends a voice message (.ogg file)
- User asks to transcribe an audio file
- User wants to know what was said in a voice memo

## Quick Start

```bash
# Transcribe an audio file
~/.openclaw/skills/audio-transcription/bin/transcribe_audio /path/to/audio.ogg

# Get JSON output with metadata
~/.openclaw/skills/audio-transcription/bin/transcribe_audio --json /path/to/audio.ogg
```

## How It Works

1. **Receives audio file** (e.g., .ogg voice message)
2. **Converts to base64** inline
3. **Sends to Gemini 2.5 Flash** API
4. **Returns transcription** with optional summary

## Supported Formats

| Format | MIME Type | Notes |
|--------|-----------|-------|
| OGG/Opus | `audio/ogg` | Voice messages (Discord, Telegram, etc.) |
| MP3 | `audio/mpeg` | Standard audio |
| WAV | `audio/wav` | Uncompressed audio |
| FLAC | `audio/flac` | Lossless audio |
| M4A | `audio/mp4` | Apple audio format |
| WEBM | `audio/webm` | Web audio |

## Usage in Conversations

When you receive a voice message:

1. The audio file is saved to `~/.openclaw/media/inbound/`
2. Run the transcription script:
   ```bash
   ~/.openclaw/skills/audio-transcription/bin/transcribe_audio <path>
   ```
3. Parse the transcription and respond to the user's request
4. Take action on their behalf if requested

## Example

```bash
# Transcribe a voice message
TRANSCRIPT=$(~/.openclaw/skills/audio-transcription/bin/transcribe_audio \
  ~/.openclaw/media/inbound/abc123.ogg)

echo "User said: $TRANSCRIPT"
```

## Response Format

The script returns the raw transcription text. For structured output:

```bash
~/.openclaw/skills/audio-transcription/bin/transcribe_audio --json <path>
```

Returns:
```json
{
  "transcription": "...",
  "model": "gemini-2.5-flash",
  "tokenCount": 697
}
```

## API Details

- **Model**: `gemini-2.5-flash`
- **API**: Google Generative AI (generativelanguage.googleapis.com)
- **Auth**: API key from `GEMINI_API_KEY` environment variable
- **Limits**: See https://ai.google.dev/pricing

## Troubleshooting

### "API key not valid"
- Ensure `GEMINI_API_KEY` is set in your environment
- Check the key hasn't expired

### "Audio format not supported"
- Gemini supports OGG/Opus natively (common format for voice messages)
- For other formats, ensure the mime type is correct

### "Argument list too long" (exit 126)
- Fixed in current version: JSON is now built via temp files to avoid the 128KB kernel
  `MAX_ARG_STRLEN` per-argument limit. Should not occur for files under 20MB.

### "File too large"
- Gemini has a 20MB limit for inline audio
- For larger files, use the File Upload API first

## Files

- `bin/transcribe_audio` - Main transcription script
- `SKILL.md` - This documentation
