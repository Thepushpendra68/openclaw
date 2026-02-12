#!/bin/bash
set -e

echo "========================================="
echo "Configuring OpenClaw for Minimax M2.1"
echo "========================================="

# Create OpenClaw directories
mkdir -p ~/.openclaw/agents/main/agent

# Create auth profile for Minimax
if [ -n "$MINIMAX_API_KEY" ]; then
  echo "Setting up Minimax auth profile..."
  cat > ~/.openclaw/agents/main/agent/auth-profiles.json << EOFAUTH
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

# Create OpenClaw configuration
echo "Creating OpenClaw config..."
cat > ~/.openclaw/openclaw.json << 'EOFCONFIG'
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
echo "========================================="
echo "Starting OpenClaw Gateway..."
echo "========================================="

# Start OpenClaw Gateway
exec node openclaw.mjs gateway --allow-unconfigured --bind lan --port ${PORT:-3000} --verbose
