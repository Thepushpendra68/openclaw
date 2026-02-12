#!/usr/bin/env python3
"""
YouTube Metadata Extraction and Transcription Script

Downloads audio from YouTube, extracts metadata, and transcribes using Whisper.
Optimized for Hindi/Hinglish content.
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


def run_command(cmd, capture_output=True):
    """Run shell command and return output"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=capture_output,
            text=True,
            check=True
        )
        return result.stdout.strip() if capture_output else None
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {cmd}", file=sys.stderr)
        print(f"Error: {e.stderr}", file=sys.stderr)
        raise


def extract_metadata(url):
    """Extract video metadata using yt-dlp"""
    print("Extracting video metadata...", file=sys.stderr)

    cmd = f'yt-dlp --dump-json --no-download "{url}"'
    json_output = run_command(cmd)

    data = json.loads(json_output)

    # Extract relevant fields
    metadata = {
        "id": data.get("id"),
        "title": data.get("title"),
        "description": data.get("description"),
        "duration": data.get("duration"),
        "views": data.get("view_count"),
        "likes": data.get("like_count"),
        "upload_date": data.get("upload_date"),
        "uploader": data.get("uploader"),
        "uploader_id": data.get("uploader_id"),
        "channel_url": data.get("channel_url"),
        "thumbnail": data.get("thumbnail"),
        "tags": data.get("tags", []),
        "categories": data.get("categories", []),
    }

    print(f"✓ Metadata extracted: {metadata['title']}", file=sys.stderr)
    return metadata


def download_audio(url, output_dir):
    """Download audio from YouTube video"""
    print("Downloading audio...", file=sys.stderr)

    output_template = os.path.join(output_dir, "%(id)s.%(ext)s")
    cmd = f'yt-dlp -x --audio-format mp3 --audio-quality 0 --output "{output_template}" "{url}"'

    run_command(cmd, capture_output=False)

    # Find downloaded file
    mp3_files = list(Path(output_dir).glob("*.mp3"))
    if not mp3_files:
        raise FileNotFoundError("Downloaded audio file not found")

    audio_path = str(mp3_files[0])
    print(f"✓ Audio downloaded: {audio_path}", file=sys.stderr)
    return audio_path


def transcribe_audio(audio_path, model="medium", language="hi"):
    """Transcribe audio using Whisper"""
    print(f"Transcribing audio (model: {model}, language: {language})...", file=sys.stderr)

    output_dir = os.path.dirname(audio_path)
    cmd = f'whisper "{audio_path}" --model {model} --language {language} --output_format json --output_dir "{output_dir}"'

    run_command(cmd, capture_output=False)

    # Find JSON output
    base_name = Path(audio_path).stem
    json_path = os.path.join(output_dir, f"{base_name}.json")

    if not os.path.exists(json_path):
        raise FileNotFoundError(f"Transcription output not found: {json_path}")

    with open(json_path, 'r', encoding='utf-8') as f:
        whisper_output = json.load(f)

    # Extract transcript data
    transcript = {
        "text": whisper_output.get("text", ""),
        "language": whisper_output.get("language", language),
        "segments": [
            {
                "start": seg.get("start"),
                "end": seg.get("end"),
                "text": seg.get("text", "").strip()
            }
            for seg in whisper_output.get("segments", [])
        ]
    }

    print(f"✓ Transcription complete ({len(transcript['segments'])} segments)", file=sys.stderr)
    return transcript


def main():
    parser = argparse.ArgumentParser(
        description="Extract YouTube metadata and transcribe audio"
    )
    parser.add_argument("url", help="YouTube video URL")
    parser.add_argument(
        "--output",
        "-o",
        help="Output JSON file path (default: stdout)"
    )
    parser.add_argument(
        "--model",
        default="medium",
        choices=["tiny", "base", "small", "medium", "large"],
        help="Whisper model size (default: medium)"
    )
    parser.add_argument(
        "--language",
        default="hi",
        help="Audio language code (default: hi for Hindi)"
    )
    parser.add_argument(
        "--keep-audio",
        action="store_true",
        help="Keep downloaded audio file"
    )

    args = parser.parse_args()

    # Create temporary directory for processing
    with tempfile.TemporaryDirectory() as temp_dir:
        try:
            # Step 1: Extract metadata
            metadata = extract_metadata(args.url)

            # Step 2: Download audio
            audio_path = download_audio(args.url, temp_dir)

            # Step 3: Transcribe audio
            transcript = transcribe_audio(audio_path, args.model, args.language)

            # Step 4: Combine results
            result = {
                "url": args.url,
                "metadata": metadata,
                "transcript": transcript,
                "processing": {
                    "whisper_model": args.model,
                    "detected_language": transcript["language"]
                }
            }

            # Output results
            if args.output:
                with open(args.output, 'w', encoding='utf-8') as f:
                    json.dump(result, f, indent=2, ensure_ascii=False)
                print(f"\n✓ Results saved to: {args.output}", file=sys.stderr)
            else:
                print(json.dumps(result, indent=2, ensure_ascii=False))

            # Cleanup
            if args.keep_audio:
                kept_path = f"/tmp/{os.path.basename(audio_path)}"
                os.rename(audio_path, kept_path)
                print(f"Audio kept at: {kept_path}", file=sys.stderr)

            print("\n✓ Processing complete!", file=sys.stderr)

        except Exception as e:
            print(f"\n✗ Error: {e}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
