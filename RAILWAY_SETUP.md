# OpenClaw Railway Deployment Guide

## Data Persistence Setup

OpenClaw is a **file-based system** that stores all data in JSON/JSONL files. It does NOT require a traditional database (PostgreSQL, MongoDB, etc.).

### What Gets Stored

All data is stored in the `OPENCLAW_STATE_DIR` directory (default: `/data/.openclaw`):

- **Configuration**: `openclaw.json` (gateway settings, model config, channels)
- **Auth Profiles**: `agents/main/agent/auth-profiles.json` (API keys, OAuth tokens)
- **Conversations**: `agents/main/sessions/*.jsonl` (conversation history)
- **Session Metadata**: `agents/main/sessions.json` (active session registry)
- **Memory**: `agents/main/memory/` (optional vector database)
- **Channel State**: Various JSON files for Telegram, Discord, etc.

## Step-by-Step Railway Setup

### 1. Provision a Railway Volume

1. Go to your Railway project dashboard
2. Click on your OpenClaw service
3. Navigate to the **"Settings"** tab
4. Scroll to **"Volumes"** section
5. Click **"New Volume"**
6. Configure:
   - **Mount Path**: `/data`
   - **Size**: Start with 1GB (can increase later based on usage)
7. Click **"Add"**

### 2. Configure Environment Variables

In your Railway project settings, add these environment variables:

#### Required Variables

```bash
# Persistent storage paths (points to the volume)
OPENCLAW_STATE_DIR=/data/.openclaw
OPENCLAW_WORKSPACE_DIR=/data/workspace

# Server configuration
PORT=8080

# Setup password for initial configuration
SETUP_PASSWORD=your-secure-password-here

# LLM Provider API Key
MINIMAX_API_KEY=your-minimax-api-key-here

# Telegram Bot (if using Telegram channel)
TELEGRAM_BOT_TOKEN=your-telegram-bot-token-here
```

#### Optional Variables

```bash
# Gateway authentication token for API access
OPENCLAW_GATEWAY_TOKEN=your-secret-token-here

# Session cache TTL (milliseconds)
OPENCLAW_SESSION_CACHE_TTL_MS=45000
```

### 3. Deploy

1. Push your code to GitHub (if not already done)
2. Railway will automatically detect changes and redeploy
3. Check deployment logs to verify:
   ```
   State directory: /data/.openclaw
   Workspace directory: /data/workspace
   ✓ Config created (or) ✓ Config already exists
   ```

### 4. Verify Persistence

After deployment:

1. **Start a conversation** with your Telegram bot or via API
2. **Send a few test messages**
3. **Trigger a redeploy** (push a small change or manual redeploy)
4. **Resume the conversation** - history should be intact

### 5. Access Your Data

If you need to access stored data:

1. Use Railway's CLI to connect to your service:
   ```bash
   railway connect
   railway run bash
   ```

2. Navigate to the data directory:
   ```bash
   ls -la /data/.openclaw
   ls -la /data/.openclaw/agents/main/sessions
   ```

## What the Updated Script Does

The `railway-start.sh` script now:

1. **Sets environment variables** with defaults pointing to the volume:
   ```bash
   export OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
   export OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspace}"
   ```

2. **Creates directories** on the persistent volume:
   ```bash
   mkdir -p "$OPENCLAW_STATE_DIR/agents/main/agent"
   mkdir -p "$OPENCLAW_WORKSPACE_DIR"
   ```

3. **Preserves existing configuration** - only creates `openclaw.json` if it doesn't exist:
   ```bash
   if [ ! -f "$OPENCLAW_STATE_DIR/openclaw.json" ]; then
     # Create config
   else
     echo "✓ Config already exists, preserving existing configuration"
   fi
   ```

## Migration from Existing Deployment

If you have an existing deployment with important conversation history:

### Option A: Fresh Start (Recommended)
- Just add the volume and environment variables
- All new conversations will be persisted
- Old data will be lost on next redeploy

### Option B: Migrate Existing Data
If you need to preserve existing conversations:

1. **Export data from current deployment**:
   ```bash
   railway run bash
   tar -czf openclaw-backup.tar.gz ~/.openclaw
   # Download the tar file
   ```

2. **After adding volume, import data**:
   ```bash
   railway run bash
   cd /data
   tar -xzf openclaw-backup.tar.gz
   mv .openclaw /data/
   ```

## Troubleshooting

### Configuration keeps resetting
- Verify `OPENCLAW_STATE_DIR` is set in Railway environment variables
- Check logs to ensure the script detects existing config
- Verify the volume is mounted at `/data`

### Conversations not persisting
- Check Railway volume is properly mounted
- Verify environment variables are set correctly
- Look for errors in deployment logs
- Ensure `/data` has write permissions

### Storage running out
- Increase Railway volume size in project settings
- Monitor conversation history growth
- Consider periodic cleanup of old sessions

## Expected File Structure

After successful deployment, your volume should contain:

```
/data/
├── .openclaw/
│   ├── openclaw.json
│   └── agents/
│       └── main/
│           ├── agent/
│           │   └── auth-profiles.json
│           ├── sessions.json
│           └── sessions/
│               ├── session-id-1.jsonl
│               ├── session-id-2.jsonl
│               └── ...
└── workspace/
    └── (temporary files from agent operations)
```

## Cost Considerations

- **Volume Storage**: Railway charges for persistent volume storage
- **Size Recommendation**:
  - Start with 1GB
  - Monitor usage and scale up as needed
  - Conversation history grows over time
  - Vector memory (if enabled) can use significant space

## Summary

✅ **You DO need**: Railway Volume for persistent file storage
❌ **You DON'T need**: PostgreSQL, MongoDB, Redis, or any external database

All OpenClaw data is file-based and will persist across redeploys once the volume is configured.
