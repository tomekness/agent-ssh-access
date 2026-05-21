#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --host HOST [--port PORT] [--remote-user USER] [--keyname NAME] [--fingerprint FPR] [--force-remove-all]

Removes agentuser's SSH key from the remote and optionally the sudoers entry.

Options:
  --host              Remote hostname (required)
  --port              SSH port (default: 22)
  --remote-user       Admin user for the SSH connection (default: agentuser)
  --keyname           Remove key matching this comment/pattern
  --fingerprint       Remove key matching this fingerprint
  --force-remove-all  Remove all ed25519/rsa keys and the sudoers entry
EOF
}

PORT=22
REMOTE_USER=agentuser
KEYNAME=""
FINGERPRINT=""
FORCE_REMOVE_ALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)             HOST="$2";        shift 2 ;;
    --port)             PORT="$2";        shift 2 ;;
    --remote-user)      REMOTE_USER="$2"; shift 2 ;;
    --keyname)          KEYNAME="$2";     shift 2 ;;
    --fingerprint)      FINGERPRINT="$2"; shift 2 ;;
    --force-remove-all) FORCE_REMOVE_ALL=1; shift 1 ;;
    -h|--help)          usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

[[ -z "${HOST:-}" ]] && { echo "Missing --host"; usage; exit 1; }

LOGGER="$(dirname "$0")/session_logger.sh"
[[ -x "$LOGGER" ]] && "$LOGGER" plan "revoke_access --host ${HOST} --port ${PORT}" || true

if [[ -n "${AGENT_SESSION:-}" ]]; then
  echo "Revoking access on ${HOST}. Awaiting 'go' approval..."
  read -r APPROVAL
  if [[ "$APPROVAL" != "go" ]]; then
    echo "Approval not received. Aborting." >&2
    exit 2
  fi
  [[ -x "$LOGGER" ]] && "$LOGGER" confirmed "agent" || true
fi

echo "Revoking access on ${HOST} (port $PORT) via ${REMOTE_USER}"

AUTHFILE=/home/agentuser/.ssh/authorized_keys

if [[ "$FORCE_REMOVE_ALL" -eq 1 ]]; then
  ssh -p "$PORT" "${REMOTE_USER}@${HOST}" sudo bash -eux <<REMOTE
if [[ -f ${AUTHFILE} ]]; then
  sed -i '/ssh-ed25519/d' ${AUTHFILE} || true
  sed -i '/ssh-rsa/d'     ${AUTHFILE} || true
fi
[[ -f /etc/sudoers.d/agentuser ]] && rm -f /etc/sudoers.d/agentuser || true
REMOTE
elif [[ -n "$FINGERPRINT" ]]; then
  ssh -p "$PORT" "${REMOTE_USER}@${HOST}" sudo bash -s "$FINGERPRINT" <<'REMOTE'
FPR="$1"
AUTHFILE=/home/agentuser/.ssh/authorized_keys
TMP=$(mktemp)
while IFS= read -r line; do
  printf '%s\n' "$line" > /tmp/_line.pub
  FP=$(ssh-keygen -lf /tmp/_line.pub 2>/dev/null | awk '{print $2}') || FP=""
  [[ "$FP" == "$FPR" ]] || printf '%s\n' "$line" >> "$TMP"
done < "$AUTHFILE"
mv "$TMP" "$AUTHFILE"
chown agentuser:agentuser "$AUTHFILE"
chmod 600 "$AUTHFILE"
[[ -f /etc/sudoers.d/agentuser ]] && rm -f /etc/sudoers.d/agentuser || true
REMOTE
elif [[ -n "$KEYNAME" ]]; then
  ssh -p "$PORT" "${REMOTE_USER}@${HOST}" sudo bash -s "$KEYNAME" <<'REMOTE'
PATTERN="$1"
AUTHFILE=/home/agentuser/.ssh/authorized_keys
TMP=$(mktemp)
grep -v "$PATTERN" "$AUTHFILE" > "$TMP" || true
mv "$TMP" "$AUTHFILE"
chown agentuser:agentuser "$AUTHFILE"
chmod 600 "$AUTHFILE"
[[ -f /etc/sudoers.d/agentuser ]] && rm -f /etc/sudoers.d/agentuser || true
REMOTE
else
  echo "No --keyname, --fingerprint, or --force-remove-all given. Nothing removed." >&2
  echo "Use --force-remove-all to remove all keys and the sudoers entry." >&2
  exit 1
fi

[[ -x "$LOGGER" ]] && "$LOGGER" cmd "revoke_access --host ${HOST} --port ${PORT} --force-remove-all=${FORCE_REMOVE_ALL}" || true
echo "Done. To delete the user entirely: sudo deluser --remove-home agentuser"
