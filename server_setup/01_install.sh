#!/usr/bin/env bash
# Install agentuser user on this server.
# Run as root or with sudo.
#
# Usage:
#   sudo ./01_install.sh --key "ssh-ed25519 AAAA..." [--from IP] [--sudo]
#   cat ~/.ssh/id_agentuser.pub | sudo ./01_install.sh [--from IP] [--sudo]
#
# Options:
#   --key "..."   Public key string (or pipe it via stdin)
#   --from IP     Restrict key to this IP only (recommended)
#   --sudo        Grant passwordless sudo to agentuser

set -euo pipefail

AGENT_USER="agentuser"
PUBKEY=""
FROM_IP=""
GRANT_SUDO=0

usage() {
  cat <<EOF
Usage: $0 --key "ssh-ed25519 AAAA..." [--from IP] [--sudo]
       cat id_agentuser.pub | $0 [--from IP] [--sudo]

  --key "..."   Public key string
  --from IP     Restrict key to source IP (security: key only works from that IP)
  --sudo        Grant passwordless sudo (use with care)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key)   PUBKEY="$2";   shift 2 ;;
    --from)  FROM_IP="$2";  shift 2 ;;
    --sudo)  GRANT_SUDO=1;  shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Accept key from stdin if not passed as argument
if [[ -z "$PUBKEY" ]] && ! [ -t 0 ]; then
  PUBKEY=$(cat)
fi

if [[ -z "$PUBKEY" ]]; then
  echo "ERROR: No public key provided. Use --key or pipe it via stdin." >&2
  usage; exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: Run as root or with sudo." >&2
  exit 1
fi

echo "==> Creating user: $AGENT_USER"
if id "$AGENT_USER" &>/dev/null; then
  echo "    User already exists — skipping useradd"
else
  useradd -m -s /bin/bash "$AGENT_USER"
  echo "    User created."
fi

echo "==> Setting up .ssh directory"
SSH_DIR="/home/${AGENT_USER}/.ssh"
AUTH_FILE="${SSH_DIR}/authorized_keys"
mkdir -p "$SSH_DIR"
touch "$AUTH_FILE"
chown -R "${AGENT_USER}:${AGENT_USER}" "$SSH_DIR"
chmod 700 "$SSH_DIR"
chmod 600 "$AUTH_FILE"

echo "==> Installing public key"
if [[ -n "$FROM_IP" ]]; then
  KEY_ENTRY="from=\"${FROM_IP}\" ${PUBKEY}"
  echo "    IP restriction: only connections from ${FROM_IP} accepted"
else
  KEY_ENTRY="$PUBKEY"
  echo "    No IP restriction — key works from any host"
fi

# Avoid duplicate entries
if grep -qF "$PUBKEY" "$AUTH_FILE" 2>/dev/null; then
  echo "    Key already present in authorized_keys — skipping"
else
  echo "$KEY_ENTRY" >> "$AUTH_FILE"
  echo "    Key added."
fi

if [[ "$GRANT_SUDO" -eq 1 ]]; then
  echo "==> Granting passwordless sudo"
  SUDOERS_FILE="/etc/sudoers.d/${AGENT_USER}"
  echo "${AGENT_USER} ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
  chmod 440 "$SUDOERS_FILE"
  visudo -c -f "$SUDOERS_FILE" && echo "    sudoers entry OK." || {
    rm -f "$SUDOERS_FILE"
    echo "ERROR: sudoers syntax check failed — entry removed." >&2
    exit 1
  }
fi

echo ""
echo "Done. Test from your agent machine:"
echo "  ssh -i ~/.ssh/id_agentuser ${AGENT_USER}@$(hostname -I | awk '{print $1}') 'whoami'"
