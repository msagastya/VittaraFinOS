#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

PROMPT='Audit only the VittaraFinOS dashboard entry flow. Read at most 6 files. Do not run flutter analyze/test/build. Find the top 5 UX/code risks with P0/P1/P2 severity, evidence, and fixes.'

./openclaw-local.sh agent \
  --local \
  --agent vittara-auditor \
  --session-id vittara-dashboard-mini-audit \
  --message "$PROMPT" \
  --thinking low \
  --timeout 900 \
  --json | tee OPENCLAW_AUDIT_RESULT.json
