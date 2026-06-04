AGENT INSTRUCTIONS — agent-ssh-access
========================================

These are the only allowed agent behaviors for this repository.
Follow them exactly. Obtain explicit human approval before executing anything.

Read order (required before any action)
----------------------------------------
1. Read this file.
2. Read `client/hosts/<host>.md` and extract:
   - Hostname, Port, User, Key (local path)
   - SAFE_PATHS — the only paths you may read on the remote host
3. Check whether `client/mounts/<host>/` is currently mounted (look for files inside).
   - If mounted: confirm SAFE_PATHS from the host file still apply.
   - If not mounted: propose a mount command and wait for `go`.

Allowed actions
---------------
- Read local files under `agent-ssh-access/client/`.
- Read remote files only within SAFE_PATHS.
- Propose exact, single-line shell commands.
- Execute commands only after explicit human `go`.

Plan / go protocol
------------------
- Before any action, print a numbered Plan (1–3 steps) under the heading "Plan:".
- Wait for the exact word `go` on its own line before executing.
- After `go`, execute the listed commands without asking again — unless the Plan changes.
- If the Plan changes (steps added, removed, or reordered), print a new Plan and request a new `go`.

Privileged actions
------------------
- Never perform system-wide changes without explicit human approval.
- For any Plan that includes root/privileged steps (sudoers edits, service restarts,
  package installs), write an Audit line to `client/session.log` BEFORE requesting `go`:
  `YYYY-MM-DDTHH:MM:SSZ | PLAN | <short description>`
  Write to `client/session.log` via `client/session_logger.sh plan "<description>"`
- After receiving `go`, append a CONFIRMED line before executing:
  `YYYY-MM-DDTHH:MM:SSZ | CONFIRMED | <user>`
  Write via `client/session_logger.sh confirmed "<user>"`

Agent mode envvar
-----------------
Scripts check `AGENT_SESSION`. Set it before running scripts to activate the
interactive approval gate:
  ```
  export AGENT_SESSION=1
  ./client/mount_sshfs.sh --host <HOST> --port <PORT>
  ```

Failure modes
-------------
- If you do not receive `go`, abort — do not attempt execution.
- If the user supplies a credential or secret, stop immediately and instruct them
  to remove and rotate it. Do not store secrets.

Forbidden actions (no exceptions)
----------------------------------
- Never request or store private keys, passwords, or secrets.
- Never write or modify files in this directory without explicit user approval.
- Never execute unapproved commands on the remote host.
- Never read paths outside SAFE_PATHS on the remote host.

Testing a login
---------------
```bash
./client/test_login.sh --host <HOST> --port <PORT> --key ~/.ssh/id_agentuser
# or as one-liners:
ssh -i ~/.ssh/id_agentuser -p <PORT> agentuser@<HOST> 'whoami; id'
ssh -i ~/.ssh/id_agentuser -p <PORT> agentuser@<HOST> 'sudo -l'
```

Scripts (only after `go`)
--------------------------
```bash
./client/create_key.sh
./client/activate_access.sh   --host <HOST> --remote-user <ADMIN_USER> [--port PORT]
./client/deactivate_access.sh --host <HOST> --remote-user <ADMIN_USER> [--port PORT]
./client/revoke_access.sh     --host <HOST> --port <PORT> --remote-user <ADMIN_USER> [--force-remove-all]
./client/mount_sshfs.sh       --host <HOST> --port <PORT> [--user agentuser] [--key ~/.ssh/id_agentuser]
./client/unmount.sh           --host <HOST>
./client/test_login.sh        --host <HOST> --port <PORT> --key ~/.ssh/id_agentuser
```

Logging
-------
All proposed actions go to `client/session.log` via `client/session_logger.sh`.
Use `client/session_logger.sh <level> <message>` with levels: plan, confirmed, cmd, info.

Adding a new host
-----------------
1. Run `client/create_key.sh` (once — skipped if key exists)
2. Copy `server_setup/` to the remote: `scp -r server_setup/ admin@HOST:~/`
3. Install: `cat ~/.ssh/id_agentuser.pub | ssh admin@HOST 'sudo bash ~/server_setup/01_install.sh'`
4. Create `client/hosts/<hostname>.md` from `client/hosts/HOST_TEMPLATE.md` and fill in details.
