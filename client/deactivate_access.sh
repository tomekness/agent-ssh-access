#!/usr/bin/env bash
# Remotely deactivate agentuser by setting shell to nologin.
# Blocks SSH key login without removing the user or keys.
# Reverse with: activate_access.sh
#
# Usage: ./deactivate_access.sh --host HOST --remote-user ADMIN [--port PORT]
#
# Requires --remote-user (admin account with sudo on the remote host).
# agentuser's own sudo cannot be used since it locks itself out.

set -euo pipefail

PORT=22
REMOTE_USER=""
HOST=""

usage() {
  cat <<EOF
Usage: $0 --host HOST --remote-user ADMIN [--port PORT]

  --host          Remote hostname (required)
  --remote-user   Admin user with sudo on the remote (required)
  --port          SSH port (default: 22)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)         HOST="$2";        shift 2 ;;
    --remote-user)  REMOTE_USER="$2"; shift 2 ;;
    --port)         PORT="$2";        shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

[[ -z "$HOST" ]]        && { echo "Missing --host"; usage; exit 1; }
[[ -z "$REMOTE_USER" ]] && { echo "Missing --remote-user"; usage; exit 1; }

LOGGER="$(dirname "$0")/session_logger.sh"
[[ -x "$LOGGER" ]] && "$LOGGER" plan "deactivate_access --host ${HOST} --remote-user ${REMOTE_USER}" || true

echo "==> Deactivating agentuser on ${HOST} (shell → nologin)"

NOLOGIN=$(ssh -p "$PORT" -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${HOST}" \
  'command -v nologin || ls /usr/sbin/nologin 2>/dev/null || ls /sbin/nologin 2>/dev/null | head -1')

if [[ -z "$NOLOGIN" ]]; then
  echo "ERROR: Could not find nologin binary on remote host." >&2
  exit 1
fi

ssh -p "$PORT" -o BatchMode=yes "${REMOTE_USER}@${HOST}" "sudo usermod -s ${NOLOGIN} agentuser"

[[ -x "$LOGGER" ]] && "$LOGGER" cmd "deactivate_access: usermod -s nologin agentuser on ${HOST}" || true
echo "    agentuser deactivated — SSH key login is now blocked."
echo "    User and keys are preserved. Reactivate with: ./activate_access.sh --host ${HOST} --remote-user ${REMOTE_USER}"
