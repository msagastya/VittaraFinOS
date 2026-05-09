#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export OPENCLAW_STATE_DIR="$ROOT_DIR/.openclaw/state"
export OPENCLAW_CONFIG_PATH="$ROOT_DIR/.openclaw/config.json"

exec openclaw "$@"
