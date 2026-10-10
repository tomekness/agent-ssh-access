#!/usr/bin/env bash
# Install agent user on macOS.
# Run with sudo on the target Mac.
#
# Usage:
#   sudo ./01_install.sh --key "ssh-ed25519 AAAA..." [--user USERNAME] [--home PATH]
#   cat ~/.ssh/id_agentuser.pub | sudo ./01_install.sh [--user USERNAME] [--home PATH]
#
# Options:
#   --key "..."      Public key string (or pipe via stdin)
#   --user NAME      Agent username (default: agentuser)
#   --home PATH      Home directory path (default: /Users/agentuser)
#                    Use a non-standard path (e.g. /Volumes/DataDisk/agent-home)
#                    to keep the agent home off the system volume.
#
# Requirements: macOS 12+, bash 3.2+, run as root

set -euo pipefail

AGENT_USER="agentuser"
AGENT_HOME=""
PUBKEY=""

usage() {
  cat <<EOF
Usage: $0 --key "ssh-ed25519 AAAA..." [--user NAME] [--home PATH]
       cat id_agentuser.pub | $0 [--user NAME] [--home PATH]

  --key "..."   Public key string
  --user NAME   Agent username (default: agentuser)
  --home PATH   Home directory (default: /Users/<user>)
                Set to a non-system volume to isolate the agent home.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key)  PUBKEY="$2";     shift 2 ;;
    --user) AGENT_USER="$2"; shift 2 ;;
    --home) AGENT_HOME="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Accept key from stdin
if [[ -z "$PUBKEY" ]] && ! [ -t 0 ]; then
  PUBKEY=$(cat)
fi

if [[ -z "$PUBKEY" ]]; then
  echo "ERROR: No public key provided. Use --key or pipe via stdin." >&2
  usage; exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: Run with sudo." >&2
  exit 1
fi

if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: This script is for macOS only. Use server_setup/ for Linux." >&2
  exit 1
fi

[[ -z "$AGENT_HOME" ]] && AGENT_HOME="/Users/${AGENT_USER}"

echo "==> Configuration"
echo "    User:  $AGENT_USER"
echo "    Home:  $AGENT_HOME"

# --- Create home directory ---
echo "==> Creating home directory at $AGENT_HOME"
mkdir -p "$AGENT_HOME"

# --- Create user ---
echo "==> Creating user: $AGENT_USER"
if dscl . -read "/Users/${AGENT_USER}" &>/dev/null; then
  echo "    User already exists — skipping"
else
  # Find a free UID (500–599 range, avoid conflicts)
  NEXT_UID=510
  while dscl . -list /Users UniqueID | awk '{print $2}' | grep -qx "$NEXT_UID"; do
    NEXT_UID=$((NEXT_UID + 1))
  done

  dscl . -create "/Users/${AGENT_USER}"
  dscl . -create "/Users/${AGENT_USER}" UserShell /bin/bash
  dscl . -create "/Users/${AGENT_USER}" RealName "Agent User"
  dscl . -create "/Users/${AGENT_USER}" UniqueID "$NEXT_UID"
  dscl . -create "/Users/${AGENT_USER}" PrimaryGroupID 20
  dscl . -create "/Users/${AGENT_USER}" NFSHomeDirectory "$AGENT_HOME"
  dscl . -create "/Users/${AGENT_USER}" Password "*"
  echo "    User created (UID $NEXT_UID)."
fi

# --- Set home ownership ---
chown -R "${AGENT_USER}:staff" "$AGENT_HOME"
chmod 700 "$AGENT_HOME"

# --- SSH authorized_keys ---
echo "==> Installing public key"
SSH_DIR="${AGENT_HOME}/.ssh"
AUTH_FILE="${SSH_DIR}/authorized_keys"

mkdir -p "$SSH_DIR"
touch "$AUTH_FILE"
chown -R "${AGENT_USER}:staff" "$SSH_DIR"
chmod 700 "$SSH_DIR"
chmod 600 "$AUTH_FILE"

if grep -qF "$PUBKEY" "$AUTH_FILE" 2>/dev/null; then
  echo "    Key already present — skipping"
else
  echo "$PUBKEY" >> "$AUTH_FILE"
  echo "    Key added."
fi

# --- Enable SSH (Remote Login) ---
echo "==> Checking Remote Login (SSH)"
if systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
  echo "    Remote Login already enabled."
else
  systemsetup -setremotelogin on 2>/dev/null && echo "    Remote Login enabled." \
    || echo "    WARNING: Could not enable Remote Login automatically."
  echo "    If it failed: System Settings → General → Sharing → Remote Login → ON"
fi

echo ""
echo "Done. Test from your agent machine:"
echo "  ssh -i ~/.ssh/id_agentuser -p 22 ${AGENT_USER}@<this-mac-ip> 'whoami'"
echo ""
echo "To deactivate access:  sudo ./03_deactivate.sh --user ${AGENT_USER} --home ${AGENT_HOME}"
echo "To remove completely:  sudo ./04_remove.sh --user ${AGENT_USER} --home ${AGENT_HOME}"
