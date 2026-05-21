---
name: agent-ssh-access
description: Use this skill when the user wants to connect to, manage, inspect, or run commands on a remote Raspberry Pi or Linux server via SSH. Works with Claude Code and OpenCode. Triggers on phrases like "check the pi", "ssh into the server", "connect to mypi", "mount the pi", "run a command on the server", "check docker on the pi", "restart a service on the remote host", "is the pi reachable", "what's running on the server", "show containers on the pi", "ssh into the server", or any request to work with a remote host defined in a agent-ssh-access/ project. Also use when the user mentions /agent-ssh-access or asks about the agent access tool.
argument-hint: [host]
compatibility: [claude-code, opencode]
allowed-tools: [Read, Write, Bash, Glob, Grep, Edit]
applyTo: '**'
usage: |
  check the pi
  /agent-ssh-access mypi
  is docker running on the pi?
  restart nginx on the server
  show me the logs on the server
  is the pi reachable?
  what's running on the server?
  ssh into the pi and check disk space
  show me the containers on the pi
---

# agent-ssh-access Skill

Safe, auditable SSH access to remote Linux hosts (Raspberry Pi or any server) with mandatory plan/go approval before every action. Works with Claude Code and OpenCode.

## Startup sequence (run every time)

### 1. Find the project

Search in order — use the first match found:

**1a. Verzeichnisbaum** — from cwd upward:
```bash
find . -maxdepth 4 -type d -name "agent-ssh-access" 2>/dev/null | head -1
```

**1b. Global config fallback** — if nothing found above:
```bash
ls ~/.config/agent-ssh-access/hosts/ 2>/dev/null
```
If `~/.config/agent-ssh-access/` exists, use it as `PROJECT`.

If neither found: tell the user and stop with this guidance:
```
No agent-ssh-access project found. Either:
  • Run Claude from a directory that contains agent-ssh-access/
  • Or create a global config: mkdir -p ~/.config/agent-ssh-access/hosts
    and copy your host file there
```
Set `PROJECT=<path-to-agent-ssh-access>`.

### 2. Resolve the host

List configured hosts (excluding the template):
```bash
ls $PROJECT/hosts/*.md | grep -v HOST_TEMPLATE
```

If no host files exist, tell the user and stop with this guidance:
```
No host configured yet. To add one:

  cp $PROJECT/hosts/HOST_TEMPLATE.md $PROJECT/hosts/<hostname>.md

Fill in Hostname, Port, User, Key, and SAFE_PATHS, then run:

  $PROJECT/create_access.sh --host <hostname> --port <port> --remote-user <your-admin-user> [--full-sudo]

See README.md for the full setup walkthrough.
```

**With argument** (e.g. `/agent-ssh-access mypi`): use `$PROJECT/hosts/<arg>.md`. If that file does not exist, show the same guidance above with `<hostname>` filled in as the argument the user provided.

**No argument and one host found**: use it automatically.

**No argument and multiple hosts found**: list them and ask which to use.

Read the host file and extract:
- `Hostname`, `Port`, `User`, `Key`
- `SAFE_PATHS` — the only remote paths you may read
- `Notes` — important context (sudo rules, running services, group memberships)

### 3. Status check (no go needed)

Run both checks in parallel and show a compact summary:

```bash
# Mount check
ls $PROJECT/mounts/<Hostname>/ 2>/dev/null | head -3

# SSH reachability (10s timeout, no interactive prompts)
ssh -i <Key> -p <Port> -o BatchMode=yes -o ConnectTimeout=10 <User>@<Hostname> 'echo ok'
```

Output format:
```
Host:       <hostname> (port <port>)
User:       <user>  |  Key: <key>
Mount:      ✓ active  /  ✗ not mounted
SSH:        ✓ reachable  /  ✗ unreachable
SAFE_PATHS: <list>
Notes:      <from host file>
```

Then ask the user what they want to do — or if their original message already stated a task, proceed directly to planning it.

---

## Plan / go protocol (mandatory for every action)

Before executing anything:

1. Print a numbered plan (1–3 steps) under the heading **Plan:**
2. For privileged steps (sudo, service restarts, package installs, sudoers edits):
   - Log to session.log BEFORE requesting go:
     `$PROJECT/session_logger.sh plan "<short description>"`
3. Wait for the exact word **go** on its own line
4. After go:
   - Log confirmed: `$PROJECT/session_logger.sh confirmed "<user>"`
   - Execute the listed commands without asking again
5. If the plan changes at any point, print a new Plan and request a new go

Never execute without an explicit go. If the user types anything other than `go`, treat it as a new instruction — do not proceed.

---

## Available actions

### Mount SSHFS
```bash
$PROJECT/mount_sshfs.sh --host <Hostname> --port <Port>
```
After mounting, SAFE_PATHS apply to all reads within `mounts/<Hostname>/`.

### Unmount
```bash
$PROJECT/unmount.sh --host <Hostname>
```

### Run SSH command (non-privileged)
```bash
ssh -i <Key> -p <Port> -o BatchMode=yes <User>@<Hostname> '<command>'
```
Only propose commands that read from SAFE_PATHS or that the user explicitly requested.

### Run SSH command (privileged / sudo)
```bash
ssh -i <Key> -p <Port> -o BatchMode=yes <User>@<Hostname> 'sudo <command>'
```
Audit log required before go. Check Notes in the host file for sudo rules.

### Test login
```bash
$PROJECT/test_login.sh --host <Hostname> --port <Port> --key <Key>
```

### Revoke access
```bash
$PROJECT/revoke_access.sh --host <Hostname> --port <Port> --remote-user <User> [--force-remove-all]
```

---

## SAFE_PATHS enforcement

Only read or reference files on the remote host that fall under the SAFE_PATHS listed in the host file.

If the user requests something outside SAFE_PATHS: decline, explain why, and suggest adding the path to the host file if appropriate.

---

## Forbidden actions (no exceptions)

- Never store or request private keys, passwords, or secrets
- Never read paths outside SAFE_PATHS on the remote host
- Never execute remote commands without an explicit go
- Never write or modify files in the project directory without user approval

---

## Adding a new host

1. Copy `$PROJECT/hosts/HOST_TEMPLATE.md` → `$PROJECT/hosts/<hostname>.md`
2. Fill in: Hostname, Port, User, Key, SAFE_PATHS, Notes
3. Run `$PROJECT/create_access.sh --host <HOST> --port <PORT> --remote-user <ADMIN>`
4. Test with `./test_login.sh`

---

## Logging

All proposed and confirmed actions go to `$PROJECT/session.log` via `session_logger.sh`.

Levels: `plan`, `confirmed`, `cmd`, `info`

```bash
$PROJECT/session_logger.sh info "connected to mypi, docker ps checked"
```
