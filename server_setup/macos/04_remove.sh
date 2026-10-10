#!/usr/bin/env bash
# Completely remove the agent user — deletes the user account and home directory.
# WARNING: Irreversible. Use 03_deactivate.sh for temporary blocks.
# Run with sudo on the target Mac.
#
# Usage:
#   sudo ./04_remove.sh [--user NAME] [--home PATH]

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

if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: This script is for macOS only." >&2
  exit 1
fi

if ! dscl . -read "/Users/${AGENT_USER}" &>/dev/null; then
  echo "User ${AGENT_USER} does not exist — nothing to remove."
  exit 0
fi

echo "WARNING: This will permanently delete ${AGENT_USER} and their home directory."
echo "         Home: ${AGENT_HOME}"
read -r -p "Type 'yes' to confirm: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

echo "==> Removing user: ${AGENT_USER}"
dscl . -delete "/Users/${AGENT_USER}"
echo "    User account removed."

if [[ -d "$AGENT_HOME" ]]; then
  echo "==> Removing home directory: ${AGENT_HOME}"
  rm -rf "$AGENT_HOME"
  echo "    Home directory removed."
fi

echo ""
echo "Done. Also delete the local private key on your agent machine:"
echo "  rm ~/.ssh/id_agentuser ~/.ssh/id_agentuser.pub"
