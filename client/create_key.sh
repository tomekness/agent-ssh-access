#!/usr/bin/env bash
# Generate a local ed25519 keypair for agentuser.
# Run this once on your agent machine before provisioning any server.
#
# Usage: ./create_key.sh [--keyname NAME]
#
# The public key is printed at the end — pipe it to server_setup/01_install.sh
# on the remote host to complete the setup.

set -euo pipefail

KEYNAME="id_agentuser"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keyname) KEYNAME="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--keyname NAME]"
      echo "  --keyname   Key filename under ~/.ssh/ (default: id_agentuser)"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

KEY_PATH="$HOME/.ssh/${KEYNAME}"
PUB_PATH="${KEY_PATH}.pub"

if [[ -f "$KEY_PATH" ]]; then
  echo "==> Key already exists: $KEY_PATH — skipping generation."
  echo "    Delete it first if you want a new key: rm $KEY_PATH ${PUB_PATH}"
else
  echo "==> Generating key: $KEY_PATH"
  ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "$KEYNAME"
  chmod 600 "$KEY_PATH"
  echo "    Done."
fi

echo ""
echo "Public key:"
echo "------------------------------------------------------------"
cat "$PUB_PATH"
echo "------------------------------------------------------------"
echo ""
echo "Next steps:"
echo "  1. Copy server_setup/ to the remote host:"
echo "     scp -r server_setup/ admin@SERVER:~/"
echo ""
echo "  2. Install agentuser on the remote:"
echo "     cat $PUB_PATH | ssh admin@SERVER 'sudo bash ~/server_setup/01_install.sh [--sudo]'"
