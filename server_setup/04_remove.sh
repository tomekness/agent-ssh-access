#!/usr/bin/env bash
# Completely remove agentuser — deletes user, home directory, and sudoers entry.
# Run as root or with sudo.
# WARNING: This is irreversible. Keys are gone. Use 03_deactivate.sh for temporary blocks.

set -euo pipefail

AGENT_USER="agentuser"

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: Run as root or with sudo." >&2
  exit 1
fi

if ! id "$AGENT_USER" &>/dev/null; then
  echo "User $AGENT_USER does not exist — nothing to remove."
  exit 0
fi

echo "WARNING: This will permanently delete $AGENT_USER, their home directory, and all keys."
read -r -p "Type 'yes' to confirm: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

echo "==> Removing sudoers entry (if any)"
SUDOERS_FILE="/etc/sudoers.d/${AGENT_USER}"
if [[ -f "$SUDOERS_FILE" ]]; then
  rm -f "$SUDOERS_FILE"
  echo "    Removed $SUDOERS_FILE"
fi

echo "==> Deleting user and home directory"
userdel -r "$AGENT_USER" 2>/dev/null || userdel "$AGENT_USER"
echo "    $AGENT_USER removed."

echo ""
echo "Done. Remember to also delete the local private key on your agent machine:"
echo "  rm ~/.ssh/id_agentuser ~/.ssh/id_agentuser.pub"
