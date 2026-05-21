AGENT INSTRUCTIONS — agent-ssh-access
========================================

These are the only allowed agent behaviors for this repository.
Follow them exactly. Obtain explicit human approval before executing anything.

Read order (required before any action)
----------------------------------------
1. Read this file.
2. Read `hosts/<host>.md` and extract:
   - Hostname, Port, User, Key (local path)
   - SAFE_PATHS — the only paths you may read on the remote host
3. Check whether `mounts/<host>/` is currently mounted (look for files inside).
   - If mounted: confirm SAFE_PATHS from the host file still apply.
   - If not mounted: propose a mount command and wait for `go`.

Allowed actions
---------------
- Read local files under `agent-ssh-access/`.
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
  package installs), write an Audit line to `session.log` BEFORE requesting `go`:
  `YYYY-MM-DDTHH:MM:SSZ | PLAN | <short description>`
- After receiving `go`, append a CONFIRMED line before executing:
  `YYYY-MM-DDTHH:MM:SSZ | CONFIRMED | <user>`

Agent mode envvar
-----------------
Scripts check `AGENT_SESSION`. Set it before running scripts to activate the
interactive approval gate:
  ```
  export AGENT_SESSION=1
  ./mount_sshfs.sh --host <HOST> --port <PORT>
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
./test_login.sh --host <HOST> --port <PORT> --key ~/.ssh/id_agentuser
# or as one-liners:
ssh -i ~/.ssh/id_agentuser -p <PORT> agentuser@<HOST> 'whoami; id'
ssh -i ~/.ssh/id_agentuser -p <PORT> agentuser@<HOST> 'sudo -l'
```

Scripts (only after `go`)
--------------------------
```bash
./create_access.sh  --host <HOST> --port <PORT> --remote-user <ADMIN_USER>
./mount_sshfs.sh    --host <HOST> --port <PORT> [--user agentuser] [--key ~/.ssh/id_agentuser]
./unmount.sh        --host <HOST>
./revoke_access.sh  --host <HOST> --port <PORT> --remote-user agentuser [--force-remove-all]
./test_login.sh     --host <HOST> --port <PORT> --key ~/.ssh/id_agentuser
```

Logging
-------
All proposed actions go to `session.log` via `session_logger.sh`.
Use `session_logger.sh <level> <message>` with levels: plan, confirmed, cmd, info.

Adding a new host
-----------------
Create `hosts/<hostname>.md` from `hosts/HOST_TEMPLATE.md`. Define SAFE_PATHS
explicitly and minimally. Then run `create_access.sh`.
