#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --host HOST [--port PORT] [--user USER] [--key PATH] [--mountroot DIR] [--allow-other]

Mounts a remote host via SSHFS into <mountroot>/<host>.

Options:
  --host        Remote hostname (required)
  --port        SSH port (default: 22)
  --user        Remote user (default: agentuser)
  --key         Local private key path (default: ~/.ssh/id_agentuser)
  --mountroot   Local mount root (default: <script-dir>/mounts)
  --allow-other Enable FUSE allow_other (requires user_allow_other in /etc/fuse.conf)
EOF
}

PORT=22
USER=agentuser
KEY="$HOME/.ssh/id_agentuser"
MOUNTROOT="$(dirname "$0")/mounts"
ALLOW_OTHER=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)       HOST="$2";       shift 2 ;;
    --port)       PORT="$2";       shift 2 ;;
    --user)       USER="$2";       shift 2 ;;
    --key)        KEY="$2";        shift 2 ;;
    --mountroot)  MOUNTROOT="$2";  shift 2 ;;
    --allow-other) ALLOW_OTHER=1;  shift 1 ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

[[ -z "${HOST:-}" ]] && { echo "Missing --host"; usage; exit 1; }

MOUNTPOINT="$MOUNTROOT/$HOST"
mkdir -p "$MOUNTPOINT"

LOGGER="$(dirname "$0")/session_logger.sh"
[[ -x "$LOGGER" ]] && "$LOGGER" plan "mount_sshfs --host ${HOST} --port ${PORT} --user ${USER} --allow_other=${ALLOW_OTHER}" || true

if [[ "$ALLOW_OTHER" -eq 1 ]]; then
  if ! grep -qE '^\s*user_allow_other\s*$' /etc/fuse.conf 2>/dev/null; then
    echo "ERROR: /etc/fuse.conf does not have 'user_allow_other' set."
    echo "Run once to enable: sudo sed -i 's/^#user_allow_other/user_allow_other/' /etc/fuse.conf"
    echo "Or omit --allow-other to mount for the current user only."
    exit 1
  fi
fi

SSHFS_OPTS=(
  -o IdentityFile="$KEY"
  -o port=$PORT
  -o reconnect
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=3
  -o uid=$(id -u)
  -o gid=$(id -g)
)
[[ "$ALLOW_OTHER" -eq 1 ]] && SSHFS_OPTS+=( -o allow_other )

SSHFS_CMD=(sshfs "${SSHFS_OPTS[@]}" "${USER}@${HOST}:/" "$MOUNTPOINT")

if [[ -n "${AGENT_SESSION:-}" ]]; then
  echo "Mounting $USER@${HOST} (port $PORT) to $MOUNTPOINT"
  echo "Awaiting 'go' approval..."
  read -r APPROVAL
  if [[ "$APPROVAL" != "go" ]]; then
    echo "Approval not received. Aborting." >&2
    exit 2
  fi
fi

echo "Mounting $USER@${HOST} (port $PORT) to $MOUNTPOINT"
[[ "$ALLOW_OTHER" -ne 1 ]] && echo "Note: mounting without allow_other (current user only)."

"${SSHFS_CMD[@]}"

[[ -x "$LOGGER" ]] && "$LOGGER" cmd "${SSHFS_CMD[*]}" || true
echo "Mounted at $MOUNTPOINT"
