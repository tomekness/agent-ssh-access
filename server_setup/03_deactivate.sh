#!/usr/bin/env bash
# Lock agentuser — blocks SSH login without deleting the user or keys.
# Run as root or with sudo.
# Reverse with: sudo ./02_activate.sh

set -euo pipefail

AGENT_USER="agentuser"

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: Run as root or with sudo." >&2
  exit 1
fi

if ! id "$AGENT_USER" &>/dev/null; then
  echo "ERROR: User $AGENT_USER does not exist." >&2
  exit 1
fi

usermod -L "$AGENT_USER"
echo "==> $AGENT_USER deactivated (account locked)."
echo "    Keys and home directory are preserved."
echo "    Reactivate with: sudo ./02_activate.sh"

passwd -S "$AGENT_USER" | awk '{print "    Status: " $2}'
