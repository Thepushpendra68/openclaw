#!/bin/bash
set -e

echo "========================================="
echo "Configuring OpenClaw for Minimax M2.1"
echo "========================================="

# Debug: Check permissions and user
echo "Current user: $(whoami) (uid=$(id -u), gid=$(id -g))"
echo "Checking /data permissions..."
ls -ld /data 2>/dev/null || echo "/data does not exist"

# Configure persistent data directories
export OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
export OPENCLAW_WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspace}"

echo "State directory: $OPENCLAW_STATE_DIR"
echo "Workspace directory: $OPENCLAW_WORKSPACE_DIR"

# Create OpenClaw directories on persistent volume with error handling
echo "Creating directories..."

# Railway volumes sometimes mount with restricted permissions
# Try to create with explicit permissions
if [ -d "/data" ]; then
  echo "Detected /data volume, checking write access..."

  # Test write access with detailed diagnostics
  if touch /data/.write-test 2>/dev/null; then
    rm /data/.write-test
    echo "✓ /data is writable (files)"

    # Try creating directories - capture actual error
    ERROR_OUTPUT=$(mkdir -p "$OPENCLAW_STATE_DIR/agents/main/agent" 2>&1)
    if [ $? -eq 0 ]; then
      echo "✓ Created $OPENCLAW_STATE_DIR"
    else
      echo "⚠ mkdir failed: $ERROR_OUTPUT"

      # Try alternate approach: create parent first, then check permissions
      if mkdir -p /data/.openclaw 2>&1; then
        echo "✓ Created /data/.openclaw"
        # Fix permissions if needed
        chmod 755 /data/.openclaw 2>/dev/null || echo "Note: chmod failed (may not be needed)"

        # Try again with full path
        if mkdir -p "$OPENCLAW_STATE_DIR/agents/main/agent" 2>&1; then
          echo "✓ Created full directory structure"
        else
          echo "⚠ Still cannot create subdirectories"
          echo "⚠ Falling back to home directory"
          export OPENCLAW_STATE_DIR="$HOME/.openclaw"
          export OPENCLAW_WORKSPACE_DIR="$HOME/workspace"
        fi
      else
        echo "⚠ Cannot create /data/.openclaw"
        echo "⚠ Falling back to home directory"
        export OPENCLAW_STATE_DIR="$HOME/.openclaw"
        export OPENCLAW_WORKSPACE_DIR="$HOME/workspace"
      fi
    fi
  else
    echo "⚠ /data exists but is not writable by current user ($(whoami) uid=$(id -u))"
    echo "⚠ /data permissions: $(ls -ld /data)"
    echo "⚠ Falling back to home directory"
    export OPENCLAW_STATE_DIR="$HOME/.openclaw"
    export OPENCLAW_WORKSPACE_DIR="$HOME/workspace"
  fi
else
  echo "⚠ /data does not exist - volume not mounted"
  echo "⚠ Using home directory"
  export OPENCLAW_STATE_DIR="$HOME/.openclaw"
  export OPENCLAW_WORKSPACE_DIR="$HOME/workspace"
fi

# Ensure final directories exist
mkdir -p "$OPENCLAW_STATE_DIR/agents/main/agent"
echo "✓ Using storage: $OPENCLAW_STATE_DIR"

mkdir -p "$OPENCLAW_WORKSPACE_DIR" 2>/dev/null || echo "⚠ Could not create workspace dir"

# Create auth profile for Minimax
if [ -n "$MINIMAX_API_KEY" ]; then
  echo "Setting up Minimax auth profile..."
  cat > "$OPENCLAW_STATE_DIR/agents/main/agent/auth-profiles.json" << EOFAUTH
{
  "version": 1,
  "profiles": [
    {
      "id": "minimax-default",
      "provider": "minimax",
      "apiKey": "${MINIMAX_API_KEY}",
      "createdAt": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")"
    }
  ]
}
EOFAUTH
  echo "✓ Auth profile created"
else
  echo "⚠ MINIMAX_API_KEY not set!"
fi

# Create OpenClaw configuration only if it doesn't exist
if [ ! -f "$OPENCLAW_STATE_DIR/openclaw.json" ]; then
  echo "Creating initial OpenClaw config..."
  cat > "$OPENCLAW_STATE_DIR/openclaw.json" << 'EOFCONFIG'
{
  "models": {
    "mode": "merge",
    "providers": {
      "minimax": {
        "baseUrl": "https://api.minimax.io/anthropic",
        "api": "anthropic-messages",
        "models": [
          {
            "id": "MiniMax-M2.1",
            "name": "MiniMax M2.1",
            "contextWindow": 200000,
            "maxTokens": 8192,
            "reasoning": false,
            "cost": {
              "input": 15,
              "output": 60,
              "cacheRead": 2,
              "cacheWrite": 10
            }
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "minimax/MiniMax-M2.1"
      },
      "models": {
        "minimax/MiniMax-M2.1": {
          "alias": "Minimax"
        }
      }
    }
  },
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "token"
    },
    "trustedProxies": ["*"],
    "controlUi": {
      "dangerouslyDisableDeviceAuth": true
    }
  },
  "channels": {
    "telegram": {
      "dmPolicy": "allowlist",
      "allowFrom": ["669367400"]
    }
  }
}
EOFCONFIG
  echo "✓ Config created"
else
  echo "✓ Config already exists, preserving existing configuration"
fi

# Verify Python dependencies
echo "========================================="
echo "Checking Python dependencies..."
echo "========================================="
which python3 && echo "✓ python3 found" || echo "⚠ python3 not found"
which yt-dlp && echo "✓ yt-dlp found" || echo "⚠ yt-dlp not found"
which whisper && echo "✓ whisper found" || echo "⚠ whisper not found"
which ffmpeg && echo "✓ ffmpeg found" || echo "⚠ ffmpeg not found"

# Pre-download Whisper model
if command -v whisper &> /dev/null; then
  echo "Pre-downloading Whisper medium model..."
  export HF_HOME="/tmp/.cache/huggingface"
  python3 -c "import whisper; whisper.load_model('medium')" 2>&1 | grep -q "100%" && echo "✓ Model downloaded" || echo "Model download deferred to first use"
fi

echo "========================================="
echo "Starting OpenClaw Gateway..."
echo "========================================="

# Start OpenClaw Gateway
exec node openclaw.mjs gateway --allow-unconfigured --bind lan --port ${PORT:-3000} --verbose
