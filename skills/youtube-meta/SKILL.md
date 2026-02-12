---
name: youtube-meta
description: Extract YouTube video metadata, transcribe audio (Hindi/Hinglish), generate SEO content
homepage: https://github.com/yt-dlp/yt-dlp
metadata:
  {
    "openclaw":
      {
        "emoji": "🎬",
        "requires": { "bins": ["yt-dlp", "whisper", "ffmpeg"] },
      },
  }
---

# YouTube Metadata Extraction

Extract YouTube video metadata, transcribe audio (optimized for Hindi/Hinglish), and generate SEO-optimized content.

## Quick Start

### Basic Usage

Use the provided Python script for automated processing:

```bash
python3 /app/skills/youtube-meta/scripts/process.py <YOUTUBE_URL>
```

The script will:
1. Download audio from YouTube video
2. Extract video metadata (title, description, views, likes, duration)
3. Transcribe audio using Whisper (optimized for Hindi/Hinglish)
4. Output combined JSON with all data

### Output Format

The script outputs JSON to stdout with:
```json
{
  "url": "https://youtu.be/VIDEO_ID",
  "metadata": {
    "title": "Video Title",
    "description": "Video description...",
    "duration": 300,
    "views": 10000,
    "likes": 500,
    "upload_date": "20240115",
    "uploader": "Channel Name"
  },
  "transcript": {
    "text": "Full transcription text...",
    "language": "hi",
    "segments": [
      {
        "start": 0.0,
        "end": 5.5,
        "text": "Segment text..."
      }
    ]
  }
}
```

## Manual Commands (Advanced)

### Download Audio Only

```bash
yt-dlp -x --audio-format mp3 --audio-quality 0 \
  --output "/tmp/%(id)s.%(ext)s" \
  <YOUTUBE_URL>
```

### Extract Metadata

```bash
yt-dlp --dump-json --no-download <YOUTUBE_URL> | jq .
```

### Transcribe Audio with Whisper

For Hindi/Hinglish content:
```bash
whisper /tmp/audio.mp3 \
  --model medium \
  --language hi \
  --output_format json \
  --output_dir /tmp
```

**Model recommendations:**
- `base`: Fast, lower accuracy (~1GB RAM)
- `medium`: Balanced (recommended, ~5GB RAM)
- `large`: Highest accuracy (~10GB RAM)

## SEO Content Generation Workflow

After getting transcript data:

1. **Generate Title Variations**
   - Create 5 variations: clickbait, keyword-rich, question-based, numeric, emotional
   - Keep under 60 characters for SEO
   - Include main keywords from transcript

2. **Create Description**
   - First 2 lines (157 chars): Hook with main keywords
   - Add detailed summary from transcript
   - Include relevant hashtags
   - Add call-to-action

3. **Extract Chapters**
   - Identify topic changes in transcript
   - Create timestamps in format: `00:00 - Introduction`
   - Aim for 5-10 chapters per video

4. **Generate Tags**
   - Extract 15-20 relevant keywords from transcript
   - Mix broad and specific tags
   - Include Hindi and English variations

5. **Suggest Thumbnails**
   - Identify key moments from transcript
   - Suggest text overlays based on main points
   - Recommend emotion/expression for thumbnail

## Error Handling

**Private/Unavailable Videos:**
```
ERROR: Video unavailable
```
→ Inform user video is private/deleted

**Age-Restricted Videos:**
```
ERROR: Sign in to confirm your age
```
→ May require cookies/authentication (skip)

**Long Videos (>30 min):**
→ Transcription takes ~10 minutes, inform user of wait time

**Non-Hindi Audio:**
→ Suggest using `--language en` or other language codes

## Technical Notes

- Audio files downloaded to `/tmp/` (automatically cleaned up)
- Whisper models cached in `/tmp/.cache/whisper/` (persistent)
- First transcription downloads model (~1.5GB for medium)
- Processing time: ~2 minutes per 5 minutes of video
- Memory usage: ~4GB for medium model

## Environment Variables

- `HF_HOME`: Hugging Face cache directory (default: `/tmp/.cache/huggingface`)
- `WHISPER_CACHE_DIR`: Whisper models cache (default: `/tmp/.cache/whisper`)

## Examples

**Example 1: Short video (<5 min)**
```bash
python3 /app/skills/youtube-meta/scripts/process.py "https://youtu.be/dQw4w9WgXcQ"
```

**Example 2: Specify custom output**
```bash
python3 /app/skills/youtube-meta/scripts/process.py \
  "https://youtu.be/VIDEO_ID" \
  --output /tmp/result.json
```

After getting the JSON output, use AI to analyze the transcript and generate:
- Title variations
- SEO description
- Chapter timestamps
- Hashtags
- Thumbnail ideas
