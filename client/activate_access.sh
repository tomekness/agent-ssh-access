#!/usr/bin/env bash
# Remotely reactivate agentuser by restoring shell to /bin/bash.
# Use after deactivate_access.sh.
#
# Usage: ./activate_access.sh --host HOST --remote-user ADMIN [--port PORT]
#
# Requires --remote-user (admin account with sudo on the remote host).

set -euo pipefail

PORT=22
REMOTE_USER=""
HOST=""
SHELL_PATH="/bin/bash"

usage() {
  cat <<EOF
Usage: $0 --host HOST --remote-user ADMIN [--port PORT] [--shell PATH]

  --host          Remote hostname (required)
  --remote-user   Admin user with sudo on the remote (required)
  --port          SSH port (default: 22)
  --shell         Shell to restore (default: /bin/bash)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)         HOST="$2";       shift 2 ;;
    --remote-user)  REMOTE_USER="$2"; shift 2 ;;
    --port)         PORT="$2";       shift 2 ;;
    --shell)        SHELL_PATH="$2"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

[[ -z "$HOST" ]]        && { echo "Missing --host"; usage; exit 1; }
[[ -z "$REMOTE_USER" ]] && { echo "Missing --remote-user"; usage; exit 1; }

LOGGER="$(dirname "$0")/session_logger.sh"
[[ -x "$LOGGER" ]] && "$LOGGER" plan "activate_access --host ${HOST} --remote-user ${REMOTE_USER}" || true

echo "==> Activating agentuser on ${HOST} (shell → ${SHELL_PATH})"

ssh -p "$PORT" -o BatchMode=yes "${REMOTE_USER}@${HOST}" "sudo usermod -s ${SHELL_PATH} agentuser"

[[ -x "$LOGGER" ]] && "$LOGGER" cmd "activate_access: usermod -s ${SHELL_PATH} agentuser on ${HOST}" || true
echo "    agentuser activated — SSH key login is restored."
