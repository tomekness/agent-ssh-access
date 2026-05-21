#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --host HOST [--mountroot DIR] [--force] [--sudo-fallback]

Unmounts the SSHFS mount for a host.

Options:
  --host           Remote hostname (required)
  --mountroot      Local mount root (default: <script-dir>/mounts)
  --force          Try fusermount3 -uz first to clear stale mounts
  --sudo-fallback  Use sudo umount -l if non-privileged unmount fails (requires approval)
EOF
}

MOUNTROOT="$(dirname "$0")/mounts"
FORCE=0
SUDO_FALLBACK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)          HOST="$2";       shift 2 ;;
    --mountroot)     MOUNTROOT="$2";  shift 2 ;;
    --force)         FORCE=1;         shift 1 ;;
    --sudo-fallback) SUDO_FALLBACK=1; shift 1 ;;
    -h|--help)       usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

[[ -z "${HOST:-}" ]] && { echo "Missing --host"; usage; exit 1; }

MOUNTPOINT="$MOUNTROOT/$HOST"
LOGGER="$(dirname "$0")/session_logger.sh"

[[ -x "$LOGGER" ]] && "$LOGGER" plan "unmount --host ${HOST} --force=${FORCE} --sudo-fallback=${SUDO_FALLBACK}" || true

if [[ -n "${AGENT_SESSION:-}" ]] && [[ "$SUDO_FALLBACK" -eq 1 ]]; then
  echo "sudo-fallback requested. Awaiting 'go' approval for privileged unmount..."
  read -r APPROVAL
  if [[ "$APPROVAL" != "go" ]]; then
    echo "Approval not received. Aborting." >&2
    exit 2
  fi
  [[ -x "$LOGGER" ]] && "$LOGGER" confirmed "agent" || true
fi

echo "Unmounting $MOUNTPOINT"

[[ "$FORCE" -eq 1 ]] && fusermount3 -uz "$MOUNTPOINT" 2>/dev/null || true

if umount "$MOUNTPOINT" 2>/dev/null; then
  echo "Unmounted."
elif [[ "$SUDO_FALLBACK" -eq 1 ]]; then
  echo "Attempting privileged lazy unmount: sudo umount -l $MOUNTPOINT"
  sudo umount -l "$MOUNTPOINT"
  echo "Unmounted (lazy)."
else
  echo "Unmount failed. Re-run with --force --sudo-fallback to allow privileged lazy unmount."
  exit 1
fi

[[ -x "$LOGGER" ]] && "$LOGGER" cmd "unmount $MOUNTPOINT (force=${FORCE}, sudo-fallback=${SUDO_FALLBACK})" || true
