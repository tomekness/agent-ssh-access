#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --host HOST [--port PORT] [--remote-user USER] [--keyname KEYNAME] [--full-sudo]

Creates a local ed25519 keypair, copies the public key to the remote host, and prints
the exact commands to run on the remote to finish creating the agentuser account.

Options:
  --host          Remote hostname (required)
  --port          SSH port (default: 22)
  --remote-user   Admin user on the remote used to copy the key (default: agentuser)
  --keyname       Local key filename under ~/.ssh/ (default: id_agentuser)
  --full-sudo     Include NOPASSWD: ALL sudoers line in the printed instructions
EOF
}

PORT=22
REMOTE_USER=agentuser
KEYNAME=id_agentuser
FULL_SUDO=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)         HOST="$2";        shift 2 ;;
    --port)         PORT="$2";        shift 2 ;;
    --remote-user)  REMOTE_USER="$2"; shift 2 ;;
    --keyname)      KEYNAME="$2";     shift 2 ;;
    --full-sudo)    FULL_SUDO=1;      shift 1 ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

[[ -z "${HOST:-}" ]] && { echo "Missing --host"; usage; exit 1; }

KEY_PATH="$HOME/.ssh/${KEYNAME}"
PUB_PATH="${KEY_PATH}.pub"

if [[ ! -f "$KEY_PATH" ]]; then
  echo "Generating key $KEY_PATH"
  ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "${KEYNAME}"
  chmod 600 "$KEY_PATH"
fi

TMPFILE="/tmp/${KEYNAME}_$$.pub"
echo "Copying public key to ${REMOTE_USER}@${HOST}:${TMPFILE}"
scp -P "$PORT" "$PUB_PATH" "${REMOTE_USER}@${HOST}:${TMPFILE}"

MOUNT_DIR="$(dirname "$0")/mounts/${HOST}"
mkdir -p "$MOUNT_DIR"

LOGGER="$(dirname "$0")/session_logger.sh"
[[ -x "$LOGGER" ]] && "$LOGGER" plan "create_access --host ${HOST} --port ${PORT} --key ${KEYNAME}" || true

cat <<MSG

Public key copied to ${REMOTE_USER}@${HOST}:${TMPFILE}

Run the following on the remote host as an admin user:

  sudo useradd -m -s /bin/bash agentuser || echo "agentuser exists"
  sudo mkdir -p /home/agentuser/.ssh
  sudo tee -a /home/agentuser/.ssh/authorized_keys < ${TMPFILE} > /dev/null
  sudo chown -R agentuser:agentuser /home/agentuser/.ssh
  sudo chmod 700 /home/agentuser/.ssh
  sudo chmod 600 /home/agentuser/.ssh/authorized_keys
  sudo rm -f ${TMPFILE}
MSG

if [[ "$FULL_SUDO" -eq 1 ]]; then
  cat <<MSG

WARNING: --full-sudo grants NOPASSWD: ALL — a compromised SSH key means root access.
Consider scoped grants instead, e.g.:
  agentuser ALL=(ALL) NOPASSWD: /usr/bin/docker, /bin/systemctl

To grant full passwordless sudo, run on the remote host:

  echo 'agentuser ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/agentuser
  sudo chmod 440 /etc/sudoers.d/agentuser
  sudo visudo -c
MSG
fi

cat <<MSG

Test the new account:

  ssh -i ${KEY_PATH} -p ${PORT} agentuser@${HOST} 'whoami; id'
  ssh -i ${KEY_PATH} -p ${PORT} agentuser@${HOST} 'sudo -l'
MSG

GENERATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "$MOUNT_DIR/meta.json" <<JSON
{
  "host": "${HOST}",
  "port": ${PORT},
  "user": "agentuser",
  "keyPath": "~/.ssh/${KEYNAME}",
  "mountPoint": "${MOUNT_DIR}",
  "fullSudo": ${FULL_SUDO},
  "generated_at": "${GENERATED_AT}"
}
JSON

echo "Wrote metadata to $MOUNT_DIR/meta.json"

if [[ -n "${AGENT_SESSION:-}" ]]; then
  echo "Awaiting 'go' approval to confirm create_access plan..."
  read -r APPROVAL
  if [[ "$APPROVAL" != "go" ]]; then
    echo "Approval not received. Aborting." >&2
    exit 2
  fi
  [[ -x "$LOGGER" ]] && "$LOGGER" confirmed "agent" || true
fi
