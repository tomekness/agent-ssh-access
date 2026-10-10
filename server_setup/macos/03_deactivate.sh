#!/usr/bin/env bash
# Block SSH access for the agent user without removing the user or keys.
# Renames authorized_keys to authorized_keys.off — reversible with 02_activate.sh.
# Run with sudo on the target Mac.
#
# Usage:
#   sudo ./03_deactivate.sh [--user NAME] [--home PATH]

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

if [[ -f "$AUTH_OFF" ]]; then
  echo "==> Access already deactivated (authorized_keys.off exists)."
  exit 0
fi

if [[ ! -f "$AUTH_FILE" ]]; then
  echo "ERROR: ${AUTH_FILE} not found. Nothing to deactivate." >&2
  exit 1
fi

mv "$AUTH_FILE" "$AUTH_OFF"
echo "==> ${AGENT_USER} SSH access DEACTIVATED."
echo "    Keys and home directory preserved."
echo "    Reactivate with: sudo ./02_activate.sh --user ${AGENT_USER} --home ${AGENT_HOME}"
