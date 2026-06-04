#!/usr/bin/env bash
# Unlock agentuser — re-enables SSH login after deactivation.
# Run as root or with sudo.

set -euo pipefail

AGENT_USER="agentuser"

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: Run as root or with sudo." >&2
  exit 1
fi

if ! id "$AGENT_USER" &>/dev/null; then
  echo "ERROR: User $AGENT_USER does not exist. Run 01_install.sh first." >&2
  exit 1
fi

usermod -U "$AGENT_USER"
echo "==> $AGENT_USER activated (account unlocked)."

# Show current status
passwd -S "$AGENT_USER" | awk '{print "    Status: " $2}'
