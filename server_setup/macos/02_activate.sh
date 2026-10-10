#!/usr/bin/env bash
# Re-enable SSH access for the agent user (after deactivation).
# Restores authorized_keys from authorized_keys.off.
# Run with sudo on the target Mac.
#
# Usage:
#   sudo ./02_activate.sh [--user NAME] [--home PATH]

set -euo pipefail

AGENT_USER="agentuser"
AGENT_HOME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) AGENT_USER="$2"; shift 2 ;;
    --home) AGENT_HOME="$2"; shift 2 ;;
    -h|--help) echo "Usage: $0 [--user NAME] [--home PATH]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

[[ -z "$AGENT_HOME" ]] && AGENT_HOME="/Users/${AGENT_USER}"

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: Run with sudo." >&2
  exit 1
fi

AUTH_FILE="${AGENT_HOME}/.ssh/authorized_keys"
AUTH_OFF="${AUTH_FILE}.off"

if [[ -f "$AUTH_FILE" ]]; then
  echo "==> Access already active (authorized_keys exists)."
  exit 0
fi

if [[ ! -f "$AUTH_OFF" ]]; then
  echo "ERROR: ${AUTH_OFF} not found. Run 01_install.sh first." >&2
  exit 1
fi

mv "$AUTH_OFF" "$AUTH_FILE"
chmod 600 "$AUTH_FILE"
echo "==> ${AGENT_USER} SSH access ACTIVATED."
