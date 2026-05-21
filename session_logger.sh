#!/usr/bin/env bash
set -euo pipefail
# Usage: session_logger.sh <level> <message>
# Levels: plan, confirmed, cmd, info

LOGFILE="$(dirname "$0")/session.log"
mkdir -p "$(dirname "$LOGFILE")"

[[ $# -lt 2 ]] && { echo "Usage: $0 <level> <message>" >&2; exit 1; }

LEVEL="$1"; shift
MSG="$*"
printf '%s | %s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${LEVEL^^}" "${MSG}" >> "$LOGFILE"
