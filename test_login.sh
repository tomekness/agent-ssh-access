#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --host HOST [--port PORT] [--user USER] --key PATH

Tests non-interactive SSH login and sudo access for the agent user.

Options:
  --host   Remote hostname (required)
  --port   SSH port (default: 22)
  --user   Remote user to test (default: agentuser)
  --key    Local private key path (required)
EOF
}

PORT=22
USER=agentuser
KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)  HOST="$2"; shift 2 ;;
    --port)  PORT="$2"; shift 2 ;;
    --user)  USER="$2"; shift 2 ;;
    --key)   KEY="$2";  shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

[[ -z "${HOST:-}" || -z "$KEY" ]] && { usage; exit 1; }

LOGGER="$(dirname "$0")/session_logger.sh"

if [[ -n "${AGENT_SESSION:-}" ]]; then
  echo "Testing login to ${HOST} as ${USER}. Awaiting 'go' approval..."
  [[ -x "$LOGGER" ]] && "$LOGGER" plan "test_login --host ${HOST} --port ${PORT} --user ${USER} --key ${KEY}" || true
  read -r APPROVAL
  if [[ "$APPROVAL" != "go" ]]; then
    echo "Approval not received. Aborting." >&2
    exit 2
  fi
  [[ -x "$LOGGER" ]] && "$LOGGER" confirmed "agent" || true
fi

echo "Testing SSH login: ${USER}@${HOST} (port $PORT)"
ssh -i "$KEY" -p "$PORT" -o BatchMode=yes -o ConnectTimeout=10 "${USER}@${HOST}" 'whoami; id' || {
  echo "Login failed." >&2; exit 2
}

echo "Testing sudo (non-interactive)"
ssh -i "$KEY" -p "$PORT" -o BatchMode=yes -o ConnectTimeout=10 "${USER}@${HOST}" 'sudo -l' || {
  echo "sudo check failed." >&2; exit 3
}

echo "All tests passed."
